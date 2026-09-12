#!/usr/bin/env bash
set -euo pipefail

CHROOT="/root/conjunction-build/arch-chroot/root.x86_64/work/archiso-work/x86_64/airootfs"
REPO_ROOT="/mnt/c/Users/Way4U/Coding-projects/conjunction"
FIXTURES="${CHROOT}/tmp/files-fixtures"

echo "[INFO] Creating test fixtures for Files app..."
rm -rf "$FIXTURES"
mkdir -p "${FIXTURES}/Documents"
mkdir -p "${FIXTURES}/Downloads"
mkdir -p "${FIXTURES}/Projects"

# Valid .app bundle
CALC_APP="${FIXTURES}/Calculator.app"
mkdir -p "${CALC_APP}/Contents/MacOS"
mkdir -p "${CALC_APP}/Contents/Resources"

cat << 'EOF' > "${CALC_APP}/Contents/Info.toml"
bundle_format = "conjunction.app/1"
id = "org.conjunction.calculator"
name = "Calculator"
version = "1.2.0"
executable = "Contents/MacOS/calculator"
architectures = ["x86_64", "aarch64"]
icon = "calc.png"
description = "Fast, native desktop calculator for Conjunction."
EOF

cat << 'EOF' > "${CALC_APP}/Contents/MacOS/calculator"
#!/bin/sh
echo "Running Calculator"
EOF
chmod 755 "${CALC_APP}/Contents/MacOS/calculator"

# Create a valid 1x1 PNG icon
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" | base64 -d > "${CALC_APP}/Contents/Resources/calc.png"
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" | base64 -d > "${FIXTURES}/Landscape.png"

# Text and code files
cat << 'EOF' > "${FIXTURES}/SampleCode.rs"
// Conjunction Filesystem Engine
pub fn analyze_file(path: &str) -> bool {
    println!("Inspecting: {}", path);
    true
}
EOF

cat << 'EOF' > "${FIXTURES}/Notes.txt"
Conjunction Phase 6A - Files Application
- Full .app bundle semantics
- Quick Look preview on Space bar
- Icon, List, and Miller Column views
EOF

echo "[INFO] Capturing screenshots of Files app views..."

# 1. Icon view (Dark theme)
arch-chroot "$CHROOT" /usr/bin/conjunction-files -platform offscreen --path /tmp/files-fixtures --view icon --dark --screenshot /var/tmp/files-icon-view.png --timeout 2500

# 2. List view (Dark theme)
arch-chroot "$CHROOT" /usr/bin/conjunction-files -platform offscreen --path /tmp/files-fixtures --view list --dark --screenshot /var/tmp/files-list-view.png --timeout 2500

# 3. Column view (Dark theme)
arch-chroot "$CHROOT" /usr/bin/conjunction-files -platform offscreen --path /tmp/files-fixtures --view column --dark --screenshot /var/tmp/files-column-view.png --timeout 2500

# 4. Quick Look overlay
arch-chroot "$CHROOT" /usr/bin/conjunction-files -platform offscreen --path /tmp/files-fixtures --quicklook /tmp/files-fixtures/Calculator.app --dark --screenshot /var/tmp/files-quicklook.png --timeout 2500

# 5. Get Info dialog
arch-chroot "$CHROOT" /usr/bin/conjunction-files -platform offscreen --path /tmp/files-fixtures --get-info /tmp/files-fixtures/Calculator.app --dark --screenshot /var/tmp/files-get-info.png --timeout 2500

# 6. Light theme view
arch-chroot "$CHROOT" /usr/bin/conjunction-files -platform offscreen --path /tmp/files-fixtures --view icon --light --screenshot /var/tmp/files-light-theme.png --timeout 2500

echo "[INFO] Deploying screenshots to docs/design/screenshots/..."
mkdir -p "${REPO_ROOT}/docs/design/screenshots"
cp "${CHROOT}/var/tmp/files-icon-view.png" "${REPO_ROOT}/docs/design/screenshots/"
cp "${CHROOT}/var/tmp/files-list-view.png" "${REPO_ROOT}/docs/design/screenshots/"
cp "${CHROOT}/var/tmp/files-column-view.png" "${REPO_ROOT}/docs/design/screenshots/"
cp "${CHROOT}/var/tmp/files-quicklook.png" "${REPO_ROOT}/docs/design/screenshots/"
cp "${CHROOT}/var/tmp/files-get-info.png" "${REPO_ROOT}/docs/design/screenshots/"
cp "${CHROOT}/var/tmp/files-light-theme.png" "${REPO_ROOT}/docs/design/screenshots/"

echo "[SUCCESS] All Phase 6A screenshots generated and saved!"
