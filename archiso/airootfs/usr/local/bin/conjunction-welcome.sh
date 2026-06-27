#!/usr/bin/env bash
# conjunction-welcome.sh - Welcome application for Conjunction OS using kdialog

while true; do
    CHOICE=$(kdialog --clear \
                     --title "Welcome to Conjunction OS" \
                     --menu "Welcome! What would you like to do?" \
                     install "Start Conjunction OS Installer" \
                     docs "Read Documentation / Wiki" \
                     diag "Run System Diagnostics" \
                     update "Check/Perform System Update" \
                     hw "Show Hardware Summary" \
                     exit "Exit" 2>/dev/null)

    # If cancel or exit is chosen, break
    if [ $? -ne 0 ] || [ "$CHOICE" = "exit" ] || [ -z "$CHOICE" ]; then
        break
    fi

    case "$CHOICE" in
        install)
            # Run the installer in konsole with sudo
            konsole -e sudo /usr/local/bin/conjunction-installer.sh &
            break
            ;;
        docs)
            # Open documentation
            xdg-open "https://archlinux.org" &
            ;;
        diag)
            # Diagnostics check
            DIAG_TEXT=""
            # Network check
            if ping -c 1 -W 2 archlinux.org &>/dev/null; then
                DIAG_TEXT+="[CONNECTED] Internet connection is active.\n"
            else
                DIAG_TEXT+="[DISCONNECTED] No internet connection detected.\n"
            fi
            # Memory check
            MEM_FREE=$(free -h | awk '/^Mem:/ {print $4}')
            DIAG_TEXT+="[MEMORY] Free Memory: $MEM_FREE\n"
            # Disk space check
            DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
            DIAG_TEXT+="[DISK] Live root free space: $DISK_FREE\n"
            # EFI check
            if [ -d /sys/firmware/efi ]; then
                DIAG_TEXT+="[BOOT MODE] UEFI mode detected.\n"
            else
                DIAG_TEXT+="[BOOT MODE] Legacy BIOS mode detected.\n"
            fi
            kdialog --title "System Diagnostics" --msgbox "$(echo -e "$DIAG_TEXT")"
            ;;
        update)
            # Run update in konsole
            konsole -e cj update &
            ;;
        hw)
            # Hardware Summary
            if command -v fastfetch &>/dev/null; then
                # Run fastfetch and capture output
                HW_TEXT=$(fastfetch --stdout 2>/dev/null)
            else
                # Fallback to standard commands
                HW_TEXT="CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)\n"
                HW_TEXT+="Memory: $(free -h | awk '/^Mem:/ {print $2}')\n"
                HW_TEXT+="GPU: $(lspci | grep -i vga | cut -d: -f3 | xargs)\n"
            fi
            kdialog --title "Hardware Summary" --msgbox "$(echo -e "$HW_TEXT")"
            ;;
    esac
done
