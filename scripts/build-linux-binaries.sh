#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/cargo-target}"
PREFIX="${PREFIX:-/usr}"
OUT_DIR="${REPO_ROOT}/out/rust-bin"

mkdir -p "${OUT_DIR}" "${PREFIX}/bin"
cd "${REPO_ROOT}"
cargo build --release -p conj-bundle -p conj-appctl -p conj-appd -p conj-open --target-dir "${TARGET_DIR}"

for bin in conj-bundle conj-appctl conj-appd conj-open; do
    cp -f "${TARGET_DIR}/release/${bin}" "${OUT_DIR}/${bin}"
    cp -f "${TARGET_DIR}/release/${bin}" "${PREFIX}/bin/${bin}"
    chmod 755 "${PREFIX}/bin/${bin}"
done

echo "[SUCCESS] Native Linux Rust binaries built and installed to ${PREFIX}/bin"
