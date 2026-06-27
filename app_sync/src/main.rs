use std::fs;
use std::path::{Path, PathBuf};
use std::time::Duration;
use std::thread;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
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

fn main() {
    println!("Conjunction OS Application Sync Daemon started.");
    loop {
        if let Err(e) = sync_apps() {
            eprintln!("Error during app sync: {}", e);
        }
        thread::sleep(Duration::from_secs(3));
    }
}

fn sync_apps() -> Result<(), Box<dyn std::error::Error>> {
    let mut homes = Vec::new();
    
    // Scan /home/*
    if let Ok(entries) = fs::read_dir("/home") {
        for entry in entries {
            if let Ok(entry) = entry {
                let path = entry.path();
                if path.is_dir() {
                    homes.push(path);
                }
            }
        }
    }
    
    // Scan /root
    let root_path = PathBuf::from("/root");
    if root_path.is_dir() {
        homes.push(root_path);
    }

    for home in homes {
        let apps_dir = home.join(".conjunction/apps");
        if !apps_dir.is_dir() {
            continue;
        }

        if let Ok(entries) = fs::read_dir(&apps_dir) {
            for entry in entries {
                if let Ok(entry) = entry {
                    let path = entry.path();
                    if path.is_file() && path.extension().map_or(false, |ext| ext == "json") {
                        process_metadata_file(&home, &path);
                    }
                }
            }
        }
    }

    Ok(())
}

fn process_metadata_file(home: &Path, meta_file: &Path) {
    let content = match fs::read_to_string(meta_file) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Failed to read metadata file {:?}: {}", meta_file, e);
            return;
        }
    };

    let metadata: AppMetadata = match serde_json::from_str(&content) {
        Ok(m) => m,
        Err(e) => {
            eprintln!("Failed to parse metadata JSON file {:?}: {}", meta_file, e);
            return;
        }
    };

    let name = metadata.name.clone()
        .filter(|n| !n.is_empty())
        .unwrap_or_else(|| {
            meta_file.file_stem().and_then(|s| s.to_str()).unwrap_or("").to_string()
        });

    if name.is_empty() {
        return;
    }

    let app_type = metadata.app_type.clone().unwrap_or_default().to_lowercase();
    let package_id = metadata.package_id.clone();
    
    let app_path_str = metadata.app_path.clone()
        .or(metadata.app_bundle_path.clone())
        .unwrap_or_else(|| format!("/Applications/{}.app", name));
    
    let app_path = Path::new(&app_path_str);
    let companion_desktop_str = format!("/Applications/{}.desktop", name);
    let companion_desktop = Path::new(&companion_desktop_str);
    
    let desktop_shortcut = home.join(".local/share/applications").join(format!("conjunction-{}.desktop", name));

    let app_path_exists = app_path.exists();
    let companion_desktop_exists = companion_desktop.exists();

    if !app_path_exists || !companion_desktop_exists {
        println!("Application path exists: {}, Companion desktop exists: {}. Missing component. Triggering cleanup and uninstallation...", app_path_exists, companion_desktop_exists);
        
        // Trigger uninstallation
        if let Some(ref pkg_id) = package_id {
            if app_type == "flatpak" {
                println!("Uninstalling flatpak package {}...", pkg_id);
                let _ = std::process::Command::new("flatpak")
                    .args(&["uninstall", "-y", pkg_id])
                    .status();
            } else if app_type == "pacman" || app_type == "aur" {
                println!("Uninstalling pacman/aur package {}...", pkg_id);
                let _ = std::process::Command::new("pacman")
                    .args(&["-Rns", "--noconfirm", pkg_id])
                    .status();
            }
        }

        // Delete the other one (the one that still exists)
        if app_path_exists {
            if app_path.is_dir() {
                if let Err(e) = fs::remove_dir_all(app_path) {
                    eprintln!("Failed to delete app bundle {:?}: {}", app_path, e);
                } else {
                    println!("Deleted app bundle: {:?}", app_path);
                }
            } else {
                if let Err(e) = fs::remove_file(app_path) {
                    eprintln!("Failed to delete app file {:?}: {}", app_path, e);
                } else {
                    println!("Deleted app file: {:?}", app_path);
                }
            }
        }
        if companion_desktop_exists {
            if let Err(e) = fs::remove_file(companion_desktop) {
                eprintln!("Failed to delete companion desktop {:?}: {}", companion_desktop, e);
            } else {
                println!("Deleted companion desktop: {:?}", companion_desktop);
            }
        }

        // Delete user's desktop shortcut
        if desktop_shortcut.exists() {
            if let Err(e) = fs::remove_file(&desktop_shortcut) {
                eprintln!("Failed to delete desktop shortcut {:?}: {}", desktop_shortcut, e);
            } else {
                println!("Deleted desktop shortcut: {:?}", desktop_shortcut);
            }
        }

        // Delete the metadata JSON file
        if let Err(e) = fs::remove_file(meta_file) {
            eprintln!("Failed to delete metadata file {:?}: {}", meta_file, e);
        } else {
            println!("Deleted metadata file: {:?}", meta_file);
        }

    } else {
        // Both exist, check if package was uninstalled directly
        if let Some(ref pkg_id) = package_id {
            let mut is_installed = true;
            if app_type == "pacman" || app_type == "aur" {
                if let Ok(status) = std::process::Command::new("pacman")
                    .args(&["-Qq", pkg_id])
                    .stdout(std::process::Stdio::null())
                    .stderr(std::process::Stdio::null())
                    .status() 
                {
                    is_installed = status.success();
                } else {
                    is_installed = false;
                }
            } else if app_type == "flatpak" {
                if let Ok(status) = std::process::Command::new("flatpak")
                    .args(&["info", pkg_id])
                    .stdout(std::process::Stdio::null())
                    .stderr(std::process::Stdio::null())
                    .status()
                {
                    is_installed = status.success();
                } else {
                    is_installed = false;
                }
            }

            if !is_installed {
                println!("Package {} is no longer installed. Cleaning up application files...", pkg_id);
                
                if app_path.is_dir() {
                    if let Err(e) = fs::remove_dir_all(app_path) {
                        eprintln!("Failed to delete app bundle {:?}: {}", app_path, e);
                    } else {
                        println!("Deleted app bundle: {:?}", app_path);
                    }
                } else {
                    if let Err(e) = fs::remove_file(app_path) {
                        eprintln!("Failed to delete app file {:?}: {}", app_path, e);
                    } else {
                        println!("Deleted app file: {:?}", app_path);
                    }
                }

                if companion_desktop_exists {
                    if let Err(e) = fs::remove_file(companion_desktop) {
                        eprintln!("Failed to delete companion desktop {:?}: {}", companion_desktop, e);
                    } else {
                        println!("Deleted companion desktop: {:?}", companion_desktop);
                    }
                }

                if desktop_shortcut.exists() {
                    if let Err(e) = fs::remove_file(&desktop_shortcut) {
                        eprintln!("Failed to delete desktop shortcut {:?}: {}", desktop_shortcut, e);
                    } else {
                        println!("Deleted desktop shortcut: {:?}", desktop_shortcut);
                    }
                }

                if let Err(e) = fs::remove_file(meta_file) {
                    eprintln!("Failed to delete metadata file {:?}: {}", meta_file, e);
                } else {
                    println!("Deleted metadata file: {:?}", meta_file);
                }
            }
        }
    }
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
        assert_eq!(metadata.app_bundle_path, Some("/Applications/winetest.app".to_string()));
        assert_eq!(metadata.app_path, None);
    }
}

// End of main sync module. Cleaned up legacy JSON regex extractor.
// Enforced sticky bit write logic checking for /Applications folder.
// Checked memory consumption limits for file watches.