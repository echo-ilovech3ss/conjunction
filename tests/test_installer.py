import pytest
import subprocess
import os
import shutil
import sys
from pathlib import Path

def get_bash_executable():
    if sys.platform == "win32":
        # Check standard Git Bash locations first since Windows system bash (WSL) might be broken
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

def test_installer_dry_run(tmp_path):
    bash_exe = get_bash_executable()
    installer_src = Path(__file__).parent.parent / "archiso" / "airootfs" / "usr/local/bin/conjunction-installer.sh"
    
    if not installer_src.exists():
        pytest.skip(f"Installer script not found at {installer_src}")
        
    # 1. Create a modified copy of the installer to bypass root checks, pacman syncs, and isolate paths
    installer_copy = tmp_path / "installer.sh"
    content = installer_src.read_text(encoding="utf-8")
    
    # Normalize line endings to avoid CRLF mismatch in replacements
    content = content.replace("\r\n", "\n")
    
    # Bypass root check
    content = content.replace("if [[ $EUID -ne 0 ]]; then", "if false; then")
    # Bypass logging redirection which breaks stdin on Windows/Git Bash
    content = content.replace('if [[ -z "${CONJUNCTION_LOGGING:-}" ]]; then', "if false; then")
    # Bypass pacman sync keyring check
    content = content.replace("if ! pacman -Sy --noconfirm --needed archlinux-keyring; then", "if false; then")
    content = content.replace("pacman -Sy --noconfirm --needed archlinux-keyring", "echo keyring-synced")
    
    # Isolate temporary files to pytest tmp_path
    state_file_path = str(tmp_path / "state.json").replace("\\", "/")
    log_file_path = str(tmp_path / "dryrun.log").replace("\\", "/")
    mnt_path = str(tmp_path / "dry-run-mnt").replace("\\", "/")
    
    content = content.replace('STATE_FILE="/tmp/conjunction-install-state.json"', f'STATE_FILE="{state_file_path}"')
    content = content.replace('LOG_FILE="/tmp/conjunction-installer-dryrun.log"', f'LOG_FILE="{log_file_path}"')
    content = content.replace('MNT="/tmp/dry-run-mnt"', f'MNT="{mnt_path}"')
    
    installer_copy.write_text(content, encoding="utf-8")
    
    # 2. Create mock bin folder with mock executables for dependencies
    bin_dir = tmp_path / "mock_bin"
    bin_dir.mkdir()
    
    dependencies = [
        "arch-chroot", "btrfs", "genfstab", "mkfs.btrfs", "mkfs.fat", 
        "pacstrap", "partprobe", "parted", "udevadm", "openssl", 
        "ping", "pacman", "systemctl", "mount", "umount"
    ]
    
    for dep in dependencies:
        dep_file = bin_dir / dep
        dep_content = "#!/bin/env bash\nexit 0\n"
        
        # Customize specific mock tools
        if dep == "openssl":
            dep_content = "#!/bin/env bash\necho 'mocked_hash'\nexit 0\n"
        elif dep == "parted":
            dep_content = "#!/bin/env bash\necho 'Disk /dev/sda: 25.0 GB'\nexit 0\n"
            
        dep_file.write_text(dep_content, encoding="utf-8")
        dep_file.chmod(0o755)
        
    # Custom mock lsblk that outputs a dummy disk name and size
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
    
    # Configure custom environment with mock bin folder prepended to PATH
    env = os.environ.copy()
    env["PATH"] = str(bin_dir) + os.path.pathsep + env.get("PATH", "")
    
    # 3. Spawn dry-run installer process using encoding="utf-8"
    proc = subprocess.Popen(
        [bash_exe, str(installer_copy), "--dry-run"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env
    )
    
    # Prepare interactive inputs
    inputs = b"ERASE\n1\ntestuser\ntestpass\ntestpass\n"
    
    stdout_bytes, stderr_bytes = proc.communicate(input=inputs, timeout=30)
    stdout = stdout_bytes.decode("utf-8")
    stderr = stderr_bytes.decode("utf-8")
    
    # Print outputs for debugging in case of failure
    print("STDOUT:")
    print(stdout)
    print("STDERR:")
    print(stderr)
    
    # Assert successful execution (exit code 0)
    assert proc.returncode == 0
    # Assert dry-run notices printed
    assert "Would run:" in stdout or "[DRY RUN]" in stdout or "Would execute" in stdout
    # Ensure it did not mutate any real partitions
    assert "Would run: mkfs.btrfs" in stdout or "[DRY RUN]" in stdout or "Would execute" in stdout
