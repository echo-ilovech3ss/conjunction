#!/usr/bin/env bash
# Run in the Linux builder after overlaying archiso/ on the releng profile.
set -euo pipefail
profile=${1:?Usage: prepare-live-profile.sh PROFILE}
root="$profile/airootfs"
test -f "$root/etc/systemd/system/conjunction-live-init.service"

# Presets are policy, not enablement. Package installation does not reliably
# apply them to units supplied by an airootfs overlay.
units="$root/etc/systemd/system"
mkdir -p "$units/multi-user.target.wants" "$units/sddm.service.d"
ln -sfn /usr/lib/systemd/system/graphical.target "$units/default.target"
ln -sfn /usr/lib/systemd/system/sddm.service "$units/display-manager.service"
ln -sfn /usr/lib/systemd/system/NetworkManager.service "$units/multi-user.target.wants/NetworkManager.service"
for unit in conjunction-live-init conjunction-setup; do
    ln -sfn "/etc/systemd/system/$unit.service" "$units/multi-user.target.wants/$unit.service"
done

# The releng rescue network configuration must not compete with NetworkManager.
for unit in systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service iwd.service; do
    ln -sfn /dev/null "$units/$unit"
done

# ─── Calamares Installer Integration ─────────────────────────────────────────
if [ -f /usr/bin/calamares ]; then
    mkdir -p "$root/usr/bin" "$root/usr/lib" "$root/usr/share"
    cp -a /usr/bin/calamares "$root/usr/bin/"
    cp -a /usr/lib/libcalamares* "$root/usr/lib/" 2>/dev/null || true
    if [ -d /usr/lib/calamares ]; then
        mkdir -p "$root/usr/lib/calamares"
        cp -a /usr/lib/calamares/* "$root/usr/lib/calamares/" 2>/dev/null || true
    fi
    if [ -d /usr/share/calamares ]; then
        mkdir -p "$root/usr/share/calamares"
        cp -a /usr/share/calamares/* "$root/usr/share/calamares/" 2>/dev/null || true
    fi
    if [ -f /usr/share/polkit-1/actions/io.calamares.calamares.policy ]; then
        mkdir -p "$root/usr/share/polkit-1/actions"
        cp -a /usr/share/polkit-1/actions/io.calamares.calamares.policy "$root/usr/share/polkit-1/actions/"
    fi
fi

# Overlay Conjunction Calamares configuration & branding
mkdir -p "$root/etc/calamares/modules" "$root/usr/share/calamares/branding/conjunction"
if [ -d /conjunction-repo/data/calamares ]; then
    cp -f /conjunction-repo/data/calamares/settings.conf "$root/etc/calamares/settings.conf" 2>/dev/null || true
    cp -rf /conjunction-repo/data/calamares/modules/* "$root/etc/calamares/modules/" 2>/dev/null || true
    cp -rf /conjunction-repo/data/calamares/branding/conjunction/* "$root/usr/share/calamares/branding/conjunction/" 2>/dev/null || true
fi
if [ -f "$root/opt/conjunction/assets/conjunction-logo.svg" ]; then
    cp -f "$root/opt/conjunction/assets/conjunction-logo.svg" "$root/usr/share/calamares/branding/conjunction/" 2>/dev/null || true
fi
if [ -f "$root/opt/conjunction/assets/conjunction-welcome.png" ]; then
    cp -f "$root/opt/conjunction/assets/conjunction-welcome.png" "$root/usr/share/calamares/branding/conjunction/welcome.png" 2>/dev/null || true
fi

# ─── SDDM Conjunction Theme ──────────────────────────────────────────────────
mkdir -p "$root/usr/share/sddm/themes/conjunction"
if [ -d /conjunction-repo/data/sddm-theme/conjunction ]; then
    cp -rf /conjunction-repo/data/sddm-theme/conjunction/* "$root/usr/share/sddm/themes/conjunction/" 2>/dev/null || true
fi
if [ -f "$root/opt/conjunction/assets/conjunction-logo.svg" ]; then
    cp -f "$root/opt/conjunction/assets/conjunction-logo.svg" "$root/usr/share/sddm/themes/conjunction/" 2>/dev/null || true
fi

# ─── Wayland Session & Init Scripts ──────────────────────────────────────────
mkdir -p "$root/usr/share/wayland-sessions" "$root/usr/bin"
if [ -f /conjunction-repo/data/conjunction.desktop ]; then
    cp -f /conjunction-repo/data/conjunction.desktop "$root/usr/share/wayland-sessions/"
fi
if [ -f /conjunction-repo/data/conjunction-session ]; then
    cp -f /conjunction-repo/data/conjunction-session "$root/usr/bin/"
    chmod 755 "$root/usr/bin/conjunction-session"
fi
if [ -f /conjunction-repo/data/conjunction-session-init ]; then
    cp -f /conjunction-repo/data/conjunction-session-init "$root/usr/bin/"
    chmod 755 "$root/usr/bin/conjunction-session-init"
fi
if [ -f /conjunction-repo/archiso/airootfs/usr/bin/conjunction-installer ]; then
    cp -f /conjunction-repo/archiso/airootfs/usr/bin/conjunction-installer "$root/usr/bin/"
    chmod 755 "$root/usr/bin/conjunction-installer"
fi

# ─── Systemd User Units ──────────────────────────────────────────────────────
mkdir -p "$root/usr/lib/systemd/user"
if [ -d /conjunction-repo/data/systemd/user ]; then
    cp -rf /conjunction-repo/data/systemd/user/* "$root/usr/lib/systemd/user/" 2>/dev/null || true
fi

# ─── UKI Preset & ALPM Hooks ─────────────────────────────────────────────────
mkdir -p "$root/etc/mkinitcpio.d" "$root/usr/share/libalpm/hooks"
if [ -f /conjunction-repo/data/mkinitcpio/linux.preset ]; then
    cp -f /conjunction-repo/data/mkinitcpio/linux.preset "$root/etc/mkinitcpio.d/"
fi
if [ -f /conjunction-repo/data/hooks/90-mkinitcpio-install.hook ]; then
    cp -f /conjunction-repo/data/hooks/90-mkinitcpio-install.hook "$root/usr/share/libalpm/hooks/"
fi

# NTFS checkouts can carry CRLF and lose executable bits.
while IFS= read -r -d '' file; do
    sed -i 's/\r$//' "$file"
done < <(find "$root" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.service' -o -name '*.target' -o -name '*.conf' -o -name '*.desktop' -o -name '*.desc' \) -print0)

find "$root/usr/local/bin" -type f -exec sed -i 's/\r$//' {} + 2>/dev/null || true
find "$root/usr/local/bin" -type f -exec chmod 755 {} + 2>/dev/null || true
find "$root/usr/bin" -type f -name "conjunction-*" -exec chmod 755 {} + 2>/dev/null || true

while IFS= read -r -d '' file; do
    bash -n "$file"
done < <(find "$root" -type f -name '*.sh' -print0)

python3 -m compileall -q "$root/opt/conjunction"
