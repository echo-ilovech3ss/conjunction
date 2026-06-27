#!/usr/bin/env bash
# profiledef.sh - Conjunction OS ISO Profile Definition
# Defines the ISO image properties for archiso

iso_name="conjunction"
iso_label="CONJUNCTION"
iso_publisher="Conjunction OS Project"
iso_application="Conjunction OS"
iso_version=$(date +%Y%m%d)
install_dir="conjunction"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')

file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/local/bin/conjunction-installer.sh"]="0:0:755"
  ["/usr/local/bin/conjunction-live-setup.sh"]="0:0:755"
  ["/usr/local/bin/conjunction-live-init.sh"]="0:0:755"
  ["/usr/local/bin/conjunction-init-check.sh"]="0:0:755"
  ["/usr/local/bin/conjunction-welcome.sh"]="0:0:755"
  ["/opt/conjunction/setup_conjunction_ui.sh"]="0:0:755"
  ["/opt/conjunction/cj"]="0:0:755"
  ["/opt/conjunction/application"]="0:0:755"
  ["/opt/conjunction/app_sync"]="0:0:755"
)
