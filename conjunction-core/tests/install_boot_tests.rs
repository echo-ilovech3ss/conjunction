use conjunction_core::boot::{OsRelease, WaylandSessionEntry};
use std::path::Path;

#[test]
fn test_os_release_identity() {
    let repo_root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let usr_os_release = repo_root.join("os/files/usr/lib/os-release");

    assert!(
        usr_os_release.exists(),
        "os/files/usr/lib/os-release must exist"
    );

    let content = std::fs::read_to_string(&usr_os_release).unwrap();
    let os = OsRelease::parse(&content);

    assert_eq!(os.name, "Conjunction");
    assert_eq!(os.pretty_name, "Conjunction Linux 45");
    assert_eq!(os.id, "conjunction");
    assert_eq!(os.id_like, "fedora");
    assert_eq!(os.raw.get("VERSION_ID").map(String::as_str), Some("45"));
    assert_eq!(os.raw.get("LOGO").map(String::as_str), Some("conjunction"));
    assert_eq!(
        os.raw.get("VARIANT_ID").map(String::as_str),
        Some("conjunction")
    );
}

#[test]
fn test_fedora_bootc_containerfiles_present() {
    let repo_root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let containerfile = repo_root.join("os/Containerfile");
    let nvidia_containerfile = repo_root.join("os/Containerfile.nvidia");

    assert!(containerfile.exists(), "os/Containerfile must exist");
    assert!(
        nvidia_containerfile.exists(),
        "os/Containerfile.nvidia must exist"
    );

    let cf = std::fs::read_to_string(&containerfile).unwrap();
    assert!(cf.contains("quay.io/fedora/fedora-kinoite:45"));
    assert!(cf.contains("bootc container lint"));
    assert!(cf.contains("ln -sfn var/Applications /Applications"));
    assert!(cf.contains("conj-appd"));
    assert!(cf.contains("conj-open"));
    assert!(cf.contains("conj-bundle"));
    assert!(cf.contains("conj-appctl"));
    assert!(cf.contains("conj-sysd"));
    assert!(cf.contains("data/dolphin-plugin"));
    assert!(cf.contains("flathub.flatpakrepo"));
    assert!(cf.contains("umu-launcher"));
    assert!(cf.contains("fex-emu"));
    assert!(cf.contains("box64"));

    let nv = std::fs::read_to_string(&nvidia_containerfile).unwrap();
    assert!(nv.contains("x86_64"));
    assert!(nv.contains("akmod-nvidia"));
    assert!(nv.contains("05-nvidia.toml"));
    assert!(nv.contains("bootc container lint"));
}

#[test]
fn test_iso_config_and_nvidia_kargs_contract() {
    let repo_root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let iso_cfg = repo_root.join("os/iso-config.toml");
    let kargs = repo_root.join("os/nvidia/usr/lib/bootc/kargs.d/05-nvidia.toml");

    assert!(iso_cfg.exists(), "os/iso-config.toml must exist");
    assert!(kargs.exists(), "05-nvidia.toml must exist");

    let iso_str = std::fs::read_to_string(&iso_cfg).unwrap();
    assert!(iso_str.contains("[customizations.installer.kickstart]"));

    let kargs_str = std::fs::read_to_string(&kargs).unwrap();
    assert!(kargs_str.contains("rd.driver.blacklist=nouveau"));
    assert!(kargs_str.contains("nvidia-drm.modeset=1"));
}

#[test]
fn test_fedora_overlays_and_bundle_integration() {
    let repo_root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();

    for rel in [
        "os/files/usr/lib/systemd/system/conj-sysd.service",
        "os/files/usr/lib/tmpfiles.d/conjunction-terminal-app.conf",
        "os/files/usr/lib/environment.d/65-conjunction-windows.conf",
        "os/files/etc/fonts/local.conf",
        "os/files/etc/gtk-3.0/settings.ini",
        "os/files/etc/gtk-4.0/settings.ini",
        "os/files/etc/xdg/kdeglobals",
        "os/ASSETS-LICENSES.md",
        "data/tmpfiles.d/conjunction-apps.conf",
        "data/environment.d/60-conjunction-apps.conf",
        "data/plasma-env/conjunction-apps.sh",
        "data/mime/packages/conjunction-bundles.xml",
        "data/polkit-1/rules.d/50-conjunction-cdmg.rules",
        "data/dolphin-plugin/CMakeLists.txt",
        "engine.py",
        "cli.py",
    ] {
        assert!(repo_root.join(rel).exists(), "{rel} must exist");
    }

    let sysd_unit =
        std::fs::read_to_string(repo_root.join("os/files/usr/lib/systemd/system/conj-sysd.service"))
            .unwrap();
    assert!(sysd_unit.contains("ExecStart=/usr/bin/conj-sysd"));
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
