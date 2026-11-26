#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-/tmp/build-terminal}"
PREFIX="${PREFIX:-/usr}"

cmake -S "${REPO_ROOT}/conjunction-terminal" -B "${BUILD_DIR}" -DCMAKE_INSTALL_PREFIX="${PREFIX}"
cmake --build "${BUILD_DIR}" -j"$(nproc)"
cmake --install "${BUILD_DIR}" ${DESTDIR:+--prefix "${DESTDIR}/${PREFIX#/}"}
"${BUILD_DIR}/test-conjunction-terminal"

mkdir -p "${PREFIX}/share/applications"
cp "${REPO_ROOT}/data/conjunction-terminal.desktop" "${PREFIX}/share/applications/conjunction-terminal.desktop"

echo "[SUCCESS] conjunction-terminal built, tested, and installed to ${PREFIX}"
