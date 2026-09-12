use conjunction_core::bundle::CURRENT_BUNDLE_FORMAT;
use conjunction_core::registry::{AppRegistry, AppScope, RegistryError, RegistryItem};
use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};

struct TestEnv {
    root: PathBuf,
    user_apps: PathBuf,
    system_apps: PathBuf,
    state_dir: PathBuf,
    desktop_dir: PathBuf,
    config_dir: PathBuf,
}

impl TestEnv {
    fn new(name: &str) -> Self {
        let unique = format!("conj_reg_{}_{}", name, std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos());
        let root = std::env::temp_dir().join(unique);
        let user_apps = root.join("UserApplications");
        let system_apps = root.join("SystemApplications");
        let state_dir = root.join("state");
        let desktop_dir = root.join("desktop");
        let config_dir = root.join("config");

        fs::create_dir_all(&user_apps).unwrap();
        fs::create_dir_all(&system_apps).unwrap();
        fs::create_dir_all(&state_dir).unwrap();
        fs::create_dir_all(&desktop_dir).unwrap();
        fs::create_dir_all(&config_dir).unwrap();

        TestEnv {
            root,
            user_apps,
            system_apps,
            state_dir,
            desktop_dir,
            config_dir,
        }
    }

    fn create_registry(&self) -> AppRegistry {
        let app_dirs = vec![
            (self.user_apps.clone(), AppScope::User),
            (self.system_apps.clone(), AppScope::System),
        ];
        AppRegistry::new(
            app_dirs,
            self.state_dir.clone(),
            self.desktop_dir.clone(),
            self.config_dir.clone(),
        )
    }

    fn create_bundle(&self, parent: &Path, name: &str, id: &str, exec_name: &str) -> PathBuf {
        let bundle_dir = parent.join(format!("{}.app", name));
        let info_path = bundle_dir.join("Contents/Info.toml");
        let exec_path = bundle_dir.join(format!("Contents/Executable/{}", exec_name));

        let manifest = format!(
            r#"bundle_format = "{}"
id = "{}"
name = "{}"
version = "1.0.0"
executable = "Contents/Executable/{}"
architectures = ["x86_64"]
mime_types = ["application/x-hello"]
"#,
            CURRENT_BUNDLE_FORMAT, id, name, exec_name
        );

        fs::create_dir_all(info_path.parent().unwrap()).unwrap();
        fs::create_dir_all(exec_path.parent().unwrap()).unwrap();

        let mut f = File::create(&info_path).unwrap();
        f.write_all(manifest.as_bytes()).unwrap();

        let mut e = File::create(&exec_path).unwrap();
        e.write_all(b"#!/bin/sh\necho 'Hello from Conjunction'\n").unwrap();

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = fs::metadata(&exec_path).unwrap().permissions();
            perms.set_mode(0o755);
            fs::set_permissions(&exec_path, perms).unwrap();
        }

        bundle_dir
    }
}

impl Drop for TestEnv {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.root);
    }
}

#[test]
fn test_registry_install_discover_launch_lifecycle() {
    let env = TestEnv::new("lifecycle");
    let mut reg = env.create_registry();

    // 1. Create a bundle in a staging folder
    let stage = env.root.join("downloads");
    let bundle_path = env.create_bundle(&stage, "Hello", "dev.conjunction.test.hello", "hello");

    // 2. Install through registry
    let installed = reg.install(&bundle_path).expect("installation should succeed");
    assert_eq!(installed.id, "dev.conjunction.test.hello");
    assert_eq!(installed.name, "Hello");

    // 3. Verify it exists in user applications directory
    let expected_bundle = env.user_apps.join("Hello.app");
    assert!(expected_bundle.exists(), "bundle should be copied to user Applications");

    // 4. Verify desktop integration generated
    let dt_path = env.desktop_dir.join("conj-dev.conjunction.test.hello.desktop");
    assert!(dt_path.exists(), "desktop file should be synthesized");
    let dt_content = fs::read_to_string(&dt_path).unwrap();
    assert!(dt_content.contains("Name=Hello"));
    assert!(dt_content.contains("X-Conjunction-AppId=dev.conjunction.test.hello"));

    // 5. Verify MIME associations updated
    let mime_path = env.config_dir.join("mimeapps.list");
    assert!(mime_path.exists(), "mimeapps.list should exist");
    let mime_content = fs::read_to_string(&mime_path).unwrap();
    assert!(mime_content.contains("application/x-hello=conj-dev.conjunction.test.hello.desktop;"));

    // 6. Discover by ID
    let item = reg.inspect("dev.conjunction.test.hello").expect("inspect should find app");
    match item {
        RegistryItem::Active(app) => {
            assert_eq!(app.id, "dev.conjunction.test.hello");
        }
        RegistryItem::Conflict(_) => panic!("should not be conflict"),
    }

    // 7. Launch by ID
    let code = reg.launch("dev.conjunction.test.hello", &[]).expect("launch should succeed");
    assert_eq!(code, 0);

    // 8. Rename bundle in user Applications
    let renamed_bundle = env.user_apps.join("Renamed Hello.app");
    fs::rename(&expected_bundle, &renamed_bundle).unwrap();

    reg.reconcile().expect("reconcile should succeed after rename");
    let item_after_rename = reg.inspect("dev.conjunction.test.hello").expect("inspect should find renamed app");
    match item_after_rename {
        RegistryItem::Active(app) => {
            assert_eq!(app.id, "dev.conjunction.test.hello");
            assert!(app.bundle_path.ends_with("Renamed Hello.app"));
        }
        RegistryItem::Conflict(_) => panic!("should not be conflict"),
    }
    assert_eq!(reg.list().len(), 1, "no ghost entry after rename");

    // 9. Cache reconstruction: delete cache file, reconcile again
    let cache_file = env.state_dir.join("registry.json");
    if cache_file.exists() {
        fs::remove_file(&cache_file).unwrap();
    }
    let mut fresh_reg = env.create_registry();
    fresh_reg.reconcile().expect("fresh registry reconciliation should reconstruct from filesystem");
    assert_eq!(fresh_reg.list().len(), 1);

    // 10. Uninstall
    fresh_reg.uninstall("dev.conjunction.test.hello").expect("uninstall should succeed");
    assert!(!renamed_bundle.exists(), "bundle should be removed on uninstall");
    assert!(!dt_path.exists(), "desktop file should be removed on uninstall");

    let mime_after = fs::read_to_string(&mime_path).unwrap();
    assert!(!mime_after.contains("conj-dev.conjunction.test.hello.desktop"), "mime should be cleaned");

    assert!(fresh_reg.inspect("dev.conjunction.test.hello").is_err(), "should not be in registry");

    // 11. Reinstall
    let reinstalled = fresh_reg.install(&bundle_path).expect("reinstall should succeed cleanly");
    assert_eq!(reinstalled.id, "dev.conjunction.test.hello");
    assert!(expected_bundle.exists());
    assert!(dt_path.exists());
}

#[test]
fn test_duplicate_id_conflict_handling() {
    let env = TestEnv::new("conflicts");
    let mut reg = env.create_registry();

    // Create two bundles with different paths/names but same ID: org.example.conflict
    let _app1 = env.create_bundle(&env.user_apps, "Alpha", "org.example.conflict", "alpha");
    let app2 = env.create_bundle(&env.user_apps, "Beta", "org.example.conflict", "beta");

    reg.reconcile().expect("reconcile should handle conflict");

    // Both visible -> conflict reported
    let inspect_res = reg.inspect("org.example.conflict");
    match inspect_res {
        Ok(RegistryItem::Conflict(c)) => {
            assert_eq!(c.id, "org.example.conflict");
            assert_eq!(c.candidate_paths.len(), 2);
        }
        other => panic!("expected conflict, got {:?}", other),
    }

    // Launch by ID must fail with conflict
    let launch_res = reg.launch("org.example.conflict", &[]);
    match launch_res {
        Err(RegistryError::ConflictDetected { id, candidates }) => {
            assert_eq!(id, "org.example.conflict");
            assert_eq!(candidates.len(), 2);
        }
        other => panic!("expected ConflictDetected error, got {:?}", other),
    }

    // Removing Beta resolves the conflict
    fs::remove_dir_all(&app2).unwrap();
    reg.reconcile().expect("reconcile after removing duplicate");

    let resolved = reg.inspect("org.example.conflict").expect("should find remaining app");
    match resolved {
        RegistryItem::Active(app) => {
            assert_eq!(app.id, "org.example.conflict");
            assert!(app.bundle_path.ends_with("Alpha.app"));
        }
        RegistryItem::Conflict(_) => panic!("conflict should have resolved"),
    }

    let code = reg.launch("org.example.conflict", &[]).expect("should launch after conflict resolution");
    assert_eq!(code, 0);
}

#[test]
fn test_reserved_id_rejection() {
    let env = TestEnv::new("reserved");
    let mut reg = env.create_registry();

    let stage = env.root.join("stage");
    let bundle = env.create_bundle(&stage, "Settings", "org.conjunction.settings", "settings");

    let res = reg.install(&bundle);
    match res {
        Err(RegistryError::ReservedId(id)) => assert_eq!(id, "org.conjunction.settings"),
        other => panic!("expected ReservedId error, got {:?}", other),
    }

    assert!(!env.user_apps.join("Settings.app").exists(), "reserved bundle must not be installed");

    let fake_bundle = env.create_bundle(&stage, "Fake", "org.conjunction.fake", "fake");
    let fake_res = reg.install(&fake_bundle);
    match fake_res {
        Err(RegistryError::ReservedId(id)) => assert_eq!(id, "org.conjunction.fake"),
        other => panic!("expected ReservedId error for fake, got {:?}", other),
    }
    assert!(!env.user_apps.join("Fake.app").exists(), "org.conjunction.fake must not be installed");
}

#[test]
fn test_malicious_bundle_rejected_before_registration() {
    let env = TestEnv::new("malicious_reg");
    let mut reg = env.create_registry();

    let stage = env.root.join("stage");
    let mal_dir = stage.join("Evil.app");
    let info = mal_dir.join("Contents/Info.toml");

    let manifest = format!(
        r#"bundle_format = "{}"
id = "org.example.evil"
name = "Evil"
version = "1.0.0"
executable = "../../bin/sh"
architectures = ["x86_64"]
"#,
        CURRENT_BUNDLE_FORMAT
    );

    fs::create_dir_all(info.parent().unwrap()).unwrap();
    fs::write(&info, manifest).unwrap();

    let res = reg.install(&mal_dir);
    assert!(res.is_err(), "installation of malicious bundle must fail");

    assert!(!env.user_apps.join("Evil.app").exists(), "evil bundle must not be installed");
    assert_eq!(reg.list().len(), 0, "registry must remain empty");

    // Verify no leftover staging directories in user_apps
    let entries: Vec<_> = fs::read_dir(&env.user_apps).unwrap().collect();
    assert_eq!(entries.len(), 0, "no staging directories left behind");
}
