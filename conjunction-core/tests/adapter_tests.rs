use conjunction_core::desktop_entry::DesktopEntry;
use conjunction_core::package::{PackageManagerQuery, PacmanPackageInfo};
use conjunction_core::registry::{AppBackend, AppRegistry, AppScope, RegistryError, RegistryItem};
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Arc;

struct MockQuery {
    map: HashMap<PathBuf, PacmanPackageInfo>,
}

impl PackageManagerQuery for MockQuery {
    fn query_file_owner(&self, path: &Path) -> Option<PacmanPackageInfo> {
        self.map.get(path).cloned()
    }
}

struct AdapterTestEnv {
    root: PathBuf,
    user_apps: PathBuf,
    system_apps: PathBuf,
    user_desktop: PathBuf,
    system_desktop: PathBuf,
    state_dir: PathBuf,
    desktop_dir: PathBuf,
    config_dir: PathBuf,
}

impl AdapterTestEnv {
    fn new(name: &str) -> Self {
        let unique = format!(
            "conj_adapt_{}_{}",
            name,
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        );
        let root = std::env::temp_dir().join(unique);
        let user_apps = root.join("UserApplications");
        let system_apps = root.join("SystemApplications");
        let user_desktop = root.join("user_desktop");
        let system_desktop = root.join("system_desktop");
        let state_dir = root.join("state");
        let desktop_dir = root.join("desktop");
        let config_dir = root.join("config");

        fs::create_dir_all(&user_apps).unwrap();
        fs::create_dir_all(&system_apps).unwrap();
        fs::create_dir_all(&user_desktop).unwrap();
        fs::create_dir_all(&system_desktop).unwrap();
        fs::create_dir_all(&state_dir).unwrap();
        fs::create_dir_all(&desktop_dir).unwrap();
        fs::create_dir_all(&config_dir).unwrap();

        AdapterTestEnv {
            root,
            user_apps,
            system_apps,
            user_desktop,
            system_desktop,
            state_dir,
            desktop_dir,
            config_dir,
        }
    }

    fn create_desktop_file(
        &self,
        dir: &Path,
        filename: &str,
        content: &str,
    ) -> PathBuf {
        let path = dir.join(filename);
        let mut f = File::create(&path).unwrap();
        f.write_all(content.as_bytes()).unwrap();
        path
    }
}

impl Drop for AdapterTestEnv {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.root);
    }
}

#[test]
fn test_desktop_entry_and_pacman_discovery() {
    let env = AdapterTestEnv::new("discover");

    let sys_dt = env.create_desktop_file(
        &env.system_desktop,
        "org.gnome.Calculator.desktop",
        "[Desktop Entry]\nType=Application\nName=Calculator\nExec=gnome-calculator %U\nIcon=gnome-calculator\nMimeType=x-scheme-handler/calc;\n",
    );

    let _user_dt = env.create_desktop_file(
        &env.user_desktop,
        "my-custom-tool.desktop",
        "[Desktop Entry]\nType=Application\nName=Custom Tool\nExec=my-tool --flag\nIcon=utilities-terminal\nTerminal=true\n",
    );

    env.create_desktop_file(
        &env.system_desktop,
        "conj-org.conjunction.demo.desktop",
        "[Desktop Entry]\nType=Application\nName=Generated\nExec=conj-appctl launch org.conjunction.demo\nX-Conjunction-AppId=org.conjunction.demo\n",
    );

    env.create_desktop_file(
        &env.system_desktop,
        "hidden-service.desktop",
        "[Desktop Entry]\nType=Application\nName=Hidden Service\nExec=hidden-srv\nNoDisplay=true\n",
    );

    let mut mock_map = HashMap::new();
    mock_map.insert(
        sys_dt.clone(),
        PacmanPackageInfo {
            package_name: "gnome-calculator".to_string(),
            package_version: Some("45.0-1".to_string()),
        },
    );

    let app_dirs = vec![
        (env.user_apps.clone(), AppScope::User),
        (env.system_apps.clone(), AppScope::System),
    ];
    let desktop_dirs = vec![
        (env.user_desktop.clone(), AppScope::User),
        (env.system_desktop.clone(), AppScope::System),
    ];

    let mut registry = AppRegistry::new(
        app_dirs,
        env.state_dir.clone(),
        env.desktop_dir.clone(),
        env.config_dir.clone(),
    )
    .with_desktop_dirs(desktop_dirs)
    .with_package_query(Arc::new(MockQuery { map: mock_map }));

    registry.reconcile().unwrap();

    let items = registry.list();
    assert_eq!(items.len(), 2);

    let calc = match registry.inspect("org.gnome.Calculator").unwrap() {
        RegistryItem::Active(app) => app,
        _ => panic!("expected active app"),
    };
    assert_eq!(calc.name, "Calculator");
    assert_eq!(calc.backend, AppBackend::Pacman);
    assert_eq!(calc.package_name, Some("gnome-calculator".to_string()));
    assert_eq!(calc.package_version, Some("45.0-1".to_string()));
    assert_eq!(calc.scope, AppScope::System);
    assert!(!calc.terminal);

    let custom = match registry.inspect("my-custom-tool").unwrap() {
        RegistryItem::Active(app) => app,
        _ => panic!("expected active app"),
    };
    assert_eq!(custom.name, "Custom Tool");
    assert_eq!(custom.backend, AppBackend::DesktopEntry);
    assert_eq!(custom.package_name, None);
    assert_eq!(custom.scope, AppScope::User);
    assert!(custom.terminal);

    assert!(registry.inspect("org.conjunction.demo").is_err());
    assert!(registry.inspect("conj-org.conjunction.demo").is_err());
    assert!(registry.inspect("hidden-service").is_err());
}

#[test]
fn test_multi_app_package_confirmation_requirement() {
    let env = AdapterTestEnv::new("multiapp");

    let app_a = env.create_desktop_file(
        &env.system_desktop,
        "conjunction-suite-app-a.desktop",
        "[Desktop Entry]\nType=Application\nName=Suite App A\nExec=suite-a\n",
    );

    let app_b = env.create_desktop_file(
        &env.system_desktop,
        "conjunction-suite-app-b.desktop",
        "[Desktop Entry]\nType=Application\nName=Suite App B\nExec=suite-b\n",
    );

    let mut mock_map = HashMap::new();
    let pkg = PacmanPackageInfo {
        package_name: "conjunction-phase3-suite".to_string(),
        package_version: Some("1.0.0-1".to_string()),
    };
    mock_map.insert(app_a, pkg.clone());
    mock_map.insert(app_b, pkg);

    let desktop_dirs = vec![(env.system_desktop.clone(), AppScope::System)];

    let mut registry = AppRegistry::new(
        vec![],
        env.state_dir.clone(),
        env.desktop_dir.clone(),
        env.config_dir.clone(),
    )
    .with_desktop_dirs(desktop_dirs)
    .with_package_query(Arc::new(MockQuery { map: mock_map }));

    registry.reconcile().unwrap();

    let a = match registry.inspect("conjunction-suite-app-a").unwrap() {
        RegistryItem::Active(app) => app,
        _ => panic!("expected active app"),
    };
    assert_eq!(a.backend, AppBackend::Pacman);
    assert_eq!(a.sibling_apps, vec!["conjunction-suite-app-b".to_string()]);

    let b = match registry.inspect("conjunction-suite-app-b").unwrap() {
        RegistryItem::Active(app) => app,
        _ => panic!("expected active app"),
    };
    assert_eq!(b.backend, AppBackend::Pacman);
    assert_eq!(b.sibling_apps, vec!["conjunction-suite-app-a".to_string()]);

    let err = registry.uninstall_with_options("conjunction-suite-app-a", false).unwrap_err();
    match err {
        RegistryError::MultiAppPackageRequiresConfirmation { package, siblings } => {
            assert_eq!(package, "conjunction-phase3-suite");
            assert_eq!(siblings, vec!["conjunction-suite-app-b".to_string()]);
        }
        other => panic!("expected MultiAppPackageRequiresConfirmation, got {:?}", other),
    }
}

#[test]
fn test_hostile_exec_parsing_security() {
    let content = "[Desktop Entry]\nType=Application\nName=Insecure App\nExec=testbin --arg1 ; rm -rf / | cat $(echo pwned) `echo evil` > /tmp/hacked\n";
    let de = DesktopEntry::parse_str(content, Path::new("/usr/share/applications/insecure.desktop")).unwrap();
    let argv = de.expand_exec(&[]).unwrap();

    assert_eq!(argv[0], "testbin");
    assert_eq!(argv[1], "--arg1");
    assert_eq!(argv[2], ";");
    assert_eq!(argv[3], "rm");
    assert_eq!(argv[4], "-rf");
    assert_eq!(argv[5], "/");
    assert_eq!(argv[6], "|");
    assert_eq!(argv[7], "cat");
    assert_eq!(argv[8], "$(echo");
    assert_eq!(argv[9], "pwned)");
    assert_eq!(argv[10], "`echo");
    assert_eq!(argv[11], "evil`");
    assert_eq!(argv[12], ">");
    assert_eq!(argv[13], "/tmp/hacked");
}
