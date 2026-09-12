#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "[INFO] Ensuring Conjunction Linux binaries are built in WSL..."
export PATH="/root/.cargo/bin:/usr/bin:/bin:/usr/local/bin:${PATH}"
cargo build --manifest-path "${REPO_ROOT}/Cargo.toml" --release -p conj-bundle -p conj-appctl -p conj-appd -p conj-open -p conj-sysd --target-dir /tmp/wsl-target

echo "[INFO] Running Phase 3 Linux Adapters QEMU verification..."
python3 "${SCRIPT_DIR}/phase3-linux-adapters.py"
