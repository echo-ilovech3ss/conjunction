import pytest
import subprocess
import tarfile
import json
import os
import shutil
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence
import engine
import cli

# Mock os.statvfs on Windows since it does not exist natively
if sys.platform == "win32":
    from collections import namedtuple
    statvfs_result = namedtuple('statvfs_result', 'f_frsize f_bavail f_bsize f_blocks f_files f_ffree f_favail f_namemax')
    def statvfs_mock(path):
        return statvfs_result(
            f_frsize=4096,
            f_bavail=10000000,
            f_bsize=4096,
            f_blocks=20000000,
            f_files=1000000,
            f_ffree=500000,
            f_favail=500000,
            f_namemax=255
        )
    os.statvfs = statvfs_mock

# Robust mock function for _run_cmd
def mock_run_cmd(
    args: Sequence[str],
    *,
    env: Optional[Dict[str, str]] = None,
    capture: bool = True,
    check: bool = True,
    timeout: Optional[int] = None,
) -> subprocess.CompletedProcess[str]:
    args = [str(x) for x in args]
    cmd = args[0]
    
    if cmd == "tar":
        # Check if creating or extracting
        is_extract = any("x" in arg for arg in args if arg.startswith("-"))
        is_create = any("c" in arg for arg in args if arg.startswith("-"))
        
        archive_path = None
        for arg in args:
            if ".tar" in arg:
                archive_path = Path(arg)
                break
                
        if is_extract:
            # Extracting to stdout (look for '-O')
            if "-O" in args:
                target_file = None
                for arg in args:
                    if arg in ("manifest.json", "app.manifest"):
                        target_file = arg
                        break
                if not target_file:
                    target_file = "manifest.json"
                
                with tarfile.open(archive_path, "r") as tar:
                    member = tar.getmember(target_file)
                    f = tar.extractfile(member)
                    content = f.read().decode("utf-8")
                return subprocess.CompletedProcess(args, 0, stdout=content, stderr="")
            
            # Extracting to directory
            else:
                dest_dir = None
                if "-C" in args:
                    idx = args.index("-C")
                    dest_dir = Path(args[idx + 1])
                else:
                    dest_dir = Path.cwd()
                
                dest_dir.mkdir(parents=True, exist_ok=True)
                with tarfile.open(archive_path, "r") as tar:
                    tar.extractall(path=dest_dir)
                return subprocess.CompletedProcess(args, 0, stdout="", stderr="")
                
        elif is_create:
            source_dir = None
            if "-C" in args:
                idx = args.index("-C")
                source_dir = Path(args[idx + 1])
            else:
                source_dir = Path.cwd()
                
            files_to_add = []
            if "-C" in args:
                idx = args.index("-C")
                files_to_add = args[idx + 2:]
            else:
                files_to_add = [args[-1]]
                
            with tarfile.open(archive_path, "w:gz") as tar:
                for file_name in files_to_add:
                    file_path = source_dir / file_name
                    deref = any("h" in arg or "dereference" in arg for arg in args if arg.startswith("-"))
                    
                    if file_name == ".":
                        for item in source_dir.iterdir():
                            if deref and item.is_symlink():
                                real_item = item.resolve()
                                if real_item.is_dir():
                                    for root, dirs, files in os.walk(real_item):
                                        for f in files:
                                            full_path = Path(root) / f
                                            rel_path = full_path.relative_to(real_item)
                                            tar.add(full_path, arcname=str(Path(item.name) / rel_path))
                                else:
                                    tar.add(real_item, arcname=item.name)
                            else:
                                tar.add(item, arcname=item.name)
                    else:
                        if deref:
                            real_path = file_path
                            if file_path.is_symlink():
                                real_path = file_path.resolve()
                            if real_path.is_dir():
                                for root, dirs, files in os.walk(real_path):
                                    for f in files:
                                        full_path = Path(root) / f
                                        rel_path = full_path.relative_to(real_path)
                                        tar.add(full_path, arcname=str(Path(file_name) / rel_path))
                            else:
                                tar.add(real_path, arcname=file_name)
                        else:
                            tar.add(file_path, arcname=file_name)
                            
            return subprocess.CompletedProcess(args, 0, stdout="", stderr="")

    elif cmd == "lspci":
        return subprocess.CompletedProcess(args, 0, stdout="01:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD104 [GeForce RTX 4070] [10de:2786] (rev a1)", stderr="")
    elif cmd == "stat":
        return subprocess.CompletedProcess(args, 0, stdout="btrfs", stderr="")
    elif cmd == "glxinfo":
        return subprocess.CompletedProcess(args, 0, stdout="direct rendering: Yes\nOpenGL version string: 4.6 (Compatibility Profile) Mesa 22.0.0", stderr="")
    elif cmd == "vulkaninfo":
        return subprocess.CompletedProcess(args, 0, stdout="Vulkan Instance Version: 1.3.204", stderr="")
    elif cmd == "flatpak":
        if "remotes" in args:
            return subprocess.CompletedProcess(args, 0, stdout="flathub\tFlathub\thttps://dl.flathub.org/repo/flathub.flatpakrepo", stderr="")
        elif "search" in args:
            return subprocess.CompletedProcess(args, 0, stdout="org.example.App", stderr="")
        return subprocess.CompletedProcess(args, 0, stdout="", stderr="")
    elif cmd == "ping":
        return subprocess.CompletedProcess(args, 0, stdout="PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.", stderr="")
    elif cmd == "snapper":
        if "list" in args:
            if "number" in args:
                return subprocess.CompletedProcess(args, 0, stdout="number\n1\n2\n3", stderr="")
            return subprocess.CompletedProcess(args, 0, stdout="1 | single | | 2026-06-25 | root | | pre-update snapshot\n2 | single | | 2026-06-25 | root | | system snapshot", stderr="")
        elif "create" in args:
            return subprocess.CompletedProcess(args, 0, stdout="42", stderr="")
        return subprocess.CompletedProcess(args, 0, stdout="", stderr="")
    elif cmd == "du":
        return subprocess.CompletedProcess(args, 0, stdout="1.2G\ttotal", stderr="")
    elif cmd == "pacman":
        if "-Si" in args:
            return subprocess.CompletedProcess(args, 0, stdout="Repository      : extra\nName            : test-pkg", stderr="")
        elif "-Q" in args or "-Qq" in args or "-Qk" in args:
            return subprocess.CompletedProcess(args, 0, stdout="dxvk-bin 1.10.3", stderr="")
        return subprocess.CompletedProcess(args, 0, stdout="", stderr="")
    elif cmd == "yay":
        return subprocess.CompletedProcess(args, 0, stdout="Repository      : aur\nName            : test-pkg", stderr="")
    elif cmd in ("nvidia-settings", "cpupower", "sysctl", "wineboot", "btrfs", "sync"):
        return subprocess.CompletedProcess(args, 0, stdout="", stderr="")
    elif "wine" in cmd or cmd.endswith("wine") or cmd.endswith("wine64") or cmd.endswith("proton"):
        if "--version" in args:
            return subprocess.CompletedProcess(args, 0, stdout="wine-7.0", stderr="")
        return subprocess.CompletedProcess(args, 0, stdout="", stderr="")

    return subprocess.CompletedProcess(args, 0, stdout="", stderr="")

@pytest.fixture(autouse=True)
def mock_engine_run_cmd(monkeypatch):
    monkeypatch.setattr(engine, "_run_cmd", mock_run_cmd)

@pytest.fixture(autouse=True)
def isolate_directories(tmp_path, monkeypatch):
    # Set the directories in engine to temporary ones
    base_dir = tmp_path / ".conjunction"
    prefix_dir = base_dir / "prefixes"
    apps_dir = base_dir / "apps"
    log_dir = base_dir / "logs"
    cache_dir = base_dir / "cache"
    crash_dir = base_dir / "crash-reports"
    exports_dir = base_dir / "exports"
    config_dir = base_dir / "config"
    desktop_dir = base_dir / "desktop_entries"
    
    # Ensure they exist
    for d in [base_dir, prefix_dir, apps_dir, log_dir, cache_dir, crash_dir, exports_dir, config_dir, desktop_dir]:
        d.mkdir(parents=True, exist_ok=True)

    monkeypatch.setattr(engine, "BASE_DIR", base_dir)
    monkeypatch.setattr(engine, "PREFIX_DIR", prefix_dir)
    monkeypatch.setattr(engine, "APPS_DIR", apps_dir)
    monkeypatch.setattr(engine, "LOG_DIR", log_dir)
    monkeypatch.setattr(engine, "CACHE_DIR", cache_dir)
    monkeypatch.setattr(engine, "CRASH_DIR", crash_dir)
    monkeypatch.setattr(engine, "EXPORTS_DIR", exports_dir)
    monkeypatch.setattr(engine, "CONFIG_DIR", config_dir)
    monkeypatch.setattr(engine, "DESKTOP_DIR", desktop_dir)

    # Set directories in cli to temporary ones
    monkeypatch.setattr(cli.ConjunctionCLI, "WINE_PREFIX", str(prefix_dir))
    monkeypatch.setattr(cli.ConjunctionCLI, "APPS_DIR", str(apps_dir))
    monkeypatch.setattr(cli.ConjunctionCLI, "DESKTOP_DIR", desktop_dir)
    monkeypatch.setattr(cli.ConjunctionCLI, "ICONS_DIR", base_dir / "icons")
