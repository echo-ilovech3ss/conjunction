use crate::bundle::Bundle;
use crate::get_user_home;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum QuickLookType {
    Image,
    CodeText,
    Pdf,
    AppBundle,
    Directory,
    Generic,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct QuickLookPreview {
    pub path: PathBuf,
    pub name: String,
    pub preview_type: QuickLookType,
    pub mime_type: String,
    pub size_formatted: String,
    pub size_bytes: u64,
    pub modified_formatted: String,
    pub text_snippet: Option<String>,
    pub metadata: HashMap<String, String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FileItemInfo {
    pub path: PathBuf,
    pub name: String,
    pub is_dir: bool,
    pub is_app_bundle: bool,
    pub is_symlink: bool,
    pub is_hidden: bool,
    pub size_bytes: u64,
    pub size_formatted: String,
    pub modified_timestamp: u64,
    pub modified_formatted: String,
    pub mime_type: String,
    pub bundle_id: Option<String>,
    pub bundle_name: Option<String>,
    pub bundle_icon: Option<PathBuf>,
    pub bundle_executable: Option<PathBuf>,
    pub can_show_package_contents: bool,
}

impl FileItemInfo {
    pub fn from_path<P: AsRef<Path>>(path: P) -> std::io::Result<Self> {
        let path = path.as_ref().to_path_buf();
        let symlink_meta = fs::symlink_metadata(&path)?;
        let is_symlink = symlink_meta.file_type().is_symlink();
        let meta = if is_symlink {
            fs::metadata(&path).unwrap_or(symlink_meta.clone())
        } else {
            symlink_meta
        };

        let file_name = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("")
            .to_string();

        let is_hidden = file_name.starts_with('.') && file_name != "." && file_name != "..";
        let is_dir = meta.is_dir();
        let size_bytes = if is_dir { 0 } else { meta.len() };
        let size_formatted = format_file_size(size_bytes, is_dir);

        let modified_timestamp = meta
            .modified()
            .ok()
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_secs())
            .unwrap_or(0);
        let modified_formatted = format_timestamp(modified_timestamp);

        // Check if directory is a valid .app bundle
        let mut is_app_bundle = false;
        let mut bundle_id = None;
        let mut bundle_name = None;
        let mut bundle_icon = None;
        let mut bundle_executable = None;

        if is_dir && file_name.ends_with(".app") {
            if let Ok(bundle) = Bundle::open(&path) {
                if bundle.validate().is_ok() {
                    let m = bundle.manifest();
                    is_app_bundle = true;
                    bundle_id = Some(m.id.clone());
                    bundle_name = Some(m.name.clone());
                    if let Ok(exec_path) = bundle.executable_path() {
                        bundle_executable = Some(exec_path);
                    }
                    // Check for bundle icon in Contents/Resources
                    let res_dir = path.join("Contents").join("Resources");
                    if let Some(icon_name) = &m.icon {
                        let candidate = res_dir.join(icon_name);
                        if candidate.exists() {
                            bundle_icon = Some(candidate);
                        }
                    }
                    if bundle_icon.is_none() {
                        for candidate_name in &["icon.png", "icon.svg", "AppIcon.png", "AppIcon.svg"] {
                            let candidate = res_dir.join(candidate_name);
                            if candidate.exists() {
                                bundle_icon = Some(candidate);
                                break;
                            }
                        }
                    }
                }
            }
        }

        let mime_type = if is_app_bundle {
            "application/x-conjunction-app".to_string()
        } else if is_dir {
            "inode/directory".to_string()
        } else {
            detect_mime_type(&path)
        };

        let can_show_package_contents = is_app_bundle;

        Ok(FileItemInfo {
            path,
            name: file_name,
            is_dir,
            is_app_bundle,
            is_symlink,
            is_hidden,
            size_bytes,
            size_formatted,
            modified_timestamp,
            modified_formatted,
            mime_type,
            bundle_id,
            bundle_name,
            bundle_icon,
            bundle_executable,
            can_show_package_contents,
        })
    }
}

pub fn format_file_size(bytes: u64, is_dir: bool) -> String {
    if is_dir {
        return "--".to_string();
    }
    const KB: u64 = 1024;
    const MB: u64 = 1024 * KB;
    const GB: u64 = 1024 * MB;

    if bytes >= GB {
        format!("{:.1} GB", bytes as f64 / GB as f64)
    } else if bytes >= MB {
        format!("{:.1} MB", bytes as f64 / MB as f64)
    } else if bytes >= KB {
        format!("{:.1} KB", bytes as f64 / KB as f64)
    } else {
        format!("{} B", bytes)
    }
}

pub fn format_timestamp(secs: u64) -> String {
    if secs == 0 {
        return "--".to_string();
    }
    let days_since_epoch = secs / 86400;
    let time_of_day = secs % 86400;
    let hours = time_of_day / 3600;
    let minutes = (time_of_day % 3600) / 60;

    let z = days_since_epoch as i64 + 719468;
    let era = (if z >= 0 { z } else { z - 146096 }) / 146097;
    let doe = (z - era * 146097) as u32;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };

    format!("{:04}-{:02}-{:02} {:02}:{:02}", y, m, d, hours, minutes)
}

pub fn detect_mime_type(path: &Path) -> String {
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .map(|s| s.to_lowercase())
        .unwrap_or_default();

    match ext.as_str() {
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "svg" => "image/svg+xml",
        "webp" => "image/webp",
        "ico" => "image/x-icon",
        "bmp" => "image/bmp",
        "pdf" => "application/pdf",
        "txt" => "text/plain",
        "md" | "markdown" => "text/markdown",
        "rs" => "text/rust",
        "c" | "h" => "text/x-c",
        "cpp" | "hpp" | "cc" | "cxx" => "text/x-c++",
        "py" => "text/x-python",
        "js" => "text/javascript",
        "ts" => "text/typescript",
        "qml" => "text/x-qml",
        "json" => "application/json",
        "toml" => "application/toml",
        "yaml" | "yml" => "application/yaml",
        "xml" => "application/xml",
        "html" | "htm" => "text/html",
        "css" => "text/css",
        "sh" | "bash" | "zsh" => "application/x-sh",
        "desktop" => "application/x-desktop",
        "tar" => "application/x-tar",
        "gz" => "application/gzip",
        "zip" => "application/zip",
        "mp3" => "audio/mpeg",
        "wav" => "audio/wav",
        "mp4" => "video/mp4",
        "mkv" => "video/x-matroska",
        _ => "application/octet-stream",
    }
    .to_string()
}

impl QuickLookPreview {
    pub fn analyze<P: AsRef<Path>>(path: P) -> Self {
        let path = path.as_ref().to_path_buf();
        let name = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("")
            .to_string();

        let meta = fs::metadata(&path).ok();
        let is_dir = meta.as_ref().map(|m| m.is_dir()).unwrap_or(false);
        let size_bytes = if is_dir { 0 } else { meta.as_ref().map(|m| m.len()).unwrap_or(0) };
        let size_formatted = format_file_size(size_bytes, is_dir);

        let modified_timestamp = meta
            .as_ref()
            .and_then(|m| m.modified().ok())
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_secs())
            .unwrap_or(0);
        let modified_formatted = format_timestamp(modified_timestamp);

        let mut metadata = HashMap::new();
        metadata.insert("Path".to_string(), path.display().to_string());
        metadata.insert("Size".to_string(), size_formatted.clone());
        metadata.insert("Modified".to_string(), modified_formatted.clone());

        // Probe for .app bundle
        if is_dir && name.ends_with(".app") {
            if let Ok(bundle) = Bundle::open(&path) {
                if bundle.validate().is_ok() {
                    let m = bundle.manifest();
                    metadata.insert("Application ID".to_string(), m.id.clone());
                    metadata.insert("Application Name".to_string(), m.name.clone());
                    metadata.insert("Version".to_string(), m.version.clone());
                    metadata.insert("Executable".to_string(), m.executable.clone());
                    metadata.insert(
                        "Architectures".to_string(),
                        m.architectures.join(", "),
                    );
                    if let Some(desc) = &m.description {
                        metadata.insert("Description".to_string(), desc.clone());
                    }

                    return QuickLookPreview {
                        path,
                        name,
                        preview_type: QuickLookType::AppBundle,
                        mime_type: "application/x-conjunction-app".to_string(),
                        size_formatted,
                        size_bytes,
                        modified_formatted,
                        text_snippet: None,
                        metadata,
                    };
                }
            }
        }

        if is_dir {
            return QuickLookPreview {
                path,
                name,
                preview_type: QuickLookType::Directory,
                mime_type: "inode/directory".to_string(),
                size_formatted,
                size_bytes,
                modified_formatted,
                text_snippet: None,
                metadata,
            };
        }

        let mime = detect_mime_type(&path);
        let ext = path
            .extension()
            .and_then(|e| e.to_str())
            .map(|s| s.to_lowercase())
            .unwrap_or_default();

        if mime.starts_with("image/") {
            QuickLookPreview {
                path,
                name,
                preview_type: QuickLookType::Image,
                mime_type: mime,
                size_formatted,
                size_bytes,
                modified_formatted,
                text_snippet: None,
                metadata,
            }
        } else if mime == "application/pdf" {
            QuickLookPreview {
                path,
                name,
                preview_type: QuickLookType::Pdf,
                mime_type: mime,
                size_formatted,
                size_bytes,
                modified_formatted,
                text_snippet: None,
                metadata,
            }
        } else if mime.starts_with("text/")
            || mime == "application/json"
            || mime == "application/toml"
            || mime == "application/yaml"
            || mime == "application/xml"
            || mime == "application/x-sh"
            || mime == "application/x-desktop"
            || ["rs", "c", "h", "cpp", "hpp", "py", "js", "ts", "qml", "sh", "txt", "md", "toml", "json", "yml", "yaml", "conf", "ini"].contains(&ext.as_str())
        {
            let text_snippet = match fs::read(&path) {
                Ok(bytes) => {
                    let cap = bytes.len().min(65536);
                    Some(String::from_utf8_lossy(&bytes[..cap]).to_string())
                }
                Err(_) => None,
            };

            QuickLookPreview {
                path,
                name,
                preview_type: QuickLookType::CodeText,
                mime_type: mime,
                size_formatted,
                size_bytes,
                modified_formatted,
                text_snippet,
                metadata,
            }
        } else {
            QuickLookPreview {
                path,
                name,
                preview_type: QuickLookType::Generic,
                mime_type: mime,
                size_formatted,
                size_bytes,
                modified_formatted,
                text_snippet: None,
                metadata,
            }
        }
    }
}

/// Validates that an application ID adheres to safe reverse-DNS syntax and contains no traversal.
pub fn is_safe_app_id(id: &str) -> bool {
    let trimmed = id.trim();
    if trimmed.is_empty() || trimmed != id {
        return false;
    }
    if id.contains('/') || id.contains('\\') || id.contains("..") || id.contains('\0') {
        return false;
    }
    crate::bundle::Bundle::validate_id(id).is_ok()
}

/// Calculate all standard user application data paths for clean removal.
pub fn get_app_data_paths(
    bundle_id: &str,
    is_flatpak: bool,
    flatpak_id: Option<&str>,
) -> Vec<PathBuf> {
    if !is_safe_app_id(bundle_id) {
        return Vec::new();
    }
    let home = get_user_home();
    let mut paths = Vec::new();

    paths.push(home.join(".config").join(bundle_id));
    paths.push(home.join(".local").join("share").join(bundle_id));
    paths.push(home.join(".cache").join(bundle_id));
    paths.push(home.join(".conjunction").join("apps").join(format!("{}.json", bundle_id)));

    if is_flatpak {
        let f_id = flatpak_id.unwrap_or(bundle_id);
        if is_safe_app_id(f_id) {
            paths.push(home.join(".var").join("app").join(f_id));
        }
    }

    paths
}

/// Remove application data directories if they exist, returning count of removed locations.
pub fn remove_app_data(
    bundle_id: &str,
    is_flatpak: bool,
    flatpak_id: Option<&str>,
) -> std::io::Result<usize> {
    if !is_safe_app_id(bundle_id) {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            format!("Invalid application ID: {}", bundle_id),
        ));
    }
    if is_flatpak {
        if let Some(f_id) = flatpak_id {
            if !is_safe_app_id(f_id) {
                return Err(std::io::Error::new(
                    std::io::ErrorKind::InvalidInput,
                    format!("Invalid flatpak ID: {}", f_id),
                ));
            }
        }
    }

    let paths = get_app_data_paths(bundle_id, is_flatpak, flatpak_id);
    let mut count = 0;
    let home = get_user_home();

    for p in paths {
        // Enforce that path is strictly within home
        if !p.starts_with(&home) {
            continue;
        }

        // Use symlink_metadata to NEVER follow symlinks
        if let Ok(meta) = fs::symlink_metadata(&p) {
            let file_type = meta.file_type();
            if file_type.is_symlink() {
                // If it is a symlink, delete the symlink itself; NEVER traverse into the target directory!
                fs::remove_file(&p)?;
                count += 1;
            } else if file_type.is_dir() {
                fs::remove_dir_all(&p)?;
                count += 1;
            } else if file_type.is_file() {
                fs::remove_file(&p)?;
                count += 1;
            }
        }
    }

    Ok(count)
}

/// Resolve the standard XDG Trash directory for the current user.
pub fn get_trash_dir() -> PathBuf {
    if let Ok(data_home) = std::env::var("XDG_DATA_HOME") {
        if !data_home.is_empty() {
            return PathBuf::from(data_home).join("Trash");
        }
    }
    get_user_home().join(".local").join("share").join("Trash")
}

/// Move a file or directory to XDG Trash adhering to the FreeDesktop Trash specification.
pub fn move_to_trash<P: AsRef<Path>>(path: P) -> std::io::Result<PathBuf> {
    let path = path.as_ref();
    if !path.exists() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::NotFound,
            format!("path does not exist: {}", path.display()),
        ));
    }

    let trash_dir = get_trash_dir();
    let files_dir = trash_dir.join("files");
    let info_dir = trash_dir.join("info");

    fs::create_dir_all(&files_dir)?;
    fs::create_dir_all(&info_dir)?;

    let original_name = path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("item")
        .to_string();

    let mut dest_name = original_name.clone();
    let mut counter = 1;
    while files_dir.join(&dest_name).exists() {
        dest_name = format!("{}.{}", original_name, counter);
        counter += 1;
    }

    let dest_file_path = files_dir.join(&dest_name);
    let dest_info_path = info_dir.join(format!("{}.trashinfo", dest_name));

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let timestamp_str = format_timestamp(now).replace(' ', "T");

    let canonical_orig = path.canonicalize().unwrap_or_else(|_| path.to_path_buf());
    let info_content = format!(
        "[Trash Info]\nPath={}\nDeletionDate={}\n",
        canonical_orig.display(),
        timestamp_str
    );

    fs::write(&dest_info_path, info_content)?;

    if let Err(_e) = fs::rename(path, &dest_file_path) {
        if path.is_dir() {
            copy_dir_recursive(path, &dest_file_path)?;
            fs::remove_dir_all(path)?;
        } else {
            fs::copy(path, &dest_file_path)?;
            fs::remove_file(path)?;
        }
    }

    Ok(dest_file_path)
}

fn copy_dir_recursive(src: &Path, dst: &Path) -> std::io::Result<()> {
    fs::create_dir_all(dst)?;
    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let src_path = entry.path();
        let dst_path = dst.join(entry.file_name());
        if src_path.is_dir() {
            copy_dir_recursive(&src_path, &dst_path)?;
        } else {
            fs::copy(&src_path, &dst_path)?;
        }
    }
    Ok(())
}

/// Empty the XDG Trash folder
pub fn empty_trash() -> std::io::Result<usize> {
    let trash_dir = get_trash_dir();
    let files_dir = trash_dir.join("files");
    let info_dir = trash_dir.join("info");

    let mut count = 0;
    if files_dir.exists() {
        for entry in fs::read_dir(&files_dir)? {
            let entry = entry?;
            let p = entry.path();
            if p.is_dir() {
                let _ = fs::remove_dir_all(&p);
            } else {
                let _ = fs::remove_file(&p);
            }
            count += 1;
        }
    }

    if info_dir.exists() {
        for entry in fs::read_dir(&info_dir)? {
            let entry = entry?;
            let _ = fs::remove_file(entry.path());
        }
    }

    Ok(count)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_format_file_size() {
        assert_eq!(format_file_size(500, false), "500 B");
        assert_eq!(format_file_size(1024, false), "1.0 KB");
        assert_eq!(format_file_size(1024 * 1024, false), "1.0 MB");
        assert_eq!(format_file_size(1024 * 1024 * 1024 * 2, false), "2.0 GB");
        assert_eq!(format_file_size(12345, true), "--");
    }

    #[test]
    fn test_detect_mime_type() {
        assert_eq!(detect_mime_type(Path::new("pic.png")), "image/png");
        assert_eq!(detect_mime_type(Path::new("doc.pdf")), "application/pdf");
        assert_eq!(detect_mime_type(Path::new("main.rs")), "text/rust");
        assert_eq!(detect_mime_type(Path::new("unknown.xyz123")), "application/octet-stream");
    }

    #[test]
    fn test_app_data_paths_generation() {
        let paths = get_app_data_paths("org.example.myapp", false, None);
        assert_eq!(paths.len(), 4);
        assert!(paths[0].to_string_lossy().contains(".config"));
        assert!(paths[1].to_string_lossy().contains(".local"));
        assert!(paths[2].to_string_lossy().contains(".cache"));

        let fp_paths = get_app_data_paths("org.example.myapp", true, Some("org.example.myapp"));
        assert_eq!(fp_paths.len(), 5);
        assert!(fp_paths[4].to_string_lossy().contains(".var"));
    }
}
