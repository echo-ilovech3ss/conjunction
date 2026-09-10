#!/usr/bin/env python3
"""
conjunction-runner — Containerized Windows Application Runner for Conjunction OS.

A Python daemon that manages isolated Wine/Proton containers for running Windows
applications on Linux with near-native performance. Each application receives its
own pristine Wine prefix with injected runtimes, GPU passthrough, and a synthesized
desktop shortcut.

Dependencies:
    Required:
        wine          — Windows compatibility layer (>= 7.0 recommended)
        winetricks    — Win32 resource installer for Wine prefixes
    Optional:
        imagemagick   — Icon conversion (.ico → .png) for desktop entries
        Pillow        — Fallback icon converter if imagemagick is unavailable
        btrfs-progs   — Prefix snapshot/restore via Btrfs subvolumes
        proton         — Valve Proton runner (used in preference to plain wine)
        pipewire      — Low-latency audio server support
    Python (>= 3.9):
        No third-party packages required; uses only the standard library.
"""

from __future__ import annotations

import argparse
import contextlib
import json
import logging
import os
import platform
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timedelta
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple


# ---------------------------------------------------------------------------
# Path Resolution Helper
# ---------------------------------------------------------------------------

def get_user_home() -> Path:
    """Dynamically resolves the user's home directory.
    
    Checks the SUDO_USER environment variable to avoid resolving /root when run under sudo.
    Validates that the path is absolute, exists, and is a directory.
    """
    sudo_user = os.environ.get("SUDO_USER")
    home_path = None

    if sudo_user:
        try:
            import pwd
            home_path = Path(pwd.getpwnam(sudo_user).pw_dir)
        except (ImportError, KeyError):
            hp = Path("/home") / sudo_user
            if hp.exists() and hp.is_dir():
                home_path = hp

    if not home_path:
        home = os.environ.get("HOME")
        if home and home not in (".", "", "/"):
            hp = Path(home)
            if hp.is_absolute():
                home_path = hp

    if not home_path:
        try:
            hp = os.path.expanduser("~")
            if hp and hp not in (".", "", "/"):
                hp_path = Path(hp)
                if hp_path.is_absolute():
                    home_path = hp_path
        except Exception:
            pass

    if not home_path:
        try:
            hp_path = Path.home()
            if hp_path.is_absolute() and str(hp_path) not in (".", "", "/"):
                home_path = hp_path
        except Exception:
            pass

    # If still unresolved, or invalid path (like root / or empty)
    if not home_path or str(home_path) in (".", "", "/") or not home_path.is_absolute():
        raise RuntimeError("Invalid or unresolved home directory")

    # If the path exists but is not a directory, it's invalid!
    if home_path.exists() and not home_path.is_dir():
        raise RuntimeError(f"Resolved home path is not a directory: {home_path}")

    return home_path


def redact_sensitive_info(text: str) -> str:
    user_home = str(get_user_home())
    username = get_user_home().name
    
    redacted = text.replace(user_home, "/home/<user>")
    redacted = redacted.replace(username, "<user>")
    redacted = re.sub(r'(--password\s+)(\S+)', r'\1<redacted>', redacted)
    redacted = re.sub(r'(:[^@:]+@)', r':<redacted>@', redacted)
    return redacted


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

APP_NAME = "conjunction-runner"
VERSION = "0.1.0"

BASE_DIR = get_user_home() / ".conjunction"
PREFIX_DIR = BASE_DIR / "prefixes"
APPS_DIR = BASE_DIR / "apps"
LOG_DIR = BASE_DIR / "logs"
CACHE_DIR = BASE_DIR / "cache"
CRASH_DIR = BASE_DIR / "crash-reports"
EXPORTS_DIR = BASE_DIR / "exports"
CONFIG_DIR = BASE_DIR / "config"
DESKTOP_DIR = get_user_home() / ".local" / "share" / "applications"

# Visual C++ Redistributable URLs (2015-2022 combined)
VC_REDIST_URLS: Dict[str, str] = {
    "x64": "https://aka.ms/vs/17/release/vc_redist.x64.exe",
    "x86": "https://aka.ms/vs/17/release/vc_redist.x86.exe",
}

# Wine component IDs for winetricks
WINE_COMPONENTS: List[str] = [
    "corefonts",
    "msxml3",
    "mshtml",
]

# Windows Media Component component IDs
MEDIA_COMPONENTS: List[str] = [
    "wmp90",
]


# ---------------------------------------------------------------------------
# File locking and atomic write helpers
# ---------------------------------------------------------------------------

try:
    import fcntl
except ImportError:
    fcntl = None


@contextlib.contextmanager
def _file_lock(file_path: Path):
    """Acquires an exclusive lock on a file using fcntl (Unix-only)."""
    lock_file_path = file_path.with_suffix(file_path.suffix + ".lock")
    try:
        lock_file = open(lock_file_path, "w")
    except Exception:
        yield
        return
    try:
        if fcntl:
            try:
                fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
            except IOError:
                pass
        yield
    finally:
        if fcntl:
            try:
                fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN)
            except IOError:
                pass
        lock_file.close()
        try:
            lock_file_path.unlink(missing_ok=True)
        except OSError:
            pass


def _atomic_write(file_path: Path, content: str) -> None:
    """Writes content to a file atomically using a temporary file and os.replace,
    protected by an exclusive fcntl file lock.
    """
    file_path.parent.mkdir(parents=True, exist_ok=True)
    with _file_lock(file_path):
        fd, temp_path_str = tempfile.mkstemp(dir=str(file_path.parent), prefix=file_path.name + ".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write(content)
                f.flush()
                os.fsync(fd)
            os.replace(temp_path_str, str(file_path))
        except Exception:
            try:
                os.unlink(temp_path_str)
            except OSError:
                pass
            raise


# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------

class JsonFormatter(logging.Formatter):
    """Structured JSON formatter for application logs."""
    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.fromtimestamp(record.created).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        session_id = getattr(logging, "session_id", None)
        if session_id:
            log_entry["session_id"] = session_id
        elif hasattr(record, "session_id"):
            log_entry["session_id"] = record.session_id
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_entry)


def _setup_logging() -> logging.Logger:
    """Configure file and console logging for the runner daemon."""
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_file = LOG_DIR / "runner.log"

    logger = logging.getLogger("conjunction-runner")
    logger.setLevel(logging.DEBUG)

    # Prevent handler accumulation on reload/re-setup
    if not logger.handlers:
        # File handler — detailed, rotated (max 10MB, 5 backups), JSON format
        fh = RotatingFileHandler(
            log_file,
            maxBytes=10 * 1024 * 1024,
            backupCount=5,
            encoding="utf-8"
        )
        fh.setLevel(logging.DEBUG)
        fh.setFormatter(JsonFormatter())
        logger.addHandler(fh)

        # Console handler — info and above, plain text
        ch = logging.StreamHandler()
        ch.setLevel(logging.INFO)
        ch.setFormatter(logging.Formatter("%(levelname)s: %(message)s"))
        logger.addHandler(ch)

    return logger


log = _setup_logging()


# ---------------------------------------------------------------------------
# Centralized Configuration
# ---------------------------------------------------------------------------

class ConjunctionConfig:
    """Centralized configuration manager for Conjunction.
    
    Loads and saves configuration keys from ~/.config/conjunction/config.json.
    Provides safe defaults, validates paths, and falls back to auto-detection.
    """
    DEFAULTS = {
        "wine_path": None,
        "proton_path": None,
        "winetricks_path": None,
        "dxvk_hud": "fps",
        "esync": True,
        "fsync": True,
        "wine_debug": "-all",
    }

    def __init__(self, config_path: Optional[Path] = None) -> None:
        if config_path is None:
            config_path = get_user_home() / ".config" / "conjunction" / "config.json"
        self.config_path = config_path
        self._data = self.DEFAULTS.copy()
        self.load()
        if not self.config_path.exists():
            self.save()

    def load(self) -> None:
        if not self.config_path.exists():
            return
        try:
            with open(self.config_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict):
                    self._data.update(data)
        except Exception as exc:
            log.warning("Failed to load config from %s: %s. Using defaults.", self.config_path, exc)

    def save(self) -> None:
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            _atomic_write(self.config_path, json.dumps(self._data, indent=2))
        except Exception as exc:
            log.error("Failed to save config to %s: %s", self.config_path, exc)

    def get(self, key: str) -> Any:
        val = self._data.get(key, self.DEFAULTS.get(key))
        # Path validation and fallback handling for path-based keys
        if key in ("wine_path", "proton_path", "winetricks_path") and val is not None:
            path = Path(val)
            if not path.exists():
                log.warning("Configured %s path '%s' does not exist. Falling back.", key, val)
                return None
            return str(path.resolve())
        return val

    def set(self, key: str, value: Any) -> None:
        self._data[key] = value
        self.save()


# ---------------------------------------------------------------------------
# Exceptions
# ---------------------------------------------------------------------------

class ConjunctionError(Exception):
    """Base exception for all Conjunction runner errors."""


class WineNotFoundError(ConjunctionError):
    """Raised when Wine or Proton is not installed on the system."""


class PrefixError(ConjunctionError):
    """Raised when a Wine prefix cannot be created or accessed."""


class AppNotFoundError(ConjunctionError):
    """Raised when a requested application is not registered."""


class RuntimeInstallError(ConjunctionError):
    """Raised when a runtime component fails to install."""


class GPUError(ConjunctionError):
    """Raised when GPU configuration or detection fails."""


# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------

def _run_cmd(
    args: Sequence[str],
    *,
    env: Optional[Dict[str, str]] = None,
    capture: bool = True,
    check: bool = True,
    timeout: Optional[int] = None,
) -> subprocess.CompletedProcess[str]:
    """Execute a shell command with consistent error handling.

    Args:
        args: Command and arguments.
        env: Extra environment variables merged onto the current environment.
        capture: If True, capture stdout/stderr.
        check: If True, raise on non-zero exit.
        timeout: Optional timeout in seconds.

    Returns:
        CompletedProcess result.

    Raises:
        subprocess.CalledProcessError: When check=True and the process fails.
    """
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)

    log.debug("exec: %s", " ".join(args))
    try:
        result = subprocess.run(
            args,
            env=merged_env,
            capture_output=capture,
            text=True,
            check=check,
            timeout=timeout,
        )
        return result
    except subprocess.CalledProcessError as exc:
        log.error("Command failed (rc=%d): %s", exc.returncode, " ".join(args))
        if exc.stderr:
            log.error("stderr: %s", exc.stderr.strip())
        raise
    except FileNotFoundError:
        log.error("Command not found: %s", args[0])
        raise


def _which(name: str) -> Optional[str]:
    """Return the path to *name* if it exists on PATH, else None."""
    return shutil.which(name)


def _is_btrfs(path: Path) -> bool:
    """Detect whether *path* resides on a Btrfs filesystem."""
    try:
        result = _run_cmd(["stat", "-f", "--format=%T", str(path)], check=False)
        return "btrfs" in result.stdout.strip().lower()
    except Exception:
        return False


def _snapshot_subvolume(source: Path, dest: Path) -> bool:
    """Create a Btrfs snapshot of *source* at *dest*. Returns True on success."""
    try:
        _run_cmd(["btrfs", "subvolume", "snapshot", str(source), str(dest)])
        log.info("Btrfs snapshot created: %s → %s", source, dest)
        return True
    except Exception as exc:
        log.warning("Btrfs snapshot failed: %s", exc)
        return False


def _delete_directory_or_subvolume(path: Path) -> None:
    """Deletes a directory or a Btrfs subvolume using native tools if possible."""
    if not path.exists():
        return
    if _is_btrfs(path):
        try:
            _run_cmd(["btrfs", "subvolume", "delete", str(path)])
            log.info("Deleted Btrfs subvolume: %s", path)
            return
        except Exception as exc:
            log.warning("btrfs subvolume delete failed for %s, falling back to rmtree: %s", path, exc)
            
    if path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink()
    log.info("Deleted directory/file: %s", path)


def _restore_snapshot(snapshot: Path, dest: Path) -> bool:
    """Restore a Btrfs snapshot, replacing the contents of *dest*."""
    try:
        if dest.exists():
            _delete_directory_or_subvolume(dest)
        _run_cmd(["btrfs", "subvolume", "snapshot", str(snapshot), str(dest)])
        log.info("Btrfs snapshot restored: %s → %s", snapshot, dest)
        return True
    except Exception as exc:
        log.warning("Btrfs snapshot restore failed: %s", exc)
        return False


# ---------------------------------------------------------------------------
# GPU / Audio detection helpers
# ---------------------------------------------------------------------------

def _detect_gpu_vendor() -> Optional[str]:
    """Detect the primary GPU vendor: 'nvidia', 'amd', 'intel', or None."""
    try:
        result = _run_cmd(
            ["lspci", "-nn"],
            check=False,
        )
        for line in result.stdout.splitlines():
            lower = line.lower()
            if "vga" in lower or "3d" in lower or "display" in lower:
                if "nvidia" in lower:
                    return "nvidia"
                if "amd" in lower or "ati" in lower:
                    return "amd"
                if "intel" in lower:
                    return "intel"
    except Exception:
        pass

    # Fallback: check for /dev/dri/card0 ownership via ls
    try:
        result = _run_cmd(["ls", "-la", "/dev/dri/"], check=False)
        for line in result.stdout.splitlines():
            if "card" in line:
                break
    except Exception:
        pass

    return None


def _detect_cuda() -> Optional[str]:
    """Return CUDA_PATH if an NVIDIA CUDA installation is detected."""
    # Check well-known paths
    for candidate in [
        "/usr/local/cuda",
        "/usr/local/cuda-12.0",
        "/usr/local/cuda-11.8",
        "/opt/cuda",
    ]:
        if Path(candidate).is_dir():
            return candidate
    # Check environment
    cuda_path = os.environ.get("CUDA_PATH")
    if cuda_path and Path(cuda_path).is_dir():
        return cuda_path
    return None


def _detect_opencl() -> Optional[str]:
    """Return OCL_ICD_FILENAMES path if OpenCL ICD loaders are found."""
    icd_dir = Path("/etc/OpenCL/vendors")
    if icd_dir.is_dir():
        icd_files = list(icd_dir.glob("*.icd"))
        if icd_files:
            return ":".join(str(f) for f in icd_files)
    return None


def _detect_audio_server() -> Optional[str]:
    """Detect the active audio server: 'pipewire', 'pulse', 'alsa', or None."""
    # Check PipeWire first (it wraps PulseAudio on modern systems)
    try:
        result = _run_cmd(["pgrep", "-x", "pipewire"], check=False)
        if result.returncode == 0:
            return "pipewire"
    except Exception:
        pass

    # Check PulseAudio
    try:
        result = _run_cmd(["pgrep", "-x", "pulseaudio"], check=False)
        if result.returncode == 0:
            return "pulse"
    except Exception:
        pass

    return "alsa"  # Fallback


def _detect_proton() -> Optional[str]:
    """Locate a Proton installation. Returns the proton binary path or None."""
    # Check common Steam Proton paths
    steam_dir = get_user_home() / ".steam" / "steam" / "steamapps" / "common"
    if steam_dir.is_dir():
        for proton_dir in sorted(steam_dir.glob("Proton *"), reverse=True):
            proton_bin = proton_dir / "proton"
            if proton_bin.exists():
                return str(proton_bin)

    # Check system path
    proton_path = _which("proton")
    if proton_path:
        return proton_path

    return None


# ---------------------------------------------------------------------------
# Desktop entry helpers
# ---------------------------------------------------------------------------

def _convert_ico_to_png(ico_path: Path, png_path: Path) -> bool:
    """Convert a .ico file to .png using imagemagick or Pillow frame seek loop."""
    # Try imagemagick first
    convert_bin = _which("convert")
    if convert_bin:
        try:
            _run_cmd([convert_bin, str(ico_path), str(png_path)])
            return True
        except Exception:
            pass

    # Fallback to Pillow using frame seek loop
    try:
        from PIL import Image
        img = Image.open(ico_path)
        
        largest_size = (0, 0)
        largest_frame = 0
        
        frame = 0
        while True:
            try:
                img.seek(frame)
                current_size = img.size
                if current_size[0] * current_size[1] > largest_size[0] * largest_size[1]:
                    largest_size = current_size
                    largest_frame = frame
                frame += 1
            except EOFError:
                break
                
        img.seek(largest_frame)
        png_path.parent.mkdir(parents=True, exist_ok=True)
        img.save(str(png_path), "PNG")
        return True
    except ImportError:
        log.warning("Neither imagemagick nor Pillow available for icon conversion")
    except Exception as exc:
        log.warning("Icon conversion failed: %s", exc)

    return False


def _detect_app_category(exe_name: str) -> str:
    """Heuristically determine the FreeDesktop category for an application."""
    name_lower = exe_name.lower()

    game_keywords = [
        "game", "steam", "epic", "battle", "riot", "launcher",
        "unity", "unreal", "dxgame", "dota", "fortnite",
    ]
    if any(kw in name_lower for kw in game_keywords):
        return "Game"

    media_keywords = [
        "vlc", "media", "player", "photo", "video", "audio",
        "spotify", "netflix", "youtube", "stream",
    ]
    if any(kw in name_lower for kw in media_keywords):
        return "AudioVideo;Video"

    office_keywords = [
        "office", "word", "excel", "powerpoint", "outlook",
        "teams", "slack", "discord", "zoom", "chat",
    ]
    if any(kw in name_lower for kw in office_keywords):
        return "Office;Chat"

    dev_keywords = [
        "code", "visual studio", "idea", "eclipse", "git",
        "terminal", "console", "dev",
    ]
    if any(kw in name_lower for kw in dev_keywords):
        return "Development;IDE"

    return "Utility"


def _generate_desktop_entry(
    app_name: str,
    exe_path: str,
    icon_path: Optional[str],
    prefix_path: Path,
    categories: str,
) -> Path:
    """Write a .desktop launcher file and return its path."""
    DESKTOP_DIR.mkdir(parents=True, exist_ok=True)

    desktop_file = DESKTOP_DIR / f"conjunction-{app_name}.desktop"

    exec_line = f"{sys.executable} {Path(__file__).resolve()} run {app_name}"

    contents = f"""[Desktop Entry]
Type=Application
Name={app_name}
Exec={exec_line}
Icon={icon_path or 'application-x-executable'}
Categories={categories};
Terminal=false
StartupNotify=true
Comment=Run {app_name} via Conjunction OS
"""

    _atomic_write(desktop_file, contents)
    desktop_file.chmod(desktop_file.stat().st_mode | 0o111)
    log.info("Desktop entry created: %s", desktop_file)
    return desktop_file


# ---------------------------------------------------------------------------
# Application metadata
# ---------------------------------------------------------------------------

def _load_app_metadata(app_name: str) -> Dict[str, Any]:
    """Load persisted metadata for *app_name*."""
    meta_path = APPS_DIR / f"{app_name}.json"
    if not meta_path.exists():
        raise AppNotFoundError(f"Application '{app_name}' is not installed")
    with open(meta_path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _save_app_metadata(app_name: str, data: Dict[str, Any]) -> None:
    """Persist metadata for *app_name*."""
    APPS_DIR.mkdir(parents=True, exist_ok=True)
    meta_path = APPS_DIR / f"{app_name}.json"
    _atomic_write(meta_path, json.dumps(data, indent=2))
    log.debug("Metadata saved: %s", meta_path)


# ---------------------------------------------------------------------------
# Version fingerprint helpers
# ---------------------------------------------------------------------------

def _get_wine_version(wine_path: Optional[str]) -> str:
    if not wine_path:
        return "unknown"
    try:
        res = _run_cmd([wine_path, "--version"], check=True)
        return res.stdout.strip()
    except Exception:
        return "unknown"


def _get_gpu_driver_version() -> str:
    try:
        if Path("/proc/driver/nvidia/version").exists():
            return Path("/proc/driver/nvidia/version").read_text("utf-8").strip()
    except Exception:
        pass
    try:
        res = _run_cmd(["glxinfo"], check=True)
        for line in res.stdout.splitlines():
            if "OpenGL version string" in line or "Mesa" in line:
                return line.strip()
    except Exception:
        pass
    return "unknown"


def _get_dxvk_version() -> str:
    try:
        res = _run_cmd(["pacman", "-Q", "dxvk-bin"], check=True)
        return res.stdout.strip()
    except Exception:
        pass
    try:
        res = _run_cmd(["pacman", "-Q", "dxvk"], check=True)
        return res.stdout.strip()
    except Exception:
        pass
    return "unknown"


def _generate_cache_fingerprint(wine_path: Optional[str]) -> Dict[str, str]:
    return {
        "wine_version": _get_wine_version(wine_path),
        "dxvk_version": _get_dxvk_version(),
        "gpu_driver": _get_gpu_driver_version(),
        "kernel_version": platform.release(),
    }


# ---------------------------------------------------------------------------
# Centralized API class
# ---------------------------------------------------------------------------

CURRENT_SCHEMA_VERSION = 2

class ConjunctionAPI:
    """Centralized API class wrapping the engine operations.

    Decouples the CLI, installer, and core running operations.
    """

    def __init__(self, session_id: Optional[str] = None) -> None:
        self.session_id = session_id
        if session_id:
            logging.session_id = session_id
        self.config = ConjunctionConfig()

        self.proton_path = self.config.get("proton_path") or _detect_proton()
        self.wine_path = self.config.get("wine_path") or _which("wine64") or _which("wine")
        self.winetricks_path = self.config.get("winetricks_path") or _which("winetricks")

        # Ensure directory hierarchy
        for d in (PREFIX_DIR, APPS_DIR, LOG_DIR, CACHE_DIR, CRASH_DIR, EXPORTS_DIR, CONFIG_DIR):
            d.mkdir(parents=True, exist_ok=True)

        log.info("conjunction-runner %s initialised", VERSION)
        log.debug("Proton: %s | Wine: %s | winetricks: %s",
                  self.proton_path, self.wine_path, self.winetricks_path)

    def cleanup_system(self, days: int = 7) -> Dict[str, List[str]]:
        """Deletes expired cache files, stale logs, old crash reports, and incomplete exports.

        Args:
            days: Age threshold in days. Files older than this will be deleted.

        Returns:
            Dict containing lists of deleted files grouped by category.
        """
        deleted_files = {
            "logs": [],
            "crash_reports": [],
            "exports": [],
            "cache": []
        }
        
        now = datetime.now()
        threshold = timedelta(days=days)
        
        # Helper to clean a directory
        def clean_dir(directory: Path, pattern: str, category: str):
            if not directory.exists() or not directory.is_dir():
                return
            for item in directory.glob(pattern):
                if item.is_file():
                    try:
                        mtime = datetime.fromtimestamp(item.stat().st_mtime)
                        if now - mtime > threshold:
                            item.unlink()
                            deleted_files[category].append(str(item))
                    except Exception as e:
                        log.warning("Failed to delete stale file %s: %s", item, e)
                        
        clean_dir(LOG_DIR, "*.log*", "logs")
        clean_dir(CRASH_DIR, "crash-*.json", "crash_reports")
        clean_dir(EXPORTS_DIR, "*.tar.zst", "exports")
        
        # Stale cache files (e.g. cache entries, temp files)
        clean_dir(CACHE_DIR, "*.json", "cache")
        clean_dir(CACHE_DIR, "*.tmp", "cache")
        
        log.info("System cleanup completed. Deleted files: %s", deleted_files)
        return deleted_files

    # ------------------------------------------------------------------
    # Prefix state validation, metadata schema migrations, & cache checking
    # ------------------------------------------------------------------

    def _validate_prefix_state(self, prefix_path: Path) -> None:
        """Validates the state of a Wine prefix before launching an application."""
        if not prefix_path.exists():
            raise PrefixError(f"Wine prefix directory does not exist: {prefix_path}")
        if not prefix_path.is_dir():
            raise PrefixError(f"Wine prefix path is not a directory: {prefix_path}")
            
        required_paths = [
            prefix_path / "drive_c",
            prefix_path / "user.reg",
            prefix_path / "system.reg",
        ]
        for p in required_paths:
            if not p.exists():
                raise PrefixError(f"Wine prefix is corrupted or incomplete (missing '{p.name}'): {prefix_path}")

    def _migrate_prefix_metadata(self, prefix_path: Path, app_name: str) -> None:
        """Migrates prefix metadata in .conjunction_meta.json if version is older."""
        meta_file = prefix_path / ".conjunction_meta.json"
        if not meta_file.exists():
            meta_data = {
                "schema_version": CURRENT_SCHEMA_VERSION,
                "app_name": app_name,
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat(),
            }
            try:
                _atomic_write(meta_file, json.dumps(meta_data, indent=2))
            except Exception as exc:
                log.warning("Failed to write initial prefix metadata: %s", exc)
            return

        try:
            with open(meta_file, "r", encoding="utf-8") as f:
                meta_data = json.load(f)
        except Exception as exc:
            log.warning("Failed to read prefix metadata, resetting: %s", exc)
            meta_data = {"schema_version": 1}

        version = meta_data.get("schema_version", 1)
        if version >= CURRENT_SCHEMA_VERSION:
            return

        log.info("Migrating prefix '%s' metadata from version %s to %s", app_name, version, CURRENT_SCHEMA_VERSION)

        if version < 2:
            meta_data["migrated_from_v1_at"] = datetime.now().isoformat()
            log.info("Running migration 1 -> 2: Regenerating desktop entry and verifying paths.")
            try:
                self._create_desktop_entry(app_name, prefix_path)
            except Exception as exc:
                log.warning("Migration 1 -> 2 desktop regeneration skipped: %s", exc)
            version = 2

        meta_data["schema_version"] = CURRENT_SCHEMA_VERSION
        meta_data["updated_at"] = datetime.now().isoformat()
        try:
            _atomic_write(meta_file, json.dumps(meta_data, indent=2))
            log.info("Prefix '%s' metadata migrated to version %s successfully", app_name, CURRENT_SCHEMA_VERSION)
        except Exception as exc:
            log.warning("Failed to save migrated prefix metadata: %s", exc)

    def _check_and_invalidate_cache(self, prefix_path: Path) -> None:
        """Checks system versions against cached fingerprint. Invalidates caches if configuration changed."""
        fingerprint_file = prefix_path / ".cache_fingerprint.json"
        current_fp = _generate_cache_fingerprint(self.wine_path)
        
        should_invalidate = False
        if not fingerprint_file.exists():
            should_invalidate = True
        else:
            try:
                with open(fingerprint_file, "r", encoding="utf-8") as f:
                    cached_fp = json.load(f)
                if cached_fp != current_fp:
                    log.info("System configuration changed. Invalidating caches. Cached: %s, Current: %s", cached_fp, current_fp)
                    should_invalidate = True
            except Exception as exc:
                log.warning("Failed to read cache fingerprint, invalidating: %s", exc)
                should_invalidate = True

        if should_invalidate:
            caches_to_clear = [
                prefix_path / "dxvk_state_cache",
                prefix_path / "nvidia_shader_cache",
                CACHE_DIR / prefix_path.name,
            ]
            for cache_path in caches_to_clear:
                if cache_path.exists():
                    try:
                        if cache_path.is_file():
                            cache_path.unlink()
                        else:
                            shutil.rmtree(cache_path)
                        log.info("Cleared cache directory: %s", cache_path)
                    except Exception as exc:
                        log.warning("Failed to clear cache %s: %s", cache_path, exc)
                        
            try:
                fingerprint_file.parent.mkdir(parents=True, exist_ok=True)
                _atomic_write(fingerprint_file, json.dumps(current_fp, indent=2))
            except Exception as exc:
                log.warning("Failed to write new cache fingerprint: %s", exc)

    # ------------------------------------------------------------------
    # Prefix management
    # ------------------------------------------------------------------

    def _create_prefix(self, app_name: str) -> Path:
        """Create a pristine 64-bit Wine prefix for *app_name*.

        If a Btrfs filesystem is detected, a snapshot is taken after initial
        boot so that the prefix can be restored to a clean state later.

        Args:
            app_name: Logical application name (used as directory name).

        Returns:
            Path to the created prefix directory.

        Raises:
            PrefixError: If the prefix cannot be created.
        """
        prefix_path = PREFIX_DIR / app_name
        if prefix_path.exists():
            log.info("Prefix already exists for '%s', reusing", app_name)
            return prefix_path

        log.info("Creating Wine prefix for '%s' at %s", app_name, prefix_path)
        prefix_path.mkdir(parents=True, exist_ok=True)

        env = {
            "WINEARCH": "win64",
            "WINEPREFIX": str(prefix_path),
        }

        # Force non-interactive mode to avoid GUI prompts during init
        env["DISPLAY"] = ""  # Suppress X display requirement
        env["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d"

        try:
            _run_cmd(["wineboot", "--init"], env=env, timeout=300)
        except Exception as exc:
            raise PrefixError(
                f"wineboot --init failed for '{app_name}': {exc}"
            ) from exc

        # Snapshot the pristine prefix if on Btrfs
        if _is_btrfs(prefix_path):
            snapshot_dir = PREFIX_DIR / ".snapshots" / app_name
            snapshot_dir.mkdir(parents=True, exist_ok=True)
            snapshot_path = snapshot_dir / "pristine"
            _snapshot_subvolume(prefix_path, snapshot_path)

        log.info("Prefix created successfully for '%s'", app_name)
        return prefix_path

    def _restore_prefix(self, app_name: str) -> bool:
        """Restore a prefix to its pristine snapshot (Btrfs only).

        Returns:
            True if the restore succeeded, False otherwise.
        """
        snapshot_path = PREFIX_DIR / f".snapshots/{app_name}/pristine"
        prefix_path = PREFIX_DIR / app_name

        if not snapshot_path.exists():
            log.warning("No pristine snapshot found for '%s'", app_name)
            return False

        return _restore_snapshot(snapshot_path, prefix_path)

    # ------------------------------------------------------------------
    # Runtime injection
    # ------------------------------------------------------------------

    def _inject_runtime(self, prefix_path: Path) -> None:
        """Install core runtimes into a Wine prefix.

        Installs:
            - Core fonts (corefonts)
            - MSXML3, MSHTML via winetricks
            - Visual C++ Redistributables 2015-2022 (x64 + x86)
            - Windows Media Components

        Falls back to direct DLL download if winetricks is unavailable.

        Args:
            prefix_path: Path to the Wine prefix.

        Raises:
            RuntimeInstallError: If critical components fail to install.
        """
        env = {
            "WINEPREFIX": str(prefix_path),
            "WINEARCH": "win64",
            "WINEDLLOVERRIDES": "winemenubuilder.exe=d",
        }

        if self.winetricks_path:
            self._inject_via_winetricks(prefix_path, env)
        else:
            log.warning("winetricks not found; attempting direct DLL injection")
            self._inject_via_direct_download(prefix_path, env)

        self._install_vc_redist(prefix_path, env)
        self._install_media_components(prefix_path, env)

    def _inject_via_winetricks(
        self,
        prefix_path: Path,
        env: Dict[str, str],
    ) -> None:
        """Use winetricks to install standard Wine components."""
        log.info("Installing Wine components via winetricks")
        for component in WINE_COMPONENTS:
            log.info("Installing %s", component)
            try:
                _run_cmd(
                    [self.winetricks_path, "-q", component],  # type: ignore[list-item]
                    env=env,
                    timeout=600,
                )
            except subprocess.CalledProcessError as exc:
                log.warning(
                    "winetricks component '%s' failed (rc=%d); continuing",
                    component,
                    exc.returncode,
                )
            except Exception as exc:
                log.warning("winetricks component '%s' error: %s", component, exc)

    def _inject_via_direct_download(
        self,
        prefix_path: Path,
        env: Dict[str, str],
    ) -> None:
        """Fallback: download and install DLLs directly into system32.

        This is a minimal fallback that installs only the most critical
        components when winetricks is unavailable.
        """
        system32 = prefix_path / "drive_c" / "windows" / "system32"
        if not system32.is_dir():
            log.warning("system32 not found at %s", system32)
            return

        # Direct DLL download for msxml3
        msxml_urls = {
            "msxml3.dll": "https://download.microsoft.com/download/A/9/8/A98E3335-2080-4BE6-BB7A-4634B6E40027/msxml3.dll",
        }
        for dll_name, url in msxml_urls.items():
            dest = system32 / dll_name
            if dest.exists():
                log.debug("%s already present, skipping", dll_name)
                continue
            log.info("Downloading %s", dll_name)
            try:
                _run_cmd(["curl", "-sL", "-o", str(dest), url], timeout=120)
            except Exception as exc:
                log.warning("Failed to download %s: %s", dll_name, exc)

    def _install_vc_redist(
        self,
        prefix_path: Path,
        env: Dict[str, str],
    ) -> None:
        """Install Visual C++ 2015-2022 Redistributables into the prefix.

        Downloads the official VC++ redistributable installers and runs them
        silently inside the Wine prefix.
        """
        vc_dir = prefix_path / "drive_c" / "vc_redist"
        vc_dir.mkdir(parents=True, exist_ok=True)

        for arch, url in VC_REDIST_URLS.items():
            installer = vc_dir / f"vc_redist.{arch}.exe"
            if not installer.exists():
                log.info("Downloading VC++ Redistributable (%s)", arch)
                try:
                    _run_cmd(
                        ["curl", "-sL", "-o", str(installer), url],
                        timeout=300,
                    )
                except Exception as exc:
                    log.warning("Failed to download VC++ %s: %s", arch, exc)
                    continue

            log.info("Installing VC++ Redistributable (%s)", arch)
            try:
                _run_cmd(
                    ["wine", str(installer), "/install", "/quiet", "/norestart"],
                    env=env,
                    timeout=600,
                )
            except Exception as exc:
                log.warning("VC++ install (%s) failed: %s", arch, exc)

    def _install_media_components(
        self,
        prefix_path: Path,
        env: Dict[str, str],
    ) -> None:
        """Install Windows Media Components for media suite initialization."""
        if not self.winetricks_path:
            return

        for component in MEDIA_COMPONENTS:
            log.info("Installing media component: %s", component)
            try:
                _run_cmd(
                    [self.winetricks_path, "-q", component],  # type: ignore[list-item]
                    env=env,
                    timeout=600,
                )
            except Exception as exc:
                log.warning("Media component '%s' install failed: %s", component, exc)

    # ------------------------------------------------------------------
    # Desktop shortcut synthesis
    # ------------------------------------------------------------------

    def _create_desktop_entry(
        self,
        app_name: str,
        prefix_path: Path,
    ) -> Optional[Path]:
        """Scan the prefix's start menu for .lnk files and synthesise a
        Linux .desktop launcher.

        Steps:
            1. Walk ``drive_c/ProgramData/Microsoft/Windows/Start Menu``
               and ``drive_c/users/<user>/AppData/Roaming/Microsoft/Windows/Start Menu``
               for ``.lnk`` shortcut files.
            2. Extract the application name and icon path.
            3. Convert ``.ico`` icons to ``.png`` (imagemagick or Pillow).
            4. Write a ``.desktop`` file to ``~/.local/share/applications/``.

        Args:
            app_name: Logical application name.
            prefix_path: Path to the Wine prefix.

        Returns:
            Path to the generated .desktop file, or None if no shortcuts found.
        """
        start_menu_roots = [
            prefix_path / "drive_c" / "ProgramData" / "Microsoft" / "Windows" / "Start Menu" / "Programs",
            prefix_path / "drive_c" / "users" / "Public" / "AppData" / "Roaming" / "Microsoft" / "Windows" / "Start Menu" / "Programs",
        ]

        # Also check the primary user's start menu
        users_dir = prefix_path / "drive_c" / "users"
        if users_dir.is_dir():
            for user_dir in users_dir.iterdir():
                if user_dir.name in ("Public", "Default", "All Users"):
                    continue
                user_start = (
                    user_dir / "AppData" / "Roaming" / "Microsoft" / "Windows"
                    / "Start Menu" / "Programs"
                )
                if user_start.is_dir():
                    start_menu_roots.append(user_start)

        lnk_files: List[Path] = []
        for root in start_menu_roots:
            if root.is_dir():
                lnk_files.extend(root.rglob("*.lnk"))

        if not lnk_files:
            log.info("No .lnk files found in start menu for '%s'", app_name)
            return None

        # Use the first (most prominent) shortcut
        lnk = lnk_files[0]
        display_name = lnk.stem

        # Attempt to extract icon
        icon_path: Optional[str] = None

        # Look for .ico files in the prefix
        ico_files = list(prefix_path.rglob("*.ico"))
        if ico_files:
            png_dir = BASE_DIR / "icons"
            png_dir.mkdir(parents=True, exist_ok=True)
            png_path = png_dir / f"{app_name}.png"

            if _convert_ico_to_png(ico_files[0], png_path):
                icon_path = str(png_path)

        category = _detect_app_category(display_name)
        desktop_path = _generate_desktop_entry(
            app_name=app_name,
            exe_path=str(lnk),
            icon_path=icon_path,
            prefix_path=prefix_path,
            categories=category,
        )

        return desktop_path

    # ------------------------------------------------------------------
    # Environment configuration
    # ------------------------------------------------------------------

    def _configure_environment(
        self,
        prefix_path: Path,
        app_name: Optional[str] = None,
        *,
        no_gpu: bool = False,
        debug: bool = False,
    ) -> Dict[str, str]:
        """Build the complete environment dictionary for application execution.

        Configures:
            - DXVK: async shader compilation, state cache, FPS overlay
            - Audio: PulseAudio dynamic UID mapping, ALSA, PipeWire
            - Esync/Fsync thread scheduling
            - GPU vendor-specific driver flags
            - CUDA/OpenCL paths if detected
            - Wine debug channels if debug mode enabled

        Args:
            prefix_path: Path to the Wine prefix.
            app_name: Optional logical name of the app to load custom overrides.
            no_gpu: If True, skip GPU-specific configuration.
            debug: If True, enable Wine debug output.

        Returns:
            Dictionary of environment variables to apply.
        """
        env: Dict[str, str] = {}

        # Core Wine configuration
        env["WINEPREFIX"] = str(prefix_path)
        env["WINEARCH"] = "win64"

        # Load app configuration overrides if present
        app_config = {}
        if app_name:
            try:
                metadata = _load_app_metadata(app_name)
                app_config = metadata.get("config", {})
            except Exception:
                pass

        # Esync / Fsync — dynamically loaded from metadata config with global fallback
        esync_enabled = app_config.get("esync") if app_config.get("esync") is not None else self.config.get("esync")
        fsync_enabled = app_config.get("fsync") if app_config.get("fsync") is not None else self.config.get("fsync")
        env["WINEESYNC"] = "1" if esync_enabled else "0"
        env["WINEFSYNC"] = "1" if fsync_enabled else "0"

        # Suppress Wine menu builder (avoids crashes and unwanted shortcuts)
        env["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d"

        if no_gpu:
            env["WINEDEBUG"] = "-all"
            return env

        # --- DXVK configuration ---
        hud_val = app_config.get("dxvk_hud") or self.config.get("dxvk_hud") or "fps"
        env["DXVK_HUD"] = hud_val             # HUD overlay
        env["DXVK_STATE_CACHE_PATH"] = str(  # Persistent state cache
            prefix_path / "dxvk_state_cache"
        )

        # Ray tracing support via VKD3D-Proton
        env["VKD3D_CONFIG"] = "dxr"

        # --- GPU vendor detection ---
        gpu_vendor = _detect_gpu_vendor()
        if gpu_vendor == "nvidia":
            env["__GL_THREADED_OPTIMIZATIONS"] = "1"
            env["__GL_SYNC_TO_VBLANK"] = "0"
            env["__GL_SYNC_DISPLAY"] = "NONE"
            # Disable NVIDIA shader cache compaction for lower latency
            env["__GL_SHADER_DISK_CACHE"] = "1"
            env["__GL_SHADER_DISK_CACHE_PATH"] = str(
                prefix_path / "nvidia_shader_cache"
            )
            log.info("NVIDIA GPU detected; applying driver flags")
        elif gpu_vendor == "amd":
            env["radv_perftest"] = "gpl"       # Enable GPL (GPU Pipeline Library)
            env["MESA_SHADER_CACHE_DISABLE"] = "false"
            env["RADV_PERFTEST"] = "gpl"
            log.info("AMD GPU detected; applying radv flags")
        elif gpu_vendor == "intel":
            env["INTEL_DEBUG"] = ""             # Clear any debug overrides
            log.info("Intel GPU detected")
        else:
            log.warning("GPU vendor not detected; using default DXVK settings")

        # --- CUDA / OpenCL ---
        cuda_path = _detect_cuda()
        if cuda_path:
            env["CUDA_PATH"] = cuda_path
            env["PATH"] = f"{cuda_path}/bin:{os.environ.get('PATH', '')}"
            log.info("CUDA detected at %s", cuda_path)

        opencl_icd = _detect_opencl()
        if opencl_icd:
            env["OCL_ICD_FILENAMES"] = opencl_icd
            log.info("OpenCL ICDs: %s", opencl_icd)

        # --- Audio configuration (Dynamic UID detection) ---
        audio_server = _detect_audio_server()
        uid = os.getuid() if hasattr(os, "getuid") else 1000
        pulse_server = os.environ.get("PULSE_SERVER")
        if not pulse_server:
            pulse_server = f"unix:/run/user/{uid}/pulse/native"

        if audio_server == "pipewire":
            env["PULSE_SERVER"] = pulse_server
            env["PIPEWIRE_RUNTIME_DIR"] = f"/run/user/{uid}/pipewire"
            log.info("PipeWire audio detected")
        elif audio_server == "pulse":
            env["PULSE_SERVER"] = pulse_server
            log.info("PulseAudio detected")
        else:
            env["ALSA_DEVICE"] = "default"
            log.info("ALSA audio (fallback)")

        # --- Wine debug ---
        if debug:
            env["WINEDEBUG"] = "+all"
            env["DXVK_LOG_LEVEL"] = "debug"
            env["WINE_LOG_LEVEL"] = "debug"
        else:
            wine_debug_val = app_config.get("wine_debug") or self.config.get("wine_debug") or "-all"
            env["WINEDEBUG"] = wine_debug_val

        return env

    # ------------------------------------------------------------------
    # Application lifecycle commands
    # ------------------------------------------------------------------

    def install(
        self,
        exe_path: str,
        app_name: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Install a Windows application into an isolated Wine prefix.

        Steps:
            1. Create a pristine Wine prefix.
            2. Initialise prefix metadata schema.
            3. Inject runtimes (fonts, MSXML, VC++ redistributables, media).
            4. Run the installer inside the prefix.
            5. Synthesise a .desktop launcher from start menu shortcuts.
            6. Persist application metadata.

        Args:
            exe_path: Path to the Windows installer (.exe).
            app_name: Optional override for the application name.

        Returns:
            Dictionary of installed application metadata.

        Raises:
            FileNotFoundError: If the installer does not exist.
            PrefixError: If prefix creation fails.
        """
        exe = Path(exe_path).resolve()
        if not exe.exists():
            raise FileNotFoundError(f"Installer not found: {exe}")

        if app_name is None:
            app_name = exe.stem

        # Sanitise the app name for filesystem safety
        app_name = re.sub(r"[^a-zA-Z0-9._-]", "_", app_name)

        log.info("Installing '%s' from %s", app_name, exe)

        # Step 1: Create prefix
        prefix_path = self._create_prefix(app_name)

        # Step 2: Initialise prefix metadata schema
        self._migrate_prefix_metadata(prefix_path, app_name)

        # Step 3: Inject runtimes
        self._inject_runtime(prefix_path)

        # Step 4: Run the installer
        env = {
            "WINEPREFIX": str(prefix_path),
            "WINEARCH": "win64",
            "WINEDLLOVERRIDES": "winemenubuilder.exe=d",
        }
        log.info("Running installer: %s", exe)
        try:
            _run_cmd(
                ["wine", str(exe)],
                env=env,
                check=False,
                timeout=3600,  # 1 hour max for installers
            )
        except Exception as exc:
            log.warning("Installer exited with error (may be normal): %s", exc)

        # Step 5: Synthesise desktop entry
        desktop_path = self._create_desktop_entry(app_name, prefix_path)

        # Step 6: Discover the primary executable in the prefix
        primary_exe = self._discover_primary_exe(prefix_path)

        # Step 7: Persist metadata
        install_time = datetime.now().isoformat()
        metadata: Dict[str, Any] = {
            "name": app_name,
            "source_exe": str(exe),
            "prefix_path": str(prefix_path),
            "primary_exe": str(primary_exe) if primary_exe else None,
            "desktop_entry": str(desktop_path) if desktop_path else None,
            "installed_at": install_time,
            "gpu_vendor": _detect_gpu_vendor() or "unknown",
            "proton": self.proton_path is not None,
        }
        _save_app_metadata(app_name, metadata)

        log.info("Installation complete for '%s'", app_name)
        return metadata

    def _discover_primary_exe(self, prefix_path: Path) -> Optional[Path]:
        """Find the primary executable after installation.

        Scans common Windows install locations and returns the most likely
        main executable based on recency and size.
        """
        search_dirs = [
            prefix_path / "drive_c" / "Program Files",
            prefix_path / "drive_c" / "Program Files (x86)",
            prefix_path / "drive_c" / "Program Files" / "WindowsApps",
        ]

        candidates: List[Tuple[float, Path]] = []
        for search_dir in search_dirs:
            if not search_dir.is_dir():
                continue
            for exe in search_dir.rglob("*.exe"):
                # Skip common system executables
                if exe.name.lower() in ("uninstall.exe", "unins000.exe", "setup.exe"):
                    continue
                try:
                    stat = exe.stat()
                    candidates.append((stat.st_mtime, exe))
                except OSError:
                    continue

        if not candidates:
            return None

        # Return the most recently modified executable
        candidates.sort(key=lambda x: x[0], reverse=True)
        return candidates[0][1]

    def run(
        self,
        app_name: str,
        *,
        no_gpu: bool = False,
        debug: bool = False,
    ) -> int:
        """Launch an installed application with full GPU/audio passthrough.

        Uses Proton if available, falling back to plain Wine. The process is
        monitored and crashes are handled gracefully with logging.

        Args:
            app_name: Name of the installed application.
            no_gpu: If True, disable GPU-specific configuration.
            debug: If True, enable verbose Wine debug output.

        Returns:
            Exit code of the launched process.

        Raises:
            AppNotFoundError: If the application is not installed.
            WineNotFoundError: If neither Wine nor Proton is available.
        """
        metadata = _load_app_metadata(app_name)
        prefix_path = Path(metadata["prefix_path"])

        # Validate prefix state before running (Requirement 12)
        self._validate_prefix_state(prefix_path)

        # Migrate prefix metadata if schema changed (Requirement 10)
        self._migrate_prefix_metadata(prefix_path, app_name)

        # Cache fingerprinting check & invalidation (Requirement 9)
        self._check_and_invalidate_cache(prefix_path)

        # Determine launch command
        if self.proton_path:
            launcher = [self.proton_path, "run"]
            log.info("Using Proton: %s", self.proton_path)
        elif self.wine_path:
            launcher = [self.wine_path]
            log.info("Using Wine: %s", self.wine_path)
        else:
            raise WineNotFoundError(
                "Neither Proton nor Wine found on the system. "
                "Install Wine (winehq.org) or Steam Proton."
            )

        # Determine the target executable
        target_exe = metadata.get("primary_exe")
        if target_exe and Path(target_exe).exists():
            launcher.append(target_exe)
        else:
            log.warning(
                "Primary executable not found; launching prefix shell for '%s'",
                app_name,
            )

        # Build environment
        env = self._configure_environment(
            prefix_path,
            app_name=app_name,
            no_gpu=no_gpu,
            debug=debug,
        )

        # Signal handling for graceful shutdown
        process: Optional[subprocess.Popen[str]] = None

        def _signal_handler(signum: int, frame: Any) -> None:
            log.info("Received signal %d, forwarding to child process", signum)
            if process and process.poll() is None:
                process.send_signal(signum)

        signal.signal(signal.SIGTERM, _signal_handler)
        signal.signal(signal.SIGINT, _signal_handler)

        log.info("Launching: %s", " ".join(launcher))
        try:
            process = subprocess.Popen(
                launcher,
                env=env,
                text=True,
            )
            exit_code = process.wait(timeout=7200)  # 2 hour max runtime
            log.info("Process exited with code %d", exit_code)
            return exit_code
        except subprocess.TimeoutExpired:
            log.warning("Process timed out after 2 hours; terminating")
            if process:
                process.terminate()
                process.wait(timeout=10)
            return -1
        except KeyboardInterrupt:
            log.info("Interrupted by user")
            if process:
                process.terminate()
                process.wait(timeout=10)
            return -2
        except Exception as exc:
            log.error("Process execution failed: %s", exc)
            return -1

    def list_apps(self) -> List[Dict[str, Any]]:
        """List all installed applications.

        Returns:
            List of application metadata dictionaries.
        """
        apps: List[Dict[str, Any]] = []
        if not APPS_DIR.is_dir():
            return apps

        for meta_file in sorted(APPS_DIR.glob("*.json")):
            try:
                with open(meta_file, "r", encoding="utf-8") as fh:
                    apps.append(json.load(fh))
            except Exception as exc:
                log.warning("Failed to read metadata %s: %s", meta_file, exc)

        return apps

    def remove(self, app_name: str) -> None:
        """Remove an installed application and its Wine prefix.

        Args:
            app_name: Name of the application to remove.

        Raises:
            AppNotFoundError: If the application is not installed.
        """
        metadata = _load_app_metadata(app_name)
        prefix_path = Path(metadata["prefix_path"])

        log.info("Removing application '%s'", app_name)

        # Remove desktop entry
        desktop_file = DESKTOP_DIR / f"conjunction-{app_name}.desktop"
        if desktop_file.exists():
            desktop_file.unlink()
            log.info("Removed desktop entry: %s", desktop_file)

        # Remove prefix safely using subvolume tools if applicable
        if prefix_path.exists():
            _delete_directory_or_subvolume(prefix_path)

        # Remove snapshot directories
        snapshot_dir = PREFIX_DIR / ".snapshots" / app_name
        if snapshot_dir.exists():
            pristine_snapshot = snapshot_dir / "pristine"
            if pristine_snapshot.exists():
                _delete_directory_or_subvolume(pristine_snapshot)
            _delete_directory_or_subvolume(snapshot_dir)

        # Remove metadata
        meta_path = APPS_DIR / f"{app_name}.json"
        if meta_path.exists():
            meta_path.unlink()
            log.info("Removed metadata: %s", meta_path)

        # Remove icon if present
        icon_path = BASE_DIR / "icons" / f"{app_name}.png"
        if icon_path.exists():
            icon_path.unlink()

        log.info("Application '%s' removed successfully", app_name)

    def configure(
        self,
        app_name: str,
        *,
        dxvk_hud: Optional[str] = None,
        esync: Optional[bool] = None,
        fsync: Optional[bool] = None,
        wine_debug: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Update runtime configuration for an installed application.

        Modifies the persisted metadata and reconfigures environment variables
        for the next launch.

        Args:
            app_name: Name of the application.
            dxvk_hud: DXVK HUD overlay string (e.g. 'fps,memory,gpuload').
            esync: Enable/disable Esync.
            fsync: Enable/disable Fsync.
            wine_debug: Wine debug channel specification.

        Returns:
            Updated metadata dictionary.

        Raises:
            AppNotFoundError: If the application is not installed.
        """
        metadata = _load_app_metadata(app_name)

        config = metadata.get("config", {})
        if dxvk_hud is not None:
            config["dxvk_hud"] = dxvk_hud
        if esync is not None:
            config["esync"] = esync
        if fsync is not None:
            config["fsync"] = fsync
        if wine_debug is not None:
            config["wine_debug"] = wine_debug
        metadata["config"] = config
        metadata["configured_at"] = datetime.now().isoformat()
        _save_app_metadata(app_name, metadata)

        log.info("Configuration updated for '%s': %s", app_name, config)
        return metadata

    def export_app(self, app_name: str, archive_path: Path) -> Path:
        """Export an application's prefix and metadata to a tarball archive (.tar.zst).

        Args:
            app_name: Name of the application to export.
            archive_path: Target path for the generated archive (.tar.zst).

        Returns:
            Path to the generated archive.
        """
        # Load metadata
        meta_file = APPS_DIR / f"{app_name}.json"
        if not meta_file.exists():
            raise AppNotFoundError(f"Application '{app_name}' is not installed")
        
        with open(meta_file, "r", encoding="utf-8") as f:
            metadata = json.load(f)

        prefix_path = Path(metadata["prefix_path"])
        if not prefix_path.exists():
            raise PrefixError(f"Prefix for '{app_name}' does not exist at {prefix_path}")

        import tempfile
        archive_path = Path(archive_path).resolve()
        archive_path.parent.mkdir(parents=True, exist_ok=True)

        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            
            # Write manifest.json
            manifest = metadata.copy()
            manifest["archive_version"] = 2
            manifest["schema_version"] = CURRENT_SCHEMA_VERSION
            
            manifest_file = tmp_path / "manifest.json"
            with open(manifest_file, "w", encoding="utf-8") as f:
                json.dump(manifest, f, indent=2)

            symlink_prefix = tmp_path / "prefix"
            try:
                os.symlink(prefix_path, symlink_prefix, target_is_directory=True)
            except Exception as e:
                log.warning("Symlink creation failed: %s. Using copy fallback.", e)
                shutil.copytree(prefix_path, symlink_prefix, symlinks=True)

            cmd = ["tar", "--zstd", "-chf", str(archive_path), "-C", str(tmp_path), "manifest.json", "prefix"]
            _run_cmd(cmd, timeout=1200)

        log.info("Application '%s' exported successfully to %s", app_name, archive_path)
        return archive_path

    def import_app(self, archive_path: Path, app_name: Optional[str] = None) -> Dict[str, Any]:
        """Import an application from an export tarball archive (.tar.zst).

        Args:
            archive_path: Path to the tarball archive.
            app_name: Optional override for the imported application name.

        Returns:
            Imported application metadata.
        """
        archive_path = Path(archive_path).resolve()
        if not archive_path.exists():
            raise FileNotFoundError(f"Archive not found: {archive_path}")

        manifest_data = None
        # Try manifest.json first
        try:
            res = _run_cmd(
                ["tar", "-xf", str(archive_path), "manifest.json", "-O"],
                capture=True,
                check=True,
                timeout=30
            )
            manifest_data = res.stdout
        except Exception:
            # Try app.manifest as legacy fallback
            try:
                res = _run_cmd(
                    ["tar", "-xf", str(archive_path), "app.manifest", "-O"],
                    capture=True,
                    check=True,
                    timeout=30
                )
                manifest_data = res.stdout
            except Exception as exc:
                raise ConjunctionError(f"Failed to read or validate manifest from archive: {exc}")

        manifest = json.loads(manifest_data)

        # Validate format versions: e.g. archive_version or schema_version
        archive_version = manifest.get("archive_version", 1)
        schema_version = manifest.get("schema_version", 1)
        
        if "name" not in manifest:
            raise ConjunctionError("Archive manifest is missing application name")

        imported_name = app_name or manifest.get("name")
        if not imported_name:
            raise ValueError("Could not determine application name from manifest or arguments")
        
        imported_name = re.sub(r"[^a-zA-Z0-9._-]", "_", imported_name)

        dest_prefix = PREFIX_DIR / imported_name
        if dest_prefix.exists():
            raise PrefixError(f"Application prefix '{imported_name}' already exists at {dest_prefix}")

        dest_prefix.mkdir(parents=True, exist_ok=True)

        try:
            cmd = ["tar", "-xf", str(archive_path), "-C", str(dest_prefix)]
            _run_cmd(cmd, timeout=1200)

            # Move contents of 'prefix' or 'wineprefix' up to dest_prefix
            for subfolder_name in ("prefix", "wineprefix"):
                subfolder = dest_prefix / subfolder_name
                if subfolder.exists() and subfolder.is_dir():
                    for item in subfolder.iterdir():
                        dest_item = dest_prefix / item.name
                        if dest_item.exists():
                            if dest_item.is_dir():
                                shutil.rmtree(dest_item)
                            else:
                                dest_item.unlink()
                        shutil.move(str(item), str(dest_prefix))
                    subfolder.rmdir()

            # Clean up extracted manifest files
            for manifest_name in ("manifest.json", "app.manifest"):
                extracted_manifest = dest_prefix / manifest_name
                if extracted_manifest.exists():
                    extracted_manifest.unlink()

            self._migrate_prefix_metadata(dest_prefix, imported_name)

            metadata = manifest.copy()
            metadata["name"] = imported_name
            metadata["prefix_path"] = str(dest_prefix)
            metadata["archive_version"] = 2
            metadata["schema_version"] = CURRENT_SCHEMA_VERSION
            
            if metadata.get("primary_exe") and manifest.get("prefix_path"):
                old_path = Path(metadata["primary_exe"])
                try:
                    rel_exe = old_path.relative_to(Path(manifest["prefix_path"]))
                    metadata["primary_exe"] = str(dest_prefix / rel_exe)
                except ValueError:
                    metadata["primary_exe"] = str(dest_prefix / old_path.name)

            metadata["imported_at"] = datetime.now().isoformat()

            _save_app_metadata(imported_name, metadata)

            try:
                self._create_desktop_entry(imported_name, dest_prefix)
            except Exception as exc:
                log.warning("Failed to recreate desktop entry for imported app: %s", exc)

            log.info("Application '%s' imported successfully", imported_name)
            return metadata
        except Exception as exc:
            if dest_prefix.exists():
                _delete_directory_or_subvolume(dest_prefix)
            raise ConjunctionError(f"Import failed: {exc}")

    def _ensure_flathub_remote(self) -> None:
        """Auto-add Flathub Flatpak remote if it is not already configured."""
        try:
            cmd = ["flatpak", "remote-add", "--if-not-exists", "flathub", "https://dl.flathub.org/repo/flathub.flatpakrepo"]
            _run_cmd(cmd, timeout=30)
        except Exception as exc:
            log.warning("Failed to auto-add Flathub remote: %s", exc)

    def get_status(self) -> Dict[str, Any]:
        """Collect and return system status information."""
        import platform
        
        # Last update time (e.g. from pacman log file modification time or custom track)
        last_update = "unknown"
        pacman_log = Path("/var/log/pacman.log")
        if pacman_log.exists():
            last_update = datetime.fromtimestamp(pacman_log.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S")

        # Snapshot count
        snapshot_count = 0
        try:
            res = _run_cmd(["snapper", "-c", "root", "list", "--columns", "number"], capture=True, check=False, timeout=10)
            if res.returncode == 0:
                lines = res.stdout.strip().split("\n")
                snapshot_count = sum(1 for line in lines if any(c.isdigit() for c in line))
        except Exception:
            pass

        # Sandbox app count
        sandbox_count = 0
        if APPS_DIR.exists():
            sandbox_count = len(list(APPS_DIR.glob("*.json")))

        # Wine version
        wine_ver = _get_wine_version(self.wine_path)

        # Uptime
        uptime_str = "unknown"
        try:
            with open("/proc/uptime", "r") as f:
                uptime_seconds = float(f.readline().split()[0])
                uptime_str = str(timedelta(seconds=int(uptime_seconds)))
        except Exception:
            pass

        # Total prefix directory size
        prefix_size = "0M"
        if PREFIX_DIR.exists():
            try:
                res = _run_cmd(["du", "-sh", str(PREFIX_DIR)], capture=True, check=False, timeout=10)
                if res.returncode == 0:
                    prefix_size = res.stdout.split()[0]
            except Exception:
                pass

        return {
            "kernel": platform.release(),
            "desktop": os.environ.get("XDG_CURRENT_DESKTOP", "unknown"),
            "gpu_driver": _get_gpu_driver_version(),
            "wine_version": wine_ver,
            "sandbox_count": sandbox_count,
            "last_update": last_update,
            "snapshot_count": snapshot_count,
            "uptime": uptime_str,
            "prefix_size": prefix_size,
        }

    def search_flatpak(self, package_name: str) -> Optional[str]:
        """Search Flatpak for the package and return the App ID if found."""
        self._ensure_flathub_remote()
        try:
            res = _run_cmd(
                ["flatpak", "search", "--columns=application", package_name],
                capture=True,
                check=False,
                timeout=30
            )
            if res.returncode == 0:
                lines = res.stdout.strip().split("\n")
                valid_ids = []
                for line in lines:
                    line = line.strip()
                    if line and line != "Application" and not line.startswith("ID"):
                        valid_ids.append(line)
                if valid_ids:
                    return valid_ids[0]
        except Exception as exc:
            log.warning("Flatpak search failed: %s", exc)
        return None

    def install_flatpak(self, package_name: str, force: bool = False) -> bool:
        """Install Flatpak package."""
        try:
            cmd = ["flatpak", "install", "-y", "flathub", package_name]
            _run_cmd(cmd, timeout=600)
            return True
        except Exception as exc:
            log.error("Flatpak install failed: %s", exc)
            return False

    def search_pacman(self, package_name: str) -> bool:
        """Check if package is available in official repositories."""
        try:
            res = _run_cmd(["pacman", "-Si", package_name], capture=True, check=False, timeout=30)
            return res.returncode == 0
        except Exception:
            return False

    def install_pacman(self, package_name: str, force: bool = False) -> bool:
        """Install package from pacman."""
        try:
            cmd = ["pacman", "-S", "--noconfirm", package_name]
            if force:
                cmd.append("--needed")
            _run_cmd(cmd, timeout=600)
            return True
        except Exception as exc:
            log.error("pacman install failed: %s", exc)
            return False

    def search_aur(self, package_name: str) -> bool:
        """Check if package is available in AUR via yay."""
        try:
            res = _run_cmd(["yay", "-Si", package_name], capture=True, check=False, timeout=30)
            return res.returncode == 0
        except Exception:
            return False

    def install_aur(self, package_name: str) -> bool:
        """Install package from AUR via yay."""
        try:
            cmd = ["yay", "-S", "--noconfirm", package_name]
            sudo_user = os.environ.get("SUDO_USER")
            if sudo_user and hasattr(os, "getuid") and os.getuid() == 0:
                cmd = ["sudo", "-u", sudo_user] + cmd
            _run_cmd(cmd, timeout=900)
            return True
        except Exception as exc:
            log.error("AUR install failed: %s", exc)
            return False

    def update(self, log_cb=None) -> Dict[str, Any]:
        """Perform a full system update (pacman, flatpak, wineboot, yay)."""
        report = {"success": True, "steps": {}}
        
        # Step 1: Trigger Btrfs snapshot via snapper
        if log_cb:
            log_cb("Step 1/5: Creating pre-update Btrfs system snapshot...", 1)
        try:
            res = _run_cmd(["snapper", "-c", "root", "create", "--description", "pre-update snapshot", "--print-number"], capture=True, check=False, timeout=60)
            if res.returncode == 0:
                raw_id = res.stdout.strip()
                num_id = "".join(c for c in raw_id if c.isdigit())
                if num_id:
                    report["steps"]["snapshot"] = f"Created snapshot {num_id}"
                    if log_cb:
                        log_cb(f"Created pre-update system snapshot: ID {num_id}", 1)
                else:
                    raise Exception(f"Invalid snapshot number from snapper: {raw_id}")
            else:
                raise Exception(f"snapper failed with code {res.returncode}: {res.stderr}")
        except Exception as exc:
            log.warning("Btrfs snapshot failed: %s", exc)
            report["steps"]["snapshot"] = f"Warning: {exc}"
            if log_cb:
                log_cb(f"Warning: System snapshot failed: {exc}", 1)

        # Step 2: Update system packages via pacman
        if log_cb:
            log_cb("Step 2/5: Updating system packages via pacman...", 2)
        try:
            _run_cmd(["pacman", "-Syu", "--noconfirm"], timeout=1800)
            report["steps"]["pacman"] = "Success"
            if log_cb:
                log_cb("System packages updated successfully via pacman.", 2)
        except Exception as exc:
            log.error("pacman update failed: %s", exc)
            report["steps"]["pacman"] = f"Failed: {exc}"
            report["success"] = False
            if log_cb:
                log_cb(f"Failed: pacman update failed: {exc}", 2)
            return report

        # Step 3: Update Flatpak packages
        if log_cb:
            log_cb("Step 3/5: Updating Flatpak packages...", 3)
        try:
            _run_cmd(["flatpak", "update", "-y"], timeout=1800)
            report["steps"]["flatpak"] = "Success"
            if log_cb:
                log_cb("Flatpak packages updated.", 3)
        except Exception as exc:
            log.warning("Flatpak update failed: %s", exc)
            report["steps"]["flatpak"] = f"Warning: {exc}"
            if log_cb:
                log_cb(f"Warning: Flatpak update: {exc}", 3)

        # Step 4: Update Wine prefixes using wineboot -u
        if log_cb:
            log_cb("Step 4/5: Updating Wine prefixes via wineboot -u...", 4)
        try:
            prefix_dirs = []
            if PREFIX_DIR.exists():
                prefix_dirs = [d for d in PREFIX_DIR.iterdir() if d.is_dir() and not d.name.startswith(".")]
            
            for prefix_path in prefix_dirs:
                if log_cb:
                    log_cb(f"Updating Wine prefix '{prefix_path.name}'...", 4)
                env = {
                    "WINEPREFIX": str(prefix_path),
                    "WINEARCH": "win64",
                    "WINEDLLOVERRIDES": "winemenubuilder.exe=d",
                    "DISPLAY": "",
                }
                try:
                    _run_cmd(["wineboot", "-u"], env=env, timeout=300)
                except Exception as prefix_exc:
                    log.warning("Failed to update prefix %s: %s", prefix_path.name, prefix_exc)
            report["steps"]["wine"] = "Success"
            if log_cb:
                log_cb("Wine prefixes updated.", 4)
        except Exception as exc:
            log.warning("Wine prefix updates failed: %s", exc)
            report["steps"]["wine"] = f"Warning: {exc}"
            if log_cb:
                log_cb(f"Warning: Wine update: {exc}", 4)

        # Step 5: Update AUR packages via yay
        if log_cb:
            log_cb("Step 5/5: Updating AUR packages via yay...", 5)
        try:
            cmd = ["yay", "-Syu", "--noconfirm"]
            sudo_user = os.environ.get("SUDO_USER")
            if sudo_user and hasattr(os, "getuid") and os.getuid() == 0:
                cmd = ["sudo", "-u", sudo_user] + cmd
            _run_cmd(cmd, timeout=1800)
            report["steps"]["yay"] = "Success"
            if log_cb:
                log_cb("AUR packages updated.", 5)
        except Exception as exc:
            log.warning("yay update failed: %s", exc)
            report["steps"]["yay"] = f"Warning: {exc}"
            if log_cb:
                log_cb(f"Warning: yay update: {exc}", 5)

        return report

    def optimize(
        self,
        gpu_only: bool = False,
        cpu_only: bool = False,
        memory_only: bool = False,
        dry_run: bool = False,
        log_cb = None,
    ) -> None:
        """Tune system performance settings (GPU, CPU, Memory)."""
        run_all = not (gpu_only or cpu_only or memory_only)
        
        # Memory optimization
        if (memory_only or run_all):
            if log_cb:
                log_cb("Optimizing memory and VM settings...")
            if not dry_run:
                try:
                    _run_cmd(["sync"], check=True)
                    drop_caches_path = Path("/proc/sys/drop_caches")
                    if drop_caches_path.exists():
                        drop_caches_path.write_text("3")
                    elif Path("/proc/sys/vm/drop_caches").exists():
                        Path("/proc/sys/vm/drop_caches").write_text("3")
                    if log_cb:
                        log_cb("RAM caches flushed successfully.")
                except Exception as exc:
                    if log_cb:
                        log_cb(f"Failed to flush RAM caches: {exc}")

                try:
                    _run_cmd(["sysctl", "-w", "vm.swappiness=10"], capture=False, check=True)
                    _run_cmd(["sysctl", "-w", "vm.dirty_ratio=15"], capture=False, check=True)
                    if log_cb:
                        log_cb("Zen kernel VM parameters (swappiness=10, dirty_ratio=15) optimized.")
                except Exception as exc:
                    if log_cb:
                        log_cb(f"Failed to optimize VM sysctl parameters: {exc}")

                try:
                    thp_path = Path("/sys/kernel/mm/transparent_hugepage/enabled")
                    if thp_path.exists():
                        thp_path.write_text("always")
                        if log_cb:
                            log_cb("Transparent Hugepages set to always.")
                except Exception as exc:
                    if log_cb:
                        log_cb(f"Failed to set Transparent Hugepages: {exc}")

        # GPU optimization
        if (gpu_only or run_all):
            if log_cb:
                log_cb("Optimizing GPU power profiles...")
            if not dry_run:
                gpu_vendor = _detect_gpu_vendor()
                if gpu_vendor == "nvidia":
                    try:
                        env = os.environ.copy()
                        if "DISPLAY" not in env:
                            env["DISPLAY"] = ":0"
                        _run_cmd(["nvidia-settings", "-a", "[gpu:0]/GPUPowerMizerMode=1"], env=env, check=True)
                        if log_cb:
                            log_cb("NVIDIA GPU PowerMizerMode set to maximum performance.")
                    except Exception as exc:
                        if log_cb:
                            log_cb(f"Failed to optimize NVIDIA GPU: {exc}")
                elif gpu_vendor == "amd":
                    try:
                        amd_pwr_path = Path("/sys/class/drm/card0/device/power_dpm_force_performance_level")
                        if amd_pwr_path.exists():
                            amd_pwr_path.write_text("performance")
                            if log_cb:
                                log_cb("AMD GPU performance level set to performance.")
                        else:
                            if log_cb:
                                log_cb("AMD GPU performance level path not found.")
                    except Exception as exc:
                        if log_cb:
                            log_cb(f"Failed to optimize AMD GPU: {exc}")
                else:
                    if log_cb:
                        log_cb("No supported dedicated GPU detected for vendor optimization.")

        # CPU optimization
        if (cpu_only or run_all):
            if log_cb:
                log_cb("Optimizing CPU frequency scaling governor...")
            if not dry_run:
                try:
                    _run_cmd(["cpupower", "frequency-set", "-g", "performance"], check=True)
                    if log_cb:
                        log_cb("CPU frequency scaling governor set to performance.")
                except Exception as exc:
                    try:
                        governor_paths = list(Path("/sys/devices/system/cpu").glob("cpu*/cpufreq/scaling_governor"))
                        for p in governor_paths:
                            p.write_text("performance")
                        if log_cb:
                            log_cb("CPU scaling governor manually set to performance for all cores.")
                    except Exception as fallback_exc:
                        if log_cb:
                            log_cb(f"Failed to set CPU scaling governor: {exc} (fallback failed: {fallback_exc})")

    def doctor(self) -> Dict[str, List[Dict[str, Any]]]:
        """Perform system-wide diagnostics on multiple components and return categorized reports."""
        report = {}

        # 1. Wine
        wine_checks = []
        if self.wine_path:
            wine_checks.append({"name": "Wine Executable", "status": "OK", "message": f"Found at {self.wine_path}"})
        else:
            wine_checks.append({"name": "Wine Executable", "status": "FAIL", "message": "Wine executable not found on PATH."})
        if self.winetricks_path:
            wine_checks.append({"name": "Winetricks Executable", "status": "OK", "message": f"Found at {self.winetricks_path}"})
        else:
            wine_checks.append({"name": "Winetricks Executable", "status": "WARN", "message": "winetricks not found; VC++ and media libraries will fall back to direct DLL injection."})
        report["Wine"] = wine_checks

        # 2. GPU
        gpu_checks = []
        gpu_vendor = _detect_gpu_vendor()
        if gpu_vendor:
            gpu_checks.append({"name": "GPU Detection", "status": "OK", "message": f"Detected vendor: {gpu_vendor}"})
            driver_ver = _get_gpu_driver_version()
            gpu_checks.append({"name": "Driver Version", "status": "OK", "message": f"Driver version: {driver_ver}"})
        else:
            gpu_checks.append({"name": "GPU Detection", "status": "FAIL", "message": "Could not identify dedicated GPU vendor."})
        report["GPU"] = gpu_checks

        # 3. Vulkan
        vulkan_checks = []
        try:
            vulkaninfo = _which("vulkaninfo")
            if vulkaninfo:
                vulkan_checks.append({"name": "Vulkan Diagnostic Utility", "status": "OK", "message": f"vulkaninfo found at {vulkaninfo}"})
                res = _run_cmd(["vulkaninfo", "--summary"], capture=True, check=False, timeout=10)
                if res.returncode == 0:
                    vulkan_checks.append({"name": "Vulkan Instance Support", "status": "OK", "message": "Vulkan instance verified successfully."})
                else:
                    vulkan_checks.append({"name": "Vulkan Instance Support", "status": "WARN", "message": f"vulkaninfo ran but exited with error code {res.returncode}"})
            else:
                res = _run_cmd(["pacman", "-Qq", "vulkan-icd-loader"], capture=True, check=False, timeout=5)
                if res.returncode == 0:
                    vulkan_checks.append({"name": "Vulkan ICD Loader", "status": "OK", "message": "vulkan-icd-loader package is installed."})
                else:
                    vulkan_checks.append({"name": "Vulkan ICD Loader", "status": "FAIL", "message": "vulkan-icd-loader is not installed; Vulkan apps will fail."})
        except Exception as exc:
            vulkan_checks.append({"name": "Vulkan Check", "status": "FAIL", "message": f"Vulkan check encountered error: {exc}"})
        report["Vulkan"] = vulkan_checks

        # 4. OpenGL
        opengl_checks = []
        try:
            glxinfo = _which("glxinfo")
            if glxinfo:
                res = _run_cmd(["glxinfo"], capture=True, check=False, timeout=10)
                if res.returncode == 0:
                    direct_rendering = "unknown"
                    for line in res.stdout.splitlines():
                        if "direct rendering" in line:
                            direct_rendering = line.split(":")[-1].strip()
                            break
                    if "yes" in direct_rendering.lower():
                        opengl_checks.append({"name": "OpenGL Direct Rendering", "status": "OK", "message": "Direct rendering enabled."})
                    else:
                        opengl_checks.append({"name": "OpenGL Direct Rendering", "status": "WARN", "message": f"Direct rendering status: {direct_rendering}"})
                else:
                    opengl_checks.append({"name": "OpenGL Query", "status": "WARN", "message": "glxinfo failed to execute properly."})
            else:
                opengl_checks.append({"name": "OpenGL Diagnostic Utility", "status": "WARN", "message": "glxinfo not found; skipping advanced OpenGL checks."})
        except Exception as exc:
            opengl_checks.append({"name": "OpenGL Check", "status": "FAIL", "message": f"OpenGL check encountered error: {exc}"})
        report["OpenGL"] = opengl_checks

        # 5. Audio
        audio_checks = []
        audio_server = _detect_audio_server()
        if audio_server:
            audio_checks.append({"name": "Audio Server", "status": "OK", "message": f"Active audio server: {audio_server}"})
        else:
            audio_checks.append({"name": "Audio Server", "status": "WARN", "message": "No active audio server (PipeWire or PulseAudio) detected."})
        
        uid = os.getuid() if hasattr(os, "getuid") else 1000
        pulse_socket = Path(f"/run/user/{uid}/pulse/native")
        if pulse_socket.exists():
            audio_checks.append({"name": "PulseAudio/PipeWire Unix Socket", "status": "OK", "message": f"Socket exists and is accessible: {pulse_socket}"})
        else:
            audio_checks.append({"name": "PulseAudio/PipeWire Unix Socket", "status": "WARN", "message": f"Socket not found at {pulse_socket}"})
        report["Audio"] = audio_checks

        # 6. Flatpak
        flatpak_checks = []
        flatpak_bin = _which("flatpak")
        if flatpak_bin:
            flatpak_checks.append({"name": "Flatpak Executable", "status": "OK", "message": f"Found at {flatpak_bin}"})
            res = _run_cmd(["flatpak", "remotes"], capture=True, check=False, timeout=10)
            if "flathub" in res.stdout.lower():
                flatpak_checks.append({"name": "Flathub Remote", "status": "OK", "message": "Flathub remote repository is configured."})
            else:
                flatpak_checks.append({"name": "Flathub Remote", "status": "WARN", "message": "Flathub remote is not configured."})
        else:
            flatpak_checks.append({"name": "Flatpak Executable", "status": "FAIL", "message": "Flatpak is not installed on the system."})
        report["Flatpak"] = flatpak_checks

        # 7. Disk Space
        disk_checks = []
        try:
            statvfs = os.statvfs(get_user_home())
            free_bytes = statvfs.f_frsize * statvfs.f_bavail
            free_gb = free_bytes / (1024**3)
            if free_gb > 10.0:
                disk_checks.append({"name": "Available Disk Space", "status": "OK", "message": f"{free_gb:.2f} GB free in user home."})
            elif free_gb > 2.0:
                disk_checks.append({"name": "Available Disk Space", "status": "WARN", "message": f"Low disk space: {free_gb:.2f} GB free in user home."})
            else:
                disk_checks.append({"name": "Available Disk Space", "status": "FAIL", "message": f"Critical low disk space: {free_gb:.2f} GB free in user home."})
        except Exception as exc:
            disk_checks.append({"name": "Disk Space Check", "status": "WARN", "message": f"Failed to check disk space: {exc}"})
        report["Disk Space"] = disk_checks

        # 8. Networks
        network_checks = []
        try:
            res = _run_cmd(["ping", "-c", "1", "-W", "3", "8.8.8.8"], capture=True, check=False, timeout=5)
            if res.returncode == 0:
                network_checks.append({"name": "Internet Connectivity", "status": "OK", "message": "Pinged 8.8.8.8 successfully."})
            else:
                network_checks.append({"name": "Internet Connectivity", "status": "FAIL", "message": "Cannot reach external network (8.8.8.8)."})
        except Exception as exc:
            network_checks.append({"name": "Internet Connectivity", "status": "FAIL", "message": f"Network ping failed: {exc}"})
        report["Networks"] = network_checks

        # 9. Btrfs
        btrfs_checks = []
        is_btr = _is_btrfs(PREFIX_DIR)
        if is_btr:
            btrfs_checks.append({"name": "Btrfs Filesystem", "status": "OK", "message": f"{PREFIX_DIR} is located on a Btrfs filesystem."})
            snapper_bin = _which("snapper")
            if snapper_bin:
                btrfs_checks.append({"name": "Snapper Config", "status": "OK", "message": "snapper utility is installed."})
            else:
                btrfs_checks.append({"name": "Snapper Config", "status": "WARN", "message": "snapper not installed; rollbacks will be disabled."})
        else:
            btrfs_checks.append({"name": "Btrfs Filesystem", "status": "WARN", "message": f"{PREFIX_DIR} is NOT on a Btrfs filesystem; snapper snapshot features disabled."})
        report["Btrfs"] = btrfs_checks

        return report

    def get_rollback_preview(self, target: str, snapshot_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve preview metadata for a rollback target before executing it."""
        numeric_chars = "".join(c for c in snapshot_id if c.isdigit())
        if not numeric_chars and target == "system":
            return None
            
        if target == "system":
            try:
                res = _run_cmd(["snapper", "-c", "root", "list"], capture=True, check=False, timeout=10)
                if res.returncode == 0:
                    lines = res.stdout.strip().split("\n")
                    for line in lines:
                        parts = [p.strip() for p in line.split("|")]
                        if parts and parts[0] == numeric_chars:
                            return {
                                "Target": "System Snapper Snapshot",
                                "Snapshot ID": parts[0],
                                "Type": parts[1] if len(parts) > 1 else "unknown",
                                "Pre #": parts[2] if len(parts) > 2 else "",
                                "Date": parts[3] if len(parts) > 3 else "unknown",
                                "User": parts[4] if len(parts) > 4 else "unknown",
                                "Cleanup": parts[5] if len(parts) > 5 else "",
                                "Description": parts[6] if len(parts) > 6 else "",
                            }
                return {
                    "Target": "System Snapper Snapshot",
                    "Snapshot ID": numeric_chars,
                    "Description": f"System snapshot {numeric_chars} (could not query full metadata)"
                }
            except Exception as exc:
                log.warning("Failed to get snapper snapshot metadata: %s", exc)
                return {"Target": "System Snapper Snapshot", "Snapshot ID": numeric_chars, "Error": str(exc)}
        else:
            app_name = target
            try:
                metadata = _load_app_metadata(app_name)
                snapshot_dir = PREFIX_DIR / ".snapshots" / app_name / snapshot_id
                if not snapshot_dir.exists():
                    return None
                
                created_at = "unknown"
                try:
                    created_at = datetime.fromtimestamp(snapshot_dir.stat().st_mtime).isoformat()
                except Exception:
                    pass
                
                return {
                    "Target": f"Application Prefix: {app_name}",
                    "Snapshot Tag/ID": snapshot_id,
                    "Path": str(snapshot_dir),
                    "Created At": created_at,
                    "Source Installer": metadata.get("source_exe", "unknown"),
                    "Original Install Time": metadata.get("installed_at", "unknown"),
                }
            except Exception as exc:
                log.warning("Failed to get app prefix snapshot metadata: %s", exc)
                return None

    def rollback(self, target: str, snapshot_id: str, dry_run: bool = False) -> bool:
        """Rollback the system or an app prefix to a given snapshot ID or tag."""
        numeric_chars = "".join(c for c in snapshot_id if c.isdigit())
        
        if target == "system":
            if not numeric_chars:
                log.error("Invalid snapper snapshot ID: %s", snapshot_id)
                return False
            if dry_run:
                log.info("[dry-run] Would execute: snapper -c root rollback %s", numeric_chars)
                return True
            try:
                _run_cmd(["snapper", "-c", "root", "rollback", numeric_chars], timeout=300)
                return True
            except Exception as exc:
                log.error("Snapper rollback failed: %s", exc)
                return False
        else:
            app_name = target
            prefix_path = PREFIX_DIR / app_name
            snapshot_path = PREFIX_DIR / ".snapshots" / app_name / snapshot_id
            
            if not snapshot_path.exists():
                log.error("App prefix snapshot not found: %s", snapshot_path)
                return False
                
            if dry_run:
                log.info("[dry-run] Would restore snapshot %s to %s", snapshot_path, prefix_path)
                return True
                
            try:
                return _restore_snapshot(snapshot_path, prefix_path)
            except Exception as exc:
                log.error("App prefix rollback failed: %s", exc)
                return False

    def bug_report(self, output_path: Optional[str] = None, dry_run: bool = False) -> str:
        """Package redacted logs, tracebacks, and diagnostics to a .tar.zst archive."""
        import tempfile
        import platform
        import sys
        
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        report_name = f"conjunction-report-{timestamp}.tar.zst"
        
        if output_path:
            out_p = Path(output_path)
            if out_p.is_dir():
                final_path = out_p / report_name
            else:
                final_path = out_p
        else:
            final_path = Path.cwd() / "conjunction-report.tar.zst"
            
        if dry_run:
            log.info("[dry-run] Would generate bug report at: %s", final_path)
            return str(final_path)
            
        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                tmp_path = Path(tmpdir)
                
                # Write diagnostics log
                diag_file = tmp_path / "diagnostics.log"
                with open(diag_file, "w", encoding="utf-8") as f:
                    f.write("=== Conjunction OS Diagnostics ===\n")
                    f.write(f"Timestamp: {datetime.now().isoformat()}\n")
                    f.write(f"Python version: {sys.version}\n")
                    f.write(f"Platform: {sys.platform}\n")
                    f.write(f"OS Platform Release: {platform.release()}\n")
                    f.write(f"Wine Path: {self.wine_path}\n")
                    f.write(f"Proton Path: {self.proton_path}\n")
                    f.write(f"Winetricks Path: {self.winetricks_path}\n")
                    
                    f.write("\n=== Environment Variables ===\n")
                    for k, v in sorted(os.environ.items()):
                        if any(x in k.upper() for x in ["PASS", "SECRET", "KEY", "TOKEN", "AUTH"]):
                            f.write(f"{k}=[REDACTED]\n")
                        else:
                            f.write(f"{k}={v}\n")
                            
                    f.write("\n=== Doctor Summary ===\n")
                    try:
                        doc = self.doctor()
                        for cat, checks in doc.items():
                            f.write(f"\n[{cat}]\n")
                            for check in checks:
                                f.write(f"  {check['name']}: {check['status']} - {check['message']}\n")
                    except Exception as doc_exc:
                        f.write(f"Failed to run doctor checks: {doc_exc}\n")
                
                diag_content = diag_file.read_text(encoding="utf-8")
                redacted_diag_content = redact_sensitive_info(diag_content)
                diag_file.write_text(redacted_diag_content, encoding="utf-8")
                
                tmp_logs = tmp_path / "logs"
                tmp_logs.mkdir(parents=True, exist_ok=True)
                if LOG_DIR.exists():
                    for log_f in LOG_DIR.glob("*"):
                        if log_f.is_file():
                            content = log_f.read_text(encoding="utf-8", errors="replace")
                            redacted_content = redact_sensitive_info(content)
                            (tmp_logs / log_f.name).write_text(redacted_content, encoding="utf-8")
                
                tmp_crashes = tmp_path / "crash-reports"
                tmp_crashes.mkdir(parents=True, exist_ok=True)
                crash_reports_dir = BASE_DIR / "crash-reports"
                if crash_reports_dir.exists():
                    for crash_f in crash_reports_dir.glob("*.json"):
                        if crash_f.is_file():
                            content = crash_f.read_text(encoding="utf-8", errors="replace")
                            redacted_content = redact_sensitive_info(content)
                            (tmp_crashes / crash_f.name).write_text(redacted_content, encoding="utf-8")
                
                cmd = ["tar", "--zstd", "-cf", str(final_path), "-C", str(tmp_path), "."]
                _run_cmd(cmd, timeout=120)
                
            return str(final_path)
        except Exception as exc:
            log.error("Failed to generate bug report: %s", exc)
            raise ConjunctionError(f"Bug report generation failed: {exc}")

    def repair_prefix(self, app_name: str, dry_run: bool = False, log_cb = None) -> bool:
        """Perform safe repair on the specified application prefix."""
        prefix_path = PREFIX_DIR / app_name
        meta_file = prefix_path / ".conjunction_meta.json"
        app_json = APPS_DIR / f"{app_name}.json"
        
        if not prefix_path.exists():
            raise PrefixError(f"Wine prefix directory does not exist: {prefix_path}")
            
        if dry_run:
            log.info("[dry-run] Would repair prefix for app: %s", app_name)
            return True
            
        if not app_json.exists():
            if log_cb:
                log_cb(f"Metadata file {app_json.name} is missing. Attempting to restore...")
            try:
                if meta_file.exists():
                    with open(meta_file, "r", encoding="utf-8") as f:
                        meta_data = json.load(f)
                    
                    primary_exe = self._discover_primary_exe(prefix_path)
                    desktop_file = DESKTOP_DIR / f"conjunction-{app_name}.desktop"
                    
                    metadata = {
                        "name": app_name,
                        "source_exe": meta_data.get("source_exe", "unknown"),
                        "prefix_path": str(prefix_path),
                        "primary_exe": str(primary_exe) if primary_exe else None,
                        "desktop_entry": str(desktop_file) if desktop_file.exists() else None,
                        "installed_at": meta_data.get("created_at", datetime.now().isoformat()),
                        "gpu_vendor": _detect_gpu_vendor() or "unknown",
                        "proton": self.proton_path is not None,
                    }
                    _save_app_metadata(app_name, metadata)
                    if log_cb:
                        log_cb("Metadata file successfully restored.")
                else:
                    if log_cb:
                        log_cb("No .conjunction_meta.json found in prefix. Re-generating default metadata...")
                    primary_exe = self._discover_primary_exe(prefix_path)
                    desktop_file = DESKTOP_DIR / f"conjunction-{app_name}.desktop"
                    metadata = {
                        "name": app_name,
                        "source_exe": "unknown",
                        "prefix_path": str(prefix_path),
                        "primary_exe": str(primary_exe) if primary_exe else None,
                        "desktop_entry": str(desktop_file) if desktop_file.exists() else None,
                        "installed_at": datetime.now().isoformat(),
                        "gpu_vendor": _detect_gpu_vendor() or "unknown",
                        "proton": self.proton_path is not None,
                    }
                    _save_app_metadata(app_name, metadata)
            except Exception as exc:
                log.warning("Failed to restore metadata: %s", exc)
                if log_cb:
                    log_cb(f"Warning: Failed to restore metadata: {exc}")

        if log_cb:
            log_cb("Checking and correcting file permissions...")
        try:
            sudo_user = os.environ.get("SUDO_USER")
            if sudo_user and hasattr(os, "getuid") and os.getuid() == 0:
                import pwd
                pw = pwd.getpwnam(sudo_user)
                uid, gid = pw.pw_uid, pw.pw_gid
                
                for root_dir, dirs, files in os.walk(prefix_path):
                    for d in dirs:
                        os.chown(os.path.join(root_dir, d), uid, gid)
                    for f in files:
                        os.chown(os.path.join(root_dir, f), uid, gid)
                os.chown(prefix_path, uid, gid)
                if log_cb:
                    log_cb(f"Reset ownership of prefix to user '{sudo_user}'.")
            else:
                for root_dir, dirs, files in os.walk(prefix_path):
                    for d in dirs:
                        p = os.path.join(root_dir, d)
                        os.chmod(p, os.stat(p).st_mode | 0o700)
                    for f in files:
                        p = os.path.join(root_dir, f)
                        os.chmod(p, os.stat(p).st_mode | 0o600)
                if log_cb:
                    log_cb("File permissions set to readable/writable by owner.")
        except Exception as exc:
            log.warning("Permissions check encountered error: %s", exc)
            if log_cb:
                log_cb(f"Warning: Permissions check: {exc}")

        if log_cb:
            log_cb("Refreshing Wine registry (wineboot -u)...")
        try:
            env = {
                "WINEPREFIX": str(prefix_path),
                "WINEARCH": "win64",
                "WINEDLLOVERRIDES": "winemenubuilder.exe=d",
                "DISPLAY": "",
            }
            _run_cmd(["wineboot", "-u"], env=env, timeout=300)
            if log_cb:
                log_cb("Wine registry successfully refreshed.")
        except Exception as exc:
            log.error("Registry refresh failed: %s", exc)
            if log_cb:
                log_cb(f"Failed to refresh Wine registry: {exc}")
            return False

        desktop_file = DESKTOP_DIR / f"conjunction-{app_name}.desktop"
        if not desktop_file.exists():
            if log_cb:
                log_cb("Desktop launcher is missing. Re-synthesizing...")
            try:
                self._create_desktop_entry(app_name, prefix_path)
                if log_cb:
                    log_cb("Desktop launcher re-created.")
            except Exception as exc:
                if log_cb:
                    log_cb(f"Warning: Failed to create desktop entry: {exc}")

        return True


class ConjunctionRunner(ConjunctionAPI):
    """Backward compatibility wrapper for ConjunctionAPI."""
    pass
# ---------------------------------------------------------------------------
# CLI interface
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    """Construct the argument parser for the conjunction-runner CLI."""
    parser = argparse.ArgumentParser(
        prog="conjunction-runner",
        description=(
            "Conjunction OS — Containerized Windows Application Runner. "
            "Manages isolated Wine/Proton containers for running Windows "
            "applications on Linux with near-native performance."
        ),
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {VERSION}",
    )

    sub = parser.add_subparsers(dest="command", help="Available commands")

    # --- install ---
    install_p = sub.add_parser(
        "install",
        help="Install a Windows application into an isolated Wine prefix",
    )
    install_p.add_argument("exe_path", help="Path to the Windows installer (.exe)")
    install_p.add_argument(
        "-n", "--name",
        help="Override the application name (default: derived from exe filename)",
    )

    # --- run ---
    run_p = sub.add_parser(
        "run",
        help="Launch an installed application",
    )
    run_p.add_argument("app_name", help="Name of the installed application")
    run_p.add_argument(
        "--no-gpu",
        action="store_true",
        help="Disable GPU-specific configuration",
    )
    run_p.add_argument(
        "--debug",
        action="store_true",
        help="Enable verbose Wine debug output",
    )

    # --- list ---
    sub.add_parser(
        "list",
        help="List all installed applications",
    )

    # --- remove ---
    remove_p = sub.add_parser(
        "remove",
        help="Remove an installed application and its Wine prefix",
    )
    remove_p.add_argument("app_name", help="Name of the application to remove")

    # --- configure ---
    configure_p = sub.add_parser(
        "configure",
        help="Update runtime configuration for an installed application",
    )
    configure_p.add_argument("app_name", help="Name of the application")
    configure_p.add_argument(
        "--dxvk-hud",
        help="DXVK HUD overlay string (e.g. 'fps,memory,gpuload')",
    )
    configure_p.add_argument(
        "--esync",
        action=argparse.BooleanOptionalAction,
        help="Enable/disable Esync",
    )
    configure_p.add_argument(
        "--fsync",
        action=argparse.BooleanOptionalAction,
        help="Enable/disable Fsync",
    )
    configure_p.add_argument(
        "--wine-debug",
        help="Wine debug channel specification",
    )

    return parser


def main() -> int:
    """Entry point for the conjunction-runner CLI."""
    parser = build_parser()
    args = parser.parse_args()

    if args.command is None:
        parser.print_help()
        return 0

    runner = ConjunctionAPI()

    try:
        if args.command == "install":
            metadata = runner.install(args.exe_path, app_name=args.name)
            print(f"Installed: {metadata['name']}")
            print(f"  Prefix:  {metadata['prefix_path']}")
            if metadata.get("primary_exe"):
                print(f"  Exe:     {metadata['primary_exe']}")
            if metadata.get("desktop_entry"):
                print(f"  Desktop: {metadata['desktop_entry']}")

        elif args.command == "run":
            return runner.run(
                args.app_name,
                no_gpu=args.no_gpu,
                debug=args.debug,
            )

        elif args.command == "list":
            apps = runner.list_apps()
            if not apps:
                print("No applications installed.")
                return 0
            print(f"{'Name':<30} {'Installed':<20} {'GPU':<10}")
            print("-" * 60)
            for app in apps:
                installed = app.get("installed_at", "?")[:10]
                gpu = app.get("gpu_vendor", "?")
                print(f"{app['name']:<30} {installed:<20} {gpu:<10}")

        elif args.command == "remove":
            runner.remove(args.app_name)
            print(f"Removed: {args.app_name}")

        elif args.command == "configure":
            metadata = runner.configure(
                args.app_name,
                dxvk_hud=args.dxvk_hud,
                esync=args.esync,
                fsync=args.fsync,
                wine_debug=args.wine_debug,
            )
            print(f"Configuration updated for: {metadata['name']}")
            if metadata.get("config"):
                print(f"  Config: {json.dumps(metadata['config'], indent=2)}")

    except ConjunctionError as exc:
        log.error("Error: %s", exc)
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:
        log.error("Unexpected error: %s", exc, exc_info=True)
        print(f"Unexpected error: {exc}", file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
