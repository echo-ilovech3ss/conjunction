use std::collections::HashMap;
use std::fs;
use std::io::{self, BufRead, BufReader};
use std::path::{Path, PathBuf};

/// Detect MIME type for a file or directory path
pub fn detect_mime(path: &Path) -> String {
    if path.is_dir() {
        return "inode/directory".to_string();
    }
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();
    match ext.as_str() {
        "txt" | "log" | "rs" | "c" | "cpp" | "h" | "py" | "sh" | "js" | "ts" | "qml" | "json"
        | "toml" | "yaml" | "yml" | "xml" | "ini" | "conf" | "md" => "text/plain".to_string(),
        "html" | "htm" => "text/html".to_string(),
        "pdf" => "application/pdf".to_string(),
        "png" => "image/png".to_string(),
        "jpg" | "jpeg" => "image/jpeg".to_string(),
        "gif" => "image/gif".to_string(),
        "svg" => "image/svg+xml".to_string(),
        "webp" => "image/webp".to_string(),
        "mp3" | "wav" | "flac" | "ogg" => "audio/mpeg".to_string(),
        "mp4" | "mkv" | "webm" | "avi" => "video/mp4".to_string(),
        "zip" => "application/zip".to_string(),
        "tar" | "gz" | "xz" | "bz2" => "application/x-tar".to_string(),
        _ => "application/octet-stream".to_string(),
    }
}

/// Parse a FreeDesktop mimeapps.list file, extracting the [Default Applications] map
pub fn parse_mimeapps_file(path: &Path) -> HashMap<String, Vec<String>> {
    let mut defaults = HashMap::new();
    let file = match fs::File::open(path) {
        Ok(f) => f,
        Err(_) => return defaults,
    };

    let reader = BufReader::new(file);
    let mut in_default_section = false;

    for line_res in reader.lines() {
        let line = match line_res {
            Ok(l) => l.trim().to_string(),
            Err(_) => continue,
        };

        if line.starts_with('#') || line.is_empty() {
            continue;
        }

        if line.starts_with('[') && line.ends_with(']') {
            let section = &line[1..line.len() - 1];
            in_default_section = section == "Default Applications";
            continue;
        }

        if in_default_section {
            if let Some((mime, apps_str)) = line.split_once('=') {
                let mime = mime.trim().to_string();
                let apps: Vec<String> = apps_str
                    .split(';')
                    .map(|s| s.trim().to_string())
                    .filter(|s| !s.is_empty())
                    .collect();
                if !apps.is_empty() {
                    defaults.insert(mime, apps);
                }
            }
        }
    }

    defaults
}

/// Resolve the default desktop application ID for a MIME type or URL scheme
pub fn resolve_default_handler(mime_or_scheme: &str, user_home: &Path) -> Option<String> {
    // 1. User configuration (~/.config/mimeapps.list)
    let user_mimeapps = user_home.join(".config").join("mimeapps.list");
    let user_map = parse_mimeapps_file(&user_mimeapps);
    if let Some(apps) = user_map.get(mime_or_scheme) {
        if let Some(first) = apps.first() {
            return Some(first.clone());
        }
    }

    // 2. System fallbacks
    let system_paths = [
        PathBuf::from("/etc/xdg/mimeapps.list"),
        PathBuf::from("/usr/share/applications/mimeapps.list"),
        PathBuf::from("/usr/local/share/applications/mimeapps.list"),
    ];

    for path in &system_paths {
        let map = parse_mimeapps_file(path);
        if let Some(apps) = map.get(mime_or_scheme) {
            if let Some(first) = apps.first() {
                return Some(first.clone());
            }
        }
    }

    None
}

/// Update ~/.config/mimeapps.list with a preferred default application
pub fn set_default_handler(mime_or_scheme: &str, desktop_id: &str, user_home: &Path) -> io::Result<()> {
    let config_dir = user_home.join(".config");
    fs::create_dir_all(&config_dir)?;
    let mimeapps_path = config_dir.join("mimeapps.list");

    let mut lines = Vec::new();
    let mut in_default_section = false;
    let mut default_section_found = false;
    let mut updated = false;

    if mimeapps_path.exists() {
        let file = fs::File::open(&mimeapps_path)?;
        let reader = BufReader::new(file);

        for line_res in reader.lines() {
            let line = line_res?;
            let trimmed = line.trim();

            if trimmed.starts_with('[') && trimmed.ends_with(']') {
                let section = &trimmed[1..trimmed.len() - 1];
                if in_default_section && !updated {
                    // Insert before exiting default section if not replaced yet
                    lines.push(format!("{}={}", mime_or_scheme, desktop_id));
                    updated = true;
                }
                in_default_section = section == "Default Applications";
                if in_default_section {
                    default_section_found = true;
                }
                lines.push(line);
                continue;
            }

            if in_default_section {
                if let Some((k, _)) = trimmed.split_once('=') {
                    if k.trim() == mime_or_scheme {
                        lines.push(format!("{}={}", mime_or_scheme, desktop_id));
                        updated = true;
                        continue;
                    }
                }
            }

            lines.push(line);
        }

        if in_default_section && !updated {
            lines.push(format!("{}={}", mime_or_scheme, desktop_id));
            updated = true;
        }
    }

    if !default_section_found {
        lines.push("[Default Applications]".to_string());
        lines.push(format!("{}={}", mime_or_scheme, desktop_id));
    } else if !updated {
        // If default section existed but wasn't updated (e.g. was empty at end of file)
        let mut new_lines = Vec::new();
        for l in lines {
            let is_sec = l.trim() == "[Default Applications]";
            new_lines.push(l);
            if is_sec {
                new_lines.push(format!("{}={}", mime_or_scheme, desktop_id));
            }
        }
        lines = new_lines;
    }

    let output = lines.join("\n") + "\n";
    fs::write(mimeapps_path, output)?;
    Ok(())
}
