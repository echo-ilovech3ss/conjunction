#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHROOT="/root/conjunction-build/arch-chroot/root.x86_64/work/archiso-work/x86_64/airootfs"

echo "[INFO] Copying conjunction-terminal sources into Arch chroot..."
mkdir -p "${CHROOT}/var/tmp"
rm -rf "${CHROOT}/var/tmp/conjunction-terminal-src"
cp -r "${REPO_ROOT}/conjunction-terminal" "${CHROOT}/var/tmp/conjunction-terminal-src"

echo "[INFO] Compiling conjunction-terminal inside Arch chroot..."
arch-chroot "$CHROOT" bash -c '
set -e
cd /var/tmp/conjunction-terminal-src
rm -rf build
cmake -B build -S . -G Ninja
cmake --build build
cp build/conjunction-terminal /usr/bin/conjunction-terminal
chmod 755 /usr/bin/conjunction-terminal
build/test-conjunction-terminal
'

echo "[INFO] Deploying desktop and bundle files in chroot..."
mkdir -p "${CHROOT}/usr/share/applications"
cp "${REPO_ROOT}/data/conjunction-terminal.desktop" "${CHROOT}/usr/share/applications/conjunction-terminal.desktop"

mkdir -p "${CHROOT}/Applications/Terminal.app/Contents/Executable"
cp "${REPO_ROOT}/data/Terminal.app/Contents/Info.toml" "${CHROOT}/Applications/Terminal.app/Contents/Info.toml"
cp "${CHROOT}/usr/bin/conjunction-terminal" "${CHROOT}/Applications/Terminal.app/Contents/Executable/conjunction-terminal"

mkdir -p /tmp/wsl-target/release
cp "${CHROOT}/usr/bin/conjunction-terminal" /tmp/wsl-target/release/conjunction-terminal

echo "[SUCCESS] Conjunction Terminal successfully built and installed to chroot /usr/bin/conjunction-terminal!"
