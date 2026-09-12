use std::collections::HashMap;
use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OsRelease {
    pub name: String,
    pub pretty_name: String,
    pub id: String,
    pub id_like: String,
    pub build_id: String,
    pub raw: HashMap<String, String>,
}

impl OsRelease {
    pub fn parse(content: &str) -> Self {
        let mut raw = HashMap::new();
        for line in content.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            if let Some((k, v)) = line.split_once('=') {
                let k = k.trim().to_string();
                let v = v.trim().trim_matches('"').trim_matches('\'').to_string();
                raw.insert(k, v);
            }
        }

        Self {
            name: raw.get("NAME").cloned().unwrap_or_default(),
            pretty_name: raw.get("PRETTY_NAME").cloned().unwrap_or_default(),
            id: raw.get("ID").cloned().unwrap_or_default(),
            id_like: raw.get("ID_LIKE").cloned().unwrap_or_default(),
            build_id: raw.get("BUILD_ID").cloned().unwrap_or_default(),
            raw,
        }
    }

    pub fn is_conjunction(&self) -> bool {
        self.id == "conjunction" && (self.id_like == "arch" || self.id_like.contains("arch"))
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WaylandSessionEntry {
    pub name: String,
    pub exec: String,
    pub entry_type: String,
    pub desktop_names: Vec<String>,
}

impl WaylandSessionEntry {
    pub fn parse(content: &str) -> Option<Self> {
        let mut name = String::new();
        let mut exec = String::new();
        let mut entry_type = String::new();
        let mut desktop_names = Vec::new();

        for line in content.lines() {
            let line = line.trim();
            if let Some(val) = line.strip_prefix("Name=") {
                name = val.trim().to_string();
            } else if let Some(val) = line.strip_prefix("Exec=") {
                exec = val.trim().to_string();
            } else if let Some(val) = line.strip_prefix("Type=") {
                entry_type = val.trim().to_string();
            } else if let Some(val) = line.strip_prefix("DesktopNames=") {
                desktop_names = val
                    .split(';')
                    .map(|s| s.trim().to_string())
                    .filter(|s| !s.is_empty())
                    .collect();
            }
        }

        if name.is_empty() || exec.is_empty() {
            None
        } else {
            Some(Self {
                name,
                exec,
                entry_type,
                desktop_names,
            })
        }
    }

    pub fn is_valid_conjunction_session(&self) -> bool {
        self.entry_type == "Application"
            && self.exec.contains("conjunction-session")
            && self.desktop_names.iter().any(|d| d == "Conjunction")
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtrfsSubvolume {
    pub mount_point: String,
    pub subvolume: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BtrfsLayoutContract {
    pub subvolumes: Vec<BtrfsSubvolume>,
}

impl BtrfsLayoutContract {
    pub fn default_conjunction() -> Self {
        Self {
            subvolumes: vec![
                BtrfsSubvolume {
                    mount_point: "/".to_string(),
                    subvolume: "/@".to_string(),
                },
                BtrfsSubvolume {
                    mount_point: "/home".to_string(),
                    subvolume: "/@home".to_string(),
                },
                BtrfsSubvolume {
                    mount_point: "/var/log".to_string(),
                    subvolume: "/@var_log".to_string(),
                },
                BtrfsSubvolume {
                    mount_point: "/var/cache/pacman/pkg".to_string(),
                    subvolume: "/@pkg".to_string(),
                },
            ],
        }
    }

    pub fn has_mount_point(&self, mp: &str) -> bool {
        self.subvolumes.iter().any(|s| s.mount_point == mp)
    }

    pub fn get_subvolume_for_mount(&self, mp: &str) -> Option<&str> {
        self.subvolumes
            .iter()
            .find(|s| s.mount_point == mp)
            .map(|s| s.subvolume.as_str())
    }

    /// Verifies that root (/) and home (/home) are strictly segregated subvolumes.
    pub fn has_isolated_home_subvolume(&self) -> bool {
        let root_sub = self.get_subvolume_for_mount("/");
        let home_sub = self.get_subvolume_for_mount("/home");
        match (root_sub, home_sub) {
            (Some(r), Some(h)) => !r.is_empty() && !h.is_empty() && r != h,
            _ => false,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UkiConfig {
    pub default_uki: PathBuf,
    pub fallback_uki: PathBuf,
    pub default_options: String,
}

impl UkiConfig {
    pub fn parse_preset(content: &str) -> Self {
        let mut default_uki = PathBuf::new();
        let mut fallback_uki = PathBuf::new();
        let mut default_options = String::new();

        for line in content.lines() {
            let line = line.trim();
            if let Some(val) = line.strip_prefix("default_uki=") {
                default_uki = PathBuf::from(val.trim().trim_matches('"').trim_matches('\''));
            } else if let Some(val) = line.strip_prefix("fallback_uki=") {
                fallback_uki = PathBuf::from(val.trim().trim_matches('"').trim_matches('\''));
            } else if let Some(val) = line.strip_prefix("default_options=") {
                default_options = val.trim().trim_matches('"').trim_matches('\'').to_string();
            }
        }

        Self {
            default_uki,
            fallback_uki,
            default_options,
        }
    }

    pub fn targets_systemd_boot_efi_linux(&self) -> bool {
        let p_str = self.default_uki.to_string_lossy();
        p_str.contains("EFI/Linux") && p_str.ends_with(".efi")
    }

    pub fn specifies_btrfs_root_subvolume(&self) -> bool {
        self.default_options.contains("rootflags=subvol=@")
    }
}
