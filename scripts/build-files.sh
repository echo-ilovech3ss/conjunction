#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-/tmp/build-files}"
PREFIX="${PREFIX:-/usr}"

cmake -S "${REPO_ROOT}/conjunction-files" -B "${BUILD_DIR}" -DCMAKE_INSTALL_PREFIX="${PREFIX}"
cmake --build "${BUILD_DIR}" -j"$(nproc)"
cmake --install "${BUILD_DIR}" ${DESTDIR:+--prefix "${DESTDIR}/${PREFIX#/}"}

mkdir -p "${PREFIX}/share/applications"
cp "${REPO_ROOT}/data/conjunction-files.desktop" "${PREFIX}/share/applications/conjunction-files.desktop"
mkdir -p "${PREFIX}/share/xdg"
cp "${REPO_ROOT}/data/mimeapps.list" "${PREFIX}/share/xdg/mimeapps.list"

echo "[SUCCESS] conjunction-files built and installed to ${PREFIX}"
