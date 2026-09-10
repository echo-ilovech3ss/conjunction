"""
Conjunction OS - Backend Engine and System Discovery
Handles disk detection, hardware specs, preflight validation, checkpoint state,
and asynchronous installation runner orchestration.
"""

import os
import sys
import re
import json
import time
import shutil
import socket
import threading
import subprocess
import tempfile
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Callable, Any, Tuple


@dataclass
class DiskInfo:
    name: str              # e.g., "sda" or "nvme0n1"
    path: str              # e.g., "/dev/sda"
    size_bytes: int        # e.g., 250059350016
    size_human: str        # e.g., "232.8 GB"
    model: str             # e.g., "Samsung SSD 980"
    is_rotational: bool    # True for HDD, False for SSD/NVMe
    partitions: List[Dict[str, Any]] = field(default_factory=list)

    @property
    def disk_type_label(self) -> str:
        if "nvme" in self.name.lower():
            return "NVMe SSD"
        return "HDD" if self.is_rotational else "SATA SSD"


@dataclass
class SystemSpecs:
    cpu_model: str
    ram_total_gb: float
    ram_free_gb: float
    is_uefi: bool
    is_network_connected: bool
    live_disk_free_gb: float


@dataclass
class InstallConfig:
    target_disk: str = ""
    part_scheme: int = 1         # 1 = UEFI (GPT), 2 = BIOS (MBR)
    part_method: int = 1         # 1 = Automatic Btrfs, 2 = Manual
    username: str = ""
    fullname: str = ""
    password: str = ""
    root_password: str = ""
    same_root_password: bool = True
    hostname: str = "conjunction"
    timezone: str = "UTC"
    enable_wine_proton: bool = True
    enable_zen_kernel: bool = True
    enable_snapper: bool = True
    enable_auto_login: bool = False
    is_dry_run: bool = False


def find_brand_asset(asset_name: str) -> Optional[Path]:
    """Finds branded SVG/PNG asset across local, live ISO, and system paths."""
    here = Path(__file__).resolve().parent
    candidates = [
        here.parent / "assets" / asset_name,
        here.parent / "assets" / "icons" / asset_name,
        Path("/opt/conjunction/assets") / asset_name,
        Path("/opt/conjunction/assets/icons") / asset_name,
        Path("/usr/share/conjunction/branding") / asset_name,
        Path("/usr/share/pixmaps") / asset_name,
        Path("/usr/share/icons/hicolor/scalable/apps") / asset_name,
    ]
    for c in candidates:
        if c.exists():
            return c
    return None


class SystemDiscovery:
    """Discovers system hardware, firmware type, storage drives, and network."""

    @staticmethod
    def is_uefi() -> bool:
        return os.path.isdir("/sys/firmware/efi")

    @staticmethod
    def check_network(timeout_sec: float = 1.5) -> bool:
        for host in ["1.1.1.1", "8.8.8.8"]:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(timeout_sec)
                sock.connect((host, 53))
                sock.close()
                return True
            except Exception:
                pass
        return False

    @staticmethod
    def get_system_specs() -> SystemSpecs:
        cpu = "Generic Multi-Core Processor"
        if sys.platform != "win32" and os.path.exists("/proc/cpuinfo"):
            try:
                with open("/proc/cpuinfo", "r", encoding="utf-8") as f:
                    for line in f:
                        if "model name" in line:
                            cpu = line.split(":", 1)[1].strip()
                            break
            except Exception:
                pass
        elif sys.platform == "win32":
            cpu = os.environ.get("PROCESSOR_IDENTIFIER", "x86_64 Processor")

        ram_total = 8.0
        ram_free = 4.0
        if sys.platform != "win32" and os.path.exists("/proc/meminfo"):
            try:
                with open("/proc/meminfo", "r", encoding="utf-8") as f:
                    mem = {}
                    for line in f:
                        parts = line.split(":")
                        if len(parts) == 2:
                            mem[parts[0].strip()] = parts[1].strip()
                    if "MemTotal" in mem:
                        total_kb = int(mem["MemTotal"].split()[0])
                        ram_total = round(total_kb / 1024 / 1024, 1)
                    if "MemAvailable" in mem:
                        avail_kb = int(mem["MemAvailable"].split()[0])
                        ram_free = round(avail_kb / 1024 / 1024, 1)
            except Exception:
                pass

        disk_free = 20.0
        try:
            st = shutil.disk_usage("/")
            disk_free = round(st.free / (1024 ** 3), 1)
        except Exception:
            pass

        return SystemSpecs(
            cpu_model=cpu,
            ram_total_gb=ram_total,
            ram_free_gb=ram_free,
            is_uefi=SystemDiscovery.is_uefi(),
            is_network_connected=SystemDiscovery.check_network(),
            live_disk_free_gb=disk_free
        )

    @staticmethod
    def get_available_disks() -> List[DiskInfo]:
        """Discovers installation block devices using lsblk, with test simulation fallback."""
        disks: List[DiskInfo] = []
        lsblk_path = shutil.which("lsblk")

        if lsblk_path:
            try:
                # Try JSON output first
                cmd = [lsblk_path, "-J", "-b", "-d", "-o", "NAME,SIZE,MODEL,ROTA,TYPE"]
                proc = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
                if proc.returncode == 0:
                    data = json.loads(proc.stdout)
                    for dev in data.get("blockdevices", []):
                        name = dev.get("name", "")
                        # Filter out loop, cdrom, ram, zram
                        if any(x in name.lower() for x in ["loop", "sr", "ram", "zram", "dm-"]):
                            continue
                        size = int(dev.get("size", 0))
                        # Ignore drives smaller than 10GB
                        if size < 10 * 1024 * 1024 * 1024:
                            continue
                        model = dev.get("model", "Storage Device").strip()
                        rota = bool(dev.get("rota", False))
                        size_gb = round(size / (1024 ** 3), 1)
                        disks.append(DiskInfo(
                            name=name,
                            path=f"/dev/{name}",
                            size_bytes=size,
                            size_human=f"{size_gb} GB",
                            model=model or "Standard Disk",
                            is_rotational=rota
                        ))
            except Exception:
                pass

            # If json failed or empty, try plain text
            if not disks:
                try:
                    cmd = [lsblk_path, "-d", "-n", "-o", "NAME,SIZE,MODEL,ROTA"]
                    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
                    if proc.returncode == 0:
                        for line in proc.stdout.strip().splitlines():
                            parts = line.split(None, 3)
                            if not parts:
                                continue
                            name = parts[0]
                            if any(x in name.lower() for x in ["loop", "sr", "ram", "zram", "dm-"]):
                                continue
                            size_human = parts[1] if len(parts) > 1 else "Unknown"
                            model = parts[2] if len(parts) > 2 else "Storage Device"
                            rota = parts[3] == "1" if len(parts) > 3 else False
                            disks.append(DiskInfo(
                                name=name,
                                path=f"/dev/{name}",
                                size_bytes=64 * 1024 * 1024 * 1024,
                                size_human=size_human,
                                model=model,
                                is_rotational=rota
                            ))
                except Exception:
                    pass

        # Fallback simulation for tests or non-Linux development
        if not disks:
            disks = [
                DiskInfo(
                    name="nvme0n1",
                    path="/dev/nvme0n1",
                    size_bytes=512110190592,
                    size_human="476.9 GB",
                    model="Samsung NVMe SSD 980 PRO 500GB",
                    is_rotational=False
                ),
                DiskInfo(
                    name="sda",
                    path="/dev/sda",
                    size_bytes=250059350016,
                    size_human="232.8 GB",
                    model="Crucial MX500 SSD",
                    is_rotational=False
                )
            ]

        return disks


class Validation:
    """Validates user account, hostname, and storage selections."""

    @staticmethod
    def validate_username(username: str) -> Tuple[bool, str]:
        if not username:
            return False, "Username cannot be empty"
        if len(username) > 32:
            return False, "Username must be 32 characters or fewer"
        # Linux standard: start with lowercase letter or underscore, followed by lowercase, numbers, dash, underscore
        if not re.match(r"^[a-z_][a-z0-9_-]*[$]?$", username):
            return False, "Use lowercase letters, numbers, hyphens or underscores; start with a letter"
        if username in ["root", "bin", "daemon", "adm", "lp", "sync", "shutdown", "halt", "mail"]:
            return False, f"Username '{username}' is reserved by the system"
        return True, ""

    @staticmethod
    def calculate_password_strength(password: str) -> int:
        """Returns score 0 (empty) to 4 (strong)."""
        if not password:
            return 0
        score = 0
        if len(password) >= 6:
            score += 1
        if len(password) >= 10:
            score += 1
        has_upper = any(c.isupper() for c in password)
        has_lower = any(c.islower() for c in password)
        has_digit = any(c.isdigit() for c in password)
        has_special = any(not c.isalnum() for c in password)
        types_count = sum([has_upper, has_lower, has_digit, has_special])
        if types_count >= 2 and len(password) >= 8:
            score = max(score, 2)
        if types_count >= 3 and len(password) >= 8:
            score = max(score, 3)
        if types_count >= 3 and len(password) >= 12:
            score = 4
        return min(4, max(1, score))

    @staticmethod
    def validate_passwords(pw: str, confirm: str) -> Tuple[bool, str]:
        if not pw:
            return False, "Password cannot be empty"
        if ":" in pw:
            return False, "Password cannot contain colon ':' character"
        if pw != confirm:
            return False, "Passwords do not match"
        if len(pw) < 4:
            return False, "Password must be at least 4 characters"
        return True, ""

    @staticmethod
    def validate_hostname(hostname: str) -> Tuple[bool, str]:
        if not hostname:
            return False, "Hostname cannot be empty"
        if len(hostname) > 63:
            return False, "Hostname must be 63 characters or fewer"
        if not re.match(r"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$", hostname):
            return False, "Hostname must contain only letters, numbers, and hyphens"
        return True, ""


    @staticmethod
    def validate_disk_size(size_bytes: int) -> Tuple[bool, str]:
        """Validates that target disk meets the 20GB system minimum."""
        min_bytes = 20 * 1024 * 1024 * 1024
        if size_bytes < min_bytes:
            gb = round(size_bytes / (1024 ** 3), 1)
            return False, f"Selected drive is {gb} GB. Conjunction OS requires at least 20.0 GB storage space."
        return True, ""


class InstallationRunner:
    """
    Asynchronously executes or dry-run simulates the 11 Conjunction OS installation steps.
    Dispatches step transitions, percentage milestones, and log lines to callbacks.
    Integrates with conjunction-installer.sh via unattended config execution.
    """

    STEPS = [
        "Preflight Checks & Storage Setup",
        "Target Disk Safety & Wiping",
        "Partitioning (Btrfs + EFI)",
        "Creating Btrfs Subvolumes (@, @home, @snapshots)",
        "Installing Base System & Zen Kernel",
        "Configuring System (fstab, locale, timezone, hostname)",
        "Creating User Account & Sudo Rules",
        "Configuring Snapper Automated Snapshots",
        "Installing & Verifying GRUB Bootloader",
        "Enabling System Services & Audio Pipeline",
        "Conjunction OS Desktop & Wine/Proton Layer"
    ]

    def __init__(self, config: InstallConfig,
                 on_progress: Optional[Callable[[int, int, str, float, str], None]] = None,
                 on_complete: Optional[Callable[[bool, Optional[str]], None]] = None,
                 force_simulation: bool = False,
                 simulation_delay: float = 0.02):
        self.config = config
        self.on_progress = on_progress
        self.on_complete = on_complete
        self.cancelled = False
        self.force_simulation = force_simulation
        self.simulation_delay = simulation_delay
        self._thread: Optional[threading.Thread] = None
        self._process: Optional[subprocess.Popen] = None
        self.state_file = Path("/tmp/conjunction-install-state.json")

    def start(self):
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def cancel(self):
        self.cancelled = True
        if self._process and self._process.poll() is None:
            try:
                self._process.terminate()
            except Exception:
                pass

    def _emit(self, step_idx: int, log_line: str, percent: float):
        total = len(self.STEPS)
        step_name = self.STEPS[min(step_idx, total - 1)]
        if self.on_progress:
            self.on_progress(step_idx + 1, total, step_name, percent, log_line)

    def _save_checkpoint(self, step_key: str):
        try:
            data = {}
            if self.state_file.exists():
                with open(self.state_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
            completed = data.get("completed_steps", [])
            if step_key not in completed:
                completed.append(step_key)
            data["completed_steps"] = completed
            data["target_disk"] = self.config.target_disk
            data["part_scheme"] = str(self.config.part_scheme)
            data["username"] = self.config.username
            self.state_file.parent.mkdir(parents=True, exist_ok=True)
            with open(self.state_file, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
        except Exception:
            pass

    def _find_installer_script(self) -> Optional[Path]:
        env_script = os.environ.get("CONJUNCTION_INSTALLER_SCRIPT")
        if env_script and Path(env_script).exists():
            return Path(env_script)
        candidates = [
            Path("/usr/local/bin/conjunction-installer.sh"),
            Path(__file__).resolve().parent.parent / "archiso" / "airootfs" / "usr" / "local" / "bin" / "conjunction-installer.sh",
            Path("/opt/conjunction/archiso/airootfs/usr/local/bin/conjunction-installer.sh"),
        ]
        for c in candidates:
            if c.exists():
                return c
        return None

    def _find_bash(self) -> Optional[str]:
        if sys.platform == "win32":
            locations = [
                r"C:\Program Files\Git\bin\bash.exe",
                r"C:\Program Files\Git\usr\bin\bash.exe",
                r"C:\Program Files (x86)\Git\bin\bash.exe",
                r"C:\Program Files (x86)\Git\usr\bin\bash.exe",
            ]
            for loc in locations:
                if os.path.exists(loc):
                    return loc
        return shutil.which("bash")

    def _write_unattended_config(self, target_path: Optional[Path] = None) -> Path:
        data = {
            "target_disk": self.config.target_disk,
            "part_scheme": str(self.config.part_scheme),
            "part_method": str(self.config.part_method),
            "username": self.config.username,
            "fullname": self.config.fullname,
            "password": self.config.password,
            "root_password": self.config.root_password or self.config.password,
            "hostname": self.config.hostname or "conjunction",
            "timezone": self.config.timezone or "UTC",
            "enable_wine_proton": self.config.enable_wine_proton,
            "enable_zen_kernel": self.config.enable_zen_kernel,
            "enable_snapper": getattr(self.config, "enable_snapper", True),
            "is_dry_run": self.config.is_dry_run
        }
        if target_path:
            target = Path(target_path)
            target.parent.mkdir(parents=True, exist_ok=True)
            with open(target, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
            return target

        candidates = [Path("/tmp/conjunction-install-config.json"), Path(tempfile.gettempdir()) / "conjunction-install-config.json"]
        for target in candidates:
            try:
                target.parent.mkdir(parents=True, exist_ok=True)
                with open(target, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)
                return target
            except Exception:
                continue
        fallback = Path("conjunction-install-config.json")
        with open(fallback, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        return fallback

    def _write_config_file(self) -> Path:
        return self._write_unattended_config()

    def _run_backend_script(self, bash_bin: str, script_path: Path, config_file: Path):
        cmd = [bash_bin, str(script_path), "--config", str(config_file).replace("\\", "/")]
        if self.config.is_dry_run:
            cmd.append("--dry-run")

        env = os.environ.copy()
        env["CONJUNCTION_UNATTENDED"] = "1"
        env["MSYS_NO_PATHCONV"] = "1"

        self._process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
            env=env
        )

        step_idx = 0
        step_pattern = re.compile(r"═══\s*Step\s*(\d+):\s*(.*?)\s*═══")
        self._emit(0, "Initiating backend installer execution...", 2.0)

        step_keys = [
            "select_disk", "partitioning", "subvolumes", "install_base",
            "configure_system", "user_setup", "snapper_config", "bootloader",
            "services", "post_install_config", "post_install_validate"
        ]

        for raw_line in iter(self._process.stdout.readline, ""):
            if self.cancelled:
                self._process.terminate()
                break
            line = raw_line.strip()
            if not line:
                continue

            m = step_pattern.search(line)
            if m:
                step_num = int(m.group(1))
                step_idx = min(len(self.STEPS) - 1, max(0, step_num - 1))
                pct = (step_num / float(len(self.STEPS))) * 100.0
                if step_idx < len(step_keys):
                    self._save_checkpoint(step_keys[step_idx])
                self._emit(step_idx, line, pct)
            else:
                pct = min(99.0, ((step_idx + 0.5) / float(len(self.STEPS))) * 100.0)
                self._emit(step_idx, line, pct)

        self._process.stdout.close()
        ret = self._process.wait()

        if self.cancelled:
            if self.on_complete:
                self.on_complete(False, "Installation cancelled by user")
        elif ret == 0:
            self._save_checkpoint("post_install_config")
            self._emit(len(self.STEPS) - 1, "Installation pipeline completed successfully!", 100.0)
            if self.on_complete:
                self.on_complete(True, None)
        else:
            err_msg = f"Installation halted with exit code {ret}"
            if self.on_complete:
                self.on_complete(False, err_msg)

    def _run_simulation(self):
        delay = self.simulation_delay
        step_checkpoints = [
            ("preflight", "Verifying installer environment, dependencies, and mirrors...", 9.0),
            ("select_disk", f"Preparing target block device /dev/{self.config.target_disk}...", 18.0),
            ("partitioning", f"Creating Btrfs & EFI partition table on /dev/{self.config.target_disk}...", 30.0),
            ("subvolumes", "Creating modern Btrfs subvolumes: @, @home, @snapshots, @var_log...", 40.0),
            ("install_base", "Installing base system and linux-zen kernel via pacstrap...", 58.0),
            ("configure_system", f"Configuring timezone '{self.config.timezone}' and hostname '{self.config.hostname}'...", 68.0),
            ("user_setup", f"Creating user account '{self.config.username}' with wheel / sudo privileges...", 75.0),
            ("snapper_config", "Configuring Snapper automated snapshots...", 82.0),
            ("bootloader", f"Installing GRUB bootloader to /dev/{self.config.target_disk}...", 90.0),
            ("services", "Enabling systemd services: sddm, NetworkManager, bluetooth...", 95.0),
            ("post_install_config", "Deploying Conjunction OS desktop, theme, and Wine/Proton layer...", 100.0)
        ]

        self._emit(0, "Starting Conjunction OS installation pipeline (simulated)...", 2.0)
        for idx, (step_key, desc, pct) in enumerate(step_checkpoints):
            if self.cancelled:
                if self.on_complete:
                    self.on_complete(False, "Installation cancelled by user")
                return
            self._emit(idx, desc, pct)
            self._save_checkpoint(step_key)
            if delay > 0:
                time.sleep(delay)

        if self.on_complete:
            self.on_complete(True, None)

    def _can_run_backend(self, bash_bin: Optional[str], installer_script: Optional[Path]) -> bool:
        if self.force_simulation or not bash_bin or not installer_script:
            return False
        if sys.platform != "win32" or os.environ.get("CONJUNCTION_FORCE_BACKEND") == "1":
            return True
        if shutil.which("arch-chroot") or shutil.which("pacstrap"):
            return True
        return False

    def _run(self):
        try:
            installer_script = self._find_installer_script()
            bash_bin = self._find_bash()
            config_file = self._write_config_file()

            if self._can_run_backend(bash_bin, installer_script):
                self._run_backend_script(bash_bin, installer_script, config_file)
            else:
                self._run_simulation()

        except Exception as e:
            if self.on_complete:
                self.on_complete(False, str(e))
