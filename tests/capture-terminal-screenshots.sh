#!/usr/bin/env bash
set -euo pipefail

CHROOT="/root/conjunction-build/arch-chroot/root.x86_64/work/archiso-work/x86_64/airootfs"
REPO_ROOT="/mnt/c/Users/Way4U/Coding-projects/conjunction"

echo "[INFO] Capturing screenshots of Conjunction Terminal..."

# 1. Default appearance (Light)
arch-chroot "$CHROOT" /usr/bin/conjunction-terminal -platform offscreen --light --screenshot /var/tmp/terminal-default.png --timeout 2500

# 2. Multiple tabs view
arch-chroot "$CHROOT" /usr/bin/conjunction-terminal -platform offscreen --test-tabs --dark --screenshot /var/tmp/terminal-tabs.png --timeout 2500

# 3. Files integration (dropped file path)
arch-chroot "$CHROOT" /usr/bin/conjunction-terminal -platform offscreen --working-directory /home/conjunction/Documents --test-dropped-path "/home/conjunction/Documents/Project Notes 2026.txt" --dark --screenshot /var/tmp/terminal-files-integration.png --timeout 2500

# 4. Dark theme view
arch-chroot "$CHROOT" /usr/bin/conjunction-terminal -platform offscreen --dark --screenshot /var/tmp/terminal-dark.png --timeout 2500

# 5. Find overlay view
arch-chroot "$CHROOT" /usr/bin/conjunction-terminal -platform offscreen --test-find --dark --screenshot /var/tmp/terminal-profile-or-find.png --timeout 2500

# 6. 150% UI scale view
arch-chroot "$CHROOT" /usr/bin/conjunction-terminal -platform offscreen --scale 1.5 --dark --screenshot /var/tmp/terminal-150scale.png --timeout 2500

echo "[INFO] Deploying screenshots to docs/design/screenshots/..."
mkdir -p "${REPO_ROOT}/docs/design/screenshots"

cp "${CHROOT}/var/tmp/terminal-default.png" "${REPO_ROOT}/docs/design/screenshots/terminal-default.png"
cp "${CHROOT}/var/tmp/terminal-tabs.png" "${REPO_ROOT}/docs/design/screenshots/terminal-tabs.png"
cp "${CHROOT}/var/tmp/terminal-files-integration.png" "${REPO_ROOT}/docs/design/screenshots/terminal-files-integration.png"
cp "${CHROOT}/var/tmp/terminal-dark.png" "${REPO_ROOT}/docs/design/screenshots/terminal-dark.png"
cp "${CHROOT}/var/tmp/terminal-profile-or-find.png" "${REPO_ROOT}/docs/design/screenshots/terminal-profile-or-find.png"
cp "${CHROOT}/var/tmp/terminal-150scale.png" "${REPO_ROOT}/docs/design/screenshots/terminal-150scale.png"

echo "[SUCCESS] All Phase 6C Terminal screenshots generated and saved!"
