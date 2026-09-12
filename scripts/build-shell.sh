#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHROOT="/root/conjunction-build/arch-chroot/root.x86_64/work/archiso-work/x86_64/airootfs"

echo "[INFO] Copying shell and design sources into Arch chroot..."
mkdir -p "${CHROOT}/tmp/conj-shelld-build"
mkdir -p "${CHROOT}/tmp/conjunction-design-build"

rm -rf "${CHROOT}/var/tmp/conj-shelld-src"
cp -r "${REPO_ROOT}/conj-shelld" "${CHROOT}/var/tmp/conj-shelld-src"

rm -rf "${CHROOT}/var/tmp/conjunction-design-src"
cp -r "${REPO_ROOT}/conjunction-design" "${CHROOT}/var/tmp/conjunction-design-src"

echo "[INFO] Compiling conj-shelld inside Arch chroot..."
arch-chroot "$CHROOT" bash -c '
set -e
cd /var/tmp/conj-shelld-src
rm -rf build
cmake -B build -S . -G Ninja
cmake --build build
cp build/conj-shelld /usr/bin/conj-shelld
chmod 755 /usr/bin/conj-shelld
'

echo "[INFO] Compiling conjunction-reference-app and gallery inside Arch chroot..."
arch-chroot "$CHROOT" bash -c '
set -e
cd /var/tmp/conjunction-design-src
rm -rf build
cmake -B build -S . -G Ninja
cmake --build build
cp build/conjunction-reference-app /usr/bin/conjunction-reference-app
cp build/conjunction-design-gallery /usr/bin/conjunction-design-gallery
chmod 755 /usr/bin/conjunction-reference-app /usr/bin/conjunction-design-gallery
'

echo "[INFO] Copying QML modules to /usr/share/conjunction/ in chroot..."
mkdir -p "${CHROOT}/usr/share/conjunction/qml"
mkdir -p "${CHROOT}/usr/share/conjunction/shell"
mkdir -p "${CHROOT}/usr/share/conjunction/reference"
cp -r "${REPO_ROOT}/conjunction-design/qml/"* "${CHROOT}/usr/share/conjunction/qml/"
cp -r "${REPO_ROOT}/conj-shelld/qml/"* "${CHROOT}/usr/share/conjunction/shell/"
cp -r "${REPO_ROOT}/conjunction-design/reference_app/"* "${CHROOT}/usr/share/conjunction/reference/"

mkdir -p /tmp/wsl-target/release
cp "${CHROOT}/usr/bin/conj-shelld" /tmp/wsl-target/release/conj-shelld
cp "${CHROOT}/usr/bin/conjunction-reference-app" /tmp/wsl-target/release/conjunction-reference-app
cp "${CHROOT}/usr/bin/conjunction-design-gallery" /tmp/wsl-target/release/conjunction-design-gallery

echo "[SUCCESS] Shell binaries and reference app successfully built and deployed!"
