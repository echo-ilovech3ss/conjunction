use conjunction_core::AppRegistry;
use serde::Deserialize;
use std::thread;
use std::time::Duration;

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct AppMetadata {
    #[serde(default)]
    name: Option<String>,
    #[serde(rename = "type", default)]
    app_type: Option<String>,
    #[serde(default)]
    package_id: Option<String>,
    #[serde(default)]
    app_path: Option<String>,
    #[serde(default)]
    app_bundle_path: Option<String>,
}

/// Legacy compatibility entrypoint: delegates safely to AppRegistry::reconcile()
/// rather than mutating or deleting user .app bundles. For real-time inotify
/// watching, prefer `conj-appd`.
fn main() {
    println!("Conjunction OS Application Sync (delegating to AppRegistry; prefer conj-appd).");
    loop {
        if let Err(e) = sync_apps() {
            eprintln!("Error during app sync: {}", e);
        }
        thread::sleep(Duration::from_secs(5));
    }
}

fn sync_apps() -> Result<(), Box<dyn std::error::Error>> {
    let mut reg = AppRegistry::default_for_user();
    reg.reconcile()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_app_metadata() {
        let json = r#"{
            "name": "firefox",
            "type": "flatpak",
            "package_id": "org.mozilla.firefox",
            "app_path": "/Applications/firefox.app"
        }"#;

        let metadata: AppMetadata = serde_json::from_str(json).unwrap();
        assert_eq!(metadata.name, Some("firefox".to_string()));
        assert_eq!(metadata.app_type, Some("flatpak".to_string()));
        assert_eq!(metadata.package_id, Some("org.mozilla.firefox".to_string()));
        assert_eq!(metadata.app_path, Some("/Applications/firefox.app".to_string()));
        assert_eq!(metadata.app_bundle_path, None);
    }

    #[test]
    fn test_parse_app_metadata_nested_or_null() {
        let json = r#"{
            "name": "winetest",
            "type": "wine",
            "package_id": null,
            "app_bundle_path": "/Applications/winetest.app"
        }"#;

        let metadata: AppMetadata = serde_json::from_str(json).unwrap();
        assert_eq!(metadata.name, Some("winetest".to_string()));
        assert_eq!(metadata.app_type, Some("wine".to_string()));
        assert_eq!(metadata.package_id, None);
        assert_eq!(
            metadata.app_bundle_path,
            Some("/Applications/winetest.app".to_string())
        );
        assert_eq!(metadata.app_path, None);
    }
}
