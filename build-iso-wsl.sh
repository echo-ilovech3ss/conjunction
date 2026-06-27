#!/usr/bin/env bash
# build-iso-wsl.sh - Conjunction OS ISO Build Script (WSL2-Native)
# Builds a bootable ISO image using an Arch Linux chroot inside WSL2 Ubuntu.
# No Docker required.
#
# IMPORTANT: This script copies all sources to WSL's native ext4 filesystem
# (~/.conjunction-build/) because the NTFS /mnt/c bridge does not support
# Unix sockets (required by gpg-agent/pacman-key) and has poor I/O performance.
#
# Usage (from PowerShell):
#   wsl -d Ubuntu -- sudo bash /mnt/c/.../conjunction/build-iso-wsl.sh
#
# Requirements:
#   - WSL2 with Ubuntu
#   - sudo/root access inside WSL
#   - ~20GB free disk space
#   - Internet connection
#
# Output:
#   ./out/conjunction-YYYYMMDD-x86_64.iso  (copied back to Windows)

set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────
# Source directory on Windows filesystem (where the script lives)
WINDOWS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build on WSL's native ext4 filesystem for Unix socket support + speed
WSL_BUILD_ROOT="/root/conjunction-build"
BUILD_DIR="${WSL_BUILD_ROOT}/out"
CHROOT_DIR="${WSL_BUILD_ROOT}/arch-chroot"
PROFILE_DIR="${WSL_BUILD_ROOT}/conjunction-profile"

ISO_NAME="conjunction"
ISO_DATE=$(date +%Y%m%d)
ISO_FILE="${ISO_NAME}-${ISO_DATE}-x86_64.iso"

# Windows output directory (final ISO copied here)
WINDOWS_OUT="${WINDOWS_SRC}/out"

# Arch Linux bootstrap mirror
ARCH_MIRROR="https://mirrors.edge.kernel.org/archlinux"
BOOTSTRAP_URL="${ARCH_MIRROR}/iso/latest/archlinux-bootstrap-x86_64.tar.zst"

# ─── Color Definitions ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Logging Functions ──────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
step()    { echo -e "${CYAN}${BOLD}[STEP]${NC} $1"; }

# ─── Cleanup on Exit ───────────────────────────────────────────────────────
cleanup_mounts() {
    info "Cleaning up mounts..."
    local ROOT="${CHROOT_DIR}/root.x86_64"
    for mp in "${ROOT}/conjunction-src" "${ROOT}/output" "${ROOT}/conjunction-repo" \
              "${ROOT}/proc" "${ROOT}/sys" \
              "${ROOT}/dev/pts" "${ROOT}/dev" \
              "${ROOT}/tmp" "${ROOT}/run"; do
        mountpoint -q "$mp" 2>/dev/null && umount -lf "$mp" 2>/dev/null || true
    done
}
trap cleanup_mounts EXIT

# ─── Pre-flight Checks ─────────────────────────────────────────────────────
preflight() {
    step "Running pre-flight checks..."

    # Must be root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)."
        exit 1
    fi

    # Check we're in WSL
    if [[ ! -f /proc/version ]] || ! grep -qi "microsoft\|WSL" /proc/version; then
        warning "This script is designed for WSL2. Proceeding anyway..."
    fi

    # Install dependencies
    info "Ensuring build dependencies are installed..."
    apt-get update -qq 2>/dev/null
    apt-get install -y -qq \
        wget curl tar zstd python3 bash git \
        xorriso mtools dosfstools e2fsprogs erofs-utils \
        squashfs-tools libisoburn1 libburn4 libisofs6 \
        2>/dev/null || true

    # Check source files exist
    if [[ ! -f "${WINDOWS_SRC}/Cargo.toml" ]]; then
        error "Cargo.toml not found in ${WINDOWS_SRC}"
        exit 1
    fi

    local archiso_dir="${WINDOWS_SRC}/archiso"
    if [[ ! -f "${archiso_dir}/profiledef.sh" ]]; then
        error "profiledef.sh not found in ${archiso_dir}"
        exit 1
    fi
    if [[ ! -f "${archiso_dir}/packages.x86_64" ]]; then
        error "packages.x86_64 not found in ${archiso_dir}"
        exit 1
    fi

    success "Pre-flight checks passed."
}

# ─── Copy Sources to ext4 ──────────────────────────────────────────────────
copy_sources() {
    step "Copying source files to WSL native filesystem (ext4)..."
    info "This avoids NTFS limitations (no Unix sockets, slow I/O)."

    mkdir -p "${WSL_BUILD_ROOT}"
    mkdir -p "${BUILD_DIR}"

    # Clean previous profile
    rm -rf "${PROFILE_DIR}"

    # Remove stale ISOs
    find "${BUILD_DIR}" -maxdepth 1 -name "${ISO_NAME}-*-x86_64.iso" -type f -delete 2>/dev/null || true

    # Create profile directory structure
    mkdir -p "${PROFILE_DIR}/airootfs/etc/systemd/system"
    mkdir -p "${PROFILE_DIR}/airootfs/etc/systemd/system/getty@tty1.service.d"
    mkdir -p "${PROFILE_DIR}/airootfs/etc/skel/.config/autostart"
    mkdir -p "${PROFILE_DIR}/airootfs/usr/local/bin"
    mkdir -p "${PROFILE_DIR}/airootfs/usr/share/applications"
    mkdir -p "${PROFILE_DIR}/airootfs/etc/sddm.conf.d"
    mkdir -p "${PROFILE_DIR}/airootfs/root"

    local archiso_dir="${WINDOWS_SRC}/archiso"

    # Copy profile definition files
    info "Copying profile files..."
    cp "${archiso_dir}/profiledef.sh" "${PROFILE_DIR}/"
    cp "${archiso_dir}/packages.x86_64" "${PROFILE_DIR}/"

    # Copy airootfs overlay
    if [[ -d "${archiso_dir}/airootfs" ]]; then
        cp -r "${archiso_dir}/airootfs/"* "${PROFILE_DIR}/airootfs/" 2>/dev/null || true
    fi

    # Copy Conjunction application files
    info "Copying Conjunction OS application files..."
    mkdir -p "${PROFILE_DIR}/airootfs/opt/conjunction"
    mkdir -p "${PROFILE_DIR}/airootfs/etc/systemd/system"
    mkdir -p "${PROFILE_DIR}/airootfs/usr/share/kio/servicemenus"
    cp "${WINDOWS_SRC}/conjunction-app-sync.service" "${PROFILE_DIR}/airootfs/etc/systemd/system/" 2>/dev/null || warning "conjunction-app-sync.service not found"
    cp "${WINDOWS_SRC}/conjunction-app.desktop" "${PROFILE_DIR}/airootfs/usr/share/kio/servicemenus/" 2>/dev/null || warning "conjunction-app.desktop not found"
    cp "${WINDOWS_SRC}/setup_conjunction_ui.sh" "${PROFILE_DIR}/airootfs/opt/conjunction/" 2>/dev/null || warning "setup_conjunction_ui.sh not found"
    chmod +x "${PROFILE_DIR}/airootfs/opt/conjunction/"*.sh 2>/dev/null || true

    # Generate build metadata
    info "Generating build metadata..."
    local timestamp git_hash python_ver bash_ver git_ver
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    git_hash=$(git -C "${WINDOWS_SRC}" rev-parse HEAD 2>/dev/null || echo "unknown")
    python_ver=$(python3 --version 2>/dev/null | awk '{print $2}') || python_ver="unknown"
    bash_ver=$(bash --version 2>/dev/null | head -n1 | awk '{print $4}') || bash_ver="unknown"
    git_ver=$(git --version 2>/dev/null | awk '{print $3}') || git_ver="unknown"

    mkdir -p "${PROFILE_DIR}/airootfs/usr/share/conjunction"
    cat > "${PROFILE_DIR}/airootfs/usr/share/conjunction/build-metadata.json" <<METADATA
{
  "timestamp": "${timestamp}",
  "git_commit_hash": "${git_hash}",
  "build_method": "wsl2-arch-chroot",
  "tool_versions": {
    "python": "${python_ver}",
    "bash": "${bash_ver}",
    "git": "${git_ver}"
  }
}
METADATA

    success "Sources copied to ext4 filesystem."
}

# ─── Bootstrap Arch Linux Chroot ────────────────────────────────────────────
bootstrap_arch() {
    step "Bootstrapping Arch Linux chroot environment..."

    mkdir -p "${CHROOT_DIR}"

    local bootstrap_file="${WSL_BUILD_ROOT}/archlinux-bootstrap-x86_64.tar.zst"

    if [[ -d "${CHROOT_DIR}/root.x86_64/usr" ]]; then
        info "Existing Arch bootstrap found. Reusing..."
    else
        info "Downloading Arch Linux bootstrap tarball..."

        if [[ ! -f "$bootstrap_file" ]]; then
            wget -q --show-progress -O "$bootstrap_file" "${BOOTSTRAP_URL}" || {
                error "Failed to download Arch Linux bootstrap tarball."
                exit 1
            }
        fi

        info "Extracting bootstrap tarball..."
        tar -xf "$bootstrap_file" -C "${CHROOT_DIR}" --zstd 2>/dev/null || {
            error "Failed to extract bootstrap tarball."
            exit 1
        }

        success "Bootstrap extracted."
    fi

    local ROOT="${CHROOT_DIR}/root.x86_64"

    # Configure mirrors by testing candidate mirrors and filtering out offline ones
    info "Testing package mirrors to filter out offline ones..."
    local candidate_mirrors=(
        "https://mirrors.nxtgen.com/archlinux-mirror/\$repo/os/\$arch"
        "https://mirrors.abhy.me/archlinux/\$repo/os/\$arch"
        "https://mirror.4v1.in/archlinux/\$repo/os/\$arch"
        "https://mirror.maa.albony.in/archlinux/\$repo/os/\$arch"
        "https://mirror.bom.kat.cx/archlinux/\$repo/os/\$arch"
        "https://in-mirror.garudalinux.org/archlinux/\$repo/os/\$arch"
        "https://mirrors.edge.kernel.org/archlinux/\$repo/os/\$arch"
        "https://mirrors.kernel.org/archlinux/\$repo/os/\$arch"
    )

    local temp_mirrorlist
    temp_mirrorlist=$(mktemp)
    
    for mirror in "${candidate_mirrors[@]}"; do
        # Extract base domain/URL for curl testing (replace /$repo/os/$arch with empty)
        local test_url
        test_url=$(echo "$mirror" | sed 's|/\$repo/os/\$arch||g')
        info "  Testing mirror: $test_url"
        if curl -sI -o /dev/null -m 2 "$test_url"; then
            success "    Mirror is ONLINE: $test_url"
            echo "Server = $mirror" >> "$temp_mirrorlist"
        else
            warning "    Mirror is OFFLINE: $test_url (skipping)"
        fi
    done

    # If no mirrors succeeded, write default CDN mirror
    if [[ ! -s "$temp_mirrorlist" ]]; then
        warning "No candidate mirrors responded. Using default fallback mirror."
        echo "Server = https://mirrors.edge.kernel.org/archlinux/\$repo/os/\$arch" > "$temp_mirrorlist"
    fi

    # Write final mirrorlist
    cp "$temp_mirrorlist" "${ROOT}/etc/pacman.d/mirrorlist"
    rm -f "$temp_mirrorlist"

    # Enable multilib
    if grep -q "^#\[multilib\]" "${ROOT}/etc/pacman.conf"; then
        info "Enabling multilib repository..."
        sed -i "/^#\[multilib\]/,/^#Include/ s/^#//" "${ROOT}/etc/pacman.conf"
    fi

    # Disable CheckSpace inside chroot pacman.conf to prevent disk space check failures in WSL
    if grep -q "^CheckSpace" "${ROOT}/etc/pacman.conf"; then
        info "Disabling pacman space checks in chroot..."
        sed -i "s/^CheckSpace/#CheckSpace/" "${ROOT}/etc/pacman.conf"
    fi

    # Enable resilient curl XferCommand in chroot pacman.conf
    if grep -q "XferCommand = /usr/bin/curl" "${ROOT}/etc/pacman.conf"; then
        info "Enabling resilient curl XferCommand in chroot..."
        sed -i 's|^#\?XferCommand = /usr/bin/curl.*|XferCommand = /usr/bin/curl -g -L -C - --connect-timeout 60 --retry 5 --retry-delay 3 -f -o %o %u|' "${ROOT}/etc/pacman.conf"
    fi

    # Enable ParallelDownloads to saturate high-speed internet connections
    if grep -q "ParallelDownloads" "${ROOT}/etc/pacman.conf"; then
        info "Enabling ParallelDownloads in chroot..."
        sed -i 's|^#\?ParallelDownloads.*|ParallelDownloads = 5|' "${ROOT}/etc/pacman.conf"
    else
        sed -i '/^\[options\]/a ParallelDownloads = 5' "${ROOT}/etc/pacman.conf"
    fi

    # Mount filesystems for chroot (unmount first to clean up stale mounts from previous runs)
    info "Mounting chroot filesystems..."
    for mp in "proc" "sys" "dev/pts" "dev" "run" "tmp"; do
        if mountpoint -q "${ROOT}/${mp}" 2>/dev/null; then
            umount -lf "${ROOT}/${mp}" 2>/dev/null || true
        fi
    done

    mount -t proc proc "${ROOT}/proc"
    mount -t sysfs sys "${ROOT}/sys"
    mount --bind /dev "${ROOT}/dev"
    mount -t devpts devpts "${ROOT}/dev/pts"
    mount -t tmpfs tmpfs "${ROOT}/run"
    mount -t tmpfs tmpfs "${ROOT}/tmp"

    # Ensure dev fd and standard stream symlinks exist in chroot for bash process substitution
    mkdir -p "${ROOT}/dev"
    ln -sf /proc/self/fd "${ROOT}/dev/fd" 2>/dev/null || true
    ln -sf /proc/self/fd/0 "${ROOT}/dev/stdin" 2>/dev/null || true
    ln -sf /proc/self/fd/1 "${ROOT}/dev/stdout" 2>/dev/null || true
    ln -sf /proc/self/fd/2 "${ROOT}/dev/stderr" 2>/dev/null || true

    # Ensure resolv.conf for DNS
    cp /etc/resolv.conf "${ROOT}/etc/resolv.conf" 2>/dev/null || true

    # Initialize pacman and install archiso
    info "Initializing pacman keyring (on ext4 — sockets will work)..."
    chroot "${ROOT}" /bin/bash -c '
        set -euo pipefail

        # Kill any stale gpg-agent processes
        gpgconf --kill all 2>/dev/null || true

        # Remove stale pacman lock file if it exists
        rm -f /var/lib/pacman/db.lck

        # Initialize keyring
        pacman-key --init
        pacman-key --populate archlinux

        # Full system upgrade first to resolve version mismatches between
        # the bootstrap tarball and current repos (e.g. systemd-sysvcompat)
        pacman -Syu --noconfirm

        # Install required packages
        pacman -S --needed --noconfirm archiso python git mtools dosfstools grub efibootmgr rust
    ' || {
        error "Failed to set up Arch chroot."
        exit 1
    }

    success "Arch Linux chroot is ready."
}

# ─── Build ISO Inside Chroot ───────────────────────────────────────────────
build_iso() {
    step "Building ISO inside Arch Linux chroot..."

    local ROOT="${CHROOT_DIR}/root.x86_64"

    # Create bind-mount targets
    mkdir -p "${ROOT}/conjunction-src"
    mkdir -p "${ROOT}/conjunction-repo"
    mkdir -p "${ROOT}/output"

    # Bind mount profile, output, and repository source (unmount first to clean up stale mounts)
    for mp in "conjunction-src" "output" "conjunction-repo"; do
        if mountpoint -q "${ROOT}/${mp}" 2>/dev/null; then
            umount -lf "${ROOT}/${mp}" 2>/dev/null || true
        fi
    done

    mount --bind "${PROFILE_DIR}" "${ROOT}/conjunction-src"
    mount --bind "${WINDOWS_SRC}" "${ROOT}/conjunction-repo"
    mount --bind "${BUILD_DIR}"   "${ROOT}/output"

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "   Conjunction OS ISO Builder — Arch Linux Chroot on ext4    "
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    chroot "${ROOT}" /bin/bash -c '
        set -euo pipefail

        echo "[1/5] Preparing build profile..."
        rm -rf /work/conjunction-profile
        mkdir -p /work/conjunction-profile

        # Copy releng base profile
        cp -r /usr/share/archiso/configs/releng/* /work/conjunction-profile/

        # Enable multilib in profile pacman.conf
        if grep -q "^#\[multilib\]" /work/conjunction-profile/pacman.conf; then
            sed -i "/^#\[multilib\]/,/^#Include/ s/^#//" /work/conjunction-profile/pacman.conf
        elif ! grep -q "^\[multilib\]" /work/conjunction-profile/pacman.conf; then
            cat >> /work/conjunction-profile/pacman.conf << "EOF"

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
        fi

        # Enable resilient curl XferCommand in profile pacman.conf
        if grep -q "XferCommand = /usr/bin/curl" /work/conjunction-profile/pacman.conf; then
            sed -i "s|^#\?XferCommand = /usr/bin/curl.*|XferCommand = /usr/bin/curl -g -L -C - --connect-timeout 60 --retry 5 --retry-delay 3 -f -o %o %u|" /work/conjunction-profile/pacman.conf
        fi

        # Enable ParallelDownloads in profile pacman.conf
        if grep -q "ParallelDownloads" /work/conjunction-profile/pacman.conf; then
            sed -i "s|^#\?ParallelDownloads.*|ParallelDownloads = 5|" /work/conjunction-profile/pacman.conf
        else
            sed -i "/^\[options\]/a ParallelDownloads = 5" /work/conjunction-profile/pacman.conf
        fi

        # Overlay Conjunction custom files on top of releng
        cp -rf /conjunction-src/* /work/conjunction-profile/

        # Disable CheckSpace in profile pacman.conf to prevent mkarchiso installer failures in WSL
        if grep -q "^CheckSpace" /work/conjunction-profile/pacman.conf; then
            sed -i "s/^CheckSpace/#CheckSpace/" /work/conjunction-profile/pacman.conf
        fi

        echo "[2/5] Generating build manifest..."
        mkdir -p /work/conjunction-profile/airootfs/usr/share/conjunction
        MANIFEST="/work/conjunction-profile/airootfs/usr/share/conjunction/build-manifest.txt"
        echo "Conjunction OS ISO Build Package Manifest" > "$MANIFEST"
        echo "Generated: $(date -u)" >> "$MANIFEST"
        echo "----------------------------------------" >> "$MANIFEST"
        while read -r pkg || [ -n "$pkg" ]; do
            pkg=$(echo "$pkg" | sed -e "s/#.*//" -e "s/[[:space:]]*//g")
            [ -z "$pkg" ] && continue
            version=$(pacman -Si "$pkg" 2>/dev/null | grep -i "^Version" | awk "{print \$3}") || version="not found"
            echo "$pkg: $version" >> "$MANIFEST"
        done < /work/conjunction-profile/packages.x86_64

        echo "[3/5] Running build validation..."
        echo "  Python syntax checks..."
        find /work/conjunction-profile/airootfs/ -name "*.py" -exec python3 -m py_compile {} + 2>/dev/null || echo "  Warning: Some Python files had syntax issues"
        echo "  Bash syntax checks..."
        find /work/conjunction-profile/airootfs/ -name "*.sh" -exec bash -n {} + 2>/dev/null || echo "  Warning: Some shell scripts had syntax issues"
        bash -n /work/conjunction-profile/profiledef.sh || echo "  Warning: profiledef.sh had syntax issues"

        # Compile Cargo workspace
        echo "  Compiling Cargo workspace..."
        cp -r /conjunction-repo /work/conjunction-workspace
        cd /work/conjunction-workspace
        cargo build --release
        mkdir -p /work/conjunction-profile/airootfs/opt/conjunction
        cp /work/conjunction-workspace/target/release/cj /work/conjunction-profile/airootfs/opt/conjunction/cj
        cp /work/conjunction-workspace/target/release/application /work/conjunction-profile/airootfs/opt/conjunction/application
        cp /work/conjunction-workspace/target/release/app_sync /work/conjunction-profile/airootfs/opt/conjunction/app_sync
        cd /work
        rm -rf /work/conjunction-workspace

        echo "[4/5] Setting file permissions..."
        find /work/conjunction-profile/airootfs/ -type d -exec chmod 755 {} +
        find /work/conjunction-profile/airootfs/ -type f -exec chmod 644 {} +
        chmod +x /work/conjunction-profile/airootfs/usr/local/bin/* 2>/dev/null || true
        chmod +x /work/conjunction-profile/airootfs/opt/conjunction/*.sh 2>/dev/null || true
        chmod +x /work/conjunction-profile/airootfs/opt/conjunction/cj 2>/dev/null || true
        chmod +x /work/conjunction-profile/airootfs/opt/conjunction/application 2>/dev/null || true
        chmod +x /work/conjunction-profile/airootfs/opt/conjunction/app_sync 2>/dev/null || true

        echo "[5/5] Building ISO image with mkarchiso..."
        echo "Cleaning work directory..."
        rm -rf /work/archiso-work
        echo "This will take a while. Please be patient."
        mkarchiso -v -w /work/archiso-work -o /output /work/conjunction-profile

        # Verify output
        ISO_PATH=$(find /output -name "*.iso" -type f | head -1)
        if [[ -n "$ISO_PATH" ]]; then
            ISO_SIZE=$(du -h "$ISO_PATH" | cut -f1)
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo "   Build Complete!                                            "
            echo "═══════════════════════════════════════════════════════════════"
            echo "   ISO: $ISO_PATH ($ISO_SIZE)"
        else
            echo "ERROR: ISO build failed."
            exit 1
        fi
    '

    success "ISO build complete inside chroot!"
}

# ─── Copy ISO to Windows ───────────────────────────────────────────────────
copy_iso_to_windows() {
    step "Copying ISO to Windows filesystem..."

    mkdir -p "${WINDOWS_OUT}"

    local final_iso
    final_iso=$(find "${BUILD_DIR}" -maxdepth 1 -name "${ISO_NAME}-*-x86_64.iso" -type f | sort | tail -n 1)

    if [[ -n "${final_iso:-}" ]] && [[ -f "$final_iso" ]]; then
        cp "$final_iso" "${WINDOWS_OUT}/"
        local iso_size
        iso_size=$(du -h "$final_iso" | cut -f1)
        echo ""
        success "═══════════════════════════════════════════════════════════════"
        success "   ISO copied to Windows!"
        success "   File: ${WINDOWS_OUT}/$(basename "$final_iso")"
        success "   Size: ${iso_size}"
        success "═══════════════════════════════════════════════════════════════"
        echo ""
        info "Next steps:"
        info "  1. Flash to USB with Rufus (Windows) or dd (Linux)"
        info "  2. Boot from USB and follow the installer"
        info "  3. Run: setup_conjunction_ui.sh"
        info "  4. Run: cj update && cj optimize"
    else
        error "ISO file not found after build. Check output above."
        exit 1
    fi
}

# ─── Main ───────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║    Conjunction OS — ISO Build System (WSL2-Native)         ║"
    echo "║    Building on ext4 via Arch Linux chroot                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    preflight
    copy_sources
    bootstrap_arch
    build_iso
    copy_iso_to_windows

    success "All done!"
}

main "$@"
