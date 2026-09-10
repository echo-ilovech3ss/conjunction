import pytest
import subprocess
import os
import shutil
import sys
import json
from pathlib import Path

def get_bash_executable():
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
    return shutil.which("bash") or "bash"

def setup_mock_installer(tmp_path):
    bash_exe = get_bash_executable()
    installer_src = Path(__file__).parent.parent / "archiso" / "airootfs" / "usr/local/bin/conjunction-installer.sh"
    
    if not installer_src.exists():
        pytest.skip(f"Installer script not found at {installer_src}")
        
    installer_copy = tmp_path / "installer.sh"
    content = installer_src.read_text(encoding="utf-8")
    content = content.replace("\r\n", "\n")
    
    content = content.replace("if [[ $EUID -ne 0 ]]; then", "if false; then")
    content = content.replace('if [[ -z "${CONJUNCTION_LOGGING:-}" ]]; then', "if false; then")
    content = content.replace("if ! pacman -Sy --noconfirm --needed archlinux-keyring; then", "if false; then")
    content = content.replace("pacman -Sy --noconfirm --needed archlinux-keyring", "echo keyring-synced")
    
    state_file_path = str(tmp_path / "state.json").replace("\\", "/")
    log_file_path = str(tmp_path / "dryrun.log").replace("\\", "/")
    mnt_path = str(tmp_path / "dry-run-mnt").replace("\\", "/")
    
    content = content.replace('STATE_FILE="/tmp/conjunction-install-state.json"', f'STATE_FILE="{state_file_path}"')
    content = content.replace('LOG_FILE="/tmp/conjunction-installer-dryrun.log"', f'LOG_FILE="{log_file_path}"')
    content = content.replace('MNT="/tmp/dry-run-mnt"', f'MNT="{mnt_path}"')
    
    installer_copy.write_text(content, encoding="utf-8")
    
    bin_dir = tmp_path / "mock_bin"
    bin_dir.mkdir(exist_ok=True)
    
    dependencies = [
        "arch-chroot", "btrfs", "genfstab", "mkfs.btrfs", "mkfs.fat", 
        "pacstrap", "partprobe", "parted", "udevadm", "openssl", 
        "ping", "pacman", "systemctl", "mount", "umount"
    ]
    
    for dep in dependencies:
        dep_file = bin_dir / dep
        dep_content = "#!/bin/env bash\nexit 0\n"
        if dep == "openssl":
            dep_content = "#!/bin/env bash\necho 'mocked_hash'\nexit 0\n"
        elif dep == "parted":
            dep_content = "#!/bin/env bash\necho 'Disk /dev/sda: 25.0 GB'\nexit 0\n"
            
        dep_file.write_text(dep_content, encoding="utf-8")
        dep_file.chmod(0o755)
        
    lsblk_file = bin_dir / "lsblk"
    lsblk_content = """#!/bin/env bash
if [[ "$*" == *"-d -n -o NAME"* ]]; then
    echo "sda"
elif [[ "$*" == *"-d -b -o SIZE"* ]]; then
    echo "25000000000"
elif [[ "$*" == *"-d -o SIZE"* ]]; then
    echo "25G"
else
    echo "sda 25G model rota"
fi
exit 0
"""
    lsblk_file.write_text(lsblk_content, encoding="utf-8")
    lsblk_file.chmod(0o755)
    
    env = os.environ.copy()
    env["PATH"] = str(bin_dir) + os.path.pathsep + env.get("PATH", "")
    
    return bash_exe, installer_copy, env, state_file_path

def test_installer_dry_run_uefi(tmp_path):
    bash_exe, installer_copy, env, _ = setup_mock_installer(tmp_path)
    proc = subprocess.Popen(
        [bash_exe, str(installer_copy), "--dry-run"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env
    )
    inputs = b"y\nERASE\n1\n1\ntestuser\ntestpass\ntestpass\ny\n"
    stdout_bytes, stderr_bytes = proc.communicate(input=inputs, timeout=30)
    stdout = stdout_bytes.decode("utf-8")
    assert proc.returncode == 0
    assert "[DRY RUN]" in stdout or "Would run:" in stdout
    assert "Would run: mkfs.btrfs" in stdout or "[DRY RUN]" in stdout

def test_installer_dry_run_bios(tmp_path):
    bash_exe, installer_copy, env, _ = setup_mock_installer(tmp_path)
    proc = subprocess.Popen(
        [bash_exe, str(installer_copy), "--dry-run"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env
    )
    inputs = b"y\nERASE\n2\n1\ntestuser\ntestpass\ntestpass\ny\n"
    stdout_bytes, stderr_bytes = proc.communicate(input=inputs, timeout=30)
    stdout = stdout_bytes.decode("utf-8")
    assert proc.returncode == 0
    assert "using scheme 2" in stdout
    assert "grub-install --target=i386-pc" in stdout

def test_installer_resume_state(tmp_path):
    bash_exe, installer_copy, env, state_file_path = setup_mock_installer(tmp_path)
    state_data = {
        "completed_steps": ["select_disk", "partitioning", "subvolumes"],
        "target_disk": "sda",
        "part_scheme": "1",
        "efi_part": "/dev/sda1",
        "root_part": "/dev/sda2",
        "username": "resumetest"
    }
    Path(state_file_path).write_text(json.dumps(state_data), encoding="utf-8")
    proc = subprocess.Popen(
        [bash_exe, str(installer_copy), "--dry-run"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env
    )
    inputs = b"y\ntestuser\ntestpass\ntestpass\ny\n"
    stdout_bytes, stderr_bytes = proc.communicate(input=inputs, timeout=30)
    stdout = stdout_bytes.decode("utf-8")
    assert proc.returncode == 0
    assert "Step 1: Select Installation Disk (Skipped - already completed)" in stdout
    assert "Step 2: Partitioning (Skipped - already completed)" in stdout
