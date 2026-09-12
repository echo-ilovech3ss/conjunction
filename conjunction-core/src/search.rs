use crate::registry::InstalledApp;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};

/// Categories for global search results.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
pub enum SearchCategory {
    Applications,
    Settings,
    Actions,
    Files,
}

impl SearchCategory {
    pub fn display_name(&self) -> &'static str {
        match self {
            SearchCategory::Applications => "Applications",
            SearchCategory::Settings => "Settings",
            SearchCategory::Actions => "Actions",
            SearchCategory::Files => "Files",
        }
    }
}

/// An individual search result item displayed in the Spotlight overlay.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SearchResult {
    pub id: String,
    pub title: String,
    pub subtitle: Option<String>,
    pub category: SearchCategory,
    pub icon: Option<String>,
    pub action_data: String,
    pub score: u32,
}

/// Trait implemented by any search result provider.
pub trait SearchProvider: Send + Sync {
    fn name(&self) -> &str;
    fn category(&self) -> SearchCategory;
    fn search(&self, query: &str) -> Vec<SearchResult>;
}

/// Searches installed applications by name, ID, comment, and keywords.
pub struct AppSearchProvider {
    apps: HashMap<String, InstalledApp>,
}

impl AppSearchProvider {
    pub fn new(apps: HashMap<String, InstalledApp>) -> Self {
        AppSearchProvider { apps }
    }

    pub fn update_apps(&mut self, apps: HashMap<String, InstalledApp>) {
        self.apps = apps;
    }
}

impl SearchProvider for AppSearchProvider {
    fn name(&self) -> &str {
        "Applications"
    }

    fn category(&self) -> SearchCategory {
        SearchCategory::Applications
    }

    fn search(&self, query: &str) -> Vec<SearchResult> {
        let q = query.trim().to_lowercase();
        if q.is_empty() {
            return Vec::new();
        }

        let mut results = Vec::new();

        for (id, app) in &self.apps {
            let name_lower = app.name.to_lowercase();
            let id_lower = id.to_lowercase();
            let pkg_lower = app.package_name.as_deref().unwrap_or("").to_lowercase();

            let mut score = 0u32;

            if name_lower == q {
                score = 1000;
            } else if name_lower.starts_with(&q) {
                score = 800 + (100 - (name_lower.len() as u32).min(100));
            } else if name_lower.contains(&q) {
                score = 500;
            } else if id_lower.starts_with(&q) {
                score = 400;
            } else if id_lower.contains(&q) {
                score = 300;
            } else if pkg_lower.contains(&q) {
                score = 200;
            }

            if score > 0 {
                results.push(SearchResult {
                    id: id.clone(),
                    title: app.name.clone(),
                    subtitle: Some(format!("{} • {}", app.backend, id)),
                    category: SearchCategory::Applications,
                    icon: app.icon.clone().or_else(|| Some("application-x-executable".to_string())),
                    action_data: format!("app:{}", id),
                    score,
                });
            }
        }

        results.sort_by(|a, b| b.score.cmp(&a.score));
        results
    }
}

/// Static system action definition.
#[derive(Debug, Clone)]
struct StaticAction {
    id: &'static str,
    title: &'static str,
    subtitle: &'static str,
    keywords: &'static [&'static str],
    icon: &'static str,
    action_data: &'static str,
}

const STATIC_SYSTEM_ACTIONS: &[StaticAction] = &[
    StaticAction {
        id: "action.lock",
        title: "Lock Screen",
        subtitle: "Lock current user session (Ctrl+Alt+L)",
        keywords: &["lock", "screen", "session", "secure"],
        icon: "system-lock-screen",
        action_data: "action:lock",
    },
    StaticAction {
        id: "action.logout",
        title: "Log Out",
        subtitle: "Log out of current user session",
        keywords: &["logout", "sign out", "exit", "session"],
        icon: "system-log-out",
        action_data: "action:logout",
    },
    StaticAction {
        id: "action.restart",
        title: "Restart Computer",
        subtitle: "Reboot system",
        keywords: &["restart", "reboot", "restarting"],
        icon: "system-reboot",
        action_data: "action:restart",
    },
    StaticAction {
        id: "action.shutdown",
        title: "Shut Down",
        subtitle: "Power off system",
        keywords: &["shutdown", "power off", "turn off"],
        icon: "system-shutdown",
        action_data: "action:shutdown",
    },
    StaticAction {
        id: "action.overview",
        title: "Mission Control / Overview",
        subtitle: "Show all open windows and workspaces",
        keywords: &["mission control", "overview", "expose", "windows", "switch"],
        icon: "view-paged",
        action_data: "action:overview",
    },
];

/// Searches settings via Canonical Registry and system actions.
pub struct SettingsSearchProvider;

impl SearchProvider for SettingsSearchProvider {
    fn name(&self) -> &str {
        "Settings & Actions"
    }

    fn category(&self) -> SearchCategory {
        SearchCategory::Settings
    }

    fn search(&self, query: &str) -> Vec<SearchResult> {
        let q = query.trim().to_lowercase();
        if q.is_empty() {
            return Vec::new();
        }

        let mut results = Vec::new();

        // 1. Search canonical settings registry
        let reg = crate::settings::SettingsRegistry::canonical();
        let setting_hits = reg.search(&q);
        for hit in setting_hits {
            results.push(SearchResult {
                id: hit.setting_id,
                title: hit.title,
                subtitle: Some(format!("{} • {}", hit.section, hit.description)),
                category: SearchCategory::Settings,
                icon: Some(hit.icon),
                action_data: hit.deep_link,
                score: hit.score,
            });
        }

        // 2. Search system actions
        for act in STATIC_SYSTEM_ACTIONS {
            let title_lower = act.title.to_lowercase();
            let mut score = 0u32;

            if title_lower == q {
                score = 950;
            } else if title_lower.starts_with(&q) {
                score = 750;
            } else if title_lower.contains(&q) {
                score = 450;
            } else if act.keywords.iter().any(|kw| kw.starts_with(&q)) {
                score = 400;
            } else if act.keywords.iter().any(|kw| kw.contains(&q)) {
                score = 250;
            }

            if score > 0 {
                results.push(SearchResult {
                    id: act.id.to_string(),
                    title: act.title.to_string(),
                    subtitle: Some(act.subtitle.to_string()),
                    category: SearchCategory::Actions,
                    icon: Some(act.icon.to_string()),
                    action_data: act.action_data.to_string(),
                    score,
                });
            }
        }

        results.sort_by(|a, b| b.score.cmp(&a.score));
        results
    }
}

/// Fast bounded file search in user directory (max depth 2, max items 10).
pub struct FileSearchProvider {
    search_dirs: Vec<PathBuf>,
}

impl FileSearchProvider {
    pub fn new(search_dirs: Vec<PathBuf>) -> Self {
        FileSearchProvider { search_dirs }
    }

    pub fn default_user_dirs() -> Self {
        let mut dirs = Vec::new();
        let home = crate::get_user_home();
        let p_docs = home.join("Documents");
        let p_down = home.join("Downloads");
        let p_desk = home.join("Desktop");
        if p_docs.exists() { dirs.push(p_docs); }
        if p_down.exists() { dirs.push(p_down); }
        if p_desk.exists() { dirs.push(p_desk); }
        FileSearchProvider { search_dirs: dirs }
    }
}

impl SearchProvider for FileSearchProvider {
    fn name(&self) -> &str {
        "Files"
    }

    fn category(&self) -> SearchCategory {
        SearchCategory::Files
    }

    fn search(&self, query: &str) -> Vec<SearchResult> {
        let q = query.trim().to_lowercase();
        if q.len() < 2 {
            return Vec::new();
        }

        let mut results = Vec::new();

        for root in &self.search_dirs {
            if results.len() >= 10 {
                break;
            }
            scan_dir_bounded(root, &q, 0, 2, &mut results);
        }

        results.sort_by(|a, b| b.score.cmp(&a.score));
        results.truncate(10);
        results
    }
}

fn scan_dir_bounded(
    dir: &Path,
    query: &str,
    depth: usize,
    max_depth: usize,
    results: &mut Vec<SearchResult>,
) {
    if depth > max_depth || results.len() >= 15 {
        return;
    }

    let entries = match std::fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return,
    };

    for entry in entries.flatten() {
        if results.len() >= 15 {
            break;
        }
        let path = entry.path();
        let name = match path.file_name().and_then(|n| n.to_str()) {
            Some(n) => n,
            None => continue,
        };

        // Skip hidden files/directories
        if name.starts_with('.') {
            continue;
        }

        let name_lower = name.to_lowercase();
        if name_lower.contains(query) {
            let mut score = 200u32;
            if name_lower.starts_with(query) {
                score = 350;
            }
            results.push(SearchResult {
                id: path.to_string_lossy().to_string(),
                title: name.to_string(),
                subtitle: Some(path.parent().map(|p| p.to_string_lossy().to_string()).unwrap_or_default()),
                category: SearchCategory::Files,
                icon: Some("text-x-generic".to_string()),
                action_data: format!("file:{}", path.to_string_lossy()),
                score,
            });
        }

        if path.is_dir() {
            scan_dir_bounded(&path, query, depth + 1, max_depth, results);
        }
    }
}

/// Global Search Engine coordinating all search providers.
pub struct SearchEngine {
    providers: Vec<Box<dyn SearchProvider>>,
}

impl Default for SearchEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl SearchEngine {
    pub fn new() -> Self {
        SearchEngine {
            providers: Vec::new(),
        }
    }

    pub fn register_provider(&mut self, provider: Box<dyn SearchProvider>) {
        self.providers.push(provider);
    }

    /// Performs search across all providers, returning ranked results.
    pub fn search(&self, query: &str, limit_per_category: usize) -> Vec<SearchResult> {
        let q = query.trim();
        if q.is_empty() {
            return Vec::new();
        }

        let mut all_results = Vec::new();

        for provider in &self.providers {
            let mut cat_results = provider.search(q);
            cat_results.truncate(limit_per_category);
            all_results.extend(cat_results);
        }

        // Sort primarily by score descending
        all_results.sort_by(|a, b| b.score.cmp(&a.score));
        all_results
    }
}
