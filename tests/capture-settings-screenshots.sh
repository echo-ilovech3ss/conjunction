#!/usr/bin/env bash
set -euo pipefail

CHROOT="/root/conjunction-build/arch-chroot/root.x86_64/work/archiso-work/x86_64/airootfs"
REPO_ROOT="/mnt/c/Users/Way4U/Coding-projects/conjunction"

echo "[INFO] Updating design tokens and settings QML in chroot..."
mkdir -p "${CHROOT}/usr/share/conjunction/settings"
cp -r "${REPO_ROOT}/conjunction-settings/qml/"* "${CHROOT}/usr/share/conjunction/settings/"
mkdir -p "${CHROOT}/usr/share/conjunction/qml/Conjunction/Design"
cp -r "${REPO_ROOT}/conjunction-design/qml/Conjunction/Design/"* "${CHROOT}/usr/share/conjunction/qml/Conjunction/Design/"

echo "[INFO] Capturing screenshots of Conjunction System Settings..."

# 1. Overview (General / About)
arch-chroot "$CHROOT" /usr/bin/conjunction-settings -platform offscreen --page about --dark --screenshot /var/tmp/settings-overview.png --timeout 2500

# 2. Search result (Searching for 'magnification')
arch-chroot "$CHROOT" /usr/bin/conjunction-settings -platform offscreen --search magnification --dark --screenshot /var/tmp/settings-search-result.png --timeout 2500

# 3. Appearance page
arch-chroot "$CHROOT" /usr/bin/conjunction-settings -platform offscreen --page appearance --dark --screenshot /var/tmp/settings-appearance.png --timeout 2500

# 4. Desktop & Dock page
arch-chroot "$CHROOT" /usr/bin/conjunction-settings -platform offscreen --page dock --dark --screenshot /var/tmp/settings-desktop-dock.png --timeout 2500

# 5. Network page
arch-chroot "$CHROOT" /usr/bin/conjunction-settings -platform offscreen --page network --dark --screenshot /var/tmp/settings-network.png --timeout 2500

# 6. Displays page
arch-chroot "$CHROOT" /usr/bin/conjunction-settings -platform offscreen --page displays --dark --screenshot /var/tmp/settings-displays.png --timeout 2500

# 7. Dark mode view
arch-chroot "$CHROOT" /usr/bin/conjunction-settings -platform offscreen --dark --screenshot /var/tmp/settings-dark-mode.png --timeout 2500

# 8. 150% UI scale view
arch-chroot "$CHROOT" /usr/bin/conjunction-settings -platform offscreen --scale 1.5 --dark --screenshot /var/tmp/settings-150-scale.png --timeout 2500

echo "[INFO] Deploying screenshots to docs/design/screenshots/..."
mkdir -p "${REPO_ROOT}/docs/design/screenshots"

cp "${CHROOT}/var/tmp/settings-overview.png" "${REPO_ROOT}/docs/design/screenshots/settings-overview.png"
cp "${CHROOT}/var/tmp/settings-search-result.png" "${REPO_ROOT}/docs/design/screenshots/settings-search-result.png"
cp "${CHROOT}/var/tmp/settings-appearance.png" "${REPO_ROOT}/docs/design/screenshots/appearance.png"
cp "${CHROOT}/var/tmp/settings-appearance.png" "${REPO_ROOT}/docs/design/screenshots/settings-appearance.png"
cp "${CHROOT}/var/tmp/settings-desktop-dock.png" "${REPO_ROOT}/docs/design/screenshots/desktop-dock.png"
cp "${CHROOT}/var/tmp/settings-desktop-dock.png" "${REPO_ROOT}/docs/design/screenshots/settings-desktop-dock.png"
cp "${CHROOT}/var/tmp/settings-network.png" "${REPO_ROOT}/docs/design/screenshots/network.png"
cp "${CHROOT}/var/tmp/settings-network.png" "${REPO_ROOT}/docs/design/screenshots/settings-network.png"
cp "${CHROOT}/var/tmp/settings-displays.png" "${REPO_ROOT}/docs/design/screenshots/displays.png"
cp "${CHROOT}/var/tmp/settings-displays.png" "${REPO_ROOT}/docs/design/screenshots/settings-displays.png"
cp "${CHROOT}/var/tmp/settings-dark-mode.png" "${REPO_ROOT}/docs/design/screenshots/dark-mode.png"
cp "${CHROOT}/var/tmp/settings-dark-mode.png" "${REPO_ROOT}/docs/design/screenshots/settings-dark-mode.png"
cp "${CHROOT}/var/tmp/settings-150-scale.png" "${REPO_ROOT}/docs/design/screenshots/150%-scale.png"
cp "${CHROOT}/var/tmp/settings-150-scale.png" "${REPO_ROOT}/docs/design/screenshots/settings-150-scale.png"

echo "[SUCCESS] All Phase 6B System Settings screenshots generated and saved!"
