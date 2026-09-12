#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHROOT="/root/conjunction-build/arch-chroot/root.x86_64/work/archiso-work/x86_64/airootfs"

echo "[INFO] Copying conj-notificationd sources into Arch chroot..."
mkdir -p "${CHROOT}/var/tmp"
rm -rf "${CHROOT}/var/tmp/conj-notificationd-src"
cp -r "${REPO_ROOT}/conj-notificationd" "${CHROOT}/var/tmp/conj-notificationd-src"

echo "[INFO] Compiling conj-notificationd inside Arch chroot..."
arch-chroot "$CHROOT" bash -c '
set -e
cd /var/tmp/conj-notificationd-src
rm -rf build
cmake -B build -S . -G Ninja
cmake --build build
cp build/conj-notificationd /usr/bin/conj-notificationd
cp build/test-conj-notificationd /usr/bin/test-conj-notificationd
chmod 755 /usr/bin/conj-notificationd /usr/bin/test-conj-notificationd
build/test-conj-notificationd
'

echo "[INFO] Deploying dbus services..."
mkdir -p "${CHROOT}/usr/share/dbus-1/services"
cp "${REPO_ROOT}/data/org.freedesktop.Notifications.service" "${CHROOT}/usr/share/dbus-1/services/"
cp "${REPO_ROOT}/data/org.conjunction.Notifications.service" "${CHROOT}/usr/share/dbus-1/services/"
cp "${REPO_ROOT}/data/org.freedesktop.impl.portal.desktop.plasmanotify.service" "${CHROOT}/usr/share/dbus-1/services/"

echo "[SUCCESS] conj-notificationd successfully built and deployed!"
