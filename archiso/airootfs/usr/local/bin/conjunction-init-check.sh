#!/usr/bin/env bash
# conjunction-init-check.sh - Check if live system initialization failed

if [ -f /var/lib/conjunction-init-failed ]; then
    kdialog --title "Conjunction OS Live Initialization Warning" \
            --error "Live environment initialization failed.\n\nYou have been logged into a fallback user account ('liveuser'). Custom desktop preferences or configs might not have loaded correctly."
fi
