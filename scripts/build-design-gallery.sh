#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHROOT="/root/conjunction-build/arch-chroot/root.x86_64/work/archiso-work/x86_64/airootfs"
TARGET="${CHROOT}/tmp/conjunction-design"

rm -rf "$TARGET"
mkdir -p "$TARGET"
cp -r "${REPO_ROOT}/conjunction-design/"* "$TARGET/"

echo "[INFO] Compiling conjunction-design-gallery inside Arch chroot with Qt 6..."
chroot "$CHROOT" bash -c '
set -e
cd /tmp/conjunction-design
FLAGS=$(pkg-config --cflags --libs Qt6Quick Qt6Gui Qt6Core Qt6Qml)
g++ -std=c++17 -O2 -fPIC gallery/main.cpp -o /tmp/conjunction-design-gallery $FLAGS
'

mkdir -p /tmp/wsl-target/release
cp "${CHROOT}/tmp/conjunction-design-gallery" /tmp/wsl-target/release/conjunction-design-gallery
chmod +x /tmp/wsl-target/release/conjunction-design-gallery
echo "[INFO] conjunction-design-gallery successfully built: /tmp/wsl-target/release/conjunction-design-gallery"
