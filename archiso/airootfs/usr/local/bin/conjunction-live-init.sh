#!/usr/bin/env bash
# conjunction-live-init.sh - Live environment user initialization

set -uo pipefail

setup_user() {
    local username="$1"
    
    # Create user
    if ! useradd -m -G wheel,video,audio,storage,optical,network,power,lp,users -s /bin/bash "$username"; then
        return 1
    fi
    passwd -d "$username" || true
    
    # Passwordless sudo configuration
    if ! cat > "/etc/sudoers.d/10-conjunction-live" <<EOF
${username} ALL=(ALL:ALL) NOPASSWD: ALL
EOF
    then
        return 1
    fi
    chmod 0440 "/etc/sudoers.d/10-conjunction-live" || true
    
    # Skel setup
    mkdir -p "/home/${username}/Desktop" || true
    cp -a /etc/skel/. "/home/${username}/" || true
    chown -R "${username}:${username}" "/home/${username}" || true
    chmod +x "/home/${username}/Desktop"/*.desktop 2>/dev/null || true
    return 0
}

main() {
    # If conjunction already exists, exit success
    if id "conjunction" &>/dev/null; then
        exit 0
    fi

    if setup_user "conjunction"; then
        echo "Successfully initialized user: conjunction"
    else
        echo "Failed to initialize user conjunction. Falling back to liveuser..."
        if setup_user "liveuser"; then
            mkdir -p /var/lib
            touch /var/lib/conjunction-init-failed
            # Update SDDM autologin user to liveuser
            if [ -f /etc/sddm.conf.d/conjunction.conf ]; then
                sed -i 's/User=conjunction/User=liveuser/' /etc/sddm.conf.d/conjunction.conf
            fi
            echo "Successfully fallback to user: liveuser"
        else
            echo "Critical: Failed to setup fallback user" >&2
            exit 1
        fi
    fi
}

main "$@"
