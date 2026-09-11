#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Ensure binaries are built in WSL
echo "[INFO] Ensuring Conjunction Linux binaries are built..."
export PATH="/root/.cargo/bin:/usr/bin:/bin:/usr/local/bin:${PATH}"
cargo build --manifest-path "${REPO_ROOT}/Cargo.toml" --release -p conj-bundle -p conj-appctl -p conj-appd -p conj-open --target-dir /tmp/wsl-target

# Run QEMU lifecycle verification
python3 "${SCRIPT_DIR}/phase2-app-lifecycle.py"
