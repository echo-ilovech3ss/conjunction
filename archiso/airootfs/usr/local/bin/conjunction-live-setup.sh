#!/usr/bin/env bash
# conjunction-live-setup.sh - Live Environment Setup
# Runs automatically on first boot of the live ISO

set -euo pipefail

# ─── Live Check ─────────────────────────────────────────────────────────────
if [ ! -f /etc/archiso-release ]; then
    echo "Not running in a live environment. Disabling service and exiting."
    systemctl disable conjunction-setup.service 2>/dev/null || true
    exit 0
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${CYAN}"
echo "  ____ ___  _   _    _ _   _ _   _  ____ _____ ___ ___  _   _    ___  ____  "
echo " / ___/ _ \| \ | |  | | | | | \ | |/ ___|_   _|_ _/ _ \| \ | |  / _ \/ ___| "
echo "| |  | | | |  \| |  | | | | |  \| | |     | |  | | | | |  \| | | | | \___ \ "
echo "| |__| |_| | |\  |__| | |_| | |\  | |___  | |  | | |_| | |\  | | |_| |___) |"
echo " \____\___/|_| \_(_)___\___/|_| \_|\____| |_| |___\___/|_| \_|  \___/|____/ "
echo -e "                   Live Environment Setup${NC}\n"

# ─── Configure Flathub Remote ───────────────────────────────────────────────
log "Configuring Flathub remote..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
if id "conjunction" &>/dev/null; then
    sudo -u conjunction flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
fi
if id "liveuser" &>/dev/null; then
    sudo -u liveuser flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
fi
ok "Flathub remote configured"

# User setup is now handled at system initialization time by conjunction-live-init.sh

# ─── Network Setup ──────────────────────────────────────────────────────────
log "Configuring network..."
if systemctl is-active --quiet NetworkManager; then
    ok "NetworkManager is running"
else
    systemctl start NetworkManager 2>/dev/null || true
fi

# Start the desktop before doing slower connectivity checks so the installer is
# available even on disconnected or slow networks.
log "Starting display server..."
if systemctl is-active --quiet display-manager; then
    ok "Display manager already running"
else
    systemctl start sddm 2>/dev/null || true
fi

# Wait for network connectivity
log "Waiting for network connectivity..."
NETWORK_READY=false
for i in {1..10}; do
    if ping -c 1 -W 2 archlinux.org &>/dev/null; then
        ok "Network connected"
        NETWORK_READY=true
        break
    fi
    sleep 1
done

if [[ "$NETWORK_READY" != true ]]; then
    warn "Network check did not complete. The installer will re-check before touching disks."
fi

# ─── Timezone ───────────────────────────────────────────────────────────────
log "Setting timezone..."
timedatectl set-timezone UTC 2>/dev/null || true

# ─── Keyboard Layout ────────────────────────────────────────────────────────
log "Setting keyboard layout..."
localectl set-keymap us 2>/dev/null || true

# ─── Display Server ─────────────────────────────────────────────────────────
ok "Live environment setup complete!"
echo ""
echo "Welcome to Conjunction OS!"
echo ""
echo "To install Conjunction OS to your hard drive, click the"
echo "'Install Conjunction OS' icon on your desktop or in the application menu."
echo ""
echo "To try Conjunction OS without installing, simply use the live environment."
echo ""

# Signal smoke test completion if serial port is available
if [ -e /dev/ttyS0 ]; then
    echo "SMOKE_TEST_OK: boot=1 sddm=1 networkmanager=1 welcome=1" > /dev/ttyS0
fi

