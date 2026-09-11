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

# NTFS checkouts can carry CRLF and lose executable bits.
while IFS= read -r -d '' file; do
    sed -i 's/\r$//' "$file"
done < <(find "$root" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.service' -o -name '*.conf' -o -name '*.desktop' \) -print0)
find "$root/usr/local/bin" -type f -exec sed -i 's/\r$//' {} +
find "$root/usr/local/bin" -type f -exec chmod 755 {} +
while IFS= read -r -d '' file; do
    bash -n "$file"
done < <(find "$root" -type f -name '*.sh' -print0)
python3 -m compileall -q "$root/opt/conjunction"
