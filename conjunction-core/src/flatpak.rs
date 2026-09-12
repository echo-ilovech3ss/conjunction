use crate::registry::AppScope;
use std::path::Path;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FlatpakAppInfo {
    pub id: String,
    pub scope: AppScope,
    pub branch: Option<String>,
    pub arch: Option<String>,
}

impl FlatpakAppInfo {
    pub fn is_flatpak_desktop(path: &Path, x_flatpak: Option<&str>) -> bool {
        if x_flatpak.is_some() {
            return true;
        }
        let p_str = path.to_string_lossy();
        p_str.contains("/flatpak/exports/share/applications")
            || p_str.contains("\\flatpak\\exports\\share\\applications")
    }

    pub fn extract_info(
        desktop_path: &Path,
        x_flatpak: Option<&str>,
        user_home: &Path,
    ) -> Self {
        let id = if let Some(xf) = x_flatpak {
            xf.to_string()
        } else {
            let filename = desktop_path
                .file_name()
                .and_then(|f| f.to_str())
                .unwrap_or_default();
            filename.strip_suffix(".desktop").unwrap_or(filename).to_string()
        };

        let scope = if desktop_path.starts_with(user_home) {
            AppScope::User
        } else {
            AppScope::System
        };

        FlatpakAppInfo {
            id,
            scope,
            branch: None,
            arch: None,
        }
    }

    pub fn build_launch_argv(&self, args: &[String]) -> Vec<String> {
        let mut argv = vec!["flatpak".to_string(), "run".to_string(), self.id.clone()];
        argv.extend_from_slice(args);
        argv
    }

    pub fn build_uninstall_argv(&self) -> Vec<String> {
        match self.scope {
            AppScope::User => vec![
                "flatpak".to_string(),
                "uninstall".to_string(),
                "--user".to_string(),
                "-y".to_string(),
                self.id.clone(),
            ],
            AppScope::System => vec![
                "flatpak".to_string(),
                "uninstall".to_string(),
                "--system".to_string(),
                "-y".to_string(),
                self.id.clone(),
            ],
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn test_is_flatpak_desktop() {
        assert!(FlatpakAppInfo::is_flatpak_desktop(
            Path::new("/var/lib/flatpak/exports/share/applications/org.mozilla.firefox.desktop"),
            None
        ));
        assert!(FlatpakAppInfo::is_flatpak_desktop(
            Path::new("/home/user/.local/share/flatpak/exports/share/applications/org.gimp.GIMP.desktop"),
            None
        ));
        assert!(FlatpakAppInfo::is_flatpak_desktop(
            Path::new("/usr/share/applications/firefox.desktop"),
            Some("org.mozilla.firefox")
        ));
        assert!(!FlatpakAppInfo::is_flatpak_desktop(
            Path::new("/usr/share/applications/firefox.desktop"),
            None
        ));
    }

    #[test]
    fn test_extract_flatpak_info() {
        let home = PathBuf::from("/home/conjunction-test");
        let user_desktop = home.join(".local/share/flatpak/exports/share/applications/org.example.App.desktop");
        let info_user = FlatpakAppInfo::extract_info(&user_desktop, None, &home);
        assert_eq!(info_user.id, "org.example.App");
        assert_eq!(info_user.scope, AppScope::User);

        let sys_desktop = Path::new("/var/lib/flatpak/exports/share/applications/org.example.SysApp.desktop");
        let info_sys = FlatpakAppInfo::extract_info(sys_desktop, None, &home);
        assert_eq!(info_sys.id, "org.example.SysApp");
        assert_eq!(info_sys.scope, AppScope::System);
    }

    #[test]
    fn test_build_launch_and_uninstall_argv() {
        let info = FlatpakAppInfo {
            id: "org.example.App".to_string(),
            scope: AppScope::User,
            branch: None,
            arch: None,
        };
        let launch_argv = info.build_launch_argv(&["--test".to_string()]);
        assert_eq!(launch_argv, vec!["flatpak", "run", "org.example.App", "--test"]);

        let uninst_argv = info.build_uninstall_argv();
        assert_eq!(uninst_argv, vec!["flatpak", "uninstall", "--user", "-y", "org.example.App"]);
    }
}
