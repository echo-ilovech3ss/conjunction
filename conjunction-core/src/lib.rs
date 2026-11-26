pub mod bundle;
pub use bundle::{
    host_arch, AppImageSpec, Bundle, BundleError, DocumentType, FlatpakSpec, Manifest,
    RuntimeKind, WineSpec, BUNDLE_FORMAT_V1, BUNDLE_FORMAT_V2, CURRENT_BUNDLE_FORMAT,
    DEFAULT_RUNTIME, SUPPORTED_ARCHITECTURES, SUPPORTED_BUNDLE_FORMATS, SUPPORTED_RUNTIMES,
};

pub mod cdmg;
pub use cdmg::{
    detect_cdmg_filesystem, eject_cdmg, list_mounted_cdmgs, mount_cdmg, pack_cdmg, CdmgError,
    CdmgFilesystem, MountBackend, MountRecord, PackOptions, VolumeMeta, CDMG_EXTENSION,
    CDMG_FORMAT_VERSION, CDMG_MIME_TYPE,
};

pub mod launcher;
pub use launcher::{
    build_bundle_launch_plan, execute_plan_captured, spawn_plan_detached, LaunchError, LaunchPlan,
};

pub mod security;
pub use security::{
    check_bundle_symlinks_contained, clear_quarantine, get_quarantine, seal_bundle_manifest,
    set_quarantine, sha256_bytes, sha256_file, sign_bundle_manifest, verify_bundle_manifest,
    verify_bundle_signature, QuarantineInfo, SecurityError,
};

pub mod watcher;

pub mod desktop_entry;
pub use desktop_entry::{DesktopEntry, DesktopEntryError};

pub mod package;
pub use package::{PackageManagerQuery, PacmanPackageInfo, SystemPacmanQuery};

pub mod flatpak;
pub use flatpak::FlatpakAppInfo;

pub mod registry;
pub use registry::{
    generated_xdg_dir, is_reserved_id, system_applications_dir, user_applications_dir,
    user_config_dir, user_desktop_dir, user_state_dir, AppBackend, AppConflict, AppRegistry,
    AppScope, InstalledApp, LaunchResult, RegistryError, RegistryItem,
};

pub mod ipc;
pub use ipc::{
    appd_runtime_dir, appd_socket_path, send_appd_request, send_appd_request_to_path,
    AppdRequest, AppdResponse,
};

pub mod shell;
pub use shell::{
    AppIdentity, DockClickAction, DockConfig, DockDisplayPolicy, DockItem, DockModel,
    GlobalMenuRegistrar, MenuItemInfo, ScreenInfo, ScreenModel, TopBarDisplayPolicy, WindowInfo,
    WindowMatcher,
};

pub mod search;
pub use search::{
    AppSearchProvider, FileSearchProvider, SearchCategory, SearchEngine, SearchProvider,
    SearchResult, SettingsSearchProvider,
};

pub mod files;
pub use files::{
    collect_leftover_candidates, detect_mime_type, empty_trash, format_file_size,
    format_timestamp, get_app_data_paths, get_trash_dir, list_leftovers, move_to_trash,
    purge_leftovers, record_leftovers, remove_app_data, FileItemInfo, LeftoverPath,
    LeftoverRecord, QuickLookPreview, QuickLookType,
};

pub mod settings;
pub use settings::{
    SettingControlType, SettingDescriptor, SettingSearchResult, SettingValue, SettingValueType,
    SettingsRegistry,
};

pub mod mime;
pub use mime::{detect_mime, parse_mimeapps_file, resolve_default_handler, set_default_handler};

pub mod boot;
pub use boot::{BtrfsLayoutContract, BtrfsSubvolume, OsRelease, UkiConfig, WaylandSessionEntry};

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
        let uid_out = std::process::Command::new("id").args(["-u", &sudo_user]).output();
        let gid_out = std::process::Command::new("id").args(["-g", &sudo_user]).output();
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
        .args(["-Ql", package_id])
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
                    if (path_str.starts_with("/usr/bin/") || path_str.starts_with("/bin/"))
                        && path.is_file() {
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
        if let Some(last_part) = package_id.split('.').next_back() {
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
                        if path.is_file() && path.extension().is_some_and(|ext| ext == "desktop") {
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
    let apps_root = if is_root() {
        system_applications_dir()
    } else {
        user_applications_dir()
    };
    let app_path = apps_root.join(format!("{}.app", name));
    let macos_dir = app_path.join("Contents/MacOS");
    let resources_dir = app_path.join("Contents/Resources");

    std::fs::create_dir_all(&macos_dir)?;
    std::fs::create_dir_all(&resources_dir)?;

    let exec_cmd = if pkg_type == "flatpak" {
        format!("exec flatpak run {} \"$@\"", package_id)
    } else {
        let bin_name = find_binary_for_package(package_id);
        format!("exec {} \"$@\"", bin_name)
    };

    let launcher_path = macos_dir.join(name);
    let launcher_content = format!("#!/bin/sh\n{}\n", exec_cmd);
    std::fs::write(&launcher_path, launcher_content)?;

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&launcher_path, std::fs::Permissions::from_mode(0o755))?;
    }

    let mut icon_rel = None;
    if let Some(icon_src) = find_package_icon(package_id, pkg_type) {
        let ext = icon_src
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("png")
            .to_string();
        let dest_icon = resources_dir.join(format!("icon.{}", ext));
        if std::fs::copy(&icon_src, &dest_icon).is_ok() {
            icon_rel = Some(format!("Contents/Resources/icon.{}", ext));
        }
    }

    let bundle_id = if pkg_type == "flatpak" && Bundle::validate_id(package_id).is_ok() {
        package_id.to_string()
    } else {
        let clean: String = name
            .chars()
            .map(|c| if c.is_ascii_alphanumeric() || c == '-' || c == '_' { c } else { '-' })
            .collect();
        let trimmed = clean.trim_matches(|c| c == '-' || c == '_');
        let seg = if trimmed.is_empty() { "app" } else { trimmed };
        format!("app.conjunction.{}", seg)
    };

    let runtime_block = if pkg_type == "flatpak" {
        format!(
            "runtime = \"flatpak\"\n\n[flatpak]\nid = \"{}\"\nscope = \"user\"\n",
            package_id
        )
    } else {
        "runtime = \"conjunction-1\"\n".to_string()
    };

    let icon_line = icon_rel
        .as_ref()
        .map(|i| format!("icon = \"{}\"\n", i))
        .unwrap_or_default();

    let info_toml = format!(
        "bundle_format = \"{}\"\nid = \"{}\"\nname = \"{}\"\nversion = \"1.0.0\"\nexecutable = \"Contents/MacOS/{}\"\narchitectures = [\"x86_64\", \"aarch64\"]\n{}{}",
        BUNDLE_FORMAT_V2, bundle_id, name, name, icon_line, runtime_block
    );
    std::fs::write(app_path.join("Contents/Info.toml"), info_toml)?;

    let mut reg = AppRegistry::default_for_user();
    let _ = reg.reconcile();
    Ok(())
}

pub fn remove_app_bundle(name: &str) -> Result<(), Box<dyn std::error::Error>> {
    let candidates = [
        user_applications_dir().join(format!("{}.app", name)),
        system_applications_dir().join(format!("{}.app", name)),
    ];
    for p in &candidates {
        if p.exists() {
            println!("Removing application bundle {}...", p.display());
            std::fs::remove_dir_all(p)?;
            println!("✓ Removed {}", p.display());
        }
    }

    let mut reg = AppRegistry::default_for_user();
    let _ = reg.reconcile();
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_user_home_returns_path() {
        let home = get_user_home();
        assert!(!home.as_os_str().is_empty());
    }

    #[test]
    fn test_which_binary_nonexistent() {
        assert!(which_binary("this_binary_definitely_does_not_exist_123456").is_none());
    }

    #[test]
    fn test_find_binary_for_package_fallback() {
        let pkg = "custom-pkg-xyz-nonexistent";
        let res = find_binary_for_package(pkg);
        assert_eq!(res, pkg);
    }

    #[test]
    fn test_write_file_user_temp() {
        let tmp_dir = std::env::temp_dir().join("conjunction_core_test_write");
        let tmp_file = tmp_dir.join("subdir").join("test.txt");
        let res = write_file_user(&tmp_file, "hello conjunction", None);
        assert!(res.is_ok());
        let read = std::fs::read_to_string(&tmp_file).unwrap();
        assert_eq!(read, "hello conjunction");
        let _ = std::fs::remove_dir_all(&tmp_dir);
    }
}