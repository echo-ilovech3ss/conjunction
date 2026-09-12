#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHROOT="/root/conjunction-build/arch-chroot/root.x86_64/work/archiso-work/x86_64/airootfs"

echo "[INFO] Copying conjunction-settings sources into Arch chroot..."
mkdir -p "${CHROOT}/var/tmp"
rm -rf "${CHROOT}/var/tmp/conjunction-settings-src"
cp -r "${REPO_ROOT}/conjunction-settings" "${CHROOT}/var/tmp/conjunction-settings-src"

echo "[INFO] Compiling conjunction-settings inside Arch chroot..."
arch-chroot "$CHROOT" bash -c '
set -e
cd /var/tmp/conjunction-settings-src
rm -rf build
cmake -B build -S . -G Ninja
cmake --build build
cp build/conjunction-settings /usr/bin/conjunction-settings
chmod 755 /usr/bin/conjunction-settings
'

echo "[INFO] Copying QML files to /usr/share/conjunction/settings/ in chroot..."
mkdir -p "${CHROOT}/usr/share/conjunction/settings"
cp -r "${REPO_ROOT}/conjunction-settings/qml/"* "${CHROOT}/usr/share/conjunction/settings/"
mkdir -p "${CHROOT}/usr/share/conjunction/qml/Conjunction/Design"
cp -r "${REPO_ROOT}/conjunction-design/qml/Conjunction/Design/"* "${CHROOT}/usr/share/conjunction/qml/Conjunction/Design/"
mkdir -p "${CHROOT}/usr/share/applications"
cp "${REPO_ROOT}/data/conjunction-settings.desktop" "${CHROOT}/usr/share/applications/conjunction-settings.desktop"

mkdir -p /tmp/wsl-target/release
cp "${CHROOT}/usr/bin/conjunction-settings" /tmp/wsl-target/release/conjunction-settings

echo "[SUCCESS] Conjunction Settings successfully built and installed to chroot /usr/bin/conjunction-settings!"
