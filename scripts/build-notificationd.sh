#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-/tmp/build-notificationd}"
PREFIX="${PREFIX:-/usr}"

cmake -S "${REPO_ROOT}/conj-notificationd" -B "${BUILD_DIR}" -DCMAKE_INSTALL_PREFIX="${PREFIX}"
cmake --build "${BUILD_DIR}" -j"$(nproc)"
cmake --install "${BUILD_DIR}" ${DESTDIR:+--prefix "${DESTDIR}/${PREFIX#/}"}
"${BUILD_DIR}/test-conj-notificationd"

mkdir -p "${PREFIX}/share/dbus-1/services"
cp "${REPO_ROOT}/data/org.freedesktop.Notifications.service" "${PREFIX}/share/dbus-1/services/"
cp "${REPO_ROOT}/data/org.conjunction.Notifications.service" "${PREFIX}/share/dbus-1/services/"
cp "${REPO_ROOT}/data/org.freedesktop.impl.portal.desktop.plasmanotify.service" "${PREFIX}/share/dbus-1/services/"

echo "[SUCCESS] conj-notificationd built, tested, and installed to ${PREFIX}"
