#[cfg(unix)]
mod unix_tests {
    use conjunction_core::ipc::send_appd_request_to_path;
    use conjunction_core::AppdRequest;
    use std::fs;
    use std::os::unix::fs::PermissionsExt;
    use std::path::PathBuf;
    use std::process::{Child, Command, Stdio};
    use std::time::{Duration, Instant};

    struct DaemonEnv {
        root: PathBuf,
        user_apps: PathBuf,
        xdg_dir: PathBuf,
        home: PathBuf,
        sock: PathBuf,
        child: Option<Child>,
    }

    impl DaemonEnv {
        fn start(name: &str) -> Self {
            let unique = format!(
                "cd_{}_{}",
                std::process::id(),
                name.chars().take(4).collect::<String>(),
            );
            let root = std::env::temp_dir().join(unique);
            let _ = fs::remove_dir_all(&root);
            let home = root.join("h");
            let user_apps = home.join("Applications");
            let sys_apps = root.join("sys");
            let xdg_dir = root.join("xdg");
            let cfg_dir = root.join("cfg");
            let state_dir = root.join("st");
            let sock = root.join("a.sock");

            fs::create_dir_all(&user_apps).unwrap();
            fs::create_dir_all(&sys_apps).unwrap();
            fs::create_dir_all(&xdg_dir).unwrap();
            fs::create_dir_all(&cfg_dir).unwrap();
            fs::create_dir_all(&state_dir).unwrap();

            let bin = env!("CARGO_BIN_EXE_conj-appd");
            let mut child = Command::new(bin)
                .arg("--socket")
                .arg(&sock)
                .env("HOME", &home)
                .env("XDG_DATA_HOME", root.join("dh"))
                .env("XDG_CONFIG_HOME", &cfg_dir)
                .env("XDG_STATE_HOME", &state_dir)
                .env("CONJUNCTION_USER_APPS_DIR", &user_apps)
                .env("CONJUNCTION_SYSTEM_APPS_DIR", &sys_apps)
                .env("CONJUNCTION_XDG_DIR", &xdg_dir)
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .spawn()
                .expect("spawn conj-appd");

            // Wait until socket accepts Ping
            let deadline = Instant::now() + Duration::from_secs(5);
            while Instant::now() < deadline {
                if let Ok(Some(status)) = child.try_wait() {
                    let out = child.wait_with_output().unwrap();
                    panic!(
                        "conj-appd exited early with {}: stdout={} stderr={}",
                        status,
                        String::from_utf8_lossy(&out.stdout),
                        String::from_utf8_lossy(&out.stderr)
                    );
                }
                if sock.exists() && send_appd_request_to_path(&sock, &AppdRequest::Ping).is_ok() {
                    break;
                }
                std::thread::sleep(Duration::from_millis(25));
            }
            if let Err(e) = send_appd_request_to_path(&sock, &AppdRequest::Ping) {
                let _ = child.kill();
                let out = child.wait_with_output().unwrap();
                panic!(
                    "conj-appd failed to start listening on {} ({}): stdout={} stderr={}",
                    sock.display(),
                    e,
                    String::from_utf8_lossy(&out.stdout),
                    String::from_utf8_lossy(&out.stderr)
                );
            }

            Self {
                root,
                user_apps,
                xdg_dir,
                home,
                sock,
                child: Some(child),
            }
        }
    }

    impl Drop for DaemonEnv {
        fn drop(&mut self) {
            if let Some(ref mut c) = self.child {
                let _ = c.kill();
                let _ = c.wait();
            }
            let _ = fs::remove_dir_all(&self.root);
        }
    }

    #[test]
    fn test_appd_live_drop_and_delete_lifecycle_with_leftovers() {
        let env = DaemonEnv::start("lifecycle");

        // 1. Drop a bundle into user_apps without manually calling Reconcile
        let bundle = env.user_apps.join("LiveDrop.app");
        fs::create_dir_all(bundle.join("Contents/MacOS")).unwrap();
        fs::create_dir_all(bundle.join("Contents/Resources")).unwrap();
        let exec_path = bundle.join("Contents/MacOS/livedrop");
        fs::write(&exec_path, "#!/bin/sh\necho live\n").unwrap();
        fs::set_permissions(&exec_path, fs::Permissions::from_mode(0o755)).unwrap();
        fs::write(
            bundle.join("Contents/Resources/icon.svg"),
            "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 16 16\"/>",
        )
        .unwrap();
        let manifest = r#"bundle_format = "conjunction.app/2"
id = "org.example.livedrop"
name = "LiveDrop"
version = "1.2.3"
executable = "Contents/MacOS/livedrop"
icon = "Contents/Resources/icon.svg"
architectures = ["x86_64", "aarch64"]
runtime = "conjunction-1"
url_schemes = ["liveapp"]

[[document_types]]
name = "LiveDrop File"
mime_types = ["application/x-livedrop"]
extensions = ["ldrop"]
"#;
        fs::write(bundle.join("Contents/Info.toml"), manifest).unwrap();

        let desktop_file = env.xdg_dir.join("applications/conj-org.example.livedrop.desktop");
        let icon_file = env
            .xdg_dir
            .join("icons/hicolor/scalable/apps/conj-org.example.livedrop.svg");
        let mime_xml = env
            .xdg_dir
            .join("mime/packages/conj-org.example.livedrop.xml");

        let deadline = Instant::now() + Duration::from_secs(3);
        while !(desktop_file.exists() && icon_file.exists() && mime_xml.exists())
            && Instant::now() < deadline
        {
            std::thread::sleep(Duration::from_millis(40));
        }

        assert!(desktop_file.exists(), "desktop entry not generated automatically");
        assert!(icon_file.exists(), "icon not installed automatically");
        assert!(mime_xml.exists(), "MIME XML not generated automatically");

        let desktop_txt = fs::read_to_string(&desktop_file).unwrap();
        assert!(desktop_txt.contains("x-scheme-handler/liveapp"));
        assert!(desktop_txt.contains("application/x-livedrop"));

        // Simulate app cache + user Documents
        let cache_dir = env.home.join(".cache/org.example.livedrop");
        fs::create_dir_all(&cache_dir).unwrap();
        fs::write(cache_dir.join("state.bin"), b"cached").unwrap();

        let docs_dir = env.home.join("Documents");
        fs::create_dir_all(&docs_dir).unwrap();
        let user_doc = docs_dir.join("important.ldrop");
        fs::write(&user_doc, "keep me").unwrap();

        // 2. Delete the bundle -> daemon removes generated XDG registrations automatically and records leftovers
        fs::remove_dir_all(&bundle).unwrap();

        let deadline = Instant::now() + Duration::from_secs(3);
        while (desktop_file.exists() || icon_file.exists() || mime_xml.exists())
            && Instant::now() < deadline
        {
            std::thread::sleep(Duration::from_millis(40));
        }
        assert!(!desktop_file.exists(), "desktop entry should be removed");
        assert!(!icon_file.exists(), "icon should be removed");
        assert!(!mime_xml.exists(), "MIME XML should be removed");
        assert!(user_doc.exists(), "user document must never be deleted");

        // Verify IPC ListLeftovers & PurgeLeftovers
        let lo = send_appd_request_to_path(&env.sock, &AppdRequest::ListLeftovers).unwrap();
        assert!(lo.success);
        let lo_str = lo.data.unwrap().to_string();
        assert!(lo_str.contains("org.example.livedrop"), "leftovers={}", lo_str);

        let purge = send_appd_request_to_path(
            &env.sock,
            &AppdRequest::PurgeLeftovers {
                id: "org.example.livedrop".to_string(),
            },
        )
        .unwrap();
        assert!(purge.success);
        assert!(!cache_dir.exists(), "leftover cache should be purged");
        assert!(user_doc.exists(), "user document must still exist after purge");
    }
}
