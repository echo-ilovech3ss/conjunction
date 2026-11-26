#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-/tmp/build-settings}"
PREFIX="${PREFIX:-/usr}"

cmake -S "${REPO_ROOT}/conjunction-settings" -B "${BUILD_DIR}" -DCMAKE_INSTALL_PREFIX="${PREFIX}"
cmake --build "${BUILD_DIR}" -j"$(nproc)"
cmake --install "${BUILD_DIR}" ${DESTDIR:+--prefix "${DESTDIR}/${PREFIX#/}"}

mkdir -p "${PREFIX}/share/applications"
cp "${REPO_ROOT}/data/conjunction-settings.desktop" "${PREFIX}/share/applications/conjunction-settings.desktop"

echo "[SUCCESS] conjunction-settings built and installed to ${PREFIX}"
