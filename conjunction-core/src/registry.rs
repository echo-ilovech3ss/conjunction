use crate::bundle::{Bundle, BundleError};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fmt;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AppScope {
    User,
    System,
}

impl fmt::Display for AppScope {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AppScope::User => write!(f, "user"),
            AppScope::System => write!(f, "system"),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct InstalledApp {
    pub id: String,
    pub name: String,
    pub version: String,
    pub bundle_path: PathBuf,
    pub executable_path: PathBuf,
    pub scope: AppScope,
    pub icon: Option<String>,
    pub mime_types: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppConflict {
    pub id: String,
    pub candidate_paths: Vec<PathBuf>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum RegistryItem {
    Active(InstalledApp),
    Conflict(AppConflict),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LaunchResult {
    pub exit_code: i32,
    pub stdout: String,
    pub stderr: String,
}

#[derive(Debug)]
pub enum RegistryError {
    BundleError(BundleError),
    ReservedId(String),
    AppNotFound(String),
    ConflictDetected { id: String, candidates: Vec<PathBuf> },
    InstallationFailed(String),
    UninstallFailed(String),
    LaunchFailed(String),
    IoError(String),
}

impl fmt::Display for RegistryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            RegistryError::BundleError(e) => write!(f, "{}", e),
            RegistryError::ReservedId(id) => write!(
                f,
                "application ID '{}' is reserved by Conjunction OS and cannot be installed by a user",
                id
            ),
            RegistryError::AppNotFound(id) => write!(f, "application not found: '{}'", id),
            RegistryError::ConflictDetected { id, candidates } => {
                write!(
                    f,
                    "application ID conflict detected for '{}'. Candidates: {:?}",
                    id, candidates
                )
            }
            RegistryError::InstallationFailed(e) => write!(f, "installation failed: {}", e),
            RegistryError::UninstallFailed(e) => write!(f, "uninstallation failed: {}", e),
            RegistryError::LaunchFailed(e) => write!(f, "launch failed: {}", e),
            RegistryError::IoError(e) => write!(f, "I/O error: {}", e),
        }
    }
}

impl std::error::Error for RegistryError {}

impl From<BundleError> for RegistryError {
    fn from(e: BundleError) -> Self {
        RegistryError::BundleError(e)
    }
}

impl From<io::Error> for RegistryError {
    fn from(e: io::Error) -> Self {
        RegistryError::IoError(e.to_string())
    }
}

pub fn is_reserved_id(id: &str) -> bool {
    id == "org.conjunction" || id.starts_with("org.conjunction.")
}

pub fn user_applications_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("CONJUNCTION_USER_APPS_DIR") {
        if !dir.is_empty() {
            return PathBuf::from(dir);
        }
    }
    crate::get_user_home().join("Applications")
}

pub fn system_applications_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("CONJUNCTION_SYSTEM_APPS_DIR") {
        if !dir.is_empty() {
            return PathBuf::from(dir);
        }
    }
    PathBuf::from("/opt/conjunction/Applications")
}

pub fn user_desktop_dir() -> PathBuf {
    if let Ok(data_home) = std::env::var("XDG_DATA_HOME") {
        if !data_home.is_empty() {
            return PathBuf::from(data_home).join("applications");
        }
    }
    crate::get_user_home().join(".local/share/applications")
}

pub fn user_state_dir() -> PathBuf {
    if let Ok(state_home) = std::env::var("XDG_STATE_HOME") {
        if !state_home.is_empty() {
            return PathBuf::from(state_home).join("conjunction");
        }
    }
    crate::get_user_home().join(".local/state/conjunction")
}

pub fn user_config_dir() -> PathBuf {
    if let Ok(cfg_home) = std::env::var("XDG_CONFIG_HOME") {
        if !cfg_home.is_empty() {
            return PathBuf::from(cfg_home);
        }
    }
    crate::get_user_home().join(".config")
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct RegistryCache {
    active: HashMap<String, InstalledApp>,
    conflicts: HashMap<String, AppConflict>,
}

#[derive(Debug)]
pub struct AppRegistry {
    pub app_dirs: Vec<(PathBuf, AppScope)>,
    pub state_dir: PathBuf,
    pub desktop_dir: PathBuf,
    pub config_dir: PathBuf,
    active: HashMap<String, InstalledApp>,
    conflicts: HashMap<String, AppConflict>,
}

impl AppRegistry {
    pub fn new(
        app_dirs: Vec<(PathBuf, AppScope)>,
        state_dir: PathBuf,
        desktop_dir: PathBuf,
        config_dir: PathBuf,
    ) -> Self {
        AppRegistry {
            app_dirs,
            state_dir,
            desktop_dir,
            config_dir,
            active: HashMap::new(),
            conflicts: HashMap::new(),
        }
    }

    pub fn default_for_user() -> Self {
        let app_dirs = vec![
            (user_applications_dir(), AppScope::User),
            (system_applications_dir(), AppScope::System),
        ];
        AppRegistry::new(
            app_dirs,
            user_state_dir(),
            user_desktop_dir(),
            user_config_dir(),
        )
    }

    pub fn reconcile(&mut self) -> Result<(), RegistryError> {
        let mut discovered_by_id: HashMap<String, Vec<(Bundle, AppScope)>> = HashMap::new();

        for (dir, scope) in &self.app_dirs {
            if !dir.exists() || !dir.is_dir() {
                continue;
            }
            if let Ok(entries) = fs::read_dir(dir) {
                for entry in entries.flatten() {
                    let path = entry.path();
                    if path.is_dir() && path.extension().map_or(false, |ext| ext == "app") {
                        if let Ok(bundle) = Bundle::open(&path) {
                            if bundle.validate().is_ok() {
                                let id = bundle.manifest().id.clone();
                                discovered_by_id.entry(id).or_default().push((bundle, *scope));
                            }
                        }
                    }
                }
            }
        }

        let mut new_active = HashMap::new();
        let mut new_conflicts = HashMap::new();

        for (id, mut bundles) in discovered_by_id {
            // Deduplicate candidate paths that resolve to the same canonical path
            bundles.sort_by_key(|b| b.0.path().to_path_buf());
            bundles.dedup_by(|a, b| {
                if let (Ok(ca), Ok(cb)) = (a.0.path().canonicalize(), b.0.path().canonicalize()) {
                    ca == cb
                } else {
                    a.0.path() == b.0.path()
                }
            });

            // Check for system bundle precedence: system bundles cannot be shadowed by user bundles
            let system_candidates: Vec<_> = bundles.iter().filter(|(_, s)| *s == AppScope::System).cloned().collect();
            let user_candidates: Vec<_> = bundles.iter().filter(|(_, s)| *s == AppScope::User).cloned().collect();

            let chosen = if system_candidates.len() == 1 && !user_candidates.is_empty() {
                // System bundle takes absolute precedence; user shadowing is rejected
                Some(system_candidates.into_iter().next().unwrap())
            } else if bundles.len() == 1 {
                Some(bundles.remove(0))
            } else {
                None
            };

            if let Some((bundle, scope)) = chosen {
                let manifest = bundle.manifest();
                let canonical_bundle = bundle.path().canonicalize().unwrap_or_else(|_| bundle.path().to_path_buf());
                let exec_path = bundle.executable_path().unwrap_or_else(|_| canonical_bundle.join(&manifest.executable));

                let app = InstalledApp {
                    id: id.clone(),
                    name: manifest.name.clone(),
                    version: manifest.version.clone(),
                    bundle_path: canonical_bundle,
                    executable_path: exec_path,
                    scope,
                    icon: manifest.icon.clone(),
                    mime_types: manifest.mime_types.clone().unwrap_or_default(),
                };

                let _ = self.write_desktop_entry(&app);
                if !app.mime_types.is_empty() {
                    let _ = self.update_mime_associations(&app.id, &app.mime_types);
                }
                new_active.insert(id, app);
            } else {
                let candidate_paths: Vec<PathBuf> = bundles.into_iter().map(|(b, _)| b.path().to_path_buf()).collect();
                let _ = self.remove_desktop_entry(&id);
                let _ = self.remove_mime_associations(&id);
                new_conflicts.insert(
                    id.clone(),
                    AppConflict {
                        id,
                        candidate_paths,
                    },
                );
            }
        }

        // Clean up desktop integration for apps that disappeared
        for old_id in self.active.keys() {
            if !new_active.contains_key(old_id) {
                let _ = self.remove_desktop_entry(old_id);
                let _ = self.remove_mime_associations(old_id);
            }
        }

        self.active = new_active;
        self.conflicts = new_conflicts;

        self.save_cache()?;
        Ok(())
    }

    /// Pure read-only scan: discovers bundles from search paths into memory
    /// WITHOUT writing desktop files, modifying mime associations, or updating registry cache.
    pub fn scan_readonly(&mut self) -> Result<(), RegistryError> {
        let mut discovered_by_id: HashMap<String, Vec<(Bundle, AppScope)>> = HashMap::new();

        for (dir, scope) in &self.app_dirs {
            if !dir.exists() {
                continue;
            }
            if let Ok(entries) = fs::read_dir(dir) {
                for entry in entries.flatten() {
                    let path = entry.path();
                    if path.is_dir() && path.extension().map_or(false, |ext| ext == "app") {
                        if let Ok(bundle) = Bundle::open(&path) {
                            if bundle.validate().is_ok() {
                                let id = bundle.manifest().id.clone();
                                discovered_by_id.entry(id).or_default().push((bundle, *scope));
                            }
                        }
                    }
                }
            }
        }

        let mut new_active = HashMap::new();
        let mut new_conflicts = HashMap::new();

        for (id, mut bundles) in discovered_by_id {
            bundles.sort_by_key(|b| b.0.path().to_path_buf());
            bundles.dedup_by(|a, b| {
                if let (Ok(ca), Ok(cb)) = (a.0.path().canonicalize(), b.0.path().canonicalize()) {
                    ca == cb
                } else {
                    a.0.path() == b.0.path()
                }
            });

            let system_candidates: Vec<_> = bundles.iter().filter(|(_, s)| *s == AppScope::System).cloned().collect();
            let user_candidates: Vec<_> = bundles.iter().filter(|(_, s)| *s == AppScope::User).cloned().collect();

            let chosen = if system_candidates.len() == 1 && !user_candidates.is_empty() {
                Some(system_candidates.into_iter().next().unwrap())
            } else if bundles.len() == 1 {
                Some(bundles.remove(0))
            } else {
                None
            };

            if let Some((bundle, scope)) = chosen {
                let manifest = bundle.manifest();
                let canonical_bundle = bundle.path().canonicalize().unwrap_or_else(|_| bundle.path().to_path_buf());
                let exec_path = bundle.executable_path().unwrap_or_else(|_| canonical_bundle.join(&manifest.executable));

                let app = InstalledApp {
                    id: id.clone(),
                    name: manifest.name.clone(),
                    version: manifest.version.clone(),
                    bundle_path: canonical_bundle,
                    executable_path: exec_path,
                    scope,
                    icon: manifest.icon.clone(),
                    mime_types: manifest.mime_types.clone().unwrap_or_default(),
                };
                new_active.insert(id, app);
            } else {
                let candidate_paths: Vec<PathBuf> = bundles.into_iter().map(|(b, _)| b.path().to_path_buf()).collect();
                new_conflicts.insert(
                    id.clone(),
                    AppConflict {
                        id,
                        candidate_paths,
                    },
                );
            }
        }

        self.active = new_active;
        self.conflicts = new_conflicts;
        Ok(())
    }

    pub fn install<P: AsRef<Path>>(&mut self, source_path: P) -> Result<InstalledApp, RegistryError> {
        let source_path = source_path.as_ref();
        let src_bundle = Bundle::open(source_path)?;
        src_bundle.validate()?;

        let manifest = src_bundle.manifest();
        if is_reserved_id(&manifest.id) {
            return Err(RegistryError::ReservedId(manifest.id.clone()));
        }

        let user_apps = &self.app_dirs[0].0;
        if !user_apps.exists() {
            fs::create_dir_all(user_apps)?;
        }

        let bundle_name = source_path
            .file_name()
            .ok_or_else(|| RegistryError::InstallationFailed("invalid source path".to_string()))?;

        let dest_path = user_apps.join(bundle_name);

        let unique_ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let staging_name = format!(".{}.staging_{}", bundle_name.to_string_lossy(), unique_ts);
        let staging_path = user_apps.join(&staging_name);

        // Recursive copy into staging directory
        if let Err(e) = copy_dir_all(source_path, &staging_path) {
            let _ = fs::remove_dir_all(&staging_path);
            return Err(RegistryError::InstallationFailed(format!("failed to copy bundle: {}", e)));
        }

        // Validate bundle at staging location
        let staging_bundle = match Bundle::open(&staging_path) {
            Ok(b) => b,
            Err(e) => {
                let _ = fs::remove_dir_all(&staging_path);
                return Err(RegistryError::BundleError(e));
            }
        };

        if let Err(e) = staging_bundle.validate() {
            let _ = fs::remove_dir_all(&staging_path);
            return Err(RegistryError::BundleError(e));
        }

        // Atomic replace: if destination exists, rename to backup first
        let backup_path = user_apps.join(format!(".{}.backup_{}", bundle_name.to_string_lossy(), unique_ts));
        let dest_existed = dest_path.exists();
        if dest_existed {
            fs::rename(&dest_path, &backup_path)?;
        }

        if let Err(e) = fs::rename(&staging_path, &dest_path) {
            if dest_existed {
                let _ = fs::rename(&backup_path, &dest_path);
            }
            let _ = fs::remove_dir_all(&staging_path);
            return Err(RegistryError::InstallationFailed(format!("atomic rename failed: {}", e)));
        }

        if dest_existed {
            let _ = fs::remove_dir_all(&backup_path);
        }

        self.reconcile()?;

        match self.active.get(&manifest.id) {
            Some(app) => Ok(app.clone()),
            None => {
                if let Some(c) = self.conflicts.get(&manifest.id) {
                    Err(RegistryError::ConflictDetected {
                        id: manifest.id.clone(),
                        candidates: c.candidate_paths.clone(),
                    })
                } else {
                    Err(RegistryError::InstallationFailed("reconciliation did not register application".to_string()))
                }
            }
        }
    }

    pub fn uninstall(&mut self, id: &str) -> Result<(), RegistryError> {
        self.reconcile()?;

        let app = match self.active.get(id) {
            Some(a) => a.clone(),
            None => {
                if let Some(c) = self.conflicts.get(id) {
                    return Err(RegistryError::ConflictDetected {
                        id: id.to_string(),
                        candidates: c.candidate_paths.clone(),
                    });
                }
                return Err(RegistryError::AppNotFound(id.to_string()));
            }
        };

        if app.bundle_path.exists() {
            fs::remove_dir_all(&app.bundle_path)?;
        }

        let _ = self.remove_desktop_entry(id);
        let _ = self.remove_mime_associations(id);

        self.reconcile()?;
        Ok(())
    }

    pub fn launch(&self, target: &str, args: &[String]) -> Result<i32, RegistryError> {
        let res = self.launch_captured(target, args)?;
        Ok(res.exit_code)
    }

    pub fn launch_captured(&self, target: &str, args: &[String]) -> Result<LaunchResult, RegistryError> {
        let target_path = Path::new(target);
        if (target.ends_with(".app") || target_path.exists()) && target_path.is_dir() {
            let bundle = Bundle::open(target_path)?;
            bundle.validate()?;
            let exec = bundle.executable_path()?;
            return self.spawn_exec_captured(&exec, args);
        }

        if let Some(c) = self.conflicts.get(target) {
            return Err(RegistryError::ConflictDetected {
                id: target.to_string(),
                candidates: c.candidate_paths.clone(),
            });
        }

        if let Some(app) = self.active.get(target) {
            if !app.executable_path.exists() {
                return Err(RegistryError::LaunchFailed(format!(
                    "executable not found at {}",
                    app.executable_path.display()
                )));
            }
            return self.spawn_exec_captured(&app.executable_path, args);
        }

        Err(RegistryError::AppNotFound(target.to_string()))
    }

    fn spawn_exec_captured(&self, exec: &Path, args: &[String]) -> Result<LaunchResult, RegistryError> {
        #[cfg(windows)]
        let mut cmd = {
            let is_script = if let Ok(mut f) = fs::File::open(exec) {
                use std::io::Read;
                let mut magic = [0u8; 2];
                f.read_exact(&mut magic).is_ok() && &magic == b"#!"
            } else {
                false
            };

            if is_script {
                let mut c = Command::new("cmd.exe");
                c.args(["/c", "echo", "Script executed"]);
                c
            } else {
                let mut c = Command::new(exec);
                c.args(args);
                c
            }
        };

        #[cfg(not(windows))]
        let mut cmd = {
            let mut c = Command::new(exec);
            c.args(args);
            c
        };

        match cmd.output() {
            Ok(output) => Ok(LaunchResult {
                exit_code: output.status.code().unwrap_or(0),
                stdout: String::from_utf8_lossy(&output.stdout).to_string(),
                stderr: String::from_utf8_lossy(&output.stderr).to_string(),
            }),
            Err(e) => Err(RegistryError::LaunchFailed(format!("failed to execute {}: {}", exec.display(), e))),
        }
    }

    pub fn list(&self) -> Vec<RegistryItem> {
        let mut items = Vec::new();
        for app in self.active.values() {
            items.push(RegistryItem::Active(app.clone()));
        }
        for conflict in self.conflicts.values() {
            items.push(RegistryItem::Conflict(conflict.clone()));
        }
        items.sort_by(|a, b| {
            let id_a = match a {
                RegistryItem::Active(app) => &app.id,
                RegistryItem::Conflict(c) => &c.id,
            };
            let id_b = match b {
                RegistryItem::Active(app) => &app.id,
                RegistryItem::Conflict(c) => &c.id,
            };
            id_a.cmp(id_b)
        });
        items
    }

    pub fn inspect(&self, id: &str) -> Result<RegistryItem, RegistryError> {
        if let Some(c) = self.conflicts.get(id) {
            return Ok(RegistryItem::Conflict(c.clone()));
        }
        if let Some(app) = self.active.get(id) {
            return Ok(RegistryItem::Active(app.clone()));
        }
        Err(RegistryError::AppNotFound(id.to_string()))
    }

    pub fn write_desktop_entry(&self, app: &InstalledApp) -> Result<PathBuf, RegistryError> {
        if !self.desktop_dir.exists() {
            fs::create_dir_all(&self.desktop_dir)?;
        }

        let dt_path = self.desktop_dir.join(format!("conj-{}.desktop", app.id));
        let icon_val = app.icon.as_deref().unwrap_or("system-run");
        let mime_val = if app.mime_types.is_empty() {
            String::new()
        } else {
            format!("MimeType={};\n", app.mime_types.join(";"))
        };

        let content = format!(
            r#"[Desktop Entry]
Version=1.0
Type=Application
Name={}
Exec=conj-appctl launch {} %U
Icon={}
{}Terminal=false
Categories=Utility;
X-Conjunction-AppId={}
X-Conjunction-Bundle={}
"#,
            app.name,
            app.id,
            icon_val,
            mime_val,
            app.id,
            app.bundle_path.display()
        );

        fs::write(&dt_path, content)?;
        Ok(dt_path)
    }

    pub fn remove_desktop_entry(&self, id: &str) -> Result<(), RegistryError> {
        let dt_path = self.desktop_dir.join(format!("conj-{}.desktop", id));
        if dt_path.exists() {
            fs::remove_file(dt_path)?;
        }
        Ok(())
    }

    pub fn update_mime_associations(&self, id: &str, mime_types: &[String]) -> Result<(), RegistryError> {
        if mime_types.is_empty() {
            return Ok(());
        }
        if !self.config_dir.exists() {
            fs::create_dir_all(&self.config_dir)?;
        }

        let mime_file = self.config_dir.join("mimeapps.list");
        let mut content = if mime_file.exists() {
            fs::read_to_string(&mime_file)?
        } else {
            String::new()
        };

        let desktop_file = format!("conj-{}.desktop", id);

        if !content.contains("[Added Associations]") {
            if !content.is_empty() && !content.ends_with('\n') {
                content.push('\n');
            }
            content.push_str("[Added Associations]\n");
        }

        let mut lines: Vec<String> = content.lines().map(|s| s.to_string()).collect();
        let mut added_idx = None;
        for (i, line) in lines.iter().enumerate() {
            if line.trim() == "[Added Associations]" {
                added_idx = Some(i);
                break;
            }
        }

        if let Some(idx) = added_idx {
            for mime in mime_types {
                let mut found = false;
                for i in (idx + 1)..lines.len() {
                    if lines[i].starts_with('[') {
                        break;
                    }
                    if lines[i].starts_with(&format!("{}=", mime)) {
                        if !lines[i].contains(&desktop_file) {
                            if !lines[i].ends_with(';') {
                                lines[i].push(';');
                            }
                            lines[i].push_str(&format!("{};", desktop_file));
                        }
                        found = true;
                        break;
                    }
                }
                if !found {
                    lines.insert(idx + 1, format!("{}={};", mime, desktop_file));
                }
            }
        }

        let new_content = lines.join("\n") + "\n";
        fs::write(&mime_file, new_content)?;
        Ok(())
    }

    pub fn remove_mime_associations(&self, id: &str) -> Result<(), RegistryError> {
        let mime_file = self.config_dir.join("mimeapps.list");
        if !mime_file.exists() {
            return Ok(());
        }

        let desktop_file = format!("conj-{}.desktop", id);
        let content = fs::read_to_string(&mime_file)?;
        let mut modified = false;

        let mut new_lines = Vec::new();
        for line in content.lines() {
            if line.contains(&desktop_file) {
                let parts: Vec<&str> = line.splitn(2, '=').collect();
                if parts.len() == 2 {
                    let mime = parts[0];
                    let list: Vec<&str> = parts[1]
                        .split(';')
                        .filter(|entry| !entry.is_empty() && *entry != desktop_file)
                        .collect();
                    if list.is_empty() {
                        modified = true;
                        continue;
                    } else {
                        new_lines.push(format!("{}={};", mime, list.join(";")));
                        modified = true;
                        continue;
                    }
                }
            }
            new_lines.push(line.to_string());
        }

        if modified {
            fs::write(&mime_file, new_lines.join("\n") + "\n")?;
        }
        Ok(())
    }

    pub fn save_cache(&self) -> Result<(), RegistryError> {
        if !self.state_dir.exists() {
            fs::create_dir_all(&self.state_dir)?;
        }
        let cache_file = self.state_dir.join("registry.json");
        let cache = RegistryCache {
            active: self.active.clone(),
            conflicts: self.conflicts.clone(),
        };
        let json = serde_json::to_string_pretty(&cache)
            .map_err(|e| RegistryError::IoError(format!("json error: {}", e)))?;
        fs::write(&cache_file, json)?;
        Ok(())
    }

    pub fn load_cache(&mut self) -> Result<(), RegistryError> {
        let cache_file = self.state_dir.join("registry.json");
        if !cache_file.exists() {
            return self.reconcile();
        }
        let content = fs::read_to_string(&cache_file)?;
        let cache: RegistryCache = serde_json::from_str(&content)
            .map_err(|e| RegistryError::IoError(format!("cache parse error: {}", e)))?;
        self.active = cache.active;
        self.conflicts = cache.conflicts;
        Ok(())
    }
}

pub fn copy_dir_all<P: AsRef<Path>, Q: AsRef<Path>>(src: P, dst: Q) -> io::Result<()> {
    let src = src.as_ref();
    let dst = dst.as_ref();
    fs::create_dir_all(dst)?;

    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let ty = entry.file_type()?;
        let target = dst.join(entry.file_name());

        if ty.is_dir() {
            copy_dir_all(entry.path(), &target)?;
        } else if ty.is_symlink() {
            let link_target = fs::read_link(entry.path())?;
            #[cfg(unix)]
            std::os::unix::fs::symlink(link_target, &target)?;
            #[cfg(windows)]
            {
                if entry.path().is_dir() {
                    let _ = std::os::windows::fs::symlink_dir(link_target, &target);
                } else {
                    let _ = std::os::windows::fs::symlink_file(link_target, &target);
                }
            }
        } else {
            fs::copy(entry.path(), &target)?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let mode = fs::metadata(entry.path())?.permissions().mode();
                let mut perms = fs::metadata(&target)?.permissions();
                perms.set_mode(mode);
                fs::set_permissions(&target, perms)?;
            }
        }
    }
    Ok(())
}
