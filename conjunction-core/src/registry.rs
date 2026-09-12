use crate::bundle::{Bundle, BundleError};
use crate::desktop_entry::DesktopEntry;
use crate::flatpak::FlatpakAppInfo;
use crate::package::{
    request_sysd_remove_package, MultiAppDetector, PackageManagerQuery, SystemPacmanQuery,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fmt;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Arc;

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

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AppBackend {
    Native,
    DesktopEntry,
    Pacman,
    Flatpak,
}

impl fmt::Display for AppBackend {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AppBackend::Native => write!(f, "native"),
            AppBackend::DesktopEntry => write!(f, "desktop-entry"),
            AppBackend::Pacman => write!(f, "pacman"),
            AppBackend::Flatpak => write!(f, "flatpak"),
        }
    }
}

fn default_backend() -> AppBackend {
    AppBackend::Native
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct InstalledApp {
    pub id: String,
    pub name: String,
    pub version: String,
    pub bundle_path: PathBuf,
    pub executable_path: PathBuf,
    pub scope: AppScope,
    #[serde(default = "default_backend")]
    pub backend: AppBackend,
    pub icon: Option<String>,
    pub mime_types: Vec<String>,
    #[serde(default)]
    pub terminal: bool,
    #[serde(default)]
    pub no_display: bool,
    #[serde(default)]
    pub package_name: Option<String>,
    #[serde(default)]
    pub package_version: Option<String>,
    #[serde(default)]
    pub sibling_apps: Vec<String>,
    #[serde(default)]
    pub flatpak_id: Option<String>,
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
    MultiAppPackageRequiresConfirmation { package: String, siblings: Vec<String> },
    PackageRemovalFailed(String),
    ImmutableSystemApp(String),
    DesktopEntryError(String),
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
            RegistryError::MultiAppPackageRequiresConfirmation { package, siblings } => {
                write!(
                    f,
                    "Package '{}' also provides other applications: {:?}. Use --yes to confirm removal of the entire package.",
                    package, siblings
                )
            }
            RegistryError::PackageRemovalFailed(e) => write!(f, "package removal failed: {}", e),
            RegistryError::ImmutableSystemApp(id) => {
                write!(f, "cannot remove system desktop application '{}'", id)
            }
            RegistryError::DesktopEntryError(e) => write!(f, "desktop entry error: {}", e),
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

pub fn system_desktop_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    if let Ok(data_dirs) = std::env::var("XDG_DATA_DIRS") {
        for p in std::env::split_paths(&data_dirs) {
            dirs.push(p.join("applications"));
        }
    } else {
        dirs.push(PathBuf::from("/usr/local/share/applications"));
        dirs.push(PathBuf::from("/usr/share/applications"));
    }
    dirs.push(PathBuf::from("/var/lib/flatpak/exports/share/applications"));
    dirs
}

pub fn user_desktop_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    dirs.push(user_desktop_dir());
    dirs.push(crate::get_user_home().join(".local/share/flatpak/exports/share/applications"));
    dirs
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

pub struct AppRegistry {
    pub app_dirs: Vec<(PathBuf, AppScope)>,
    pub desktop_dirs: Vec<(PathBuf, AppScope)>,
    pub state_dir: PathBuf,
    pub desktop_dir: PathBuf,
    pub config_dir: PathBuf,
    active: HashMap<String, InstalledApp>,
    conflicts: HashMap<String, AppConflict>,
    package_query: Arc<dyn PackageManagerQuery>,
    sysd_socket: Option<PathBuf>,
}

impl fmt::Debug for AppRegistry {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("AppRegistry")
            .field("app_dirs", &self.app_dirs)
            .field("desktop_dirs", &self.desktop_dirs)
            .field("state_dir", &self.state_dir)
            .field("desktop_dir", &self.desktop_dir)
            .field("config_dir", &self.config_dir)
            .field("active", &self.active)
            .field("conflicts", &self.conflicts)
            .finish()
    }
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
            desktop_dirs: Vec::new(),
            state_dir,
            desktop_dir,
            config_dir,
            active: HashMap::new(),
            conflicts: HashMap::new(),
            package_query: Arc::new(SystemPacmanQuery),
            sysd_socket: None,
        }
    }

    pub fn with_desktop_dirs(mut self, dirs: Vec<(PathBuf, AppScope)>) -> Self {
        self.desktop_dirs = dirs;
        self
    }

    pub fn with_package_query(mut self, q: Arc<dyn PackageManagerQuery>) -> Self {
        self.package_query = q;
        self
    }

    pub fn with_sysd_socket(mut self, s: PathBuf) -> Self {
        self.sysd_socket = Some(s);
        self
    }

    pub fn default_for_user() -> Self {
        let app_dirs = vec![
            (user_applications_dir(), AppScope::User),
            (system_applications_dir(), AppScope::System),
        ];

        let mut desktop_dirs = Vec::new();
        for d in user_desktop_dirs() {
            desktop_dirs.push((d, AppScope::User));
        }
        for d in system_desktop_dirs() {
            desktop_dirs.push((d, AppScope::System));
        }

        AppRegistry::new(
            app_dirs,
            user_state_dir(),
            user_desktop_dir(),
            user_config_dir(),
        )
        .with_desktop_dirs(desktop_dirs)
    }

    pub fn discover_desktop_entries(&self) -> HashMap<String, InstalledApp> {
        let mut discovered = HashMap::new();
        let user_home = crate::get_user_home();
        let mut non_flatpak_entries: Vec<(PathBuf, AppScope, DesktopEntry)> = Vec::new();

        // desktop_dirs are ordered: user directories first, then system directories.
        // Higher precedence entries (e.g. user overrides) will be inserted first
        // and avoid being overwritten by lower precedence system entries.
        for (dir, scope) in &self.desktop_dirs {
            if !dir.exists() || !dir.is_dir() {
                continue;
            }
            if let Ok(entries) = fs::read_dir(dir) {
                for entry in entries.flatten() {
                    let path = entry.path();
                    if path.is_file() && path.extension().map_or(false, |ext| ext == "desktop") {
                        let filename = path.file_name().and_then(|f| f.to_str()).unwrap_or_default();
                        if filename.starts_with("conj-") {
                            continue;
                        }
                        let de = match DesktopEntry::parse_file(&path) {
                            Ok(de) => de,
                            Err(_) => continue,
                        };
                        if de.no_display || de.hidden {
                            continue;
                        }
                        let id = de.id.clone();
                        if discovered.contains_key(&id) || non_flatpak_entries.iter().any(|(_, _, d)| d.id == id) {
                            continue;
                        }

                        // Check if Flatpak
                        let is_flatpak = FlatpakAppInfo::is_flatpak_desktop(&path, de.flatpak_id.as_deref());
                        if is_flatpak {
                            let fp_info = FlatpakAppInfo::extract_info(&path, de.flatpak_id.as_deref(), &user_home);
                            let app = InstalledApp {
                                id: id.clone(),
                                name: de.name.clone(),
                                version: String::new(),
                                bundle_path: path.clone(),
                                executable_path: PathBuf::from("flatpak"),
                                scope: fp_info.scope,
                                backend: AppBackend::Flatpak,
                                icon: de.icon.clone(),
                                mime_types: de.mime_types.clone(),
                                terminal: de.terminal,
                                no_display: de.no_display,
                                package_name: None,
                                package_version: None,
                                sibling_apps: Vec::new(),
                                flatpak_id: Some(fp_info.id),
                            };
                            discovered.insert(id, app);
                        } else {
                            non_flatpak_entries.push((path, *scope, de));
                        }
                    }
                }
            }
        }

        // Batch query package owners for all non-flatpak desktop entries
        let paths_to_query: Vec<&Path> = non_flatpak_entries.iter().map(|(p, _, _)| p.as_path()).collect();
        let pkg_owners = self.package_query.query_files_owners(&paths_to_query);

        for (path, scope, de) in non_flatpak_entries {
            let pkg_opt = pkg_owners.get(&path).cloned();
            let backend = if pkg_opt.is_some() {
                AppBackend::Pacman
            } else {
                AppBackend::DesktopEntry
            };
            let (pkg_name, pkg_ver) = match pkg_opt {
                Some(p) => (Some(p.package_name), p.package_version),
                None => (None, None),
            };
            let first_token = crate::desktop_entry::tokenize_exec(&de.exec)
                .ok()
                .and_then(|tokens| tokens.into_iter().next())
                .unwrap_or_else(|| de.exec.clone());
            let exec_path = PathBuf::from(first_token);

            let app = InstalledApp {
                id: de.id.clone(),
                name: de.name.clone(),
                version: pkg_ver.clone().unwrap_or_default(),
                bundle_path: path.clone(),
                executable_path: exec_path,
                scope,
                backend,
                icon: de.icon.clone(),
                mime_types: de.mime_types.clone(),
                terminal: de.terminal,
                no_display: de.no_display,
                package_name: pkg_name,
                package_version: pkg_ver,
                sibling_apps: Vec::new(),
                flatpak_id: None,
            };
            discovered.insert(de.id, app);
        }

        let app_pkg_pairs: Vec<(String, Option<String>)> = discovered
            .values()
            .map(|app| (app.id.clone(), app.package_name.clone()))
            .collect();
        let sibling_map = MultiAppDetector::compute_sibling_map(&app_pkg_pairs);
        for (app_id, siblings) in sibling_map {
            if let Some(app) = discovered.get_mut(&app_id) {
                app.sibling_apps = siblings;
            }
        }

        discovered
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
                    backend: AppBackend::Native,
                    icon: manifest.icon.clone(),
                    mime_types: manifest.mime_types.clone().unwrap_or_default(),
                    terminal: false,
                    no_display: false,
                    package_name: None,
                    package_version: None,
                    sibling_apps: Vec::new(),
                    flatpak_id: None,
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

        // Integrate discovered desktop adapter entries (Pacman, DesktopEntry, Flatpak)
        let desktop_apps = self.discover_desktop_entries();
        for (id, app) in desktop_apps {
            if !new_active.contains_key(&id) && !new_conflicts.contains_key(&id) {
                new_active.insert(id, app);
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
                    backend: AppBackend::Native,
                    icon: manifest.icon.clone(),
                    mime_types: manifest.mime_types.clone().unwrap_or_default(),
                    terminal: false,
                    no_display: false,
                    package_name: None,
                    package_version: None,
                    sibling_apps: Vec::new(),
                    flatpak_id: None,
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

        // Integrate discovered desktop adapter entries (Pacman, DesktopEntry, Flatpak)
        let desktop_apps = self.discover_desktop_entries();
        for (id, app) in desktop_apps {
            if !new_active.contains_key(&id) && !new_conflicts.contains_key(&id) {
                new_active.insert(id, app);
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
        self.uninstall_with_options(id, false)
    }

    pub fn uninstall_with_options(&mut self, id: &str, yes: bool) -> Result<(), RegistryError> {
        self.uninstall_with_options_and_data(id, yes, false)
    }

    pub fn uninstall_with_options_and_data(&mut self, id: &str, yes: bool, with_data: bool) -> Result<(), RegistryError> {
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

        let is_flatpak = matches!(app.backend, AppBackend::Flatpak);
        let fp_id = app.flatpak_id.clone();

        match app.backend {
            AppBackend::Native => {
                if app.bundle_path.exists() {
                    fs::remove_dir_all(&app.bundle_path)?;
                }
                let _ = self.remove_desktop_entry(id);
                let _ = self.remove_mime_associations(id);
                self.reconcile()?;
            }
            AppBackend::DesktopEntry => {
                match app.scope {
                    AppScope::User => {
                        if app.bundle_path.exists() {
                            fs::remove_file(&app.bundle_path)?;
                        }
                        let _ = self.remove_mime_associations(id);
                        self.reconcile()?;
                    }
                    AppScope::System => {
                        return Err(RegistryError::ImmutableSystemApp(id.to_string()));
                    }
                }
            }
            AppBackend::Pacman => {
                let pkg_name = app.package_name.as_ref().ok_or_else(|| {
                    RegistryError::UninstallFailed("missing package name for pacman app".to_string())
                })?;

                if !app.sibling_apps.is_empty() && !yes {
                    return Err(RegistryError::MultiAppPackageRequiresConfirmation {
                        package: pkg_name.clone(),
                        siblings: app.sibling_apps.clone(),
                    });
                }

                request_sysd_remove_package(pkg_name, self.sysd_socket.as_deref())
                    .map_err(RegistryError::PackageRemovalFailed)?;

                self.reconcile()?;
            }
            AppBackend::Flatpak => {
                let fp_id_ref = fp_id.as_deref().unwrap_or(&app.id);
                let scope_arg = match app.scope {
                    AppScope::User => "--user",
                    AppScope::System => "--system",
                };
                let output = Command::new("flatpak")
                    .args(["uninstall", scope_arg, "-y", fp_id_ref])
                    .output()
                    .map_err(|e| RegistryError::UninstallFailed(format!("failed to execute flatpak uninstall: {}", e)))?;

                if !output.status.success() {
                    let stderr = String::from_utf8_lossy(&output.stderr);
                    return Err(RegistryError::UninstallFailed(format!(
                        "flatpak uninstall failed: {}",
                        stderr.trim()
                    )));
                }

                self.reconcile()?;
            }
        }

        if with_data {
            let _ = crate::files::remove_app_data(id, is_flatpak, fp_id.as_deref());
        }

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
            match app.backend {
                AppBackend::Native => {
                    if !app.executable_path.exists() {
                        return Err(RegistryError::LaunchFailed(format!(
                            "executable not found at {}",
                            app.executable_path.display()
                        )));
                    }
                    return self.spawn_exec_captured(&app.executable_path, args);
                }
                AppBackend::DesktopEntry | AppBackend::Pacman => {
                    let entry = DesktopEntry::parse_file(&app.bundle_path)
                        .map_err(|e| RegistryError::LaunchFailed(format!("failed to parse desktop entry: {}", e)))?;
                    let mut argv = entry
                        .expand_exec(args)
                        .map_err(RegistryError::LaunchFailed)?;
                    if app.terminal {
                        argv = wrap_terminal_argv(argv);
                    }
                    return self.spawn_argv_captured(&argv);
                }
                AppBackend::Flatpak => {
                    let fp_info = FlatpakAppInfo::extract_info(
                        &app.bundle_path,
                        app.flatpak_id.as_deref(),
                        &crate::get_user_home(),
                    );
                    let mut argv = fp_info.build_launch_argv(args);
                    if app.terminal {
                        argv = wrap_terminal_argv(argv);
                    }
                    return self.spawn_argv_captured(&argv);
                }
            }
        }

        // Check for URI schemes (e.g. http://, https://, mailto:)
        let is_uri = target.contains("://") || target.starts_with("mailto:");
        if is_uri {
            let scheme = if let Some(idx) = target.find(':') {
                &target[..idx]
            } else {
                "http"
            };
            let scheme_key = format!("x-scheme-handler/{}", scheme);
            let home = crate::get_user_home();
            let handler = crate::mime::resolve_default_handler(&scheme_key, &home).or_else(|| {
                if scheme == "https" {
                    crate::mime::resolve_default_handler("x-scheme-handler/http", &home)
                } else if scheme == "http" {
                    crate::mime::resolve_default_handler("x-scheme-handler/https", &home)
                } else {
                    None
                }
            });
            if let Some(handler_desktop) = handler {
                if let Some(res) = self.launch_by_desktop_id(&handler_desktop, &[target.to_string()]) {
                    return res;
                }
            }
        }

        // Check if target is an existing file or directory
        if target_path.exists() {
            let mime = crate::mime::detect_mime(target_path);
            let home = crate::get_user_home();
            if let Some(handler_desktop) = crate::mime::resolve_default_handler(&mime, &home) {
                let abs_target = target_path.canonicalize().unwrap_or_else(|_| target_path.to_path_buf());
                if let Some(res) = self.launch_by_desktop_id(&handler_desktop, &[abs_target.to_string_lossy().to_string()]) {
                    return res;
                }
            }

            // Fallback for directory: open with Conjunction Files or file manager
            if target_path.is_dir() {
                if let Some(files_app) = self.active.get("org.conjunction.files") {
                    return self.spawn_exec_captured(&files_app.executable_path, &[target_path.to_string_lossy().to_string()]);
                }
            }
        }

        Err(RegistryError::AppNotFound(target.to_string()))
    }

    fn launch_by_desktop_id(&self, desktop_id: &str, args: &[String]) -> Option<Result<LaunchResult, RegistryError>> {
        let clean_id = desktop_id.trim_end_matches(".desktop");
        if let Some(app) = self.active.get(clean_id).or_else(|| self.active.get(desktop_id)) {
            return Some(self.launch_captured(&app.id, args));
        }

        for app in self.active.values() {
            if let Some(fname) = app.bundle_path.file_name().and_then(|f| f.to_str()) {
                if fname == desktop_id || fname.trim_end_matches(".desktop") == clean_id {
                    return Some(self.launch_captured(&app.id, args));
                }
            }
        }

        // Direct desktop entry launch from /usr/share/applications if not in active registry
        let sys_desktop = Path::new("/usr/share/applications").join(desktop_id);
        if sys_desktop.exists() {
            if let Ok(entry) = DesktopEntry::parse_file(&sys_desktop) {
                if let Ok(mut argv) = entry.expand_exec(args) {
                    if entry.terminal {
                        argv = wrap_terminal_argv(argv);
                    }
                    return Some(self.spawn_argv_captured(&argv));
                }
            }
        }

        None
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

    fn spawn_argv_captured(&self, argv: &[String]) -> Result<LaunchResult, RegistryError> {
        if argv.is_empty() {
            return Err(RegistryError::LaunchFailed("empty command argv".to_string()));
        }
        let prog = &argv[0];
        let args = &argv[1..];

        let mut cmd = Command::new(prog);
        cmd.args(args);

        match cmd.output() {
            Ok(output) => Ok(LaunchResult {
                exit_code: output.status.code().unwrap_or(0),
                stdout: String::from_utf8_lossy(&output.stdout).to_string(),
                stderr: String::from_utf8_lossy(&output.stderr).to_string(),
            }),
            Err(e) => Err(RegistryError::LaunchFailed(format!(
                "failed to execute {}: {}",
                prog, e
            ))),
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

pub fn wrap_terminal_argv(argv: Vec<String>) -> Vec<String> {
    if let Ok(term) = std::env::var("CONJUNCTION_TERMINAL") {
        if !term.trim().is_empty() {
            let mut parts: Vec<String> = term.split_whitespace().map(|s| s.to_string()).collect();
            parts.extend(argv);
            return parts;
        }
    }
    if let Ok(term) = std::env::var("TERMINAL") {
        if !term.trim().is_empty() {
            let mut parts = vec![term, "-e".to_string()];
            parts.extend(argv);
            return parts;
        }
    }
    for t in &["alacritty", "foot", "kitty", "xterm"] {
        if crate::desktop_entry::is_executable_available(t) {
            let mut parts = vec![t.to_string(), "-e".to_string()];
            parts.extend(argv);
            return parts;
        }
    }
    argv
}
