use conjunction_core::boot::{BtrfsLayoutContract, OsRelease, UkiConfig, WaylandSessionEntry};
use std::path::Path;

#[test]
fn test_os_release_identity() {
    let repo_root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let etc_os_release = repo_root.join("archiso/airootfs/etc/os-release");
    let usr_os_release = repo_root.join("archiso/airootfs/usr/lib/os-release");

    assert!(etc_os_release.exists(), "etc/os-release must exist");
    assert!(usr_os_release.exists(), "usr/lib/os-release must exist");

    let content = std::fs::read_to_string(&etc_os_release).unwrap();
    let os = OsRelease::parse(&content);

    assert_eq!(os.name, "Conjunction");
    assert_eq!(os.pretty_name, "Conjunction Linux");
    assert_eq!(os.id, "conjunction");
    assert_eq!(os.id_like, "arch");
    assert_eq!(os.build_id, "rolling");
    assert!(os.is_conjunction());

    // Verify usr/lib/os-release matches
    let usr_content = std::fs::read_to_string(&usr_os_release).unwrap();
    let usr_os = OsRelease::parse(&usr_content);
    assert_eq!(os, usr_os);
}

#[test]
fn test_wayland_session_contract() {
    let repo_root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let desktop_path = repo_root.join("data/conjunction.desktop");
    assert!(desktop_path.exists(), "data/conjunction.desktop must exist");

    let content = std::fs::read_to_string(&desktop_path).unwrap();
    let entry = WaylandSessionEntry::parse(&content).expect("Valid desktop entry format");

    assert_eq!(entry.name, "Conjunction");
    assert_eq!(entry.entry_type, "Application");
    assert_eq!(entry.exec, "/usr/bin/conjunction-session");
    assert!(entry.desktop_names.contains(&"Conjunction".to_string()));
    assert!(entry.desktop_names.contains(&"KDE".to_string()));
    assert!(entry.is_valid_conjunction_session());

    // Also check session launcher script exists
    let session_sh = repo_root.join("data/conjunction-session");
    assert!(session_sh.exists(), "conjunction-session script must exist");
    let sh_content = std::fs::read_to_string(&session_sh).unwrap();
    assert!(sh_content.contains("XDG_CURRENT_DESKTOP=Conjunction"));
    assert!(sh_content.contains("kwin_wayland"));
}

#[test]
fn test_btrfs_subvolumes_contract() {
    let layout = BtrfsLayoutContract::default_conjunction();

    assert!(layout.has_mount_point("/"));
    assert_eq!(layout.get_subvolume_for_mount("/"), Some("/@"));

    assert!(layout.has_mount_point("/home"));
    assert_eq!(layout.get_subvolume_for_mount("/home"), Some("/@home"));

    assert!(layout.has_mount_point("/var/log"));
    assert_eq!(layout.get_subvolume_for_mount("/var/log"), Some("/@var_log"));

    assert!(layout.has_mount_point("/var/cache/pacman/pkg"));
    assert_eq!(
        layout.get_subvolume_for_mount("/var/cache/pacman/pkg"),
        Some("/@pkg")
    );

    // Critical: user home data must be isolated from root subvolume for safe rollbacks
    assert!(layout.has_isolated_home_subvolume());
}

#[test]
fn test_calamares_mount_and_partition_btrfs_schema() {
    let repo_root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let mount_conf = repo_root.join("data/calamares/modules/mount.conf");
    let part_conf = repo_root.join("data/calamares/modules/partition.conf");

    assert!(mount_conf.exists(), "mount.conf must exist");
    assert!(part_conf.exists(), "partition.conf must exist");

    let mount_str = std::fs::read_to_string(&mount_conf).unwrap();
    assert!(mount_str.contains("subvolume: /@"));
    assert!(mount_str.contains("subvolume: /@home"));
    assert!(mount_str.contains("subvolume: /@var_log"));
    assert!(mount_str.contains("subvolume: /@pkg"));
    assert!(mount_str.contains("btrfsSwapSubvol: /@swap"));

    let part_str = std::fs::read_to_string(&part_conf).unwrap();
    assert!(part_str.contains("defaultFileSystemType: \"btrfs\""));
    assert!(part_str.contains("defaultPartitionTableType: gpt"));
    assert!(part_str.contains("efiSystemPartition: \"/boot/efi\""));
}

#[test]
fn test_calamares_bootloader_systemd_boot() {
    let repo_root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let boot_conf = repo_root.join("data/calamares/modules/bootloader.conf");
    assert!(boot_conf.exists(), "bootloader.conf must exist");

    let content = std::fs::read_to_string(&boot_conf).unwrap();
    assert!(content.contains("efiBootLoader: \"systemd-boot\""));
    assert!(content.contains("rootflags=subvol=@"));
    assert!(content.contains("kernelPattern: \"^vmlinuz.*\""));
}

#[test]
fn test_uki_preset_and_alpm_hook() {
    let repo_root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let preset_path = repo_root.join("data/mkinitcpio/linux.preset");
    let hook_path = repo_root.join("data/hooks/90-mkinitcpio-install.hook");

    assert!(preset_path.exists(), "linux.preset must exist");
    assert!(hook_path.exists(), "90-mkinitcpio-install.hook must exist");

    let preset_content = std::fs::read_to_string(&preset_path).unwrap();
    let uki = UkiConfig::parse_preset(&preset_content);

    assert!(uki.targets_systemd_boot_efi_linux());
    assert!(uki.specifies_btrfs_root_subvolume());
    assert_eq!(
        uki.default_uki.to_string_lossy(),
        "/boot/efi/EFI/Linux/conjunction-linux.efi"
    );

    let hook_content = std::fs::read_to_string(&hook_path).unwrap();
    assert!(hook_content.contains("Exec = /usr/bin/mkinitcpio -P"));
    assert!(hook_content.contains("Target = usr/lib/modules/*/vmlinuz"));
}

#[test]
fn test_sddm_conjunction_theme_contract() {
    let repo_root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let theme_dir = repo_root.join("data/sddm-theme/conjunction");

    let meta = theme_dir.join("metadata.desktop");
    let conf = theme_dir.join("theme.conf");
    let qml = theme_dir.join("Main.qml");

    assert!(meta.exists(), "SDDM metadata.desktop must exist");
    assert!(conf.exists(), "SDDM theme.conf must exist");
    assert!(qml.exists(), "SDDM Main.qml must exist");

    let meta_str = std::fs::read_to_string(&meta).unwrap();
    assert!(meta_str.contains("Theme-Id=conjunction"));
    assert!(meta_str.contains("MainScript=Main.qml"));

    let qml_str = std::fs::read_to_string(&qml).unwrap();
    assert!(qml_str.contains("sddm.login"));
    assert!(qml_str.contains("userModel"));
    assert!(qml_str.contains("sessionModel"));
    assert!(qml_str.contains("Conjunction Linux"));
}

#[test]
fn test_systemd_user_session_units_contract() {
    let repo_root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let units_dir = repo_root.join("data/systemd/user");

    let target = units_dir.join("conjunction-session.target");
    let appd = units_dir.join("conj-appd.service");
    let shelld = units_dir.join("conj-shelld.service");
    let notifd = units_dir.join("conj-notificationd.service");

    assert!(target.exists(), "conjunction-session.target must exist");
    assert!(appd.exists(), "conj-appd.service must exist");
    assert!(shelld.exists(), "conj-shelld.service must exist");
    assert!(notifd.exists(), "conj-notificationd.service must exist");

    let appd_str = std::fs::read_to_string(&appd).unwrap();
    assert!(appd_str.contains("PartOf=conjunction-session.target"));
    assert!(appd_str.contains("ExecStart=/usr/bin/conj-appd"));

    let shelld_str = std::fs::read_to_string(&shelld).unwrap();
    assert!(shelld_str.contains("PartOf=conjunction-session.target"));
    assert!(shelld_str.contains("ExecStart=/usr/bin/conj-shelld"));

    let notifd_str = std::fs::read_to_string(&notifd).unwrap();
    assert!(notifd_str.contains("PartOf=conjunction-session.target"));
    assert!(notifd_str.contains("ExecStart=/usr/bin/conj-notificationd"));
}
