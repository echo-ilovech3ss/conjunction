use crate::registry::{AppBackend, InstalledApp};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

/// Detailed window state received from KWin / Wayland compositor bridge.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WindowInfo {
    pub internal_id: String,
    pub pid: u32,
    pub title: String,
    pub app_id: String,
    pub active: bool,
    pub minimized: bool,
    pub maximized: bool,
    pub fullscreen: bool,
    pub screen: String,
    pub workspace: u32,
    #[serde(default)]
    pub executable_path: Option<PathBuf>,
}

/// Resolved application identity associated with a window or dock entry.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppIdentity {
    pub id: String,
    pub name: String,
    pub icon: Option<String>,
    pub backend: AppBackend,
    pub is_unknown: bool,
}

/// Matcher that resolves running windows to Conjunction Application Services identities.
pub struct WindowMatcher;

impl WindowMatcher {
    /// Resolves a window to an installed application identity using deterministic priority:
    /// 1. Exact appId / desktop filename match
    /// 2. Process executable path match
    /// 3. Package binary name match
    /// 4. Flatpak ID match
    /// 5. Fallback unknown running application representation
    pub fn resolve_window(
        window: &WindowInfo,
        known_apps: &HashMap<String, InstalledApp>,
    ) -> AppIdentity {
        let app_id_clean = window.app_id.trim();
        let app_id_no_desktop = app_id_clean.strip_suffix(".desktop").unwrap_or(app_id_clean);

        // 1. Exact appId match
        if let Some(app) = known_apps.get(app_id_clean) {
            return Self::from_installed(app);
        }
        if let Some(app) = known_apps.get(app_id_no_desktop) {
            return Self::from_installed(app);
        }
        for (id, app) in known_apps {
            if id.eq_ignore_ascii_case(app_id_clean) || id.eq_ignore_ascii_case(app_id_no_desktop) {
                return Self::from_installed(app);
            }
        }

        // 2. Executable path match
        if let Some(ref exec_path) = window.executable_path {
            for app in known_apps.values() {
                if &app.executable_path == exec_path {
                    return Self::from_installed(app);
                }
                if let Ok(canon_exec) = exec_path.canonicalize() {
                    if let Ok(canon_app) = app.executable_path.canonicalize() {
                        if canon_exec == canon_app {
                            return Self::from_installed(app);
                        }
                    }
                }
            }
        }

        // 3. Package binary match / binary filename match
        if let Some(ref exec_path) = window.executable_path {
            if let Some(exec_name) = exec_path.file_name().and_then(|n| n.to_str()) {
                for app in known_apps.values() {
                    if let Some(app_bin) = app.executable_path.file_name().and_then(|n| n.to_str()) {
                        if exec_name == app_bin {
                            return Self::from_installed(app);
                        }
                    }
                    if let Some(ref pkg_name) = app.package_name {
                        if exec_name == pkg_name {
                            return Self::from_installed(app);
                        }
                    }
                }
            }
        }

        // 4. Flatpak ID match
        for app in known_apps.values() {
            if let Some(ref fpid) = app.flatpak_id {
                if fpid == app_id_clean || fpid == app_id_no_desktop {
                    return Self::from_installed(app);
                }
            }
        }

        // 5. Fallback unknown running application
        let fallback_name = if !window.title.trim().is_empty() {
            window.title.trim().to_string()
        } else if !app_id_no_desktop.is_empty() {
            app_id_no_desktop.to_string()
        } else {
            format!("Application ({})", window.pid)
        };

        AppIdentity {
            id: if !app_id_no_desktop.is_empty() {
                app_id_no_desktop.to_string()
            } else {
                format!("unknown.{}", window.pid)
            },
            name: fallback_name,
            icon: Some("application-x-executable".to_string()),
            backend: AppBackend::Native,
            is_unknown: true,
        }
    }

    fn from_installed(app: &InstalledApp) -> AppIdentity {
        AppIdentity {
            id: app.id.clone(),
            name: app.name.clone(),
            icon: app.icon.clone(),
            backend: app.backend,
            is_unknown: false,
        }
    }
}

/// Dock configuration storing pinned applications persistently.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DockConfig {
    pub pinned_apps: Vec<String>,
}

impl Default for DockConfig {
    fn default() -> Self {
        DockConfig {
            pinned_apps: vec![
                "dev.conjunction.gallery".to_string(),
                "dev.conjunction.reference".to_string(),
                "org.conjunction.files".to_string(),
                "org.conjunction.terminal".to_string(),
            ],
        }
    }
}

impl DockConfig {
    pub fn config_path() -> PathBuf {
        crate::registry::user_config_dir()
            .join("conjunction")
            .join("dock.json")
    }

    pub fn load_or_default() -> Self {
        let p = Self::config_path();
        Self::load_from_file(&p).unwrap_or_default()
    }

    pub fn load_from_file(path: &Path) -> Result<Self, String> {
        if !path.exists() {
            return Ok(Self::default());
        }
        let data = fs::read_to_string(path).map_err(|e| format!("cannot read dock config: {}", e))?;
        serde_json::from_str(&data).map_err(|e| format!("cannot parse dock config: {}", e))
    }

    pub fn save_to_file(&self, path: &Path) -> Result<(), String> {
        if let Some(parent) = path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        let data = serde_json::to_string_pretty(self)
            .map_err(|e| format!("cannot serialize dock config: {}", e))?;
        fs::write(path, data).map_err(|e| format!("cannot write dock config: {}", e))
    }

    pub fn pin(&mut self, app_id: &str) -> bool {
        if !self.is_pinned(app_id) {
            self.pinned_apps.push(app_id.to_string());
            true
        } else {
            false
        }
    }

    pub fn unpin(&mut self, app_id: &str) -> bool {
        let original_len = self.pinned_apps.len();
        self.pinned_apps.retain(|id| id != app_id);
        self.pinned_apps.len() < original_len
    }

    pub fn reorder(&mut self, app_id: &str, new_index: usize) -> bool {
        if let Some(pos) = self.pinned_apps.iter().position(|id| id == app_id) {
            let item = self.pinned_apps.remove(pos);
            let target_idx = new_index.min(self.pinned_apps.len());
            self.pinned_apps.insert(target_idx, item);
            true
        } else {
            false
        }
    }

    pub fn is_pinned(&self, app_id: &str) -> bool {
        self.pinned_apps.iter().any(|id| id == app_id)
    }
}

/// An individual item in the Dock (pinned or running).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DockItem {
    pub app_id: String,
    pub name: String,
    pub icon: Option<String>,
    pub pinned: bool,
    pub running: bool,
    pub active: bool,
    pub window_count: usize,
    pub window_ids: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DockClickAction {
    Launch(String),
    FocusWindow(String),
}

/// DockModel manages the layout and dynamic state of the floating Dock.
pub struct DockModel {
    pub config: DockConfig,
    pub items: Vec<DockItem>,
}

impl DockModel {
    pub fn new(config: DockConfig) -> Self {
        DockModel {
            config,
            items: Vec::new(),
        }
    }

    /// Reconstructs the Dock items from known apps and active windows.
    pub fn update(
        &mut self,
        known_apps: &HashMap<String, InstalledApp>,
        windows: &[WindowInfo],
    ) {
        let mut app_windows: HashMap<String, Vec<WindowInfo>> = HashMap::new();
        let mut app_identities: HashMap<String, AppIdentity> = HashMap::new();

        for win in windows {
            let ident = WindowMatcher::resolve_window(win, known_apps);
            app_identities.insert(ident.id.clone(), ident.clone());
            app_windows.entry(ident.id).or_default().push(win.clone());
        }

        let mut new_items = Vec::new();
        let mut processed_apps = std::collections::HashSet::new();

        // 1. Pinned items in persistent order
        for pinned_id in &self.config.pinned_apps {
            processed_apps.insert(pinned_id.clone());
            let (name, icon) = if let Some(app) = known_apps.get(pinned_id) {
                (app.name.clone(), app.icon.clone())
            } else if let Some(ident) = app_identities.get(pinned_id) {
                (ident.name.clone(), ident.icon.clone())
            } else {
                (pinned_id.clone(), Some("application-x-executable".to_string()))
            };

            let wins = app_windows.get(pinned_id);
            let running = wins.is_some() && !wins.unwrap().is_empty();
            let window_count = wins.map(|w| w.len()).unwrap_or(0);
            let active = wins.map(|w| w.iter().any(|win| win.active)).unwrap_or(false);
            let window_ids = wins
                .map(|w| w.iter().map(|win| win.internal_id.clone()).collect())
                .unwrap_or_default();

            new_items.push(DockItem {
                app_id: pinned_id.clone(),
                name,
                icon,
                pinned: true,
                running,
                active,
                window_count,
                window_ids,
            });
        }

        // 2. Unpinned running items (order preserved from previous items or newly opened)
        for (app_id, wins) in &app_windows {
            if processed_apps.contains(app_id) || wins.is_empty() {
                continue;
            }
            processed_apps.insert(app_id.clone());

            let ident = app_identities.get(app_id).cloned().unwrap_or_else(|| AppIdentity {
                id: app_id.clone(),
                name: app_id.clone(),
                icon: Some("application-x-executable".to_string()),
                backend: AppBackend::Native,
                is_unknown: true,
            });

            let running = true;
            let window_count = wins.len();
            let active = wins.iter().any(|win| win.active);
            let window_ids = wins.iter().map(|win| win.internal_id.clone()).collect();

            new_items.push(DockItem {
                app_id: app_id.clone(),
                name: ident.name,
                icon: ident.icon,
                pinned: false,
                running,
                active,
                window_count,
                window_ids,
            });
        }

        self.items = new_items;
    }

    /// Determines the action to take when a user clicks a dock item:
    /// - If not running: Launch app
    /// - If running with 1 window: Focus that window
    /// - If running with multiple windows: Focus most recently active or first window
    pub fn handle_click(&self, app_id: &str) -> Option<DockClickAction> {
        let item = self.items.iter().find(|it| it.app_id == app_id)?;
        if !item.running || item.window_ids.is_empty() {
            Some(DockClickAction::Launch(app_id.to_string()))
        } else {
            Some(DockClickAction::FocusWindow(item.window_ids[0].clone()))
        }
    }

    pub fn pin(&mut self, app_id: &str) -> bool {
        let res = self.config.pin(app_id);
        if res {
            let _ = self.config.save_to_file(&DockConfig::config_path());
        }
        res
    }

    pub fn unpin(&mut self, app_id: &str) -> bool {
        let res = self.config.unpin(app_id);
        if res {
            let _ = self.config.save_to_file(&DockConfig::config_path());
        }
        res
    }
}

/// Screen display information for multi-monitor policy.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ScreenInfo {
    pub id: String,
    pub name: String,
    pub x: i32,
    pub y: i32,
    pub width: u32,
    pub height: u32,
    pub scale: f64,
    pub is_primary: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DockDisplayPolicy {
    PrimaryOnly,
    AllScreens,
    FollowActiveWindow,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TopBarDisplayPolicy {
    AllScreens,
    PrimaryOnly,
}

/// Screen manager managing multi-monitor geometry and shell display policies.
pub struct ScreenModel {
    pub screens: Vec<ScreenInfo>,
    pub dock_policy: DockDisplayPolicy,
    pub topbar_policy: TopBarDisplayPolicy,
}

impl ScreenModel {
    pub fn new() -> Self {
        ScreenModel {
            screens: Vec::new(),
            dock_policy: DockDisplayPolicy::PrimaryOnly,
            topbar_policy: TopBarDisplayPolicy::AllScreens,
        }
    }

    pub fn add_screen(&mut self, screen: ScreenInfo) {
        self.screens.retain(|s| s.id != screen.id);
        self.screens.push(screen);
    }

    pub fn remove_screen(&mut self, id: &str) {
        self.screens.retain(|s| s.id != id);
    }

    pub fn set_primary(&mut self, id: &str) {
        for s in &mut self.screens {
            s.is_primary = s.id == id;
        }
    }

    pub fn primary_screen(&self) -> Option<&ScreenInfo> {
        self.screens.iter().find(|s| s.is_primary).or_else(|| self.screens.first())
    }

    /// Finds the screen containing point (x, y), properly handling negative coordinate offsets.
    pub fn screen_at(&self, x: i32, y: i32) -> Option<&ScreenInfo> {
        self.screens.iter().find(|s| {
            let right = s.x + s.width as i32;
            let bottom = s.y + s.height as i32;
            x >= s.x && x < right && y >= s.y && y < bottom
        })
    }

    /// Returns the target screens where the Dock should be displayed according to configured policy.
    pub fn screens_for_dock(&self, active_screen_id: Option<&str>) -> Vec<&ScreenInfo> {
        match self.dock_policy {
            DockDisplayPolicy::AllScreens => self.screens.iter().collect(),
            DockDisplayPolicy::PrimaryOnly => {
                self.primary_screen().into_iter().collect()
            }
            DockDisplayPolicy::FollowActiveWindow => {
                if let Some(act_id) = active_screen_id {
                    if let Some(s) = self.screens.iter().find(|s| s.id == act_id) {
                        return vec![s];
                    }
                }
                self.primary_screen().into_iter().collect()
            }
        }
    }

    /// Returns the target screens where the Top Bar should be displayed according to configured policy.
    pub fn screens_for_topbar(&self) -> Vec<&ScreenInfo> {
        match self.topbar_policy {
            TopBarDisplayPolicy::AllScreens => self.screens.iter().collect(),
            TopBarDisplayPolicy::PrimaryOnly => {
                self.primary_screen().into_iter().collect()
            }
        }
    }
}

/// Global menu item representation compatible with com.canonical.dbusmenu.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MenuItemInfo {
    pub id: i32,
    pub label: String,
    pub enabled: bool,
    pub visible: bool,
    pub icon_name: Option<String>,
    pub shortcut: Option<String>,
    pub children: Vec<MenuItemInfo>,
}

/// Registrar tracking com.canonical.AppMenu.Registrar registrations.
#[derive(Debug, Default)]
pub struct GlobalMenuRegistrar {
    pub registrations: HashMap<u32, (String, String)>, // window_id -> (service, path)
}

impl GlobalMenuRegistrar {
    pub fn new() -> Self {
        GlobalMenuRegistrar {
            registrations: HashMap::new(),
        }
    }

    pub fn register_window(&mut self, window_id: u32, service: &str, path: &str) {
        self.registrations.insert(window_id, (service.to_string(), path.to_string()));
    }

    pub fn unregister_window(&mut self, window_id: u32) -> bool {
        self.registrations.remove(&window_id).is_some()
    }

    pub fn get_menu(&self, window_id: u32) -> Option<&(String, String)> {
        self.registrations.get(&window_id)
    }

    pub fn remove_service(&mut self, service: &str) {
        self.registrations.retain(|_, (s, _)| s != service);
    }
}
