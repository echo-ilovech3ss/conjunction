#!/usr/bin/env bash
# conjunction-installer.sh - Conjunction OS Installer
# Interactive installer for Conjunction OS

set -euo pipefail

# ─── Colors ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Dry Run & Logging Setup ───────────────────────────────────────────────
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        -d|--dry-run)
            DRY_RUN=true
            ;;
    esac
done

LOG_FILE="/var/log/conjunction-installer.log"
# Redirect stdout and stderr to the log file as well as the terminal
if [[ "$DRY_RUN" == true ]]; then
    LOG_FILE="/tmp/conjunction-installer-dryrun.log"
fi
# We use a tee-based redirection but avoid infinite loop by checking if we are already redirected
if [[ -z "${CONJUNCTION_LOGGING:-}" ]]; then
    export CONJUNCTION_LOGGING=1
    exec > >(tee -i "$LOG_FILE") 2>&1
fi

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }
header() { echo -e "\n${BOLD}${CYAN}═══ $1 ═══${NC}\n"; }

# ─── Checkpoint Management ──────────────────────────────────────────────────
STATE_FILE="/tmp/conjunction-install-state.json"

save_checkpoint() {
    # Ensure state file exists
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "{}" > "$STATE_FILE"
    fi
    
    python3 -c "
import json
try:
    with open('$STATE_FILE', 'r') as f:
        data = json.load(f)
except Exception:
    data = {}
if 'completed_steps' not in data:
    data['completed_steps'] = []
if '$1' not in data['completed_steps']:
    data['completed_steps'].append('$1')
data['target_disk'] = '${TARGET_DISK:-}'
data['part_scheme'] = '${PART_SCHEME:-}'
data['efi_part'] = '${EFI_PART:-}'
data['root_part'] = '${ROOT_PART:-}'
data['username'] = '${USERNAME:-}'
with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || true
}

get_checkpoint_state() {
    if [[ -f "$STATE_FILE" ]]; then
        python3 -c "
import json
try:
    with open('$STATE_FILE', 'r') as f:
        data = json.load(f)
    print(data.get('$1', ''))
except Exception:
    pass
" 2>/dev/null || true
    fi
}

is_step_completed() {
    if [[ -f "$STATE_FILE" ]]; then
        python3 -c "
import json, sys
try:
    with open('$STATE_FILE', 'r') as f:
        data = json.load(f)
    if '$1' in data.get('completed_steps', []):
        sys.exit(0)
except Exception:
    pass
sys.exit(1)
" 2>/dev/null
    else
        return 1
    fi
}

# ─── Target Mount Directory ────────────────────────────────────────────────
MNT="/mnt"
if [[ "$DRY_RUN" == true ]]; then
    MNT="/tmp/dry-run-mnt"
    mkdir -p "$MNT"
fi

run_chroot() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] chroot:${NC} $*"
    else
        arch-chroot "$MNT" "$@"
    fi
}

run_install_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Would run: $*"
    else
        "$@"
    fi
}

partition_path() {
    local disk="$1"
    local number="$2"

    if [[ "$disk" =~ [0-9]$ ]]; then
        echo "/dev/${disk}p${number}"
    else
        echo "/dev/${disk}${number}"
    fi
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        err "Required command not found: $cmd"
        return 1
    fi
}

preflight_checks() {
    header "Preflight Checks"

    local missing=false
    local required_commands=(
        arch-chroot
        btrfs
        genfstab
        lsblk
        mkfs.btrfs
        mkfs.fat
        pacstrap
        partprobe
        parted
        udevadm
    )

    for cmd in "${required_commands[@]}"; do
        if ! require_command "$cmd"; then
            missing=true
        fi
    done

    if [[ "$missing" == true ]]; then
        err "The live ISO is missing installer dependencies. Rebuild the ISO after fixing packages.x86_64."
        exit 1
    fi

    log "Checking Arch mirror/keyring access before any disk changes..."
    if ! ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
        warn "ICMP ping failed; continuing to pacman check because some networks block ping."
    fi

    if ! pacman -Sy --noconfirm --needed archlinux-keyring; then
        err "Cannot refresh Arch package databases/keyring."
        err "Connect to the internet or choose a working mirror before running the installer."
        exit 1
    fi

    ok "Installer dependencies and package mirrors look usable"
}

validate_username() {
    local username="$1"

    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
        err "Invalid username. Use lowercase letters, numbers, underscore, or hyphen; start with a letter or underscore."
        return 1
    fi
}

set_chroot_password() {
    local account="$1"
    local password="$2"

    local hashed_password
    hashed_password=$(openssl passwd -6 "$password")
    run_chroot usermod -p "$hashed_password" "$account"
}

# ─── Check for Root ────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    err "This installer must be run as root."
    err "Please run: sudo $0"
    exit 1
fi

echo -e "${CYAN}"
echo "  ____ ___  _   _    _ _   _ _   _  ____ _____ ___ ___  _   _    ___  ____  "
echo " / ___/ _ \| \ | |  | | | | | \ | |/ ___|_   _|_ _/ _ \| \ | |  / _ \/ ___| "
echo "| |  | | | |  \| |  | | | | |  \| | |     | |  | | | | |  \| | | | | \___ \ "
echo "| |__| |_| | |\  |__| | |_| | |\  | |___  | |  | | |_| | |\  | | |_| |___) |"
echo " \____\___/|_| \_(_)___\___/|_| \_|\____| |_| |___\___/|_| \_|  \___/|____/ "
echo -e "                     Installer - Version 1.0.0${NC}\n"

# ─── Resume Checkpoint Check ────────────────────────────────────────────────
TARGET_DISK=""
PART_SCHEME=""
EFI_PART=""
ROOT_PART=""
USERNAME=""

if [[ -f "$STATE_FILE" ]]; then
    echo -e "${YELLOW}An existing installation state was found.${NC}"
    read -p "Would you like to resume from the last failed step? (Y/n): " -r RESUME
    RESUME="${RESUME:-y}"
    if [[ ! $RESUME =~ ^[Yy]$ ]]; then
        log "Starting fresh installation. Wiping state file..."
        rm -f "$STATE_FILE"
    else
        # Load variables from state file
        TARGET_DISK=$(get_checkpoint_state "target_disk")
        PART_SCHEME=$(get_checkpoint_state "part_scheme")
        EFI_PART=$(get_checkpoint_state "efi_part")
        ROOT_PART=$(get_checkpoint_state "root_part")
        USERNAME=$(get_checkpoint_state "username")
        log "Resuming installation. Loaded: disk=/dev/${TARGET_DISK}, scheme=${PART_SCHEME}, efi=${EFI_PART}, root=${ROOT_PART}, user=${USERNAME}"
    fi
fi

preflight_checks

# ─── Step 1: Select Disk ───────────────────────────────────────────────────
if ! is_step_completed "select_disk"; then
    header "Step 1: Select Installation Disk"

    DISKS=($(lsblk -d -n -o NAME | grep -v "loop\|sr\|ram\|zram\|dm-" || true))
    if [[ "${#DISKS[@]}" -eq 0 ]]; then
        err "No available installation disks found!"
        exit 1
    elif [[ "${#DISKS[@]}" -eq 1 ]]; then
        TARGET_DISK="${DISKS[0]}"
        echo "Available disk: /dev/${TARGET_DISK} ($(lsblk -d -o SIZE "/dev/${TARGET_DISK}" | tail -1 | xargs))"
        read -p "Install Conjunction OS to /dev/${TARGET_DISK}? (Y/n): " CONFIRM_DISK
        CONFIRM_DISK="${CONFIRM_DISK:-y}"
        if [[ ! "$CONFIRM_DISK" =~ ^[Yy]$ ]]; then
            err "Installation aborted by user."
            exit 1
        fi
    else
        echo "Available disks:"
        echo ""
        lsblk -d -o NAME,SIZE,MODEL,ROTA | grep -v "loop\|sr\|ram\|zram\|dm-"
        echo ""
        read -p "Enter disk name (e.g., sda, nvme0n1): " TARGET_DISK
        TARGET_DISK="${TARGET_DISK#/dev/}"
    fi

    if [[ ! -b "/dev/${TARGET_DISK}" ]]; then
        err "Disk /dev/${TARGET_DISK} does not exist."
        exit 1
    fi

    TARGET_SIZE=$(lsblk -d -b -o SIZE "/dev/${TARGET_DISK}" | tail -1 | xargs)
    if [[ "$TARGET_SIZE" -lt 21474836480 ]]; then
        err "Disk is too small. Minimum 20GB required."
        exit 1
    fi

    log "Selected: /dev/${TARGET_DISK} ($(lsblk -d -o SIZE "/dev/${TARGET_DISK}" | tail -1 | xargs))"

    # Display partition map, warn, and require ERASE confirmation
    header "Safety Confirmation"
    log "Active partition map for /dev/${TARGET_DISK}:"
    if command -v parted &>/dev/null; then
        parted -s "/dev/${TARGET_DISK}" print || true
    else
        fdisk -l "/dev/${TARGET_DISK}" || true
    fi
    echo ""
    warn "⚠️ WARNING: Installing Conjunction OS will completely WIPE all data on /dev/${TARGET_DISK}!"
    warn "This includes any existing Linux or Windows partitions on that drive."
    echo "Type 'ERASE' (all capital letters) to confirm and proceed with the installation."
    read -p "Confirmation: " -r ERASE_CONFIRM

    if [[ "$ERASE_CONFIRM" != "ERASE" ]]; then
        err "Confirmation failed. Installation aborted."
        exit 1
    fi

    log "Deactivating swap, LVM volume groups, and MD RAID arrays on /dev/${TARGET_DISK}..."
    # Deactivate active swap partitions and unmount partitions
    for part in "/dev/${TARGET_DISK}"*; do
        if [[ -b "$part" ]]; then
            swapoff "$part" 2>/dev/null || true
            umount -l "$part" 2>/dev/null || true
        fi
    done

    # Deactivate active LVM volume groups
    if command -v vgs &>/dev/null && command -v pvs &>/dev/null; then
        for vg in $(pvs --noheadings -o vg_name,pv_name 2>/dev/null | grep -E "/dev/${TARGET_DISK}(p?[0-9]+)?" | awk '{print $1}' | sort -u); do
            if [[ -n "$vg" ]]; then
                log "Deactivating LVM Volume Group: $vg"
                vgchange -an "$vg" 2>/dev/null || true
            fi
        done
    fi

    # Deactivate active MD RAID arrays
    if [[ -f /proc/mdstat ]]; then
        for md in $(grep -oE "md[0-9]+" /proc/mdstat | sort -u); do
            if mdadm --detail "/dev/$md" 2>/dev/null | grep -E "/dev/${TARGET_DISK}(p?[0-9]+)?" >/dev/null; then
                log "Stopping MD RAID array: /dev/$md"
                mdadm --stop "/dev/$md" 2>/dev/null || true
            fi
        done
    fi

    save_checkpoint "select_disk"
else
    log "Step 1: Select Installation Disk (Skipped - already completed)"
fi

# Define partition paths if target disk and scheme are known, and they haven't been loaded from a checkpoint
if [[ -n "${TARGET_DISK:-}" && -n "${PART_SCHEME:-}" && -z "${ROOT_PART:-}" ]]; then
    if [[ "$PART_SCHEME" == "1" ]]; then
        EFI_PART="$(partition_path "$TARGET_DISK" 1)"
        ROOT_PART="$(partition_path "$TARGET_DISK" 2)"
    else
        ROOT_PART="$(partition_path "$TARGET_DISK" 1)"
        EFI_PART=""
    fi
fi

# ─── Step 2: Partitioning ──────────────────────────────────────────────────
if ! is_step_completed "partitioning"; then
    header "Step 2: Partitioning"

    echo "Partitioning scheme:"
    echo "  1. UEFI (GPT) - Recommended for modern systems"
    echo "  2. BIOS (MBR) - Legacy systems"
    echo ""
    if [[ -d /sys/firmware/efi ]]; then
        DEFAULT_PART_SCHEME="1"
        log "UEFI firmware detected. Defaulting to GPT."
    else
        DEFAULT_PART_SCHEME="2"
        log "Legacy BIOS firmware detected. Defaulting to MBR."
    fi

    read -p "Select partitioning scheme [${DEFAULT_PART_SCHEME}]: " PART_SCHEME
    PART_SCHEME="${PART_SCHEME:-$DEFAULT_PART_SCHEME}"

    echo ""
    echo "Partitioning method:"
    echo "  1. Automatic partitioning (WIPES DISK, creates EFI and Btrfs root)"
    echo "  2. Manual partitioning (Opens cfdisk command-line interface)"
    echo ""
    echo "💡 TIP: If you prefer a graphical interface (with a slider), you can open"
    echo "   'KDE Partition Manager' from the system application launcher first to"
    echo "   graphically resize or create partitions. Then select '2' here to assign them."
    echo ""
    read -p "Select partitioning method [1]: " PART_METHOD
    PART_METHOD="${PART_METHOD:-1}"

    if [[ "$DRY_RUN" == true ]]; then
        EFI_PART=""
        if [[ "$PART_SCHEME" == "1" ]]; then
            EFI_PART="$(partition_path "$TARGET_DISK" 1)"
            ROOT_PART="$(partition_path "$TARGET_DISK" 2)"
        else
            ROOT_PART="$(partition_path "$TARGET_DISK" 1)"
        fi
        echo -e "${YELLOW}[DRY RUN]${NC} Simulating partitioning on /dev/${TARGET_DISK} using scheme ${PART_SCHEME} and method ${PART_METHOD}..."
    else
        if [[ "$PART_METHOD" == "2" ]]; then
            log "Starting manual partitioning with cfdisk..."
            cfdisk "/dev/${TARGET_DISK}"
            sync
            partprobe "/dev/${TARGET_DISK}" 2>/dev/null || true
            udevadm settle

            echo ""
            echo "Current partitions on /dev/${TARGET_DISK}:"
            lsblk "/dev/${TARGET_DISK}" -o NAME,FSTYPE,SIZE,MOUNTPOINTS
            echo ""

            # Root partition selection
            read -p "Enter partition number for ROOT (e.g., 2 for /dev/sda2): " ROOT_PART_NUM
            ROOT_PART="$(partition_path "$TARGET_DISK" "$ROOT_PART_NUM")"
            while [[ ! -b "$ROOT_PART" ]]; do
                err "Partition $ROOT_PART does not exist. Please enter a valid number."
                read -p "Enter partition number for ROOT: " ROOT_PART_NUM
                ROOT_PART="$(partition_path "$TARGET_DISK" "$ROOT_PART_NUM")"
            done

            # EFI partition selection (if UEFI)
            if [[ "$PART_SCHEME" == "1" ]]; then
                read -p "Enter partition number for EFI (e.g., 1 for /dev/sda1): " EFI_PART_NUM
                EFI_PART="$(partition_path "$TARGET_DISK" "$EFI_PART_NUM")"
                while [[ ! -b "$EFI_PART" ]]; do
                    err "Partition $EFI_PART does not exist. Please enter a valid number."
                    read -p "Enter partition number for EFI: " EFI_PART_NUM
                    EFI_PART="$(partition_path "$TARGET_DISK" "$EFI_PART_NUM")"
                done
            else
                EFI_PART=""
            fi

            # Confirm formatting
            echo ""
            warn "About to format root partition $ROOT_PART as Btrfs."
            read -p "Are you sure you want to format root partition $ROOT_PART? (y/N): " CONFIRM_ROOT
            if [[ ! "$CONFIRM_ROOT" =~ ^[Yy]$ ]]; then
                err "Root partition formatting aborted. Cannot proceed without formatting root."
                exit 1
            fi
            mkfs.btrfs -f -L "CONJUNCTION" "$ROOT_PART"

            if [[ -n "$EFI_PART" ]]; then
                echo ""
                warn "Format EFI partition $EFI_PART as FAT32?"
                warn "⚠️ DO NOT format if you are sharing this EFI partition with Windows or another OS!"
                read -p "Format EFI partition? (y/N): " CONFIRM_EFI
                if [[ "$CONFIRM_EFI" =~ ^[Yy]$ ]]; then
                    mkfs.fat -F32 "$EFI_PART"
                    ok "EFI partition formatted"
                else
                    log "Skipped formatting EFI partition (reusing existing filesystem)"
                fi
            fi
            ok "Manual partitions configured"
        else
            if [[ "$PART_SCHEME" == "1" ]]; then
                log "Using UEFI (GPT) partitioning..."

                # Create GPT partition table
                parted -s "/dev/${TARGET_DISK}" mklabel gpt

                # Create EFI System Partition (512MB)
                parted -s "/dev/${TARGET_DISK}" mkpart ESP fat32 1MiB 513MiB
                parted -s "/dev/${TARGET_DISK}" set 1 esp on

                # Create root partition (remaining space)
                parted -s "/dev/${TARGET_DISK}" mkpart root ext4 513MiB 100%

                sync
                partprobe "/dev/${TARGET_DISK}" 2>/dev/null || true
                udevadm settle

                EFI_PART="$(partition_path "$TARGET_DISK" 1)"
                ROOT_PART="$(partition_path "$TARGET_DISK" 2)"

                # Format partitions
                mkfs.fat -F32 "$EFI_PART"
                mkfs.btrfs -f -L "CONJUNCTION" "$ROOT_PART"

                ok "UEFI partitions created"
            else
                log "Using BIOS (MBR) partitioning..."

                # Create MBR partition table
                parted -s "/dev/${TARGET_DISK}" mklabel msdos

                # Create root partition (entire disk)
                parted -s "/dev/${TARGET_DISK}" mkpart primary ext4 1MiB 100%

                sync
                partprobe "/dev/${TARGET_DISK}" 2>/dev/null || true
                udevadm settle

                ROOT_PART="$(partition_path "$TARGET_DISK" 1)"

                # Format partition
                mkfs.btrfs -f -L "CONJUNCTION" "$ROOT_PART"

                EFI_PART=""

                ok "BIOS partitions created"
            fi
        fi
    fi
    save_checkpoint "partitioning"
else
    log "Step 2: Partitioning (Skipped - already completed)"
fi

# ─── Step 3: Create Btrfs Subvolumes ────────────────────────────────────────
if ! is_step_completed "subvolumes"; then
    header "Step 3: Creating Btrfs Subvolumes"

    if [[ "$DRY_RUN" == true ]]; then
        mkdir -p "$MNT"/{boot,home,.snapshots,var/log}
        echo -e "${YELLOW}[DRY RUN]${NC} Simulating Btrfs subvolumes and mounts under $MNT..."
    else
        # Mount root partition
        mkdir -p /mnt
        mount "${ROOT_PART}" /mnt

        # Create subvolumes
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        btrfs subvolume create /mnt/@snapshots
        btrfs subvolume create /mnt/@var_log

        # Unmount and remount with subvolumes
        umount /mnt

        # Mount root subvolume
        mount -o subvol=@,compress=zstd,noatime "${ROOT_PART}" /mnt

        # Create mount points
        mkdir -p /mnt/{boot,home,.snapshots,var/log}

        # Mount subvolumes
        mount -o subvol=@home,compress=zstd,noatime "${ROOT_PART}" /mnt/home
        mount -o subvol=@snapshots,compress=zstd,noatime "${ROOT_PART}" /mnt/.snapshots
        mount -o subvol=@var_log,compress=zstd,noatime "${ROOT_PART}" /mnt/var/log

        # Mount EFI partition (UEFI only)
        if [[ -n "$EFI_PART" ]]; then
            mkdir -p /mnt/boot/efi
            mount "${EFI_PART}" /mnt/boot/efi
        fi
    fi
    ok "Btrfs subvolumes created"
    save_checkpoint "subvolumes"
else
    log "Step 3: Creating Btrfs Subvolumes (Skipped - already completed)"
fi

# ─── Step 4: Install Base System ────────────────────────────────────────────
if ! is_step_completed "install_base"; then
    header "Step 4: Installing Base System"

    # Pre-install mirror selection
    log "Selecting fastest pacman mirrors..."
    if command -v rate-mirrors &>/dev/null; then
        log "Using rate-mirrors to select mirrors..."
        run_install_cmd rate-mirrors --save /etc/pacman.d/mirrorlist arch 2>/dev/null || true
    elif command -v reflector &>/dev/null; then
        log "Using reflector to select mirrors..."
        run_install_cmd reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null || true
    else
        warn "Neither rate-mirrors nor reflector found. Skipping mirror selection."
    fi

    # Configure pacman
    if [[ "$DRY_RUN" == false ]]; then
        sed -i 's/#Color/Color/' /etc/pacman.conf
        sed -i 's/#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    fi

    # Install base packages
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Simulating pacstrap installation to $MNT..."
        mkdir -p "$MNT"/{etc,usr/local/bin,opt/conjunction,var/log}
    else
        pacstrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware \
            amd-ucode intel-ucode sudo \
            grub efibootmgr dosfstools mtools \
            networkmanager network-manager-applet iwd openssh \
            pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
            plasma-desktop plasma-workspace plasma-x11-session plasma-nm plasma-pa \
            sddm konsole dolphin xdg-desktop-portal xdg-desktop-portal-kde \
            nano vim git wget curl flatpak \
            snapper btrfs-progs grub-btrfs bluez bluez-utils cups \
            plank kvantum breeze-gtk breeze-icons inter-font noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono ttf-fira-code \
            zsh kitty appmenu-gtk-module libdbusmenu-glib libdbusmenu-gtk3
    fi

    ok "Base system installed"
    save_checkpoint "install_base"
else
    log "Step 4: Install Base System (Skipped - already completed)"
fi

# ─── Step 5: Configure System ───────────────────────────────────────────────
if ! is_step_completed "configure_system"; then
    header "Step 5: Configuring System"

    # Generate fstab
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Simulating fstab generation..."
        mkdir -p "$MNT/etc"
        echo "# Mock fstab" > "$MNT/etc/fstab"
    else
        genfstab -U /mnt >> /mnt/etc/fstab
    fi

    ok "fstab generated successfully"

    # Set timezone
    run_chroot ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    run_chroot hwclock --systohc
    ok "Timezone configured"

    # Set locale
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Simulating locale-gen and writing locale.conf..."
    else
        echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
        arch-chroot /mnt locale-gen
        echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
    fi
    ok "Locale configured"

    # Set hostname
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Simulating writing /etc/hostname and /etc/hosts..."
    else
        echo "conjunction" > /mnt/etc/hostname
        cat > /mnt/etc/hosts << EOF
127.0.0.1   localhost
127.0.1.1   conjunction
::1         localhost
EOF
    fi
    ok "Hostname configured"

    # Write Nouveau blacklist configuration
    log "Writing Nouveau blacklist configuration..."
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Simulating writing /etc/modprobe.d/nouveau.conf..."
    else
        mkdir -p /mnt/etc/modprobe.d
        cat > /mnt/etc/modprobe.d/nouveau.conf << 'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
    fi
    ok "Nouveau blacklist configured"

    # Configure flathub remote in target chroot
    log "Configuring Flathub remote..."
    run_chroot flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || warn "Failed to configure Flathub remote."
    ok "Flathub remote configured"

    save_checkpoint "configure_system"
else
    log "Step 5: Configuring System (Skipped - already completed)"
fi

post_install_validation() {
    header "Post-Install Validation"
    local failed=false

    log "Checking mount points..."
    # Root mount
    if ! findmnt -n -o SOURCE "$MNT" >/dev/null; then
        err "Validation failed: Root partition is not mounted at $MNT"
        failed=true
    else
        ok "Root partition mount OK"
    fi
    # Home mount
    if ! findmnt -n -o SOURCE "$MNT/home" >/dev/null; then
        err "Validation failed: /home is not mounted"
        failed=true
    else
        ok "/home mount OK"
    fi
    # Snapshots mount
    if ! findmnt -n -o SOURCE "$MNT/.snapshots" >/dev/null; then
        err "Validation failed: /.snapshots is not mounted"
        failed=true
    else
        ok "/.snapshots mount OK"
    fi

    log "Checking kernel files..."
    if [[ ! -f "$MNT/boot/vmlinuz-linux-zen" ]]; then
        err "Validation failed: Kernel vmlinuz-linux-zen not found in target boot directory"
        failed=true
    else
        ok "Kernel files OK"
    fi

    log "Checking EFI bootloader..."
    if [[ -n "$EFI_PART" ]]; then
        if [[ ! -f "$MNT/boot/efi/EFI/BOOT/BOOTX64.EFI" ]] && [[ ! -f "$MNT/boot/efi/EFI/BOOT/bootx64.efi" ]]; then
            err "Validation failed: EFI bootloader BOOTX64.EFI not found in target ESP"
            failed=true
        else
            ok "EFI bootloader OK"
        fi
    fi

    log "Checking user accounts..."
    if ! grep -q "^${USERNAME}:" "$MNT/etc/passwd"; then
        err "Validation failed: User '${USERNAME}' was not created in target /etc/passwd"
        failed=true
    else
        ok "User account '${USERNAME}' OK"
    fi

    log "Checking sudo configurations..."
    if [[ ! -f "$MNT/etc/sudoers" ]] || ! grep -q "wheel ALL" "$MNT/etc/sudoers"; then
        err "Validation failed: Sudo config for wheel group is not active"
        failed=true
    else
        ok "Sudo configuration OK"
    fi

    log "Checking network configuration..."
    if [[ ! -f "$MNT/etc/systemd/system/multi-user.target.wants/NetworkManager.service" ]]; then
        err "Validation failed: NetworkManager service is not enabled"
        failed=true
    else
        ok "NetworkManager service OK"
    fi

    log "Checking Flatpak configuration..."
    # Check if flathub remote is configured
    if ! run_chroot flatpak remotes | grep -q "flathub"; then
        err "Validation failed: Flatpak flathub remote not configured"
        failed=true
    else
        ok "Flatpak flathub remote OK"
    fi

    log "Checking Snapper snapshot configuration..."
    if [[ ! -f "$MNT/etc/snapper/configs/root" ]]; then
        warn "Snapper config 'root' was not created (Non-fatal warning)"
    else
        ok "Snapper configuration OK"
    fi

    if [[ "$failed" == true ]]; then
        warn "⚠️ Some validation checks failed! Please review the errors above."
        read -p "Do you want to continue anyway? (y/N): " -r CONTINUE_ANYWAY
        if [[ ! $CONTINUE_ANYWAY =~ ^[Yy]$ ]]; then
            err "Installation aborted due to validation failure."
            exit 1
        fi
    else
        ok "All post-install validation checks passed!"
    fi
}

# ─── Step 6: User Setup ─────────────────────────────────────────────────────
if ! is_step_completed "user_setup"; then
    header "Step 6: Creating User Account"

    read -p "Enter username: " USERNAME
    validate_username "$USERNAME"

    read -s -p "Enter password for $USERNAME: " PASSWORD
    echo ""
    read -s -p "Confirm password: " PASSWORD_CONFIRM
    echo ""

    if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
        err "Passwords do not match."
        exit 1
    fi

    if [[ -z "$PASSWORD" ]]; then
        err "Password cannot be empty."
        exit 1
    fi

    if [[ "$PASSWORD" == *:* ]]; then
        err "Password cannot contain ':' because Linux chpasswd uses it as a field separator."
        exit 1
    fi

    read -p "Use the same password for the root (administrator) account? (Y/n): " SAME_PASSWORD
    SAME_PASSWORD="${SAME_PASSWORD:-y}"

    if [[ ! "$SAME_PASSWORD" =~ ^[Yy]$ ]]; then
        read -s -p "Enter password for root: " ROOT_PASSWORD
        echo ""
        read -s -p "Confirm root password: " ROOT_PASSWORD_CONFIRM
        echo ""

        if [[ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ]]; then
            err "Passwords do not match."
            exit 1
        fi

        if [[ -z "$ROOT_PASSWORD" ]]; then
            err "Password cannot be empty."
            exit 1
        fi

        if [[ "$ROOT_PASSWORD" == *:* ]]; then
            err "Password cannot contain ':' because Linux chpasswd uses it as a field separator."
            exit 1
        fi
    else
        ROOT_PASSWORD="$PASSWORD"
    fi

    # Create user
    run_chroot useradd -m -G wheel,video,audio,storage,optical,network,power,lp,users -s /bin/zsh "$USERNAME"

    # Set password
    set_chroot_password "$USERNAME" "$PASSWORD"

    # Set root password
    set_chroot_password root "$ROOT_PASSWORD"

    # Enable sudo for wheel group
    if [[ "$DRY_RUN" == false ]]; then
        sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' "$MNT/etc/sudoers"
    else
        echo -e "${YELLOW}[DRY RUN]${NC} Simulating enabling sudo for wheel group..."
    fi

    ok "User account created"
    save_checkpoint "user_setup"
else
    log "Step 6: Creating User Account (Skipped - already completed)"
fi

# ─── Step 7: Configuring Snapper ──────────────────────────────────────────────
if ! is_step_completed "snapper_config"; then
    header "Step 7: Configuring Snapper"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Simulating Snapper configuration..."
    else
        # Unmount the snapshots subvolume temporarily so snapper can create its config
        log "Unmounting .snapshots temporarily..."
        umount -l /mnt/.snapshots 2>/dev/null || true
        rm -rf /mnt/.snapshots

        # Create snapper config
        log "Initializing Snapper config..."
        arch-chroot /mnt snapper -c root create-config / || true

        # Delete the directory snapper created so we can remount our subvolume there
        log "Remounting .snapshots subvolume..."
        rm -rf /mnt/.snapshots
        mkdir -p /mnt/.snapshots
        mount -o subvol=@snapshots,compress=zstd,noatime "${ROOT_PART}" /mnt/.snapshots || true
    fi

    run_chroot snapper -c root set-timeline-limit-hourly 10 || true
    run_chroot snapper -c root set-timeline-limit-daily 7 || true
    run_chroot snapper -c root set-timeline-limit-weekly 4 || true
    run_chroot snapper -c root set-timeline-limit-monthly 6 || true

    ok "Snapper configured"
    save_checkpoint "snapper_config"
else
    log "Step 7: Configuring Snapper (Skipped - already completed)"
fi

# ─── Step 8: Installing Bootloader ─────────────────────────────────────────────
if ! is_step_completed "bootloader"; then
    header "Step 8: Installing Bootloader"

    # Generate initramfs before bootloader so grub-mkconfig finds the images
    log "Generating initramfs..."
    run_chroot mkinitcpio -P
    ok "Initramfs generated"

    if [[ -n "$EFI_PART" ]]; then
        # UEFI bootloader
        run_chroot grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=CONJUNCTION
        run_chroot grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=CONJUNCTION --removable

        # Verify EFI bootloader was written
        if ! run_chroot test -f /boot/efi/EFI/BOOT/BOOTX64.EFI && ! run_chroot test -f /boot/efi/EFI/BOOT/bootx64.efi; then
            err "UEFI bootloader verification failed: BOOTX64.EFI not found after grub-install"
            exit 1
        fi
        ok "EFI bootloader file verified"

        # Hyper-V Gen 2 fallback: ensure BOOTX64.EFI exists at the removable media path
        run_chroot mkdir -p /boot/efi/EFI/BOOT
        run_chroot cp /boot/efi/EFI/CONJUNCTION/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI 2>/dev/null || true
        run_chroot cp /boot/efi/EFI/CONJUNCTION/grubx64.efi /boot/efi/EFI/BOOT/bootx64.efi 2>/dev/null || true
    else
        # BIOS bootloader
        run_chroot grub-install --target=i386-pc "/dev/${TARGET_DISK}"
    fi

    # Generate GRUB config
    run_chroot grub-mkconfig -o /boot/grub/grub.cfg

    # Verify grub.cfg contains at least one boot entry
    if ! grep -q 'menuentry' "$MNT/boot/grub/grub.cfg"; then
        err "GRUB config verification failed: /boot/grub/grub.cfg contains no menuentry"
        exit 1
    fi
    ok "GRUB config verified"

    ok "Bootloader installed"
    save_checkpoint "bootloader"
else
    log "Step 8: Installing Bootloader (Skipped - already completed)"
fi

# ─── Step 9: Enabling Services ────────────────────────────────────────────────
if ! is_step_completed "services"; then
    header "Step 9: Enabling Services"

    run_chroot systemctl enable sddm
    run_chroot systemctl enable NetworkManager
    # Commented out enabling sshd by default
    # run_chroot systemctl enable sshd
    run_chroot systemctl enable bluetooth
    run_chroot systemctl enable cups

    ok "Services enabled"
    save_checkpoint "services"
else
    log "Step 9: Enabling Services (Skipped - already completed)"
fi

# ─── Step 10: Installing Conjunction OS Components ───────────────────────────
if ! is_step_completed "conjunction_files"; then
    header "Step 10: Installing Conjunction OS Components"

    # Create directories
    run_chroot mkdir -p /opt/conjunction
    run_chroot mkdir -p /usr/local/bin

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Simulating copying Conjunction OS components to $MNT..."
    else
        # Copy live setup script
        cp /usr/local/bin/conjunction-live-setup.sh /mnt/usr/local/bin/ 2>/dev/null || true

        # Copy Conjunction OS components from /opt/conjunction on the live ISO
        CONJUNCTION_SRC="/opt/conjunction"
        mkdir -p /mnt/opt/conjunction

        if [[ -f "${CONJUNCTION_SRC}/cj" ]]; then
            cp "${CONJUNCTION_SRC}/cj" /mnt/opt/conjunction/
            chmod +x /mnt/opt/conjunction/cj
            ln -sf /opt/conjunction/cj /mnt/usr/local/bin/cj
        fi
        if [[ -f "${CONJUNCTION_SRC}/application" ]]; then
            cp "${CONJUNCTION_SRC}/application" /mnt/opt/conjunction/
            chmod +x /mnt/opt/conjunction/application
            ln -sf /opt/conjunction/application /mnt/usr/local/bin/application
        fi
        if [[ -f "${CONJUNCTION_SRC}/app_sync" ]]; then
            cp "${CONJUNCTION_SRC}/app_sync" /mnt/opt/conjunction/
            chmod +x /mnt/opt/conjunction/app_sync
        fi
        if [[ -f "/etc/systemd/system/conjunction-app-sync.service" ]]; then
            cp "/etc/systemd/system/conjunction-app-sync.service" /mnt/etc/systemd/system/
            run_chroot systemctl enable conjunction-app-sync || true
        fi
        if [[ -f "/usr/share/kio/servicemenus/conjunction-app.desktop" ]]; then
            mkdir -p /mnt/usr/share/kio/servicemenus/
            cp "/usr/share/kio/servicemenus/conjunction-app.desktop" /mnt/usr/share/kio/servicemenus/
        fi
        if [[ -f "${CONJUNCTION_SRC}/setup_conjunction_ui.sh" ]]; then
            cp "${CONJUNCTION_SRC}/setup_conjunction_ui.sh" /mnt/opt/conjunction/
            chmod +x /mnt/opt/conjunction/setup_conjunction_ui.sh
            log "Pre-configuring macOS-style desktop theme and shortcuts for user ${USERNAME}..."
            run_chroot env SUDO_USER="$USERNAME" /opt/conjunction/setup_conjunction_ui.sh --skip-packages || warn "Failed to pre-configure UI layout."
        fi
    fi

    ok "Conjunction OS components installed"
    save_checkpoint "conjunction_files"
else
    log "Step 10: Installing Conjunction OS Components (Skipped - already completed)"
fi

# ─── Step 11: Final Configuration ────────────────────────────────────────────
if ! is_step_completed "post_install_config"; then
    header "Step 11: Final Configuration"

    # Create post-install script without delayed boot animation
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} Simulating writing post-install script and service..."
    else
        mkdir -p "$MNT/usr/local/bin"
        cat > "$MNT/usr/local/bin/conjunction-post-install.sh" << 'POSTINSTALL'
#!/usr/bin/env bash
# conjunction-post-install.sh - First boot configuration

set -euo pipefail

echo "Running Conjunction OS post-install configuration..."

# Set CPU governor to performance
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > "$cpu" 2>/dev/null || true
done

# Enable transparent hugepages
echo always > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true

# Optimize sysctl
cat > /etc/sysctl.d/99-conjunction.conf << SYSCTL
vm.swappiness=10
vm.dirty_ratio=15
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
SYSCTL

sysctl --system 2>/dev/null || true

echo "Post-install configuration complete!"
systemctl disable conjunction-post-install.service >/dev/null 2>&1 || true
POSTINSTALL
        chmod +x "$MNT/usr/local/bin/conjunction-post-install.sh"

        # Create first-boot service (RemainAfterExit=no)
        cat > "$MNT/etc/systemd/system/conjunction-post-install.service" << SERVICE
[Unit]
Description=Conjunction OS Post-Install Setup
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/conjunction-post-install.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
SERVICE
    fi

    run_chroot systemctl enable conjunction-post-install

    ok "Final configuration complete"
    save_checkpoint "post_install_config"
else
    log "Step 11: Final Configuration (Skipped - already completed)"
fi

# Copy the log to target system before validation (only if not dry run)
if [[ "$DRY_RUN" == false ]]; then
    log "Copying installer log to target system..."
    mkdir -p "$MNT/var/log"
    cp "$LOG_FILE" "$MNT/var/log/conjunction-installer.log" || true
fi

# Post-install validation checking mounts, kernels, users, sudo, network, flatpak, snapshots configs
if [[ "$DRY_RUN" == true ]]; then
    log "[DRY RUN] Skipping actual post-install validation."
else
    post_install_validation
fi

# Clean up state file on success
if [[ "$DRY_RUN" == false ]]; then
    rm -f "$STATE_FILE"
fi

# ─── Complete ───────────────────────────────────────────────────────────────
header "Installation Complete!"

if [[ "$DRY_RUN" == true ]]; then
    ok "Dry run complete! No changes were made to physical disks."
    exit 0
fi

echo ""
echo "Conjunction OS has been installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Reboot your system: sudo reboot"
echo "  2. Remove the installation media"
echo "  3. Log in with your username and password"
echo "  4. Run the UI setup: sudo /opt/conjunction/setup_conjunction_ui.sh"
echo "  5. Run system update: cj update"
echo "  6. Run optimization: cj optimize"
echo ""
echo "Thank you for choosing Conjunction OS!"
echo ""
echo "Rebooting automatically into Conjunction OS in 5 seconds... Press Ctrl+C to cancel."
for i in {5..1}; do
    echo -n "$i... "
    sleep 1
done
echo ""
log "Unmounting filesystems..."
umount -R /mnt 2>/dev/null || true
log "Rebooting now..."
reboot
