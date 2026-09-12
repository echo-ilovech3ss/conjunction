use conjunction_core::registry::{AppBackend, AppScope, InstalledApp};
use conjunction_core::shell::{
    DockClickAction, DockConfig, DockModel, GlobalMenuRegistrar, MenuItemInfo, ScreenInfo,
    ScreenModel, WindowInfo, WindowMatcher,
};
use std::collections::HashMap;
use std::path::PathBuf;

fn make_test_apps() -> HashMap<String, InstalledApp> {
    let mut apps = HashMap::new();

    // 1. Native .app
    apps.insert(
        "dev.conjunction.gallery".to_string(),
        InstalledApp {
            id: "dev.conjunction.gallery".to_string(),
            name: "Conjunction Gallery".to_string(),
            version: "1.0.0".to_string(),
            bundle_path: PathBuf::from("/Applications/Gallery.app"),
            executable_path: PathBuf::from("/Applications/Gallery.app/Contents/MacOS/Gallery"),
            scope: AppScope::User,
            backend: AppBackend::Native,
            icon: Some("gallery".to_string()),
            mime_types: vec![],
            terminal: false,
            no_display: false,
            package_name: None,
            package_version: None,
            sibling_apps: vec![],
            flatpak_id: None,
        },
    );

    // 2. Pacman app
    apps.insert(
        "org.mozilla.firefox".to_string(),
        InstalledApp {
            id: "org.mozilla.firefox".to_string(),
            name: "Firefox".to_string(),
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

    // 3. Flatpak app
    apps.insert(
        "org.gnome.Calculator".to_string(),
        InstalledApp {
            id: "org.gnome.Calculator".to_string(),
            name: "Calculator".to_string(),
            version: "46.0".to_string(),
            bundle_path: PathBuf::from("/var/lib/flatpak/exports/share/applications/org.gnome.Calculator.desktop"),
            executable_path: PathBuf::from("flatpak"),
            scope: AppScope::System,
            backend: AppBackend::Flatpak,
            icon: Some("org.gnome.Calculator".to_string()),
            mime_types: vec![],
            terminal: false,
            no_display: false,
            package_name: None,
            package_version: None,
            sibling_apps: vec![],
            flatpak_id: Some("org.gnome.Calculator".to_string()),
        },
    );

    apps
}

// -------------------------------------------------------------
// WINDOW MODEL & RESOLUTION TESTS
// -------------------------------------------------------------

#[test]
fn test_window_resolution_exact_and_desktop_suffix() {
    let apps = make_test_apps();

    let win1 = WindowInfo {
        internal_id: "win-1".to_string(),
        pid: 1001,
        title: "Conjunction Gallery - Controls".to_string(),
        app_id: "dev.conjunction.gallery".to_string(),
        active: true,
        minimized: false,
        maximized: false,
        fullscreen: false,
        screen: "eDP-1".to_string(),
        workspace: 1,
        executable_path: None,
    };
    let ident1 = WindowMatcher::resolve_window(&win1, &apps);
    assert_eq!(ident1.id, "dev.conjunction.gallery");
    assert_eq!(ident1.name, "Conjunction Gallery");
    assert!(!ident1.is_unknown);

    let win2 = WindowInfo {
        internal_id: "win-2".to_string(),
        pid: 1002,
        title: "Mozilla Firefox".to_string(),
        app_id: "org.mozilla.firefox.desktop".to_string(),
        active: false,
        minimized: false,
        maximized: false,
        fullscreen: false,
        screen: "eDP-1".to_string(),
        workspace: 1,
        executable_path: None,
    };
    let ident2 = WindowMatcher::resolve_window(&win2, &apps);
    assert_eq!(ident2.id, "org.mozilla.firefox");
    assert_eq!(ident2.name, "Firefox");
    assert!(!ident2.is_unknown);
}

#[test]
fn test_window_resolution_executable_and_package_matching() {
    let apps = make_test_apps();

    // Window with generic or empty app_id but matching executable path
    let win = WindowInfo {
        internal_id: "win-3".to_string(),
        pid: 2005,
        title: "Web Browser".to_string(),
        app_id: "".to_string(),
        active: true,
        minimized: false,
        maximized: false,
        fullscreen: false,
        screen: "eDP-1".to_string(),
        workspace: 1,
        executable_path: Some(PathBuf::from("/usr/bin/firefox")),
    };
    let ident = WindowMatcher::resolve_window(&win, &apps);
    assert_eq!(ident.id, "org.mozilla.firefox");
    assert_eq!(ident.name, "Firefox");
    assert!(!ident.is_unknown);
}

#[test]
fn test_window_resolution_flatpak_matching() {
    let apps = make_test_apps();

    let win = WindowInfo {
        internal_id: "win-4".to_string(),
        pid: 3001,
        title: "Calculator".to_string(),
        app_id: "org.gnome.Calculator".to_string(),
        active: true,
        minimized: false,
        maximized: false,
        fullscreen: false,
        screen: "eDP-1".to_string(),
        workspace: 1,
        executable_path: None,
    };
    let ident = WindowMatcher::resolve_window(&win, &apps);
    assert_eq!(ident.id, "org.gnome.Calculator");
    assert_eq!(ident.name, "Calculator");
    assert!(!ident.is_unknown);
}

#[test]
fn test_window_resolution_unmatched_window_fallback() {
    let apps = make_test_apps();

    let win = WindowInfo {
        internal_id: "win-unknown".to_string(),
        pid: 9999,
        title: "Proprietary Custom Tool".to_string(),
        app_id: "custom-tool-unregistered".to_string(),
        active: true,
        minimized: false,
        maximized: false,
        fullscreen: false,
        screen: "eDP-1".to_string(),
        workspace: 1,
        executable_path: Some(PathBuf::from("/opt/custom/bin")),
    };
    let ident = WindowMatcher::resolve_window(&win, &apps);
    assert!(ident.is_unknown);
    assert_eq!(ident.id, "custom-tool-unregistered");
    assert_eq!(ident.name, "Proprietary Custom Tool");
}

// -------------------------------------------------------------
// DOCK MODEL TESTS
// -------------------------------------------------------------

#[test]
fn test_dock_model_pinned_and_running_states() {
    let apps = make_test_apps();
    let config = DockConfig {
        pinned_apps: vec![
            "dev.conjunction.gallery".to_string(),
            "org.mozilla.firefox".to_string(),
        ],
    };

    let mut dock = DockModel::new(config);

    // Initial state: no windows running
    dock.update(&apps, &[]);
    assert_eq!(dock.items.len(), 2);
    assert!(dock.items[0].pinned);
    assert!(!dock.items[0].running);
    assert_eq!(dock.items[0].window_count, 0);

    // Launch Firefox window
    let win1 = WindowInfo {
        internal_id: "win-ff-1".to_string(),
        pid: 101,
        title: "Mozilla Firefox".to_string(),
        app_id: "org.mozilla.firefox".to_string(),
        active: true,
        minimized: false,
        maximized: false,
        fullscreen: false,
        screen: "eDP-1".to_string(),
        workspace: 1,
        executable_path: None,
    };
    dock.update(&apps, &[win1.clone()]);
    assert_eq!(dock.items.len(), 2);
    assert!(dock.items[1].running);
    assert!(dock.items[1].active);
    assert_eq!(dock.items[1].window_count, 1);

    // Launch a second window for Firefox (one app, multiple windows)
    let win2 = WindowInfo {
        internal_id: "win-ff-2".to_string(),
        pid: 101,
        title: "Mozilla Firefox - Private Browsing".to_string(),
        app_id: "org.mozilla.firefox".to_string(),
        active: false,
        minimized: false,
        maximized: false,
        fullscreen: false,
        screen: "eDP-1".to_string(),
        workspace: 1,
        executable_path: None,
    };
    dock.update(&apps, &[win1.clone(), win2.clone()]);
    // MUST NOT duplicate dock items!
    assert_eq!(dock.items.len(), 2);
    assert_eq!(dock.items[1].window_count, 2);

    // Launch an unpinned app (Calculator)
    let win_calc = WindowInfo {
        internal_id: "win-calc-1".to_string(),
        pid: 202,
        title: "Calculator".to_string(),
        app_id: "org.gnome.Calculator".to_string(),
        active: false,
        minimized: false,
        maximized: false,
        fullscreen: false,
        screen: "eDP-1".to_string(),
        workspace: 1,
        executable_path: None,
    };
    dock.update(&apps, &[win1.clone(), win2.clone(), win_calc.clone()]);
    assert_eq!(dock.items.len(), 3);
    assert_eq!(dock.items[2].app_id, "org.gnome.Calculator");
    assert!(!dock.items[2].pinned);
    assert!(dock.items[2].running);

    // Close unpinned app -> must disappear from Dock
    dock.update(&apps, &[win1.clone(), win2.clone()]);
    assert_eq!(dock.items.len(), 2);
    assert!(!dock.items.iter().any(|it| it.app_id == "org.gnome.Calculator"));
}

#[test]
fn test_dock_click_action_and_focus_selection() {
    let apps = make_test_apps();
    let config = DockConfig {
        pinned_apps: vec![
            "dev.conjunction.gallery".to_string(),
            "org.mozilla.firefox".to_string(),
        ],
    };
    let mut dock = DockModel::new(config);

    let win_ff = WindowInfo {
        internal_id: "win-ff-1".to_string(),
        pid: 101,
        title: "Mozilla Firefox".to_string(),
        app_id: "org.mozilla.firefox".to_string(),
        active: false,
        minimized: false,
        maximized: false,
        fullscreen: false,
        screen: "eDP-1".to_string(),
        workspace: 1,
        executable_path: None,
    };

    dock.update(&apps, &[win_ff]);

    // Closed app click -> Launch
    let action_gallery = dock.handle_click("dev.conjunction.gallery");
    assert_eq!(action_gallery, Some(DockClickAction::Launch("dev.conjunction.gallery".to_string())));

    // Running app click -> Focus
    let action_ff = dock.handle_click("org.mozilla.firefox");
    assert_eq!(action_ff, Some(DockClickAction::FocusWindow("win-ff-1".to_string())));
}

#[test]
fn test_dock_pin_unpin_and_reorder_persistence() {
    let temp_dir = std::env::temp_dir().join("conjunction_dock_test");
    let _ = std::fs::create_dir_all(&temp_dir);
    let cfg_path = temp_dir.join("dock.json");

    let mut config = DockConfig {
        pinned_apps: vec!["app.a".to_string(), "app.b".to_string()],
    };
    assert!(config.save_to_file(&cfg_path).is_ok());

    // Pin new app
    assert!(config.pin("app.c"));
    assert!(!config.pin("app.c")); // already pinned
    assert_eq!(config.pinned_apps, vec!["app.a", "app.b", "app.c"]);

    // Reorder
    assert!(config.reorder("app.c", 0));
    assert_eq!(config.pinned_apps, vec!["app.c", "app.a", "app.b"]);

    // Unpin
    assert!(config.unpin("app.a"));
    assert_eq!(config.pinned_apps, vec!["app.c", "app.b"]);

    assert!(config.save_to_file(&cfg_path).is_ok());

    // Reload from file
    let loaded = DockConfig::load_from_file(&cfg_path).unwrap();
    assert_eq!(loaded.pinned_apps, vec!["app.c", "app.b"]);

    let _ = std::fs::remove_dir_all(&temp_dir);
}

// -------------------------------------------------------------
// GLOBAL MENU REGISTRAR & MODEL TESTS
// -------------------------------------------------------------

#[test]
fn test_global_menu_registrar_lifecycle() {
    let mut registrar = GlobalMenuRegistrar::new();

    registrar.register_window(1001, ":1.45", "/MenuBar");
    assert_eq!(
        registrar.get_menu(1001),
        Some(&(":1.45".to_string(), "/MenuBar".to_string()))
    );

    // Unregister window
    assert!(registrar.unregister_window(1001));
    assert_eq!(registrar.get_menu(1001), None);

    // Service disappearance
    registrar.register_window(1002, ":1.88", "/AppMenu");
    registrar.register_window(1003, ":1.88", "/OtherMenu");
    registrar.register_window(1004, ":1.99", "/MenuBar");

    registrar.remove_service(":1.88");
    assert_eq!(registrar.get_menu(1002), None);
    assert_eq!(registrar.get_menu(1003), None);
    assert_eq!(
        registrar.get_menu(1004),
        Some(&(":1.99".to_string(), "/MenuBar".to_string()))
    );
}

#[test]
fn test_menu_item_hierarchy_and_malformed_tolerance() {
    let menu = MenuItemInfo {
        id: 1,
        label: "File".to_string(),
        enabled: true,
        visible: true,
        icon_name: None,
        shortcut: None,
        children: vec![
            MenuItemInfo {
                id: 2,
                label: "New".to_string(),
                enabled: true,
                visible: true,
                icon_name: Some("document-new".to_string()),
                shortcut: Some("Ctrl+N".to_string()),
                children: vec![],
            },
            MenuItemInfo {
                id: 3,
                label: "Quit".to_string(),
                enabled: true,
                visible: true,
                icon_name: Some("application-exit".to_string()),
                shortcut: Some("Ctrl+Q".to_string()),
                children: vec![],
            },
        ],
    };

    assert_eq!(menu.children.len(), 2);
    assert_eq!(menu.children[0].label, "New");
    assert_eq!(menu.children[1].shortcut.as_deref(), Some("Ctrl+Q"));

    // Serialization / Deserialization check
    let serialized = serde_json::to_string(&menu).unwrap();
    let deserialized: Result<MenuItemInfo, _> = serde_json::from_str(&serialized);
    assert!(deserialized.is_ok());

    // Malformed JSON data fails safely without panic
    let malformed = "{\"id\": \"not_an_int\", \"label\": 123}";
    let bad_parse: Result<MenuItemInfo, _> = serde_json::from_str(malformed);
    assert!(bad_parse.is_err());
}

// -------------------------------------------------------------
// SCREEN MODEL & MULTI-MONITOR TESTS
// -------------------------------------------------------------

#[test]
fn test_screen_model_multi_monitor_and_primary() {
    let mut model = ScreenModel::new();

    let screen_internal = ScreenInfo {
        id: "eDP-1".to_string(),
        name: "Built-in Display".to_string(),
        x: 0,
        y: 0,
        width: 1920,
        height: 1080,
        scale: 1.0,
        is_primary: true,
    };

    // External monitor positioned to the left (negative coordinates) with 1.5 scale
    let screen_external = ScreenInfo {
        id: "DP-1".to_string(),
        name: "External 4K Monitor".to_string(),
        x: -3840,
        y: 0,
        width: 3840,
        height: 2160,
        scale: 1.5,
        is_primary: false,
    };

    model.add_screen(screen_internal.clone());
    model.add_screen(screen_external.clone());

    assert_eq!(model.screens.len(), 2);
    assert_eq!(model.primary_screen().unwrap().id, "eDP-1");

    // Change primary display to external
    model.set_primary("DP-1");
    assert_eq!(model.primary_screen().unwrap().id, "DP-1");
    assert_eq!(model.primary_screen().unwrap().x, -3840);
    assert_eq!(model.primary_screen().unwrap().scale, 1.5);

    // Remove external display (disconnect)
    model.remove_screen("DP-1");
    assert_eq!(model.screens.len(), 1);
    assert_eq!(model.primary_screen().unwrap().id, "eDP-1");
}
