#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-/tmp/build-kwin}"
PREFIX="${PREFIX:-/usr}"

cmake -S "${REPO_ROOT}/kwin" -B "${BUILD_DIR}" \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DKDE_INSTALL_USE_QT_SYS_PATHS=ON
cmake --build "${BUILD_DIR}" -j"$(nproc)"
cmake --install "${BUILD_DIR}" ${DESTDIR:+--prefix "${DESTDIR}/${PREFIX#/}"}

echo "[SUCCESS] Conjunction KWin 6 decoration & effects built and installed"
