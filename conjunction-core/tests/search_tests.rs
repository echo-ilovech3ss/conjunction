use conjunction_core::registry::{AppBackend, AppScope, InstalledApp};
use conjunction_core::search::*;
use std::collections::HashMap;
use std::path::PathBuf;

fn create_sample_apps() -> HashMap<String, InstalledApp> {
    let mut apps = HashMap::new();

    apps.insert(
        "dev.conjunction.gallery".to_string(),
        InstalledApp {
            id: "dev.conjunction.gallery".to_string(),
            name: "Conjunction Gallery".to_string(),
            version: "1.0.0".to_string(),
            bundle_path: PathBuf::from("/Applications/Gallery.app"),
            executable_path: PathBuf::from("/usr/bin/conjunction-design-gallery"),
            scope: AppScope::User,
            backend: AppBackend::Native,
            icon: Some("preferences-desktop-theme".to_string()),
            mime_types: vec![],
            terminal: false,
            no_display: false,
            package_name: None,
            package_version: None,
            sibling_apps: vec![],
            flatpak_id: None,
        },
    );

    apps.insert(
        "org.mozilla.firefox".to_string(),
        InstalledApp {
            id: "org.mozilla.firefox".to_string(),
            name: "Firefox Web Browser".to_string(),
            version: "128.0".to_string(),
            bundle_path: PathBuf::from("/usr/share/applications/firefox.desktop"),
            executable_path: PathBuf::from("/usr/bin/firefox"),
            scope: AppScope::System,
            backend: AppBackend::Pacman,
            icon: Some("firefox".to_string()),
            mime_types: vec!["text/html".to_string()],
            terminal: false,
            no_display: false,
            package_name: Some("firefox".to_string()),
            package_version: Some("128.0-1".to_string()),
            sibling_apps: vec![],
            flatpak_id: None,
        },
    );

    apps.insert(
        "org.conjunction.files".to_string(),
        InstalledApp {
            id: "org.conjunction.files".to_string(),
            name: "Finder".to_string(),
            version: "1.0.0".to_string(),
            bundle_path: PathBuf::from("/Applications/Finder.app"),
            executable_path: PathBuf::from("/usr/bin/conjunction-files"),
            scope: AppScope::System,
            backend: AppBackend::Native,
            icon: Some("system-file-manager".to_string()),
            mime_types: vec![],
            terminal: false,
            no_display: false,
            package_name: None,
            package_version: None,
            sibling_apps: vec![],
            flatpak_id: None,
        },
    );

    apps
}

#[test]
fn test_app_search_exact_and_prefix() {
    let apps = create_sample_apps();
    let provider = AppSearchProvider::new(apps);

    // Exact match
    let res = provider.search("Finder");
    assert!(!res.is_empty());
    assert_eq!(res[0].id, "org.conjunction.files");
    assert_eq!(res[0].category, SearchCategory::Applications);
    assert_eq!(res[0].score, 1000);

    // Prefix match
    let res = provider.search("Fire");
    assert!(!res.is_empty());
    assert_eq!(res[0].id, "org.mozilla.firefox");
    assert!(res[0].score >= 800);

    // Package name match
    let res = provider.search("firefox");
    assert!(!res.is_empty());
    assert_eq!(res[0].id, "org.mozilla.firefox");
}

#[test]
fn test_settings_and_actions_search() {
    let provider = SettingsSearchProvider;

    // Search for Display settings
    let res = provider.search("brightness");
    assert!(!res.is_empty());
    assert_eq!(res[0].id, "settings.display");
    assert_eq!(res[0].category, SearchCategory::Settings);

    // Search for system action
    let res = provider.search("lock");
    assert!(!res.is_empty());
    assert_eq!(res[0].id, "action.lock");
    assert_eq!(res[0].category, SearchCategory::Actions);

    // Search for mission control / overview
    let res = provider.search("overview");
    assert!(!res.is_empty());
    assert_eq!(res[0].id, "action.overview");
}

#[test]
fn test_search_engine_coordination_and_ranking() {
    let mut engine = SearchEngine::new();
    engine.register_provider(Box::new(AppSearchProvider::new(create_sample_apps())));
    engine.register_provider(Box::new(SettingsSearchProvider));

    let res = engine.search("theme", 5);
    assert!(!res.is_empty());
    // Should match Appearance settings
    assert!(res.iter().any(|r| r.id == "settings.appearance"));

    let res_empty = engine.search("", 5);
    assert!(res_empty.is_empty());
}

#[test]
fn test_file_search_provider_bounded() {
    let temp_dir = std::env::temp_dir().join("conjunction_search_test");
    let _ = std::fs::create_dir_all(&temp_dir);
    let sample_file = temp_dir.join("quarterly_budget_2026.pdf");
    let _ = std::fs::write(&sample_file, "budget content");

    let provider = FileSearchProvider::new(vec![temp_dir.clone()]);
    let res = provider.search("budget");
    assert!(!res.is_empty());
    assert!(res[0].title.contains("quarterly_budget_2026"));
    assert_eq!(res[0].category, SearchCategory::Files);

    let _ = std::fs::remove_dir_all(&temp_dir);
}
