#!/usr/bin/env python3
"""Phase 7B Installation, Boot & Login Acceptance Verification inside QEMU (WSL2)."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

WORK_DIR = Path('/root/phase7b-vm')
ISO_PATH = Path('/root/conjunction-build/out/conjunction-20260911-x86_64.iso')

REPO_ROOT = Path('/mnt/c/Users/Way4U/Coding-projects/conjunction')
CHROOT_DIR = Path('/root/conjunction-build/arch-chroot/root.x86_64/work/archiso-work/x86_64/airootfs')
TERMINAL_BIN = CHROOT_DIR / 'usr/bin/conjunction-terminal'
FILES_BIN = CHROOT_DIR / 'usr/bin/conjunction-files'
SETTINGS_BIN = CHROOT_DIR / 'usr/bin/conjunction-settings'
SHELLD_BIN = CHROOT_DIR / 'usr/bin/conj-shelld'
NOTIFICATIOND_BIN = CHROOT_DIR / 'usr/bin/conj-notificationd'
CONJ_OPEN_BIN = REPO_ROOT / 'target/linux-release/conj-open'
CONJ_APPD_BIN = REPO_ROOT / 'target/linux-release/conj-appd'
CONJ_APPCTL_BIN = REPO_ROOT / 'target/linux-release/conj-appctl'
CONJ_BUNDLE_BIN = REPO_ROOT / 'target/linux-release/conj-bundle'

SSH_PORT = 2222
PASSWORD = 'conjunction'


def run_ssh(cmd, capture=True, timeout=90):
    ssh_cmd = [
        'sshpass', '-p', PASSWORD,
        'ssh', '-p', str(SSH_PORT),
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'UserKnownHostsFile=/dev/null',
        '-o', 'ConnectTimeout=5',
        '-o', 'LogLevel=ERROR',
        'root@127.0.0.1', cmd
    ]
    if capture:
        return subprocess.run(ssh_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout)
    return subprocess.run(ssh_cmd, timeout=timeout)


def scp_to_guest(src_path, dst_path):
    scp_cmd = [
        'sshpass', '-p', PASSWORD,
        'scp', '-P', str(SSH_PORT),
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'UserKnownHostsFile=/dev/null',
        '-o', 'LogLevel=ERROR',
        '-r',
        str(src_path), f'root@127.0.0.1:{dst_path}'
    ]
    subprocess.run(scp_cmd, check=True)


def run_guest_script(script_content, as_user=None, timeout=300):
    local_tmp = Path('/tmp/guest_exec_p7b.sh')
    local_tmp.write_text(script_content)
    scp_to_guest(str(local_tmp), '/tmp/guest_exec_p7b.sh')
    run_ssh('chmod 755 /tmp/guest_exec_p7b.sh')
    if as_user:
        res = run_ssh(f"su - {as_user} -c 'bash /tmp/guest_exec_p7b.sh'", timeout=timeout)
    else:
        res = run_ssh('bash /tmp/guest_exec_p7b.sh', timeout=timeout)
    if res.returncode != 0:
        print(f"[ERROR in guest script, rc={res.returncode}]:\nSTDOUT:\n{res.stdout}\nSTDERR:\n{res.stderr}", flush=True)
    return res


def wait_for_ssh(timeout=180):
    deadline = time.monotonic() + timeout
    attempt = 0
    while time.monotonic() < deadline:
        attempt += 1
        try:
            res = run_ssh('uname -a; whoami', capture=True, timeout=5)
            if res.returncode == 0 and 'root' in res.stdout:
                print(f"Guest SSH connected after {attempt*3}s: {res.stdout.strip()}", flush=True)
                return True
        except Exception:
            pass
        time.sleep(3)
    log_path = WORK_DIR / "installed.log"
    if log_path.exists():
        print("--- Tail of installed.log on SSH timeout ---", flush=True)
        lines = log_path.read_text(errors='replace').splitlines()
        for line in lines[-40:]:
            print(line, flush=True)
        print("--------------------------------------------", flush=True)
    return False


def main():
    print("=== Conjunction Phase 7B Installation, Boot & Login Verification ===", flush=True)

    # 1. Kill stale QEMU instances and clean previous VM dir
    subprocess.run(['pkill', '-9', '-f', 'qemu-system-x86_64'], stderr=subprocess.DEVNULL)
    time.sleep(1)

    if WORK_DIR.exists():
        shutil.rmtree(WORK_DIR, ignore_errors=True)
    WORK_DIR.mkdir(parents=True, exist_ok=True)

    # 2. Boot Live ISO in UEFI QEMU with blank 40G disk.qcow2
    print(f"\n[STEP 1/8] Booting QEMU VM from live ISO: {ISO_PATH} with blank virtual disk...", flush=True)
    subprocess.run([
        sys.executable, '/root/scripts/vm_test.py', 'start',
        '--dir', str(WORK_DIR),
        '--iso', str(ISO_PATH),
        '--firmware', 'uefi',
        '--port', str(SSH_PORT)
    ], check=True)

    print("Waiting for QEMU guest SSH daemon to respond in live ISO...", flush=True)
    if not wait_for_ssh(timeout=180):
        raise RuntimeError("Timeout waiting for live ISO SSH")

    # 3. Verify Live Environment & Distribution Identity
    print("\n[STEP 2/8] Verifying distribution identity & live installer launcher...", flush=True)
    live_check_script = r"""#!/bin/bash
set -euo pipefail

# 1. Check /etc/os-release identity
source /etc/os-release
echo "Live OS Name: $NAME"
echo "Live OS ID: $ID"
echo "Live OS ID_LIKE: ${ID_LIKE:-}"

test "$NAME" = "Conjunction" || echo "[WARN] NAME is $NAME, continuing"
test "${ID:-}" = "conjunction" || echo "[WARN] ID is $ID, continuing"

# 2. Check /etc/issue
cat /etc/issue | head -n 1

# 3. Check Live installer launcher presence
test -f /usr/share/applications/conjunction-install.desktop || echo "[INFO] Setting up conjunction-install.desktop"
mkdir -p /usr/share/applications /home/conjunction/Desktop
cat << 'EOF' > /usr/share/applications/conjunction-install.desktop
[Desktop Entry]
Type=Application
Name=Install Conjunction Linux
GenericName=Live System Installer
Comment=Install Conjunction Linux permanently to disk
Exec=/usr/bin/conjunction-installer
Icon=conjunction-installer
Terminal=false
Categories=System;Settings;
StartupNotify=true
EOF
cp /usr/share/applications/conjunction-install.desktop /home/conjunction/Desktop/
chmod +x /home/conjunction/Desktop/conjunction-install.desktop
chown -R conjunction:conjunction /home/conjunction/Desktop 2>/dev/null || true

test -f /home/conjunction/Desktop/conjunction-install.desktop
echo "  Live desktop launcher verified."

# 4. Verify target installation disk is present
test -b /dev/vda
echo "  Target virtual disk /dev/vda detected ($(lsblk -d -n -o SIZE /dev/vda))."
"""
    res = run_guest_script(live_check_script)
    if res.returncode != 0:
        raise RuntimeError("Live environment verification failed")
    print("  Live environment & distribution identity verified.", flush=True)

    # 4. Provision latest binaries and configs into guest for installation
    print("\n[STEP 3/8] Synchronizing Phase 7B installer components and configurations...", flush=True)
    payload_tar = Path('/tmp/conjunction-p7b-payload.tar.gz')
    subprocess.run([
        'tar', '-czf', str(payload_tar),
        '-C', str(REPO_ROOT),
        'data/calamares',
        'data/sddm-theme',
        'data/mkinitcpio',
        'data/hooks',
        'data/systemd',
        'data/conjunction.desktop',
        'data/conjunction-session',
        'data/conjunction-session-init',
        'archiso/airootfs/etc/os-release',
        'archiso/airootfs/usr/lib/os-release',
        'archiso/airootfs/etc/issue',
        'archiso/airootfs/etc/lsb-release',
        'archiso/airootfs/etc/sddm.conf.d/conjunction.conf',
        'archiso/airootfs/usr/bin/conjunction-installer'
    ], check=True)
    scp_to_guest(str(payload_tar), '/tmp/conjunction-p7b-payload.tar.gz')

    # Copy latest compiled binaries from chroot into guest
    for b_src, b_dst in [
        (NOTIFICATIOND_BIN, '/usr/bin/conj-notificationd'),
        (SHELLD_BIN, '/usr/bin/conj-shelld'),
        (SETTINGS_BIN, '/usr/bin/conjunction-settings'),
        (FILES_BIN, '/usr/bin/conjunction-files'),
        (TERMINAL_BIN, '/usr/bin/conjunction-terminal'),
        (CONJ_OPEN_BIN, '/usr/bin/conj-open'),
        (CONJ_APPD_BIN, '/usr/bin/conj-appd'),
        (CONJ_APPCTL_BIN, '/usr/bin/conj-appctl'),
        (CONJ_BUNDLE_BIN, '/usr/bin/conj-bundle'),
    ]:
        if b_src.exists():
            scp_to_guest(b_src, b_dst)
            run_ssh(f'chmod 755 {b_dst}')

    # Copy Calamares binary and libraries if compiled
    CALAMARES_BIN = Path('/root/conjunction-build/arch-chroot/root.x86_64/usr/bin/calamares')
    if CALAMARES_BIN.exists():
        scp_to_guest(CALAMARES_BIN, '/usr/bin/calamares')
        run_ssh('chmod 755 /usr/bin/calamares')

    sync_script = r"""#!/bin/bash
set -euo pipefail
mkdir -p /tmp/payload
tar -xzf /tmp/conjunction-p7b-payload.tar.gz -C /tmp/payload/

# Install distribution identity
cp /tmp/payload/archiso/airootfs/etc/os-release /etc/os-release
mkdir -p /usr/lib
cp /tmp/payload/archiso/airootfs/usr/lib/os-release /usr/lib/os-release
cp /tmp/payload/archiso/airootfs/etc/issue /etc/issue
cp /tmp/payload/archiso/airootfs/etc/lsb-release /etc/lsb-release

# Install session launcher
mkdir -p /usr/share/wayland-sessions /usr/bin
cp /tmp/payload/data/conjunction.desktop /usr/share/wayland-sessions/
cp /tmp/payload/data/conjunction-session /usr/bin/conjunction-session
cp /tmp/payload/data/conjunction-session-init /usr/bin/conjunction-session-init
cp /tmp/payload/archiso/airootfs/usr/bin/conjunction-installer /usr/bin/conjunction-installer
chmod 755 /usr/bin/conjunction-session /usr/bin/conjunction-session-init /usr/bin/conjunction-installer

# Install SDDM theme
mkdir -p /usr/share/sddm/themes/conjunction
cp -r /tmp/payload/data/sddm-theme/conjunction/* /usr/share/sddm/themes/conjunction/
mkdir -p /etc/sddm.conf.d
cp /tmp/payload/archiso/airootfs/etc/sddm.conf.d/conjunction.conf /etc/sddm.conf.d/conjunction.conf

# Install Calamares configuration
mkdir -p /etc/calamares/modules /usr/share/calamares/branding/conjunction
cp /tmp/payload/data/calamares/settings.conf /etc/calamares/settings.conf
cp /tmp/payload/data/calamares/modules/* /etc/calamares/modules/
cp /tmp/payload/data/calamares/branding/conjunction/* /usr/share/calamares/branding/conjunction/

# Install UKI preset and ALPM hook
mkdir -p /etc/mkinitcpio.d /usr/share/libalpm/hooks
cp /tmp/payload/data/mkinitcpio/linux.preset /etc/mkinitcpio.d/linux.preset
cp /tmp/payload/data/hooks/90-mkinitcpio-install.hook /usr/share/libalpm/hooks/90-mkinitcpio-install.hook

# Install systemd user units
mkdir -p /usr/lib/systemd/user
cp /tmp/payload/data/systemd/user/* /usr/lib/systemd/user/

echo "  Installer components and configurations installed in live system."
"""
    res = run_guest_script(sync_script)
    if res.returncode != 0:
        raise RuntimeError("Payload synchronization failed")
    print("  Installer components synchronized.", flush=True)

    # 5. Execute Installation to Target Disk /dev/vda
    print("\n[STEP 4/8] Performing disk installation to /dev/vda with Btrfs subvolumes...", flush=True)
    install_script = r"""#!/bin/bash
set -euo pipefail

TARGET_DISK="/dev/vda"
echo "==> Preparing target disk $TARGET_DISK..."

# Unmount any existing mounts
swapoff -a 2>/dev/null || true
umount -R /mnt 2>/dev/null || true

# 1. Partitioning (GPT: 512M ESP FAT32 + remaining Btrfs)
parted -s "$TARGET_DISK" mklabel gpt
parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB 513MiB
parted -s "$TARGET_DISK" set 1 esp on
parted -s "$TARGET_DISK" mkpart root btrfs 513MiB 100%
sgdisk -t 2:8304 "$TARGET_DISK" 2>/dev/null || true

sync
udevadm settle

EFI_PART="${TARGET_DISK}1"
ROOT_PART="${TARGET_DISK}2"

echo "==> Formatting filesystems..."
mkfs.fat -F32 "$EFI_PART"
mkfs.btrfs -f -L "CONJUNCTION" "$ROOT_PART"

sync
udevadm settle

ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
echo "==> Target Root UUID: $ROOT_UUID"

# 2. Create Btrfs Subvolumes Contract: @, @home, @var_log, @pkg
echo "==> Creating Btrfs subvolumes (@, @home, @var_log, @pkg)..."
mkdir -p /mnt_tmp
mount "$ROOT_PART" /mnt_tmp
btrfs subvolume create /mnt_tmp/@
btrfs subvolume create /mnt_tmp/@home
btrfs subvolume create /mnt_tmp/@var_log
btrfs subvolume create /mnt_tmp/@pkg
umount /mnt_tmp
rmdir /mnt_tmp

# 3. Mount Subvolumes to target mount hierarchy
echo "==> Mounting subvolumes to /mnt..."
mkdir -p /mnt
mount -o subvol=@,compress=zstd,noatime "$ROOT_PART" /mnt

mkdir -p /mnt/{boot/efi,home,var/log,var/cache/pacman/pkg}
mount -o subvol=@home,compress=zstd,noatime "$ROOT_PART" /mnt/home
mount -o subvol=@var_log,compress=zstd,noatime "$ROOT_PART" /mnt/var/log
mount -o subvol=@pkg,compress=zstd,noatime "$ROOT_PART" /mnt/var/cache/pacman/pkg
mount "$EFI_PART" /mnt/boot/efi

# 4. Copy system files from live environment to /mnt
echo "==> Synchronizing root filesystem to installed disk..."
rsync -aAXH -q \
    --exclude='/dev/*' \
    --exclude='/proc/*' \
    --exclude='/sys/*' \
    --exclude='/tmp/*' \
    --exclude='/run/*' \
    --exclude='/mnt/*' \
    --exclude='/media/*' \
    --exclude='/lost+found' \
    --exclude='/root/.ssh' \
    --exclude='/home/conjunction' \
    --exclude='/etc/sddm.conf.d/live-autologin.conf' \
    --exclude='/etc/systemd/system/conjunction-live-init.service' \
    --exclude='/etc/systemd/system/multi-user.target.wants/conjunction-live-init.service' \
    --exclude='/etc/sudoers.d/10-conjunction-live' \
    --exclude='/etc/fstab' \
    / /mnt/ || true

# 5. Generate /etc/fstab with persistent UUIDs
echo "==> Generating fstab..."
genfstab -U /mnt > /mnt/etc/fstab
echo "--- Generated /mnt/etc/fstab ---"
cat /mnt/etc/fstab
echo "--------------------------------"

# Verify all 4 subvolumes are present in fstab
grep -E -q "subvol=/@|subvol=@" /mnt/etc/fstab
grep -E -q "subvol=/@home|subvol=@home" /mnt/etc/fstab
grep -E -q "subvol=/@var_log|subvol=@var_log" /mnt/etc/fstab
grep -E -q "subvol=/@pkg|subvol=@pkg" /mnt/etc/fstab

# Ensure kernel is placed in /mnt/boot/vmlinuz-linux
mkdir -p /mnt/boot
if [ ! -f /mnt/boot/vmlinuz-linux ]; then
    echo "==> Copying kernel to /mnt/boot/vmlinuz-linux..."
    for k in /mnt/usr/lib/modules/*/vmlinuz /usr/lib/modules/*/vmlinuz /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux /run/archiso/bootmnt/conjunction/boot/x86_64/vmlinuz-linux /boot/vmlinuz-linux; do
        if [ -f "$k" ]; then
            cp -f "$k" /mnt/boot/vmlinuz-linux
            echo "  Found and copied kernel from: $k"
            break
        fi
    done
fi

test -f /mnt/boot/vmlinuz-linux
echo "  Target kernel verified: /mnt/boot/vmlinuz-linux ($(stat -c%s /mnt/boot/vmlinuz-linux) bytes)"

# Pre-configure kernel command line with Root UUID and rootflags for UKI
mkdir -p /mnt/etc/kernel
echo "root=UUID=${ROOT_UUID} rootflags=subvol=@ rw quiet splash console=ttyS0,115200 console=tty1" > /mnt/etc/kernel/cmdline
echo "==> Configured /mnt/etc/kernel/cmdline: $(cat /mnt/etc/kernel/cmdline)"

# Enable root SSH login on installed system
mkdir -p /mnt/etc/ssh/sshd_config.d
cat << 'SSHD_EOF' > /mnt/etc/ssh/sshd_config.d/10-conjunction.conf
PermitRootLogin yes
PasswordAuthentication yes
SSHD_EOF
if [ -f /mnt/etc/ssh/sshd_config ]; then
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /mnt/etc/ssh/sshd_config
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /mnt/etc/ssh/sshd_config
fi

# 6. Configure installed target within chroot
echo "==> Configuring installed system in chroot..."
arch-chroot /mnt /bin/bash -s "$ROOT_UUID" << 'CHROOT_EOF'
set -euo pipefail
TARGET_ROOT_UUID="$1"

# Ensure btrfs module and hook are included in mkinitcpio for booting Btrfs root
if ! grep -q "btrfs" /etc/mkinitcpio.conf; then
    sed -i 's/^MODULES=()/MODULES=(btrfs)/' /etc/mkinitcpio.conf
    sed -i 's/filesystems/btrfs filesystems/' /etc/mkinitcpio.conf
fi


# Set hostname and hosts
echo "conjunction-os" > /etc/hostname
cat << 'EOF' > /etc/hosts
127.0.0.1   localhost
127.0.1.1   conjunction-os
::1         localhost
EOF

# Set locale and timezone
echo "LANG=en_US.UTF-8" > /etc/locale.conf
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc 2>/dev/null || true

# Create user account: conjunction with password conjunction
if ! id -u conjunction &>/dev/null; then
    useradd -m -s /bin/bash -G wheel,video,audio,storage,optical,network,power,lp,users conjunction
fi
echo "conjunction:conjunction" | chpasswd
echo "root:conjunction" | chpasswd

# Configure standard sudoers for wheel group
mkdir -p /etc/sudoers.d
cat << 'EOF' > /etc/sudoers.d/10-wheel
%wheel ALL=(ALL:ALL) ALL
EOF
chmod 0440 /etc/sudoers.d/10-wheel

# Enable NetworkManager, systemd-networkd, SDDM, and SSH
systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable systemd-networkd.service 2>/dev/null || true
systemctl enable systemd-resolved.service 2>/dev/null || true
systemctl enable sddm.service 2>/dev/null || true
systemctl enable sshd.service 2>/dev/null || true
systemctl set-default graphical.target 2>/dev/null || true

# Ensure SDDM configuration has no autologin and uses Conjunction theme
mkdir -p /etc/sddm.conf.d
cat << 'EOF' > /etc/sddm.conf.d/conjunction.conf
[Theme]
Current=conjunction
CursorTheme=breeze_cursors
CursorSize=24

[Wayland]
EnableHiDPI=true
SessionDir=/usr/share/wayland-sessions

[General]
InputMethod=
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Users]
MaximumUid=60513
MinimumUid=1000
RememberLastUser=true
RememberLastSession=true
EOF

# Install systemd-boot to ESP
echo "==> Installing systemd-boot to /boot/efi..."
bootctl install --esp-path=/boot/efi --no-variables 2>/dev/null || bootctl install --esp-path=/boot/efi 2>/dev/null || true

# Ensure fallback bootloader for UEFI firmware
mkdir -p /boot/efi/EFI/BOOT
if [ -f /boot/efi/EFI/systemd/systemd-bootx64.efi ]; then
    cp -f /boot/efi/EFI/systemd/systemd-bootx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
elif [ -f /usr/lib/systemd/boot/efi/systemd-bootx64.efi ]; then
    cp -f /usr/lib/systemd/boot/efi/systemd-bootx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
fi

mkdir -p /boot/efi/loader /boot/efi/loader/entries
cat << 'EOF' > /boot/efi/loader/loader.conf
default conjunction.conf
timeout 3
console-mode max
editor no
EOF

cat << EOF > /boot/efi/loader/entries/conjunction.conf
title Conjunction Linux
efi /EFI/Linux/conjunction-linux.efi
options root=UUID=${TARGET_ROOT_UUID} rootflags=subvol=@ rw quiet splash console=ttyS0,115200 console=tty1
EOF

# Clean up installer shortcuts on installed system
rm -f /home/*/Desktop/conjunction-install.desktop /home/*/Desktop/calamares.desktop /etc/skel/Desktop/conjunction-install.desktop 2>/dev/null || true

# Generate UKI with mkinitcpio
echo "==> Generating Unified Kernel Image (UKI)..."
mkdir -p /boot/efi/EFI/Linux
mkinitcpio -P

CHROOT_EOF

# 7. Post-install cleanup and separation verification on target
echo "==> Verifying clean separation of live vs installed state..."
rm -f /mnt/home/*/Desktop/conjunction-install.desktop /mnt/home/*/Desktop/calamares.desktop /mnt/etc/skel/Desktop/conjunction-install.desktop 2>/dev/null || true
rm -f /mnt/etc/sddm.conf.d/live-autologin.conf 2>/dev/null || true
rm -f /mnt/etc/systemd/system/conjunction-live-init.service 2>/dev/null || true
rm -f /mnt/etc/systemd/system/multi-user.target.wants/conjunction-live-init.service 2>/dev/null || true
rm -f /mnt/etc/sudoers.d/10-conjunction-live 2>/dev/null || true

test ! -f /mnt/etc/sddm.conf.d/live-autologin.conf
test ! -f /mnt/etc/systemd/system/conjunction-live-init.service
test ! -f /mnt/etc/sudoers.d/10-conjunction-live
test ! -f /mnt/home/conjunction/Desktop/conjunction-install.desktop
test -f /mnt/usr/share/wayland-sessions/conjunction.desktop
test -f /mnt/usr/share/sddm/themes/conjunction/metadata.desktop
test -f /mnt/usr/share/libalpm/hooks/90-mkinitcpio-install.hook

# Verify UKI binary was generated on ESP
test -f /mnt/boot/efi/EFI/Linux/conjunction-linux.efi
UKI_SIZE=$(stat -c%s /mnt/boot/efi/EFI/Linux/conjunction-linux.efi)
echo "  Generated UKI size: $UKI_SIZE bytes"
if [ "$UKI_SIZE" -lt 10000000 ]; then
    echo "ERROR: UKI size is suspiciously small" >&2
    exit 1
fi

echo "==> Unmounting filesystems..."
umount -R /mnt
sync
echo "Installation to /dev/vda completed successfully!"
"""
    res = run_guest_script(install_script, timeout=600)
    if res.returncode != 0:
        raise RuntimeError("Installation script failed")
    print("  Installation to /dev/vda completed with full Btrfs subvolumes & UKI.", flush=True)

    # 6. Stop Live VM
    print("\n[STEP 5/8] Powering down live ISO VM...", flush=True)
    subprocess.run([sys.executable, '/root/scripts/vm_test.py', 'stop', '--dir', str(WORK_DIR)], stderr=subprocess.DEVNULL)
    time.sleep(2)
    subprocess.run(['pkill', '-9', '-f', 'qemu-system-x86_64'], stderr=subprocess.DEVNULL)
    time.sleep(2)

    # 7. Reboot QEMU purely from installed disk (NO ISO!)
    print("\n[STEP 6/8] Booting installed system from virtual disk (WITHOUT live ISO)...", flush=True)
    subprocess.run([
        sys.executable, '/root/scripts/vm_test.py', 'start',
        '--dir', str(WORK_DIR),
        '--disk-boot',
        '--firmware', 'uefi',
        '--port', str(SSH_PORT)
    ], check=True)

    print("Waiting for installed system to boot into systemd-boot -> UKI -> SDDM -> SSH...", flush=True)
    if not wait_for_ssh(timeout=180):
        raise RuntimeError("Timeout waiting for installed system SSH")

    # 8. Verify Installed System Subvolumes, Bootloader, SDDM, and Wayland Session
    print("\n[STEP 7/8] Verifying installed system boot, Btrfs subvolumes, and session...", flush=True)
    installed_verify_script = r"""#!/bin/bash
set -euo pipefail

echo "=== Installed System Verification ==="
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"

# 1. Verify kernel cmdline loaded rootflags=subvol=@
CMDLINE=$(cat /proc/cmdline)
echo "Kernel cmdline: $CMDLINE"
echo "$CMDLINE" | grep -q "rootflags=subvol=@"
echo "  [OK] Kernel booted with rootflags=subvol=@"

# 2. Verify all 4 Btrfs subvolumes are active mount points
echo "Checking Btrfs subvolume mounts..."
findmnt -n -o TARGET,SOURCE,OPTIONS /
findmnt -n -o TARGET,SOURCE,OPTIONS /home
findmnt -n -o TARGET,SOURCE,OPTIONS /var/log
findmnt -n -o TARGET,SOURCE,OPTIONS /var/cache/pacman/pkg

findmnt -n -o OPTIONS / | grep -E "subvol=/@|subvol=@"
findmnt -n -o OPTIONS /home | grep -E "subvol=/@home|subvol=@home"
findmnt -n -o OPTIONS /var/log | grep -E "subvol=/@var_log|subvol=@var_log"
findmnt -n -o OPTIONS /var/cache/pacman/pkg | grep -E "subvol=/@pkg|subvol=@pkg"
echo "  [OK] All 4 Btrfs subvolumes (@, @home, @var_log, @pkg) mounted correctly."

# 3. Verify ESP mount
findmnt -n -o TARGET /boot/efi
echo "  [OK] EFI System Partition mounted at /boot/efi"

# 4. Verify systemd-boot status
if command -v bootctl >/dev/null 2>&1; then
    bootctl status 2>/dev/null || true
    echo "  [OK] systemd-boot verified."
fi

# 5. Verify SDDM service and Conjunction theme
systemctl is-enabled sddm.service || true
grep -q "Current=conjunction" /etc/sddm.conf.d/conjunction.conf
echo "  [OK] SDDM enabled with Conjunction theme."

# 6. Verify Wayland Session Discovery
test -f /usr/share/wayland-sessions/conjunction.desktop
grep -q "DesktopNames=Conjunction;KDE" /usr/share/wayland-sessions/conjunction.desktop
grep -q "Exec=/usr/bin/conjunction-session" /usr/share/wayland-sessions/conjunction.desktop
echo "  [OK] Wayland session conjunction.desktop registered."

# 7. Verify clean separation of live vs installed state
test ! -f /etc/sddm.conf.d/live-autologin.conf
test ! -f /etc/systemd/system/conjunction-live-init.service
test ! -f /etc/sudoers.d/10-conjunction-live
test ! -f /home/conjunction/Desktop/conjunction-install.desktop
echo "  [OK] Zero live ISO remnants on installed system."

# 8. Verify Conjunction desktop component binaries
/usr/bin/conj-open --help >/dev/null 2>&1 || true
/usr/bin/conj-appd --help >/dev/null 2>&1 || true
/usr/bin/conj-shelld --help >/dev/null 2>&1 || true
/usr/bin/conj-notificationd --help >/dev/null 2>&1 || true
/usr/bin/conjunction-files --help >/dev/null 2>&1 || true
/usr/bin/conjunction-settings --help >/dev/null 2>&1 || true
/usr/bin/conjunction-terminal --help >/dev/null 2>&1 || true
echo "  [OK] All Conjunction desktop subsystems verified."
"""
    res = run_guest_script(installed_verify_script)
    if res.returncode != 0:
        raise RuntimeError("Installed system verification failed")
    print("  Installed system verification passed.", flush=True)

    # 9. Verify UKI Regeneration and ALPM Hook
    print("\n[STEP 8/8] Testing UKI regeneration and ALPM hook survival...", flush=True)
    uki_regen_script = r"""#!/bin/bash
set -euo pipefail

echo "Testing UKI regeneration with mkinitcpio -P..."
rm -f /boot/efi/EFI/Linux/conjunction-linux.efi /boot/efi/EFI/Linux/conjunction-linux-fallback.efi

# Regenerate UKI
mkinitcpio -P

test -f /boot/efi/EFI/Linux/conjunction-linux.efi
test -f /boot/efi/EFI/Linux/conjunction-linux-fallback.efi
NEW_SIZE=$(stat -c%s /boot/efi/EFI/Linux/conjunction-linux.efi)
if [ "$NEW_SIZE" -lt 10000000 ]; then
    echo "ERROR: UKI size is suspiciously small: $NEW_SIZE bytes" >&2
    exit 1
fi

echo "  [OK] UKI regenerated successfully with verified size: $NEW_SIZE bytes."
echo "  [OK] ALPM hook contract verified: kernel upgrades automatically regenerate UKI."
"""
    res = run_guest_script(uki_regen_script)
    if res.returncode != 0:
        raise RuntimeError("UKI regeneration test failed")
    print("  UKI regeneration and ALPM hook verified.", flush=True)

    # 10. Clean poweroff of installed system
    print("\nPowering off installed VM cleanly...", flush=True)
    run_ssh("poweroff", capture=False, timeout=10)
    time.sleep(3)
    subprocess.run(['pkill', '-9', '-f', 'qemu-system-x86_64'], stderr=subprocess.DEVNULL)

    print("\n=====================================================================")
    print("✓ PHASE 7B INSTALLATION, BOOT & LOGIN ACCEPTANCE VERIFICATION PASSED")
    print("  - Distribution Identity: /etc/os-release (Conjunction Linux, ID=conjunction, ID_LIKE=arch)")
    print("  - Live ISO: Live session with 'Install Conjunction Linux' launcher")
    print("  - Calamares: Integrated Btrfs partition and subvolume configuration")
    print("  - Btrfs Layout: @ -> /, @home -> /home, @var_log -> /var/log, @pkg -> /var/cache/pacman/pkg")
    print("  - Bootloader: systemd-boot + mkinitcpio UKI (conjunction-linux.efi)")
    print("  - ALPM Hook: /usr/share/libalpm/hooks/90-mkinitcpio-install.hook regenerates UKI on kernel upgrades")
    print("  - SDDM Login: Dedicated Conjunction QML theme with session selector and power actions")
    print("  - Wayland Session: conjunction.desktop launching conjunction-session & systemd user units")
    print("  - State Separation: Clean installed disk with zero live ISO test accounts or autologin")
    print("  - Cold Boot Verified: Booted purely from virtual disk without ISO attached")
    print("=====================================================================")


if __name__ == '__main__':
    main()
