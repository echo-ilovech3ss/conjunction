#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-/tmp/build-shelld}"
PREFIX="${PREFIX:-/usr}"

cmake -S "${REPO_ROOT}/conj-shelld" -B "${BUILD_DIR}" -DCMAKE_INSTALL_PREFIX="${PREFIX}"
cmake --build "${BUILD_DIR}" -j"$(nproc)"
cmake --install "${BUILD_DIR}" ${DESTDIR:+--prefix "${DESTDIR}/${PREFIX#/}"}

mkdir -p "${PREFIX}/share/kwin/effects/conjunction-overview"
cp -r "${REPO_ROOT}/data/conjunction-overview/"* "${PREFIX}/share/kwin/effects/conjunction-overview/"
mkdir -p "${PREFIX}/share/kwin/scripts/conjunctionbridge/contents/code"
cp "${REPO_ROOT}/data/conjunction-kwin-bridge.js" "${PREFIX}/share/kwin/scripts/conjunctionbridge/contents/code/main.js"
mkdir -p "${PREFIX}/share/plasma/look-and-feel"
cp -r "${REPO_ROOT}/plasma/look-and-feel/"* "${PREFIX}/share/plasma/look-and-feel/"
mkdir -p "${PREFIX}/share/wallpapers/Conjunction"
cp -r "${REPO_ROOT}/data/wallpapers/"* "${PREFIX}/share/wallpapers/Conjunction/"

echo "[SUCCESS] conj-shelld and Plasma look-and-feel assets installed to ${PREFIX}"
