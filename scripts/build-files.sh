#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHROOT="/root/conjunction-build/arch-chroot/root.x86_64/work/archiso-work/x86_64/airootfs"

echo "[INFO] Copying conjunction-files sources into Arch chroot..."
mkdir -p "${CHROOT}/var/tmp"
rm -rf "${CHROOT}/var/tmp/conjunction-files-src"
cp -r "${REPO_ROOT}/conjunction-files" "${CHROOT}/var/tmp/conjunction-files-src"

echo "[INFO] Compiling conjunction-files inside Arch chroot..."
arch-chroot "$CHROOT" bash -c '
set -e
cd /var/tmp/conjunction-files-src
rm -rf build
cmake -B build -S . -G Ninja
cmake --build build
cp build/conjunction-files /usr/bin/conjunction-files
chmod 755 /usr/bin/conjunction-files
'

echo "[INFO] Copying QML files to /usr/share/conjunction/files/ in chroot..."
mkdir -p "${CHROOT}/usr/share/conjunction/files"
cp -r "${REPO_ROOT}/conjunction-files/qml/"* "${CHROOT}/usr/share/conjunction/files/"
mkdir -p "${CHROOT}/usr/share/applications"
cp "${REPO_ROOT}/data/conjunction-files.desktop" "${CHROOT}/usr/share/applications/conjunction-files.desktop"

mkdir -p /tmp/wsl-target/release
cp "${CHROOT}/usr/bin/conjunction-files" /tmp/wsl-target/release/conjunction-files

echo "[SUCCESS] Conjunction Files successfully built and installed to chroot /usr/bin/conjunction-files!"
