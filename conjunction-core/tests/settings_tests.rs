use conjunction_core::settings::{
    SettingControlType, SettingDescriptor, SettingValue, SettingValueType, SettingsRegistry,
};

#[test]
fn test_canonical_registry_stable_ids_and_descriptors() {
    let reg = SettingsRegistry::canonical();
    let all = reg.all_settings();
    assert!(all.len() >= 12, "Must contain all standard canonical settings");

    let required_ids = [
        "appearance.mode",
        "appearance.accent",
        "dock.size",
        "dock.magnification",
        "dock.magnificationScale",
        "dock.displayPolicy",
        "displays.scale",
        "sound.volume",
        "sound.muted",
        "network.wifi.enabled",
        "bluetooth.enabled",
        "desktop.wallpaper",
        "general.about",
    ];

    for id in required_ids {
        let desc = reg.find_by_id(id);
        assert!(desc.is_some(), "Registry must contain stable setting ID '{}'", id);
        let s = desc.unwrap();
        assert!(!s.page.is_empty());
        assert!(!s.title.is_empty());
        assert!(!s.description.is_empty());
        assert!(!s.deep_link.is_empty());
        assert!(s.deep_link.starts_with("settings://"));
    }
}

#[test]
fn test_authoritative_boundary_validation() {
    let reg = SettingsRegistry::canonical();

    // 1. Int range validation (dock.size: 36..96)
    let dock_size = reg.find_by_id("dock.size").unwrap();
    assert!(dock_size.validate_value(&SettingValue::Int(68)).is_ok());
    assert!(dock_size.validate_value(&SettingValue::Int(36)).is_ok());
    assert!(dock_size.validate_value(&SettingValue::Int(96)).is_ok());
    assert!(dock_size.validate_value(&SettingValue::Int(12)).is_err(), "Underflow rejected");
    assert!(dock_size.validate_value(&SettingValue::Int(256)).is_err(), "Overflow rejected");
    assert!(dock_size.validate_value(&SettingValue::String("large".into())).is_err(), "Type mismatch rejected");

    // 2. Float range validation (dock.magnificationScale: 1.1..2.0)
    let dock_scale = reg.find_by_id("dock.magnificationScale").unwrap();
    assert!(dock_scale.validate_value(&SettingValue::Float(1.35)).is_ok());
    assert!(dock_scale.validate_value(&SettingValue::Float(0.5)).is_err());
    assert!(dock_scale.validate_value(&SettingValue::Float(3.0)).is_err());

    // 3. Enum string options validation (appearance.mode: dark, light)
    let app_mode = reg.find_by_id("appearance.mode").unwrap();
    assert!(app_mode.validate_value(&SettingValue::String("dark".into())).is_ok());
    assert!(app_mode.validate_value(&SettingValue::String("light".into())).is_ok());
    assert!(app_mode.validate_value(&SettingValue::String("neon_pink".into())).is_err(), "Unknown enum rejected");

    // 4. Bool validation (dock.magnification)
    let dock_mag = reg.find_by_id("dock.magnification").unwrap();
    assert!(dock_mag.validate_value(&SettingValue::Bool(true)).is_ok());
    assert!(dock_mag.validate_value(&SettingValue::Bool(false)).is_ok());
    assert!(dock_mag.validate_value(&SettingValue::Int(1)).is_err());
}

#[test]
fn test_settings_registry_search_and_synonyms() {
    let reg = SettingsRegistry::canonical();

    // "dark" -> Appearance
    let hits = reg.search("dark");
    assert!(!hits.is_empty());
    assert!(hits.iter().any(|h| h.page == "appearance"));

    // "theme" -> Appearance
    let hits = reg.search("theme");
    assert!(!hits.is_empty());
    assert!(hits.iter().any(|h| h.page == "appearance"));

    // "wifi" / "wireless" -> Network
    let hits = reg.search("wifi");
    assert!(!hits.is_empty());
    assert!(hits.iter().any(|h| h.page == "network"));

    let hits = reg.search("wireless");
    assert!(!hits.is_empty());
    assert!(hits.iter().any(|h| h.page == "network" || h.page == "bluetooth"));

    // "screen scale" / "resolution" -> Displays
    let hits = reg.search("scale");
    assert!(!hits.is_empty());
    assert!(hits.iter().any(|h| h.page == "displays" || h.setting_id.contains("scale")));

    // "dock zoom" -> Dock Magnification
    let hits = reg.search("zoom");
    assert!(!hits.is_empty());
    assert!(hits.iter().any(|h| h.setting_id.contains("magnification")));

    // "volume" / "speaker" -> Sound
    let hits = reg.search("volume");
    assert!(!hits.is_empty());
    assert!(hits.iter().any(|h| h.page == "sound"));

    let hits = reg.search("speaker");
    assert!(!hits.is_empty());
    assert!(hits.iter().any(|h| h.page == "sound"));
}

#[test]
fn test_settings_deep_link_formatting() {
    let reg = SettingsRegistry::canonical();

    let mag = reg.find_by_id("dock.magnification").unwrap();
    assert_eq!(mag.deep_link, "settings://dock?setting=dock.magnification");

    let vol = reg.find_by_id("sound.volume").unwrap();
    assert_eq!(vol.deep_link, "settings://sound?setting=sound.volume");

    let about = reg.find_by_id("general.about").unwrap();
    assert_eq!(about.deep_link, "settings://about");
}

#[test]
fn test_settings_json_export() {
    let reg = SettingsRegistry::canonical();
    let json = reg.to_json();
    assert!(json.contains("appearance.mode"));
    assert!(json.contains("dock.magnification"));
    assert!(json.contains("sound.volume"));
}
