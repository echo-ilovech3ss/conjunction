#!/usr/bin/env bash
set -euo pipefail
[[ -f /etc/archiso-release ]] || exit 0
[[ -n ${XDG_RUNTIME_DIR:-} ]] || exit 1
for ((attempt=0; attempt<120; attempt++)); do
    if pgrep -u "$(id -u)" -x plasmashell >/dev/null &&
       [[ -f "$XDG_RUNTIME_DIR/conjunction-welcome.ready" ]] &&
       systemctl is-active --quiet sddm.service NetworkManager.service; then
        sudo -n /bin/sh -c 'test ! -c /dev/ttyS0 || echo "SMOKE_TEST_OK: boot=1 sddm=1 networkmanager=1 plasma=1 welcome=1" > /dev/ttyS0'
        exit 0
    fi
    sleep 2
done
echo "Conjunction desktop did not become ready" >&2
exit 1
