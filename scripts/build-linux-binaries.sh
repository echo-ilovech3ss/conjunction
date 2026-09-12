#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/conjunction-build/arch-chroot/root.x86_64"
WINDOWS_SRC="/mnt/c/Users/Way4U/Coding-projects/conjunction"

# Mount essential chroot filesystems
mountpoint -q "${ROOT}/proc" || mount -t proc proc "${ROOT}/proc"
mountpoint -q "${ROOT}/sys"  || mount -t sysfs sys "${ROOT}/sys"
mountpoint -q "${ROOT}/dev"  || { mount --bind /dev "${ROOT}/dev" && mount --make-rslave "${ROOT}/dev"; }
mountpoint -q "${ROOT}/dev/pts" || mount -t devpts devpts "${ROOT}/dev/pts"
cp -f /etc/resolv.conf "${ROOT}/etc/resolv.conf" 2>/dev/null || true

# Bind-mount repo source
mkdir -p "${ROOT}/conjunction-repo"
mountpoint -q "${ROOT}/conjunction-repo" || mount --bind "${WINDOWS_SRC}" "${ROOT}/conjunction-repo"

echo "[INFO] Compiling native Linux Conjunction binaries in Arch chroot..."
chroot "${ROOT}" /bin/bash -c "
set -euo pipefail
export CARGO_HOME=/root/.cargo
mkdir -p /root/.cargo
cd /conjunction-repo
cargo build --release -p conj-bundle -p conj-appctl -p conj-appd -p conj-open --target-dir /tmp/target
mkdir -p /conjunction-repo/target/linux-release
cp -f /tmp/target/release/conj-bundle /conjunction-repo/target/linux-release/
cp -f /tmp/target/release/conj-appctl /conjunction-repo/target/linux-release/
cp -f /tmp/target/release/conj-appd   /conjunction-repo/target/linux-release/
cp -f /tmp/target/release/conj-open   /conjunction-repo/target/linux-release/
cp -f /tmp/target/release/conj-bundle /usr/bin/
cp -f /tmp/target/release/conj-appctl /usr/bin/
cp -f /tmp/target/release/conj-appd   /usr/bin/
cp -f /tmp/target/release/conj-open   /usr/bin/
chmod 755 /usr/bin/conj-bundle /usr/bin/conj-appctl /usr/bin/conj-appd /usr/bin/conj-open
"

echo "[SUCCESS] Native Linux binaries compiled successfully to target/linux-release/"
