#!/usr/bin/env bash
# =============================================================================
# setup_conjunction_ui.sh - Conjunction OS Desktop Environment Configuration
# =============================================================================
# Purpose: Configure KDE Plasma on Arch Linux to replicate macOS UI/UX patterns
# Target: Arch Linux with KDE Plasma 5.x/6.x
# Requirements: sudo access, internet connection, Arch-based distribution
# Idempotent: Safe to run multiple times without side effects
# =============================================================================

set -euo pipefail

# Resolve real target user and their home directory under sudo
if [[ -n "${SUDO_USER:-}" ]]; then
    readonly TARGET_USER="$SUDO_USER"
    readonly USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    readonly TARGET_USER="$(whoami)"
    readonly USER_HOME="$HOME"
fi

# Override HOME variable to ensure all user config commands write to correct path
export HOME="$USER_HOME"

# ─── Global Configuration ───────────────────────────────────────────────────
readonly SCRIPT_VERSION="1.0.0"
readonly LOG_FILE="/var/log/conjunction_setup.log"
readonly PANEL_HEIGHT=28
readonly DOCK_HEIGHT=56
readonly CORNER_RADIUS=12
readonly FONT_FAMILY="Inter"
KWRITECONFIG="$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)"
QDBUS_CMD="$(command -v qdbus6 || command -v qdbus || true)"

# ─── Color Definitions ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─── Argument Parsing ───────────────────────────────────────────────────────
DRY_RUN=false
VERBOSE=false
SKIP_PACKAGES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)  DRY_RUN=true; shift ;;
        --skip-packages) SKIP_PACKAGES=true; shift ;;
        --verbose|-v) VERBOSE=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--skip-packages] [--verbose] [--help]"
            exit 0
            ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# ─── Logging ────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" >> "$LOG_FILE" 2>/dev/null || true; }
info()    { echo -e "${BLUE}[INFO]${NC} $1";    log "INFO" "$1"; }
success() { echo -e "${GREEN}[OK]${NC} $1";     log "OK" "$1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1";  log "WARN" "$1"; }
err()     { echo -e "${RED}[ERROR]${NC} $1";    log "ERROR" "$1"; }
verbose() { [[ "$VERBOSE" == true ]] && echo -e "${CYAN}[DEBUG]${NC} $1"; log "DEBUG" "$1"; }

# ─── Helpers ────────────────────────────────────────────────────────────────
run() {
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] $*"
        return 0
    fi
    verbose "exec: $*"
    "$@" 2>&1 | tee -a "$LOG_FILE"
    return "${PIPESTATUS[0]}"
}

run_sudo() {
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] sudo $*"
        return 0
    fi
    verbose "exec: sudo $*"
    sudo "$@" 2>&1 | tee -a "$LOG_FILE"
    return "${PIPESTATUS[0]}"
}

# ─── Pre-flight ─────────────────────────────────────────────────────────────
preflight() {
    info "Running pre-flight checks..."

    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        err "Requires root or passwordless sudo. Run: sudo $0"
        exit 1
    fi

    if [[ ! -f /etc/arch-release ]] && ! grep -qi "arch" /etc/os-release 2>/dev/null; then
        warn "Not detected as Arch Linux. Proceed with caution."
        read -p "Continue? (y/N): " -r
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi

    success "Pre-flight checks passed."
}

# ─── Package Installation ──────────────────────────────────────────────────
install_packages() {
    info "Installing required packages..."

    local packages=(
        plasma-desktop plasma-workspace plasma-nm plasma-pa
        kdeplasma-addons systemsettings
        sddm sddm-kcm
        plank
        qt5-base qt5-wayland qt6-base qt6-wayland qt6-tools
        kvantum breeze-gtk breeze-icons
        inter-font noto-fonts noto-fonts-cjk noto-fonts-emoji
        ttf-jetbrains-mono ttf-fira-code
        xdg-utils xdg-desktop-portal xdg-desktop-portal-kde
        imagemagick
        base-devel git go
    )

    run_sudo pacman -S --needed --noconfirm "${packages[@]}"

    KWRITECONFIG="$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)"
    QDBUS_CMD="$(command -v qdbus6 || command -v qdbus || true)"

    if [[ -z "$KWRITECONFIG" && "$DRY_RUN" != true ]]; then
        err "kwriteconfig was not found after package installation."
        exit 1
    fi

    # AUR packages
    if ! command -v yay &>/dev/null; then
        info "yay not found. Automating cloning and building of yay AUR helper as $TARGET_USER..."
        local yay_dir
        yay_dir=$(sudo -u "$TARGET_USER" mktemp -d)
        if sudo -u "$TARGET_USER" git clone https://aur.archlinux.org/yay.git "$yay_dir/yay"; then
            if sudo -u "$TARGET_USER" bash -c "cd '$yay_dir/yay' && makepkg -si --noconfirm"; then
                success "yay installed successfully from source."
            else
                warn "Failed to build and install yay from source."
            fi
        else
            warn "Failed to clone yay from AUR."
        fi
        rm -rf "$yay_dir"
    fi

    if command -v yay &>/dev/null; then
        for pkg in "ttf-san-francisco"; do
            if ! sudo -u "$TARGET_USER" yay -Qi "$pkg" &>/dev/null; then
                sudo -u "$TARGET_USER" yay -S --noconfirm "$pkg" || warn "Failed to install AUR package: $pkg"
            fi
        done
    else
        warn "yay helper is still missing. Font support may be incomplete."
    fi

    success "Package installation complete."
}

# ─── Panel Configuration (macOS-style top bar) ──────────────────────────────
configure_panel() {
    info "Configuring macOS-style top panel..."

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] Would configure top panel"
        return 0
    fi

    # Use KDE's scripting API to configure panels
    # This is the proper way to set up panels in KDE Plasma 5/6

    # First, get the current layout
    local layout_script
    layout_script=$(mktemp /tmp/conjunction_layout_XXXXXX.js)

    cat > "$layout_script" << 'LAYOUTSCRIPT'
// Conjunction OS Panel Layout Script
// Configures a macOS-style top panel with global menu

function configureTopPanel() {
    // Remove existing panels
    var panels = panelIds();
    for (var i = 0; i < panels.length; i++) {
        removePanel(panels[i]);
    }

    // Create top panel (macOS menu bar)
    var topPanel = new Panel();
    topPanel.screen = 0;
    topPanel.position = TopEdge;
    topPanel.height = 30;
    topPanel.length = screenGeometry(0).width;
    topPanel.offset = 0;
    topPanel.alignment = 0;
    topPanel.hiding = "none";
    topPanel.floating = false;

    // Add app menu widget (global menu)
    var appMenu = topPanel.addWidget("org.kde.plasma.appmenu");
    if (appMenu) {
        print("Added global menu widget");
    }

    // Add spacer to push tray and clock to the right
    topPanel.addWidget("org.kde.plasma.panelspacer");

    // Add system tray
    var systemTray = topPanel.addWidget("org.kde.plasma.systemtray");
    if (systemTray) {
        print("Added system tray");
    }

    // Add digital clock
    var clock = topPanel.addWidget("org.kde.plasma.digitalclock");
    if (clock) {
        print("Added clock widget");
    }

    // Add lock/logout buttons
    var lockBtn = topPanel.addWidget("org.kde.plasma.lockscreen");
    if (lockBtn) {
        print("Added lock screen button");
    }

    return topPanel;
}

function configureDock() {
    // Create bottom dock (macOS-style)
    var dock = new Panel();
    dock.screen = 0;
    dock.position = BottomEdge;
    dock.height = 56;
    dock.lengthMode = "fit";
    dock.floating = true;
    dock.alignment = 1; // Center
    dock.hiding = "none";

    // Add task manager (dock icons)
    var taskManager = dock.addWidget("org.kde.plasma.icontasks");
    if (taskManager) {
        print("Added icon task manager");
    }

    return dock;
}

// Execute configuration
configureTopPanel();
configureDock();
LAYOUTSCRIPT

    # Apply the layout using plasmashell
    local user_uid
    user_uid=$(id -u "$TARGET_USER")
    if [[ -n "$QDBUS_CMD" ]]; then
        sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${user_uid}/bus" "$QDBUS_CMD" org.kde.PlasmaShell /PlasmaShell evaluateScript "$(cat "$layout_script")" 2>/dev/null || {
            # Fallback: write config files directly
            warn "qdbus scripting failed, writing config files directly"
            write_panel_config
        }
    else
        # Fallback: write config files directly
        warn "qdbus scripting failed, writing config files directly"
        write_panel_config
    fi

    rm -f "$layout_script"

    success "Top panel configured."
}

# Fallback: write panel configuration files directly
write_panel_config() {
    local appletsrc="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    
    mkdir -p "$(dirname "$appletsrc")"

    # Top panel and bottom dock configuration
    cat > "$appletsrc" << 'EOF'
[Containments][1]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=3
plugin=org.kde.panel
wallpaperplugin=org.kde.image

[Containments][1][Applets][1]
plugin=org.kde.plasma.appmenu

[Containments][1][Applets][1][Configuration]
PreloadWeight=34

[Containments][1][Applets][2]
plugin=org.kde.plasma.systemtray

[Containments][1][Applets][3]
plugin=org.kde.plasma.digitalclock

[Containments][1][Applets][4]
plugin=org.kde.plasma.lockscreen

[Containments][2]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=5
plugin=org.kde.panel
wallpaperplugin=org.kde.image

[Containments][2][Applets][5]
plugin=org.kde.plasma.icontasks

[Containments][2][Applets][5][Configuration]
launchers=
showOnlyCurrentActivity=false
showOnlyCurrentScreen=false
showOnlyMinimized=false
sortingStrategy=0
EOF
}

# ─── Window Effects (macOS-style) ──────────────────────────────────────────
configure_window_effects() {
    info "Configuring macOS-style window effects..."

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] Would configure window effects"
        return 0
    fi

    local kwinrc="$HOME/.config/kwinrc"
    mkdir -p "$(dirname "$kwinrc")"

    # Enable compositing
    "$KWRITECONFIG" --file "$kwinrc" --group Compositing --key Enabled true
    "$KWRITECONFIG" --file "$kwinrc" --group Compositing --key OpenGLIsUnsafe false
    "$KWRITECONFIG" --file "$kwinrc" --group Compositing --key AnimationSpeed 3
    "$KWRITECONFIG" --file "$kwinrc" --group Compositing --key LatencyPolicy Balanced
    "$KWRITECONFIG" --file "$kwinrc" --group Compositing --key VSyncMethod OpenGL

    # Enable blur effect (macOS-style transparency)
    "$KWRITECONFIG" --file "$kwinrc" --group Effect-Blur --key Enabled true
    "$KWRITECONFIG" --file "$kwinrc" --group Effect-Blur --key BlurStrength 12

    # Enable rounded corners (12px radius like macOS)
    "$KWRITECONFIG" --file "$kwinrc" --group Effect-RoundedCorners --key Enabled true
    "$KWRITECONFIG" --file "$kwinrc" --group Effect-RoundedCorners --key BorderSize "$CORNER_RADIUS"

    # Window shadows (macOS-style)
    "$KWRITECONFIG" --file "$kwinrc" --group Shadow --key Enabled true
    "$KWRITECONFIG" --file "$kwinrc" --group Shadow --key ShadowSize 20
    "$KWRITECONFIG" --file "$kwinrc" --group Shadow --key ShadowStrength 128

    # Window placement
    "$KWRITECONFIG" --file "$kwinrc" --group Windows --key Placement Centered

    # Window decorations (thin title bars like macOS)
    "$KWRITECONFIG" --file "$kwinrc" --group org.kde.kdecoration --key Theme "Breeze"
    "$KWRITECONFIG" --file "$kwinrc" --group org.kde.kdecoration --key BorderSize Normal
    "$KWRITECONFIG" --file "$kwinrc" --group org.kde.kdecoration --key BorderSizeMax Normal
    "$KWRITECONFIG" --file "$kwinrc" --group org.kde.kdecoration --key ShowToolTips false

    # Move buttons to the left (macOS traffic-light style)
    "$KWRITECONFIG" --file "$kwinrc" --group org.kde.kdecoration2 --key ButtonsOnLeft "XIA"
    "$KWRITECONFIG" --file "$kwinrc" --group org.kde.kdecoration2 --key ButtonsOnRight ""

    # Enable all desktop effects
    local effects=(
        "blur"
        "roundedcorners"
        "shadow"
        "presentwindows"
        "desktopgrid"
        "zoom"
        "overview"
        "fade"
        "translucency"
    )

    for effect in "${effects[@]}"; do
        "$KWRITECONFIG" --file "$kwinrc" --group "Effect-${effect}" --key Enabled true 2>/dev/null || true
    done

    success "Window effects configured."
}

# ─── Font Configuration ─────────────────────────────────────────────────────
configure_fonts() {
    info "Configuring system fonts..."

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] Would configure fonts"
        return 0
    fi

    local fontconfig_dir="$HOME/.config/fontconfig"
    mkdir -p "$fontconfig_dir"

    # Relying on package-manager provided inter-font package

    # Fontconfig: Set Inter as primary
    cat > "$fontconfig_dir/fonts.conf" << FONTCONF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <alias>
        <family>sans-serif</family>
        <prefer>
            <family>${FONT_FAMILY}</family>
            <family>Noto Sans</family>
            <family>DejaVu Sans</family>
        </prefer>
    </alias>
    <alias>
        <family>serif</family>
        <prefer>
            <family>Noto Serif</family>
            <family>DejaVu Serif</family>
        </prefer>
    </alias>
    <alias>
        <family>monospace</family>
        <prefer>
            <family>JetBrains Mono</family>
            <family>DejaVu Sans Mono</family>
        </prefer>
    </alias>
    <match target="font">
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
        <edit name="rgba" mode="assign"><const>rgb</const></edit>
    </match>
</fontconfig>
FONTCONF

    # KDE font settings
    "$KWRITECONFIG" --file kdeglobals --group General --key font "${FONT_FAMILY},10,-1,0,400,0,0,0,0,0"
    "$KWRITECONFIG" --file kdeglobals --group General --key fixed "${FONT_FAMILY},10,-1,0,400,0,0,0,0,0"
    "$KWRITECONFIG" --file kdeglobals --group General --key menuFont "${FONT_FAMILY},10,-1,0,400,0,0,0,0,0"
    "$KWRITECONFIG" --file kdeglobals --group General --key toolBarFont "${FONT_FAMILY},10,-1,0,400,0,0,0,0,0"

    fc-cache -f 2>/dev/null || true

    success "Font configuration complete."
}

# ─── Theme Configuration ────────────────────────────────────────────────────
configure_theme() {
    info "Configuring macOS-like theme..."

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] Would configure theme"
        return 0
    fi

    # Global theme
    "$KWRITECONFIG" --file kdeglobals --group General --key ColorScheme "BreezeDark"
    "$KWRITECONFIG" --file kdeglobals --group General --key widgetStyle "Breeze"

    # Window decoration
    "$KWRITECONFIG" --file kwinrc --group org.kde.kdecoration --key Theme "Breeze"

    # Kvantum theme
    local kvantum_dir="$HOME/.config/Kvantum"
    mkdir -p "$kvantum_dir"
    cat > "$kvantum_dir/Kvantum.conf" << 'EOF'
[General]
theme=Breeze-Dark
EOF

    # Konsole profile
    local konsole_dir="$HOME/.local/share/konsole"
    mkdir -p "$konsole_dir"

    # Detect the best available monospaced font (SF Mono vs JetBrains Mono)
    local terminal_font="JetBrains Mono"
    if fc-list : family | grep -qi "SF Mono"; then
        terminal_font="SF Mono"
    elif fc-list : family | grep -qi "SFMono"; then
        terminal_font="SFMono-Regular"
    fi

    cat > "$konsole_dir/Conjunction.profile" << EOF
[General]
Name=Conjunction
Parent=FALLBACK/

[Appearance]
ColorScheme=BreezeDark
Font=${terminal_font},11,-1,5,50,0,0,0,0,0

[Scrolling]
HistoryMode=2
EOF

    # Dolphin settings (file manager)
    "$KWRITECONFIG" --file dolphinrc --group General --key ShowFullPath true
    "$KWRITECONFIG" --file dolphinrc --group General --key ShowMenuBar false
    "$KWRITECONFIG" --file dolphinrc --group DetailsMode --key SortDescending true

    # System Settings defaults
    "$KWRITECONFIG" --file kdeglobals --group KDE --key AnimationDurationFactor 0.5

    success "Theme configuration complete."
}

# ─── macOS-like Keyboard Shortcuts ──────────────────────────────────────────
configure_shortcuts() {
    info "Configuring macOS-like keyboard shortcuts..."

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] Would configure shortcuts"
        return 0
    fi

    local kwinrc="$HOME/.config/kwinrc"
    local kcminputrc="$HOME/.config/kcminputrc"

    # Window management shortcuts (macOS-style)
    "$KWRITECONFIG" --file "$kwinrc" --group "Script-switch-one-desktop-up" --key "Default" "Meta+Up"
    "$KWRITECONFIG" --file "$kwinrc" --group "Script-switch-one-desktop-down" --key "Default" "Meta+Down"
    "$KWRITECONFIG" --file "$kwinrc" --group "Script-switch-one-desktop-left" --key "Default" "Meta+Left"
    "$KWRITECONFIG" --file "$kwinrc" --group "Script-switch-one-desktop-right" --key "Default" "Meta+Right"

    # Mission Control (Overview)
    "$KWRITECONFIG" --file "$kwinrc" --group "Overview" --key "Toggle" "Meta+W"

    # Spotlight (KRunner)
    "$KWRITECONFIG" --file "$kwinrc" --group "KRunner" --key "Run" "Alt+Space"

    success "Keyboard shortcuts configured."
}

# ─── Create macOS-like Aliases ──────────────────────────────────────────────
create_aliases() {
    info "Creating macOS-like shell aliases..."

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] Would create aliases"
        return 0
    fi

    local alias_file="$HOME/.bash_aliases"
    cat > "$alias_file" << 'ALIASES'
# Conjunction OS - macOS-like aliases

# Navigation (macOS-style)
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ~="cd ~"
alias -- -="cd -"

# Listing (macOS-style ls)
alias ls="ls --color=auto --group-directories-first"
alias ll="ls -lah"
alias la="ls -A"
alias l="ls -CF"
alias lsd="ls -d */"

# File operations (macOS-like)
alias cp="cp -iv"
alias mv="mv -iv"
alias rm="rm -i"
alias mkdir="mkdir -pv"

# Grep with color
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"

# History
alias h="history"
alias hg="history | grep"
alias history="history 1"

# Quick edit
alias vi="vim"
alias nano="nano -x"

# Git shortcuts
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git log"
alias gd="git diff"
alias gb="git branch"
alias gco="git checkout"

# System shortcuts
alias df="df -h"
alias du="du -h"
alias free="free -m"
alias top="htop 2>/dev/null || top"

# Conjunction OS shortcuts
alias cj="python3 /opt/conjunction/cli.py"
alias cj-update="cj update"
alias cj-install="cj install"
alias cj-optimize="cj optimize"
ALIASES

    # Source in .bashrc if not already sourced
    if [[ -f "$HOME/.bashrc" ]]; then
        if ! grep -q ".bash_aliases" "$HOME/.bashrc" 2>/dev/null; then
            echo "" >> "$HOME/.bashrc"
            echo "# Load Conjunction OS aliases" >> "$HOME/.bashrc"
            echo "[ -f ~/.bash_aliases ] && . ~/.bash_aliases" >> "$HOME/.bashrc"
        fi
    fi

    success "Shell aliases created."
}

# ─── Create macOS-like Functions ────────────────────────────────────────────
create_functions() {
    info "Creating macOS-like shell functions..."

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] Would create functions"
        return 0
    fi

    local func_file="$HOME/.bash_functions"
    cat > "$func_file" << 'FUNCTIONS'
# Conjunction OS - macOS-like functions

# Open file with default application (like macOS 'open')
open() {
    if [[ -z "$1" ]]; then
        echo "Usage: open <file|url>"
        return 1
    fi

    if [[ "$1" =~ ^https?:// ]]; then
        xdg-open "$1" 2>/dev/null &
    elif [[ -f "$1" ]]; then
        xdg-open "$1" 2>/dev/null &
    elif [[ -d "$1" ]]; then
        dolphin "$1" 2>/dev/null &
    else
        echo "File not found: $1"
        return 1
    fi
}

# Quick file preview (like macOS Quick Look)
ql() {
    if [[ -z "$1" ]]; then
        echo "Usage: ql <file>"
        return 1
    fi

    if [[ -f "$1" ]]; then
        if command -v okular &>/dev/null; then
            okular "$1" 2>/dev/null &
        elif command -v eog &>/dev/null; then
            eog "$1" 2>/dev/null &
        else
            xdg-open "$1" 2>/dev/null &
        fi
    else
        echo "File not found: $1"
        return 1
    fi
}

# Copy to clipboard (like macOS pbcopy)
pbcopy() {
    if command -v wl-copy &>/dev/null; then
        if [[ -z "${1:-}" ]]; then
            wl-copy
        else
            echo -n "$1" | wl-copy
        fi
    else
        if [[ -z "${1:-}" ]]; then
            xclip -selection clipboard 2>/dev/null || xsel --clipboard 2>/dev/null
        else
            echo -n "$1" | xclip -selection clipboard 2>/dev/null || echo -n "$1" | xsel --clipboard 2>/dev/null
        fi
    fi
}

# Paste from clipboard (like macOS pbpaste)
pbpaste() {
    if command -v wl-paste &>/dev/null; then
        wl-paste
    else
        xclip -selection clipboard -o 2>/dev/null || xsel --clipboard 2>/dev/null
    fi
}

# Show file type (like macOS file)
filetype() {
    if [[ -z "$1" ]]; then
        echo "Usage: filetype <file>"
        return 1
    fi
    file --brief "$1"
}

# Quick backup (like Time Machine concept)
backup() {
    if [[ -z "$1" ]]; then
        echo "Usage: backup <file>"
        return 1
    fi

    if [[ -f "$1" ]]; then
        cp "$1" "$1.bak.$(date +%Y%m%d_%H%M%S)"
        echo "Backed up: $1"
    else
        echo "File not found: $1"
        return 1
    fi
}

# Extract any archive
extract() {
    if [[ -z "$1" ]]; then
        echo "Usage: extract <archive>"
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        echo "File not found: $1"
        return 1
    fi

    case "$1" in
        *.tar.bz2) tar xjf "$1" ;;
        *.tar.gz)  tar xzf "$1" ;;
        *.tar.xz)  tar xJf "$1" ;;
        *.bz2)     bunzip2 "$1" ;;
        *.rar)     unrar x "$1" ;;
        *.gz)      gunzip "$1" ;;
        *.tar)     tar xf "$1" ;;
        *.tbz2)    tar xjf "$1" ;;
        *.tgz)     tar xzf "$1" ;;
        *.zip)     unzip "$1" ;;
        *.Z)       uncompress "$1" ;;
        *.7z)      7z x "$1" ;;
        *)         echo "Unknown archive format: $1" ;;
    esac
}

# Weather (simple)
weather() {
    curl -s "wttr.in/${1:-}" 2>/dev/null || echo "Could not fetch weather"
}

# Matrix rain effect
matrix() {
    echo -e "\e[32m"
    while true; do
        echo -n $(( RANDOM % 2 ))
        sleep 0.02
    done
}
FUNCTIONS

    # Source in .bashrc if not already sourced
    if [[ -f "$HOME/.bashrc" ]]; then
        if ! grep -q ".bash_functions" "$HOME/.bashrc" 2>/dev/null; then
            echo "" >> "$HOME/.bashrc"
            echo "# Load Conjunction OS functions" >> "$HOME/.bashrc"
            echo "[ -f ~/.bash_functions ] && . ~/.bash_functions" >> "$HOME/.bashrc"
        fi
    fi

    success "Shell functions created."
}

# ─── Finalize ───────────────────────────────────────────────────────────────
finalize() {
    info "Finalizing setup..."

    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY RUN] Would finalize setup"
        return 0
    fi

    # Reload KDE
    if [[ -n "$QDBUS_CMD" ]]; then
        "$QDBUS_CMD" org.kde.KWin /KWin reconfigure 2>/dev/null || true
        "$QDBUS_CMD" org.kde.plasmashell /PlasmaShell refreshCurrentConfiguration 2>/dev/null || true
    fi

    # Restore ownership of config files to the target user
    if [[ "${TARGET_USER}" != "root" ]]; then
        info "Restoring file ownership for ${TARGET_USER}..."
        chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}/.config" "${USER_HOME}/.local" "${USER_HOME}/.bash_aliases" "${USER_HOME}/.bash_functions" 2>/dev/null || true
        if [[ -f "${USER_HOME}/.bashrc" ]]; then
            chown "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}/.bashrc"
        fi
    fi

    echo ""
    success "Setup complete! Please log out and back in for all changes."
    echo ""
    info "Configuration summary:"
    info "  - macOS-style top panel with global menu"
    info "  - Bottom dock with centered icons"
    info "  - Window effects: blur, rounded corners ($CORNER_RADIUS px), shadows"
    info "  - Font: ${FONT_FAMILY} family"
    info "  - Theme: Breeze Dark"
    info "  - macOS-like shell aliases and functions"
    echo ""
    info "Log file: $LOG_FILE"
}

# ─── Main ───────────────────────────────────────────────────────────────────
main() {
    echo -e "${CYAN}"
    echo "  ____ ___  _   _    _ _   _ _   _  ____ _____ ___ ___  _   _    ___  ____  "
    echo " / ___/ _ \| \ | |  | | | | | \ | |/ ___|_   _|_ _/ _ \| \ | |  / _ \/ ___| "
    echo "| |  | | | |  \| |  | | | | |  \| | |     | |  | | | | |  \| | | | | \___ \ "
    echo "| |__| |_| | |\  |__| | |_| | |\  | |___  | |  | | |_| | |\  | | |_| |___) |"
    echo " \____\___/|_| \_(_)___\___/|_| \_|\____| |_| |___\___/|_| \_|  \___/|____/ "
    echo -e "                   UI & Desktop Configurator${NC}\n"

    [[ "$DRY_RUN" == true ]] && warn "DRY RUN mode - no changes will be made"
    echo ""

    preflight
    if [[ "$SKIP_PACKAGES" == "false" ]]; then
        install_packages
    else
        info "Skipping package installation step (pre-installed)..."
        # Ensure helper variables are updated
        KWRITECONFIG="$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)"
        QDBUS_CMD="$(command -v qdbus6 || command -v qdbus || true)"
        if [[ -z "$KWRITECONFIG" && "$DRY_RUN" != true ]]; then
            err "kwriteconfig5 or kwriteconfig6 is required but not found in the path."
            exit 1
        fi
    fi
    configure_panel
    configure_window_effects
    configure_fonts
    configure_theme
    configure_shortcuts
    create_aliases
    create_functions
    finalize
}

main "$@"
