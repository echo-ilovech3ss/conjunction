#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Executing Phase 4A QEMU visual verification inside WSL..."
python3 "${DIR}/phase4a-visual-verification.py"
