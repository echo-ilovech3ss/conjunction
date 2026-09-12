#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Executing Phase 4B QEMU production controls verification inside WSL..."
python3 "${DIR}/phase4b-controls-verification.py"
