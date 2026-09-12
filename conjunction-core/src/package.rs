use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PacmanPackageInfo {
    pub package_name: String,
    pub package_version: Option<String>,
}

pub trait PackageManagerQuery: Send + Sync {
    fn query_file_owner(&self, path: &Path) -> Option<PacmanPackageInfo> {
        let mut map = self.query_files_owners(&[path]);
        map.remove(path)
    }

    fn query_files_owners(&self, paths: &[&Path]) -> HashMap<PathBuf, PacmanPackageInfo> {
        let mut map = HashMap::new();
        for p in paths {
            if let Some(info) = self.query_file_owner(p) {
                map.insert(p.to_path_buf(), info);
            }
        }
        map
    }
}

pub struct SystemPacmanQuery;

impl PackageManagerQuery for SystemPacmanQuery {
    fn query_file_owner(&self, path: &Path) -> Option<PacmanPackageInfo> {
        let output = Command::new("pacman")
            .args(["-Qo", &path.to_string_lossy()])
            .output()
            .ok()?;

        if !output.status.success() {
            return None;
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        parse_pacman_qo_output(&stdout)
    }

    fn query_files_owners(&self, paths: &[&Path]) -> HashMap<PathBuf, PacmanPackageInfo> {
        if paths.is_empty() {
            return HashMap::new();
        }

        let mut results = HashMap::new();
        for chunk in paths.chunks(50) {
            let mut cmd = Command::new("pacman");
            cmd.arg("-Qo");
            for p in chunk {
                cmd.arg(p.as_os_str());
            }

            if let Ok(output) = cmd.output() {
                let stdout = String::from_utf8_lossy(&output.stdout);
                let parsed = parse_pacman_qo_multi_output(&stdout);
                results.extend(parsed);
            }
        }
        results
    }
}

pub fn parse_pacman_qo_multi_output(output: &str) -> HashMap<PathBuf, PacmanPackageInfo> {
    let mut map = HashMap::new();
    for line in output.lines() {
        if let Some(idx) = line.find(" is owned by ") {
            let file_str = line[..idx].trim();
            let rest = &line[idx + " is owned by ".len()..];
            let parts: Vec<&str> = rest.split_whitespace().collect();
            if let Some(&pkg_name) = parts.first() {
                let pkg_ver = parts.get(1).map(|v| v.to_string());
                map.insert(
                    PathBuf::from(file_str),
                    PacmanPackageInfo {
                        package_name: pkg_name.to_string(),
                        package_version: pkg_ver,
                    },
                );
            }
        }
    }
    map
}

pub fn parse_pacman_qo_output(output: &str) -> Option<PacmanPackageInfo> {
    for line in output.lines() {
        // Format: /usr/share/applications/foo.desktop is owned by package-name 1.2.3-1
        if let Some(idx) = line.find(" is owned by ") {
            let rest = &line[idx + " is owned by ".len()..];
            let parts: Vec<&str> = rest.split_whitespace().collect();
            if let Some(&pkg_name) = parts.first() {
                let pkg_ver = parts.get(1).map(|v| v.to_string());
                return Some(PacmanPackageInfo {
                    package_name: pkg_name.to_string(),
                    package_version: pkg_ver,
                });
            }
        }
    }
    None
}

pub fn is_valid_package_name(name: &str) -> bool {
    if name.is_empty() || name.len() > 128 {
        return false;
    }
    let mut chars = name.chars();
    let first = match chars.next() {
        Some(c) => c,
        None => return false,
    };
    if !first.is_ascii_alphanumeric() {
        return false;
    }
    chars.all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '@' || c == '.' || c == '+' || c == '-')
}

pub struct MultiAppDetector;

impl MultiAppDetector {
    pub fn compute_sibling_map(apps: &[(String, Option<String>)]) -> HashMap<String, Vec<String>> {
        // apps is a slice of (app_id, Option<package_name>)
        let mut pkg_to_apps: HashMap<String, Vec<String>> = HashMap::new();
        for (app_id, pkg) in apps {
            if let Some(p) = pkg {
                pkg_to_apps.entry(p.clone()).or_default().push(app_id.clone());
            }
        }

        let mut app_to_siblings: HashMap<String, Vec<String>> = HashMap::new();
        for (_pkg, app_list) in pkg_to_apps {
            for app in &app_list {
                let siblings: Vec<String> = app_list
                    .iter()
                    .filter(|a| *a != app)
                    .cloned()
                    .collect();
                app_to_siblings.insert(app.clone(), siblings);
            }
        }
        app_to_siblings
    }
}

pub fn request_sysd_remove_package(package_name: &str, socket_override: Option<&Path>) -> Result<(), String> {
    #[cfg(unix)]
    {
        use std::io::{BufRead, BufReader, Write};
        use std::os::unix::net::UnixStream;

        let sock_path = socket_override
            .map(|p| p.to_path_buf())
            .unwrap_or_else(|| PathBuf::from("/run/conjunction/sysd.sock"));

        if !sock_path.exists() {
            return Err(format!(
                "privileged system package service (conj-sysd) is not running (socket {} not found)",
                sock_path.display()
            ));
        }

        let mut stream = UnixStream::connect(&sock_path)
            .map_err(|e| format!("cannot connect to conj-sysd at {}: {}", sock_path.display(), e))?;

        let req = serde_json::json!({
            "action": "RemovePacmanPackage",
            "package": package_name
        });

        let req_str = serde_json::to_string(&req).map_err(|e| e.to_string())?;
        stream.write_all(req_str.as_bytes()).map_err(|e| e.to_string())?;
        stream.write_all(b"\n").map_err(|e| e.to_string())?;
        stream.flush().map_err(|e| e.to_string())?;

        let mut reader = BufReader::new(stream);
        let mut line = String::new();
        reader.read_line(&mut line).map_err(|e| e.to_string())?;

        let resp: serde_json::Value = serde_json::from_str(&line).map_err(|e| e.to_string())?;
        if resp.get("success").and_then(|s| s.as_bool()).unwrap_or(false) {
            Ok(())
        } else {
            let err = resp.get("error").and_then(|e| e.as_str()).unwrap_or("unknown sysd error");
            Err(err.to_string())
        }
    }

    #[cfg(not(unix))]
    {
        let _ = (package_name, socket_override);
        Err("conj-sysd is not supported on non-unix platforms".to_string())
    }
}

#[cfg(test)]
pub struct MockPacmanQuery {
    pub map: HashMap<PathBuf, PacmanPackageInfo>,
}

#[cfg(test)]
impl PackageManagerQuery for MockPacmanQuery {
    fn query_file_owner(&self, path: &Path) -> Option<PacmanPackageInfo> {
        self.map.get(path).cloned()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_pacman_qo_output() {
        let out = "/usr/share/applications/firefox.desktop is owned by firefox 128.0-1\n";
        let info = parse_pacman_qo_output(out).unwrap();
        assert_eq!(info.package_name, "firefox");
        assert_eq!(info.package_version.as_deref(), Some("128.0-1"));
    }

    #[test]
    fn test_parse_pacman_qo_not_owned() {
        let out = "error: No package owns /home/user/.local/share/applications/custom.desktop\n";
        assert!(parse_pacman_qo_output(out).is_none());
    }

    #[test]
    fn test_valid_package_names() {
        assert!(is_valid_package_name("conjunction-phase3-demo"));
        assert!(is_valid_package_name("firefox"));
        assert!(is_valid_package_name("gcc-libs"));
        assert!(is_valid_package_name("lib32-glibc"));
        assert!(is_valid_package_name("python@3.10"));

        assert!(!is_valid_package_name(""));
        assert!(!is_valid_package_name("-rf"));
        assert!(!is_valid_package_name("pkg; touch /tmp/pwned"));
        assert!(!is_valid_package_name("pkg|cat"));
        assert!(!is_valid_package_name("../evil"));
        assert!(!is_valid_package_name("pkg$var"));
    }

    #[test]
    fn test_multi_app_package_detection() {
        let app_list = vec![
            ("demo_a".to_string(), Some("conjunction-phase3-suite".to_string())),
            ("demo_b".to_string(), Some("conjunction-phase3-suite".to_string())),
            ("standalone".to_string(), Some("other-pkg".to_string())),
            ("user_app".to_string(), None),
        ];

        let siblings = MultiAppDetector::compute_sibling_map(&app_list);
        assert_eq!(siblings.get("demo_a").unwrap(), &vec!["demo_b".to_string()]);
        assert_eq!(siblings.get("demo_b").unwrap(), &vec!["demo_a".to_string()]);
        assert!(siblings.get("standalone").unwrap().is_empty());
        assert!(siblings.get("user_app").is_none());
    }
}
