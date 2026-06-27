#!/usr/bin/env bash
# build-iso.sh - Conjunction OS ISO Build Script
# Builds a bootable ISO image using Docker on any platform (Windows/macOS/Linux)
#
# Usage:
#   ./build-iso.sh              Build ISO with default settings
#   ./build-iso.sh --clean      Clean build artifacts
#   ./build-iso.sh --verbose    Enable verbose output
#
# Requirements:
#   - Docker Desktop installed and running
#   - At least 20GB free disk space
#   - Internet connection
#
# Output:
#   ./out/conjunction-YYYYMMDD-x86_64.iso

set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILD_DIR="${SCRIPT_DIR}/out"
readonly ISO_NAME="conjunction"
readonly ISO_DATE=$(date +%Y%m%d)
readonly ISO_FILE="${ISO_NAME}-${ISO_DATE}-x86_64.iso"

# Docker settings
readonly DOCKER_IMAGE="archlinux:latest"
readonly DOCKER_CONTAINER="conjunction-build"
readonly DOCKER_WORKDIR="/build"

# Archiso settings
readonly ARCHISO_DIR="${SCRIPT_DIR}/archiso"
readonly PROFILE_DIR="${BUILD_DIR}/conjunction-profile"
readonly CACHE_DIR="${SCRIPT_DIR}/pkgcache"

# ─── Color Definitions ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─── Logging Functions ──────────────────────────────────────────────────────
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# ─── Argument Parsing ───────────────────────────────────────────────────────
CLEAN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--clean] [--verbose] [--help]"
            echo ""
            echo "Build a bootable Conjunction OS ISO image using Docker."
            echo ""
            echo "Options:"
            echo "  --clean      Clean build artifacts before building"
            echo "  --verbose    Enable verbose output"
            echo "  --help       Show this help message"
            echo ""
            echo "Output: ./out/${ISO_FILE}"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ─── Pre-flight Checks ─────────────────────────────────────────────────────
preflight() {
    info "Running pre-flight checks..."

    # Check required host tools
    local missing_tools=()
    local tools=(docker python3 bash git)
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            if [[ "$tool" == "python3" ]] && command -v python &>/dev/null; then
                continue
            fi
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required host tools: ${missing_tools[*]}"
        error "Please install the missing tools to proceed:"
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                docker)
                    error "  - docker: Install Docker Desktop (https://docs.docker.com/desktop/)"
                    ;;
                python3)
                    error "  - python: Install Python 3.x"
                    ;;
                bash)
                    error "  - bash: Install Bash shell"
                    ;;
                git)
                    error "  - git: Install Git"
                    ;;
            esac
        done
        exit 1
    fi

    # Check Docker daemon is running
    if ! docker info &>/dev/null 2>&1; then
        error "Docker daemon is not running."
        error "Start Docker Desktop and try again."
        exit 1
    fi

    # Check disk space (need ~20GB)
    local free_space
    free_space=$(df -BG "${SCRIPT_DIR}" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ -n "$free_space" ]] && [[ "$free_space" -lt 20 ]]; then
        warning "Low disk space: ${free_space}GB available (20GB recommended)"
        read -p "Continue anyway? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Check for loop device limitations on Windows/macOS Docker hosts
    if [[ "${OSTYPE:-}" == "msys" ]] || [[ "${OSTYPE:-}" == "cygwin" ]] || [[ "$(uname)" == "Darwin" ]]; then
        warning "Non-Linux host detected ($(uname))."
        warning "Building Arch Linux ISOs inside Docker on Windows/macOS requires loop device support inside the Docker VM."
        warning "If the build fails with loop mount or SquashFS errors, please use a native Linux machine or VM."
        read -p "Proceed with the build? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    success "Pre-flight checks passed."
}

# ─── Clean Build Artifacts ──────────────────────────────────────────────────
clean() {
    info "Cleaning build artifacts..."
    rm -rf "${BUILD_DIR}"
    docker rm -f "${DOCKER_CONTAINER}" 2>/dev/null || true
    success "Clean complete."
}

# ─── Prepare Build Environment ──────────────────────────────────────────────
prepare() {
    info "Preparing build environment..."

    # Create build and cache directories
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${CACHE_DIR}"

    # Recreate the generated profile from source every time. Leaving this
    # directory in place can preserve deleted or obsolete files across builds.
    rm -rf "${PROFILE_DIR}"

    # Remove stale ISOs so testers do not accidentally boot an older image after
    # changing installer or live-session files.
    find "${BUILD_DIR}" -maxdepth 1 -name "${ISO_NAME}-*-x86_64.iso" -type f -delete

    # Create the archiso profile directory
    mkdir -p "${PROFILE_DIR}/airootfs/etc/systemd/system"
    mkdir -p "${PROFILE_DIR}/airootfs/etc/systemd/system/getty@tty1.service.d"
    mkdir -p "${PROFILE_DIR}/airootfs/etc/skel/.config/autostart"
    mkdir -p "${PROFILE_DIR}/airootfs/usr/local/bin"
    mkdir -p "${PROFILE_DIR}/airootfs/usr/share/applications"
    mkdir -p "${PROFILE_DIR}/airootfs/etc/sddm.conf.d"
    mkdir -p "${PROFILE_DIR}/airootfs/root"

    # Copy profile files
    info "Copying profile files..."
    cp "${ARCHISO_DIR}/profiledef.sh" "${PROFILE_DIR}/"
    cp "${ARCHISO_DIR}/packages.x86_64" "${PROFILE_DIR}/"

    # Copy airootfs overlay
    if [[ -d "${ARCHISO_DIR}/airootfs" ]]; then
        cp -r "${ARCHISO_DIR}/airootfs/"* "${PROFILE_DIR}/airootfs/" 2>/dev/null || true
    fi

    # Copy Conjunction OS application files into the airootfs
    info "Copying Conjunction OS application files..."
    mkdir -p "${PROFILE_DIR}/airootfs/opt/conjunction"
    mkdir -p "${PROFILE_DIR}/airootfs/etc/systemd/system"
    mkdir -p "${PROFILE_DIR}/airootfs/usr/share/kio/servicemenus"
    cp "${SCRIPT_DIR}/conjunction-app-sync.service" "${PROFILE_DIR}/airootfs/etc/systemd/system/" 2>/dev/null || warning "conjunction-app-sync.service not found"
    cp "${SCRIPT_DIR}/conjunction-app.desktop" "${PROFILE_DIR}/airootfs/usr/share/kio/servicemenus/" 2>/dev/null || warning "conjunction-app.desktop not found"
    cp "${SCRIPT_DIR}/setup_conjunction_ui.sh" "${PROFILE_DIR}/airootfs/opt/conjunction/" 2>/dev/null || warning "setup_conjunction_ui.sh not found"
    chmod +x "${PROFILE_DIR}/airootfs/opt/conjunction/"*.sh 2>/dev/null || true

    # Generate initial build-metadata.json
    info "Generating build metadata..."
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local git_hash
    git_hash=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    
    local docker_ver
    docker_ver=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',') || docker_ver="unknown"
    
    local python_ver
    python_ver=$(python3 --version 2>/dev/null || python --version 2>/dev/null) || python_ver="unknown"
    python_ver=$(echo "$python_ver" | awk '{print $2}')
    
    local bash_ver
    bash_ver=$(bash --version 2>/dev/null | head -n1 | awk '{print $4}') || bash_ver="unknown"
    
    local git_ver
    git_ver=$(git --version 2>/dev/null | awk '{print $3}') || git_ver="unknown"

    mkdir -p "${PROFILE_DIR}/airootfs/usr/share/conjunction"
    cat > "${PROFILE_DIR}/airootfs/usr/share/conjunction/build-metadata.json" <<METADATA
{
  "timestamp": "${timestamp}",
  "git_commit_hash": "${git_hash}",
  "tool_versions": {
    "docker": "${docker_ver}",
    "python": "${python_ver}",
    "bash": "${bash_ver}",
    "git": "${git_ver}"
  }
}
METADATA

    success "Build environment prepared."
}

# ─── Build ISO in Docker ────────────────────────────────────────────────────
build_docker() {
    info "Starting Docker build..."

    # Pull the latest Arch Linux image
    docker pull "${DOCKER_IMAGE}"

    # Remove old container if exists
    docker rm -f "${DOCKER_CONTAINER}" 2>/dev/null || true

    # Build the ISO inside Docker
    info "Building ISO (this may take 30-60 minutes)..."
    info "Output will be saved to: ${BUILD_DIR}/${ISO_FILE}"
    echo ""

    docker run --rm --privileged \
        --name "${DOCKER_CONTAINER}" \
        -v "${BUILD_DIR}:/output" \
        -v "${PROFILE_DIR}:/conjunction-profile:ro" \
        -v "${CACHE_DIR}:/var/cache/pacman/pkg" \
        -v "${SCRIPT_DIR}:/conjunction-src:ro" \
        "${DOCKER_IMAGE}" \
        bash -c '
            set -euo pipefail

            echo "═══════════════════════════════════════════════════════════════"
            echo "   Conjunction OS ISO Builder - Running in Docker Container   "
            echo "═══════════════════════════════════════════════════════════════"
            echo ""

            # Update system and install dependencies
            echo "[1/6] Updating system packages and installing tools..."
            pacman -Syu --noconfirm
            pacman -S --needed --noconfirm archiso python git systemd mtools dosfstools grub efibootmgr rust

            # Create working directory
            mkdir -p /work
            cd /work

            # Copy profile
            echo "[2/6] Preparing build profile..."
            mkdir -p /work/conjunction-profile
            # Copy base releng profile to get standard bootloaders and pacman.conf
            cp -r /usr/share/archiso/configs/releng/* /work/conjunction-profile/

            # Enable multilib repository for 32-bit package support (robust detection/appending)
            if grep -q "^\[multilib\]" /work/conjunction-profile/pacman.conf; then
                echo "Multilib repository already enabled in pacman.conf"
            elif grep -q "^#\[multilib\]" /work/conjunction-profile/pacman.conf; then
                echo "Enabling existing commented multilib repository in pacman.conf..."
                sed -i "/^#\[multilib\]/,/^#Include/ s/^#//" /work/conjunction-profile/pacman.conf
            else
                echo "Appending multilib repository to pacman.conf..."
                cat >> /work/conjunction-profile/pacman.conf << "EOF"

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
            fi

            # Overlay custom conjunction profile files on top
            cp -rf /conjunction-profile/* /work/conjunction-profile/

            # Write manifest and update metadata
            echo "[3/6] Generating build metadata and manifest inside container..."
            mkdir -p /work/conjunction-profile/airootfs/usr/share/conjunction
            
            # Query container tool versions
            ARCHISO_VER=$(pacman -Q archiso | awk "{print \$2}")
            SYSTEMD_VER=$(pacman -Q systemd | awk "{print \$2}")
            
            # Update build-metadata.json
            if [ -f /work/conjunction-profile/airootfs/usr/share/conjunction/build-metadata.json ]; then
                python3 -c "
import json
with open(\"/work/conjunction-profile/airootfs/usr/share/conjunction/build-metadata.json\", \"r+\") as f:
    data = json.load(f)
    data[\"tool_versions\"][\"mkarchiso\"] = \"${ARCHISO_VER}\"
    data[\"tool_versions\"][\"systemd-analyze\"] = \"${SYSTEMD_VER}\"
    f.seek(0)
    json.dump(data, f, indent=2)
    f.truncate()
" 2>/dev/null || echo "Warning: Failed to update build-metadata.json"
            fi

            # Package version manifest
            MANIFEST_FILE="/work/conjunction-profile/airootfs/usr/share/conjunction/build-manifest.txt"
            echo "Conjunction OS ISO Build Package Manifest" > "$MANIFEST_FILE"
            echo "Generated: $(date -u)" >> "$MANIFEST_FILE"
            echo "----------------------------------------" >> "$MANIFEST_FILE"
            while read -r pkg || [ -n "$pkg" ]; do
                # Strip comments and whitespace
                pkg=$(echo "$pkg" | sed -e "s/#.*//" -e "s/[[:space:]]*//g")
                [ -z "$pkg" ] && continue
                version=$(pacman -Si "$pkg" 2>/dev/null | grep -i "^Version" | awk "{print \$3}") || version="not found in sync db"
                echo "$pkg: $version" >> "$MANIFEST_FILE"
            done < /work/conjunction-profile/packages.x86_64

            # Run build validation stage
            echo "[4/6] Running build validation stage..."
            echo "Running Python syntax checks..."
            find /work/conjunction-profile/airootfs/ -name "*.py" -exec python3 -m py_compile {} +
            echo "Running Bash syntax checks..."
            find /work/conjunction-profile/airootfs/ -name "*.sh" -exec bash -n {} +
            bash -n /work/conjunction-profile/profiledef.sh
            echo "Running Systemd service validation..."
            SYSTEMD_UNIT_PATH="/work/conjunction-profile/airootfs/etc/systemd/system:" systemd-analyze verify /work/conjunction-profile/airootfs/etc/systemd/system/*.service

            # Compile Cargo workspace
            echo "Compiling Cargo workspace..."
            cp -r /conjunction-src /work/conjunction-workspace
            cd /work/conjunction-workspace
            cargo build --release
            mkdir -p /work/conjunction-profile/airootfs/opt/conjunction
            cp /work/conjunction-workspace/target/release/cj /work/conjunction-profile/airootfs/opt/conjunction/cj
            cp /work/conjunction-workspace/target/release/application /work/conjunction-profile/airootfs/opt/conjunction/application
            cp /work/conjunction-workspace/target/release/app_sync /work/conjunction-profile/airootfs/opt/conjunction/app_sync
            cd /work
            rm -rf /work/conjunction-workspace

            # Create symlinks so cj and application are on PATH during the live session
            mkdir -p /work/conjunction-profile/airootfs/usr/local/bin
            ln -sf /opt/conjunction/cj /work/conjunction-profile/airootfs/usr/local/bin/cj
            ln -sf /opt/conjunction/application /work/conjunction-profile/airootfs/usr/local/bin/application

            # Set robust permissions
            echo "[5/6] Setting file and directory permissions..."
            find /work/conjunction-profile/airootfs/ -type d -exec chmod 755 {} +
            find /work/conjunction-profile/airootfs/ -type f -exec chmod 644 {} +
            chmod +x /work/conjunction-profile/airootfs/usr/local/bin/* 2>/dev/null || true
            chmod +x /work/conjunction-profile/airootfs/opt/conjunction/*.sh 2>/dev/null || true
            chmod +x /work/conjunction-profile/airootfs/opt/conjunction/cj 2>/dev/null || true
            chmod +x /work/conjunction-profile/airootfs/opt/conjunction/application 2>/dev/null || true
            chmod +x /work/conjunction-profile/airootfs/opt/conjunction/app_sync 2>/dev/null || true

            # Build the ISO using mkarchiso
            echo "[6/6] Building ISO image..."
            echo "Cleaning work directory..."
            rm -rf /work/archiso-work
            echo "This will take a while. Please be patient."
            mkarchiso -v -w /work/archiso-work -o /output /work/conjunction-profile

            # Find the output ISO
            ISO_PATH=$(find /output -name "*.iso" -type f | head -1)

            if [[ -n "$ISO_PATH" ]]; then
                ISO_SIZE=$(du -h "$ISO_PATH" | cut -f1)
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo "   Build Complete!                                           "
                echo "═══════════════════════════════════════════════════════════════"
                echo ""
                echo "   ISO File: $ISO_PATH"
                echo "   ISO Size: $ISO_SIZE"
                echo ""
            else
                echo "ERROR: ISO build failed. Check output above for errors."
                exit 1
            fi
        '

    echo ""
    success "ISO build complete!"
    info "Output: ${BUILD_DIR}/${ISO_FILE}"

    # Verify ISO exists
    local final_iso="${BUILD_DIR}/${ISO_FILE}"
    if [[ ! -f "$final_iso" ]]; then
        final_iso=$(find "${BUILD_DIR}" -maxdepth 1 -name "${ISO_NAME}-*-x86_64.iso" -type f | sort | tail -n 1)
    fi

    if [[ -n "${final_iso:-}" ]] && [[ -f "$final_iso" ]]; then
        local iso_size
        iso_size=$(du -h "$final_iso" | cut -f1)
        echo ""
        success "ISO File: ${final_iso}"
        success "ISO Size: ${iso_size}"
        echo ""
    else
        error "ISO file not found at expected location"
        error "Check Docker output for errors"
        exit 1
    fi
}

# ─── Post-build Smoke Test ──────────────────────────────────────────────────
smoke_test() {
    if ! command -v qemu-system-x86_64 &>/dev/null; then
        warning "qemu-system-x86_64 not found on host. Skipping smoke test."
        return 0
    fi

    local final_iso="${BUILD_DIR}/${ISO_FILE}"
    if [[ ! -f "$final_iso" ]]; then
        final_iso=$(find "${BUILD_DIR}" -maxdepth 1 -name "${ISO_NAME}-*-x86_64.iso" -type f | sort | tail -n 1)
    fi

    if [[ -z "${final_iso:-}" ]] || [[ ! -f "$final_iso" ]]; then
        error "No ISO found for smoke test."
        exit 1
    fi

    info "Starting post-build ISO Smoke Test utilizing QEMU..."
    local serial_log="${BUILD_DIR}/qemu-serial.log"
    rm -f "$serial_log"

    # Run QEMU in the background
    info "Launching QEMU non-interactively..."
    qemu-system-x86_64 -m 2G -cdrom "$final_iso" -serial file:"$serial_log" -display none &
    local qemu_pid=$!

    info "Waiting for system boot, SDDM, user targets, welcome flow and NetworkManager (timeout 120s)..."
    local timeout=120
    local elapsed=0
    local success=false

    while [[ $elapsed -lt $timeout ]]; do
        if [[ -f "$serial_log" ]] && grep -q "SMOKE_TEST_OK" "$serial_log"; then
            success=true
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    echo ""

    # Kill QEMU
    kill "$qemu_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true

    if [[ "$success" == true ]]; then
        success "Smoke test PASSED! ISO boots successfully and starts all target services."
        info "Next steps:"
        info "  1. Flash to USB: Use Rufus (Windows) or dd (Linux)"
        info "  2. Boot from USB and follow the installer"
        info "  3. Run: setup_conjunction_ui.sh"
        info "  4. Run: cj update && cj optimize"
    else
        error "Smoke test FAILED! Timeout reached before receiving boot success signal."
        if [[ -f "$serial_log" ]]; then
            error "Last serial log output:"
            cat "$serial_log"
        else
            error "No serial log file was generated."
        fi
        exit 1
    fi
}

# ─── Main ───────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║        Conjunction OS - ISO Build System                   ║"
    echo "║        Building a bootable Linux distribution              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    if [[ "$CLEAN" == true ]]; then
        clean
    fi

    preflight
    prepare
    build_docker
    smoke_test
}

main "$@"
