use std::path::{Path, PathBuf};

pub fn get_user_home() -> PathBuf {
    if let Some(sudo_user) = std::env::var_os("SUDO_USER") {
        if !sudo_user.is_empty() {
            let hp = PathBuf::from("/home").join(&sudo_user);
            if hp.is_dir() {
                return hp;
            }
            if sudo_user == "root" {
                return PathBuf::from("/root");
            }
        }
    }
    if let Some(home) = std::env::var_os("HOME") {
        let hp = PathBuf::from(home);
        if hp.is_absolute() && hp.is_dir() {
            return hp;
        }
    }
    PathBuf::from("/root")
}

pub fn is_root() -> bool {
    if let Ok(output) = std::process::Command::new("id").arg("-u").output() {
        if let Ok(uid_str) = String::from_utf8(output.stdout) {
            if let Ok(uid) = uid_str.trim().parse::<u32>() {
                return uid == 0;
            }
        }
    }
    false
}

pub fn chown_to_user<P: AsRef<Path>>(path: P) {
    if let Ok(sudo_user) = std::env::var("SUDO_USER") {
        if sudo_user.is_empty() {
            return;
        }
        let uid_out = std::process::Command::new("id").args(&["-u", &sudo_user]).output();
        let gid_out = std::process::Command::new("id").args(&["-g", &sudo_user]).output();
        if let (Ok(u), Ok(g)) = (uid_out, gid_out) {
            let uid_str = String::from_utf8_lossy(&u.stdout);
            let gid_str = String::from_utf8_lossy(&g.stdout);
            if let (Ok(uid), Ok(gid)) = (uid_str.trim().parse::<u32>(), gid_str.trim().parse::<u32>()) {
                let _ = std::process::Command::new("chown")
                    .arg(format!("{}:{}", uid, gid))
                    .arg(path.as_ref())
                    .status();
            }
        }
    }
}

pub fn write_file_user<P: AsRef<Path>>(path: P, content: &str, mode: Option<u32>) -> std::io::Result<()> {
    let path = path.as_ref();
    if let Some(parent) = path.parent() {
        if !parent.exists() {
            std::fs::create_dir_all(parent)?;
            chown_to_user(parent);
        }
    }
    std::fs::write(path, content)?;
    if let Some(m) = mode {
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(path, std::fs::Permissions::from_mode(m))?;
        }
        let _ = m; // avoid unused warning on non-unix
    }
    chown_to_user(path);
    Ok(())
}

fn find_binary_for_package(package_id: &str) -> String {
    if which_binary(package_id).is_some() {
        return package_id.to_string();
    }
    
    let output = std::process::Command::new("pacman")
        .args(&["-Ql", package_id])
        .output();
        
    if let Ok(out) = output {
        if out.status.success() {
            let stdout = String::from_utf8_lossy(&out.stdout);
            let mut binaries = Vec::new();
            for line in stdout.lines() {
                let parts: Vec<&str> = line.trim().splitn(2, ' ').collect();
                if parts.len() == 2 {
                    let path_str = parts[1];
                    let path = Path::new(path_str);
                    if path_str.starts_with("/usr/bin/") || path_str.starts_with("/bin/") {
                        if path.is_file() {
                            let is_executable = {
                                #[cfg(unix)]
                                {
                                    use std::os::unix::fs::PermissionsExt;
                                    if let Ok(meta) = path.metadata() {
                                        meta.permissions().mode() & 0o111 != 0
                                    } else {
                                        false
                                    }
                                }
                                #[cfg(not(unix))]
                                true
                            };
                            if is_executable {
                                if let Some(file_name) = path.file_name() {
                                    if let Some(name_str) = file_name.to_str() {
                                        binaries.push(name_str.to_string());
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if !binaries.is_empty() {
                for b in &binaries {
                    if b.to_lowercase() == package_id.to_lowercase() {
                        return b.clone();
                    }
                }
                for b in &binaries {
                    if b.to_lowercase().contains(&package_id.to_lowercase()) {
                        return b.clone();
                    }
                }
                return binaries[0].clone();
            }
        }
    }
    package_id.to_string()
}

fn which_binary(name: &str) -> Option<PathBuf> {
    if let Ok(path_env) = std::env::var("PATH") {
        for path_dir in std::env::split_paths(&path_env) {
            let bin_path = path_dir.join(name);
            if bin_path.is_file() {
                return Some(bin_path);
            }
        }
    }
    None
}

fn find_package_icon(package_id: &str, pkg_type: &str) -> Option<PathBuf> {
    let mut icon_names = vec![package_id.to_string()];
    if package_id.contains('.') {
        if let Some(last_part) = package_id.split('.').last() {
            icon_names.push(last_part.to_string());
        }
    }
    
    let mut desktop_files = Vec::new();
    if pkg_type == "flatpak" {
        let home = get_user_home();
        let user_flatpak_dir = home.join(".local/share/flatpak/exports/share/applications");
        for base_path in &[
            Path::new("/var/lib/flatpak/exports/share/applications"),
            &user_flatpak_dir
        ] {
            let fp = base_path.join(format!("{}.desktop", package_id));
            if fp.exists() {
                desktop_files.push(fp);
            }
        }
    } else {
        for base_path in &["/usr/share/applications", "/usr/local/share/applications"] {
            let bp = Path::new(base_path);
            if bp.exists() {
                if let Ok(entries) = std::fs::read_dir(bp) {
                    for entry in entries.flatten() {
                        let path = entry.path();
                        if path.is_file() && path.extension().map_or(false, |ext| ext == "desktop") {
                            if let Some(filename) = path.file_name().and_then(|f| f.to_str()) {
                                if filename.to_lowercase().contains(&package_id.to_lowercase()) {
                                    desktop_files.push(path);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    for df in &desktop_files {
        if let Ok(content) = std::fs::read_to_string(df) {
            for line in content.lines() {
                if line.starts_with("Icon=") {
                    let val = line.split_once('=').map(|(_, val)| val.trim()).unwrap_or("");
                    if !val.is_empty() && !icon_names.contains(&val.to_string()) {
                        icon_names.insert(0, val.to_string());
                    }
                }
            }
        }
    }
    
    let home = get_user_home();
    let search_dirs = vec![
        PathBuf::from("/usr/share/icons/hicolor"),
        PathBuf::from("/usr/share/pixmaps"),
        PathBuf::from("/var/lib/flatpak/exports/share/icons/hicolor"),
        home.join(".local/share/flatpak/exports/share/icons/hicolor"),
        home.join(".local/share/icons/hicolor"),
    ];
    
    for icon_name in &icon_names {
        let p = Path::new(icon_name);
        if p.is_absolute() && p.exists() {
            return Some(p.to_path_buf());
        }
        
        for sdir in &search_dirs {
            if !sdir.exists() {
                continue;
            }
            if let Some(found) = walk_dir_for_file(sdir, &format!("{}.png", icon_name.to_lowercase())) {
                return Some(found);
            }
        }
        
        for sdir in &search_dirs {
            if !sdir.exists() {
                continue;
            }
            if let Some(found) = walk_dir_for_file(sdir, &format!("{}.svg", icon_name.to_lowercase())) {
                return Some(found);
            }
        }
        
        for sdir in &search_dirs {
            if !sdir.exists() {
                continue;
            }
            if let Some(found) = walk_dir_for_stem(sdir, &icon_name.to_lowercase()) {
                return Some(found);
            }
        }
    }
    
    None
}

fn walk_dir_for_file(dir: &Path, target_filename: &str) -> Option<PathBuf> {
    if let Ok(entries) = std::fs::read_dir(dir) {
        let mut dirs_to_visit = Vec::new();
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_file() {
                if let Some(name) = path.file_name().and_then(|f| f.to_str()) {
                    if name.to_lowercase() == target_filename {
                        return Some(path);
                    }
                }
            } else if path.is_dir() {
                dirs_to_visit.push(path);
            }
        }
        for d in dirs_to_visit {
            if let Some(found) = walk_dir_for_file(&d, target_filename) {
                return Some(found);
            }
        }
    }
    None
}

fn walk_dir_for_stem(dir: &Path, target_stem: &str) -> Option<PathBuf> {
    if let Ok(entries) = std::fs::read_dir(dir) {
        let mut dirs_to_visit = Vec::new();
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_file() {
                if let Some(stem) = path.file_stem().and_then(|f| f.to_str()) {
                    if stem.to_lowercase() == target_stem {
                        return Some(path);
                    }
                }
            } else if path.is_dir() {
                dirs_to_visit.push(path);
            }
        }
        for d in dirs_to_visit {
            if let Some(found) = walk_dir_for_stem(&d, target_stem) {
                return Some(found);
            }
        }
    }
    None
}

pub fn create_app_bundle(name: &str, pkg_type: &str, package_id: &str) -> Result<(), Box<dyn std::error::Error>> {
    let app_path = format!("/Applications/{}.app", name);
    let macos_dir = format!("{}/Contents/MacOS", app_path);
    let resources_dir = format!("{}/Contents/Resources", app_path);
    
    std::fs::create_dir_all(&macos_dir)?;
    std::fs::create_dir_all(&resources_dir)?;
    
    let exec_cmd = if pkg_type == "flatpak" {
        format!("exec flatpak run {}", package_id)
    } else {
        let bin_name = find_binary_for_package(package_id);
        format!("exec {}", bin_name)
    };
    
    let launcher_path = format!("{}/{}", macos_dir, name);
    let launcher_content = format!("#!/bin/bash\n{} \"$@\"\n", exec_cmd);
    std::fs::write(&launcher_path, launcher_content)?;
    
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&launcher_path, std::fs::Permissions::from_mode(0o755))?;
    }
    
    let plist_path = format!("{}/Contents/Info.plist", app_path);
    let bundle_id = if pkg_type == "flatpak" {
        package_id.to_string()
    } else {
        format!("org.conjunction.{}", name)
    };
    
    let plist_content = format!(r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>{}</string>
    <key>CFBundleExecutable</key>
    <string>{}</string>
    <key>CFBundleIdentifier</key>
    <string>{}</string>
</dict>
</plist>
"#, name, name, bundle_id);
    std::fs::write(&plist_path, plist_content)?;
    
    let dest_icon_path = format!("{}/icon.png", resources_dir);
    if let Some(icon_path) = find_package_icon(package_id, pkg_type) {
        let _ = std::fs::copy(icon_path, &dest_icon_path);
    }
    
    let user_home = get_user_home();
    let meta_dir = user_home.join(".conjunction").join("apps");
    let meta_path = meta_dir.join(format!("{}.json", name));
    
    let meta_data = serde_json::json!({
        "name": name,
        "type": pkg_type,
        "package_id": package_id,
        "app_path": app_path
    });
    
    write_file_user(&meta_path, &serde_json::to_string_pretty(&meta_data)?, None)?;
    
    let desktop_dir = user_home.join(".local").join("share").join("applications");
    let desktop_path = desktop_dir.join(format!("conjunction-{}.desktop", name));
    
    let icon_val = if Path::new(&dest_icon_path).exists() {
        dest_icon_path.clone()
    } else {
        "system-run".to_string()
    };
    
    let desktop_content = format!(r#"[Desktop Entry]
Version=1.0
Type=Application
Name={}
Exec={}
Icon={}
Terminal=false
Categories=Utility;
"#, name, launcher_path, icon_val);
    
    write_file_user(&desktop_path, &desktop_content, None)?;
    
    let app_desktop_path = format!("/Applications/{}.desktop", name);
    let app_icon_val = if Path::new(&dest_icon_path).exists() {
        dest_icon_path
    } else {
        "system-run".to_string()
    };
    
    let app_desktop_content = format!(r#"[Desktop Entry]
Version=1.0
Type=Application
Name={}
Exec=/Applications/{}.app/Contents/MacOS/{}
Icon={}
Terminal=false
Categories=Utility;
"#, name, name, name, app_icon_val);
    
    std::fs::write(&app_desktop_path, app_desktop_content)?;
    
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&app_desktop_path, std::fs::Permissions::from_mode(0o755))?;
    }
    
    Ok(())
}

pub fn remove_app_bundle(name: &str) -> Result<(), Box<dyn std::error::Error>> {
    let user_home = get_user_home();
    let apps_dir = user_home.join(".conjunction").join("apps");
    let mut app_name = name.to_string();
    
    if apps_dir.exists() {
        if let Ok(entries) = std::fs::read_dir(&apps_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_file() && path.extension().map_or(false, |ext| ext == "json") {
                    if let Ok(content) = std::fs::read_to_string(&path) {
                        if let Ok(meta) = serde_json::from_str::<serde_json::Value>(&content) {
                            let meta_name = meta.get("name").and_then(|v| v.as_str()).unwrap_or("");
                            let meta_pkg_id = meta.get("package_id").and_then(|v| v.as_str()).unwrap_or("");
                            if meta_name.to_lowercase() == name.to_lowercase() || meta_pkg_id.to_lowercase() == name.to_lowercase() {
                                if !meta_name.is_empty() {
                                    app_name = meta_name.to_string();
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    let app_path = format!("/Applications/{}.app", app_name);
    let app_path_p = Path::new(&app_path);
    if app_path_p.exists() {
        println!("Removing application bundle {}...", app_path);
        let _ = std::fs::remove_dir_all(app_path_p);
        println!("✓ Removed {}", app_path);
    }
    
    let companion_desktop_path = format!("/Applications/{}.desktop", app_name);
    let companion_desktop_p = Path::new(&companion_desktop_path);
    if companion_desktop_p.exists() {
        let _ = std::fs::remove_file(companion_desktop_p);
        println!("✓ Removed companion desktop file {}", companion_desktop_path);
    }
    
    let desktop_path = user_home.join(".local").join("share").join("applications").join(format!("conjunction-{}.desktop", app_name));
    if desktop_path.exists() {
        let _ = std::fs::remove_file(desktop_path);
    }
    
    let json_path = apps_dir.join(format!("{}.json", app_name));
    if json_path.exists() {
        let _ = std::fs::remove_file(json_path);
    }
    
    Ok(())
}

// Added standard safety annotations for system-wide path resolution.
// Added fallback lookup handling for system-wide icon resolution.
// Added logic to strip raw control characters from plist strings.