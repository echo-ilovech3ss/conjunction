use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Control types for settings UI rendering.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SettingControlType {
    Switch,
    Slider,
    Segmented,
    ComboBox,
    ColorPicker,
    Action,
    Text,
}

/// Primitive value types supported by settings.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SettingValueType {
    Bool,
    Int,
    Float,
    String,
}

/// A strongly-typed setting value.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum SettingValue {
    Bool(bool),
    Int(i64),
    Float(f64),
    String(String),
}

impl SettingValue {
    pub fn as_bool(&self) -> Option<bool> {
        match self {
            SettingValue::Bool(b) => Some(*b),
            _ => None,
        }
    }

    pub fn as_i64(&self) -> Option<i64> {
        match self {
            SettingValue::Int(i) => Some(*i),
            SettingValue::Float(f) => Some(*f as i64),
            _ => None,
        }
    }

    pub fn as_f64(&self) -> Option<f64> {
        match self {
            SettingValue::Float(f) => Some(*f),
            SettingValue::Int(i) => Some(*i as f64),
            _ => None,
        }
    }

    pub fn as_str(&self) -> Option<&str> {
        match self {
            SettingValue::String(s) => Some(s.as_str()),
            _ => None,
        }
    }
}

/// Canonical metadata descriptor for a single setting.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SettingDescriptor {
    pub id: String,
    pub page: String,
    pub section: String,
    pub title: String,
    pub description: String,
    pub keywords: Vec<String>,
    pub control_type: SettingControlType,
    pub value_type: SettingValueType,
    pub default_value: SettingValue,
    pub min_value: Option<f64>,
    pub max_value: Option<f64>,
    pub step: Option<f64>,
    pub options: Vec<String>,
    pub deep_link: String,
    pub spotlight_visible: bool,
    pub control_center_integrated: bool,
    pub privilege_required: bool,
}

impl SettingDescriptor {
    /// Validates an incoming setting value against this descriptor's type, range, and options.
    pub fn validate_value(&self, value: &SettingValue) -> Result<(), String> {
        match (self.value_type, value) {
            (SettingValueType::Bool, SettingValue::Bool(_)) => Ok(()),
            (SettingValueType::Int, SettingValue::Int(v)) => {
                if let Some(min) = self.min_value {
                    if (*v as f64) < min {
                        return Err(format!("Value {} is less than minimum {}", v, min));
                    }
                }
                if let Some(max) = self.max_value {
                    if (*v as f64) > max {
                        return Err(format!("Value {} is greater than maximum {}", v, max));
                    }
                }
                Ok(())
            }
            (SettingValueType::Float, SettingValue::Float(v)) => {
                if let Some(min) = self.min_value {
                    if *v < min {
                        return Err(format!("Value {} is less than minimum {}", v, min));
                    }
                }
                if let Some(max) = self.max_value {
                    if *v > max {
                        return Err(format!("Value {} is greater than maximum {}", v, max));
                    }
                }
                Ok(())
            }
            (SettingValueType::String, SettingValue::String(s)) => {
                if !self.options.is_empty() && !self.options.contains(s) {
                    return Err(format!("Value '{}' is not one of allowed options: {:?}", s, self.options));
                }
                Ok(())
            }
            _ => Err(format!(
                "Type mismatch: expected {:?} for setting '{}'",
                self.value_type, self.id
            )),
        }
    }
}

/// A search hit produced when matching settings in Spotlight or System Settings search.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SettingSearchResult {
    pub setting_id: String,
    pub page: String,
    pub title: String,
    pub section: String,
    pub description: String,
    pub deep_link: String,
    pub icon: String,
    pub score: u32,
}

/// Canonical System Settings Registry.
#[derive(Debug, Clone)]
pub struct SettingsRegistry {
    settings: Vec<SettingDescriptor>,
    by_id: HashMap<String, usize>,
}

impl Default for SettingsRegistry {
    fn default() -> Self {
        Self::canonical()
    }
}

impl SettingsRegistry {
    /// Creates the standard canonical registry with all supported Conjunction settings.
    pub fn canonical() -> Self {
        let mut reg = SettingsRegistry {
            settings: Vec::new(),
            by_id: HashMap::new(),
        };

        reg.register(SettingDescriptor {
            id: "appearance.mode".to_string(),
            page: "appearance".to_string(),
            section: "Theme".to_string(),
            title: "Appearance Mode".to_string(),
            description: "Switch between Light and Dark desktop themes".to_string(),
            keywords: vec!["theme".into(), "dark".into(), "light".into(), "appearance".into(), "mode".into(), "night".into()],
            control_type: SettingControlType::Segmented,
            value_type: SettingValueType::String,
            default_value: SettingValue::String("dark".to_string()),
            min_value: None,
            max_value: None,
            step: None,
            options: vec!["dark".to_string(), "light".to_string()],
            deep_link: "settings://appearance?setting=appearance.mode".to_string(),
            spotlight_visible: true,
            control_center_integrated: true,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "appearance.accent".to_string(),
            page: "appearance".to_string(),
            section: "Theme".to_string(),
            title: "Accent Color".to_string(),
            description: "System highlight and focus tint color".to_string(),
            keywords: vec!["color".into(), "accent".into(), "tint".into(), "highlight".into(), "blue".into(), "purple".into()],
            control_type: SettingControlType::ColorPicker,
            value_type: SettingValueType::String,
            default_value: SettingValue::String("#0066CC".to_string()),
            min_value: None,
            max_value: None,
            step: None,
            options: vec!["#0066CC".to_string(), "#5856D6".to_string(), "#34C759".to_string(), "#FF9500".to_string(), "#FF2D55".to_string()],
            deep_link: "settings://appearance?setting=appearance.accent".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "dock.size".to_string(),
            page: "dock".to_string(),
            section: "Dock".to_string(),
            title: "Dock Size".to_string(),
            description: "Base height and icon scale of the desktop Dock".to_string(),
            keywords: vec!["dock".into(), "size".into(), "icons".into(), "height".into(), "bar".into()],
            control_type: SettingControlType::Slider,
            value_type: SettingValueType::Int,
            default_value: SettingValue::Int(68),
            min_value: Some(36.0),
            max_value: Some(96.0),
            step: Some(4.0),
            options: Vec::new(),
            deep_link: "settings://dock?setting=dock.size".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "dock.magnification".to_string(),
            page: "dock".to_string(),
            section: "Dock".to_string(),
            title: "Dock Magnification".to_string(),
            description: "Magnify Dock icons on pointer hover".to_string(),
            keywords: vec!["dock".into(), "magnification".into(), "zoom".into(), "hover".into(), "scale".into()],
            control_type: SettingControlType::Switch,
            value_type: SettingValueType::Bool,
            default_value: SettingValue::Bool(true),
            min_value: None,
            max_value: None,
            step: None,
            options: Vec::new(),
            deep_link: "settings://dock?setting=dock.magnification".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "dock.magnificationScale".to_string(),
            page: "dock".to_string(),
            section: "Dock".to_string(),
            title: "Magnification Scale".to_string(),
            description: "Maximum scale multiplier for hovered Dock icons".to_string(),
            keywords: vec!["dock".into(), "zoom".into(), "magnification".into(), "scale".into(), "max".into()],
            control_type: SettingControlType::Slider,
            value_type: SettingValueType::Float,
            default_value: SettingValue::Float(1.35),
            min_value: Some(1.1),
            max_value: Some(2.0),
            step: Some(0.05),
            options: Vec::new(),
            deep_link: "settings://dock?setting=dock.magnificationScale".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "dock.displayPolicy".to_string(),
            page: "dock".to_string(),
            section: "Dock".to_string(),
            title: "Dock Display Placement".to_string(),
            description: "Which connected displays show the Dock".to_string(),
            keywords: vec!["dock".into(), "display".into(), "screen".into(), "monitor".into(), "placement".into()],
            control_type: SettingControlType::ComboBox,
            value_type: SettingValueType::String,
            default_value: SettingValue::String("primary".to_string()),
            min_value: None,
            max_value: None,
            step: None,
            options: vec!["primary".to_string(), "all".to_string(), "active".to_string()],
            deep_link: "settings://dock?setting=dock.displayPolicy".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "displays.scale".to_string(),
            page: "displays".to_string(),
            section: "Scale & Resolution".to_string(),
            title: "Display Scale".to_string(),
            description: "User interface scaling factor for high-resolution displays".to_string(),
            keywords: vec!["display".into(), "scale".into(), "screen".into(), "resolution".into(), "hidpi".into(), "zoom".into(), "size".into()],
            control_type: SettingControlType::Segmented,
            value_type: SettingValueType::Float,
            default_value: SettingValue::Float(1.0),
            min_value: Some(1.0),
            max_value: Some(2.5),
            step: Some(0.25),
            options: vec!["1.0".to_string(), "1.25".to_string(), "1.5".to_string(), "2.0".to_string()],
            deep_link: "settings://displays?setting=displays.scale".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "sound.volume".to_string(),
            page: "sound".to_string(),
            section: "Output".to_string(),
            title: "Output Volume".to_string(),
            description: "Main speaker and headphone output volume".to_string(),
            keywords: vec!["sound".into(), "volume".into(), "speaker".into(), "audio".into(), "headphones".into(), "loudness".into()],
            control_type: SettingControlType::Slider,
            value_type: SettingValueType::Int,
            default_value: SettingValue::Int(75),
            min_value: Some(0.0),
            max_value: Some(100.0),
            step: Some(1.0),
            options: Vec::new(),
            deep_link: "settings://sound?setting=sound.volume".to_string(),
            spotlight_visible: true,
            control_center_integrated: true,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "sound.muted".to_string(),
            page: "sound".to_string(),
            section: "Output".to_string(),
            title: "Mute Sound".to_string(),
            description: "Mute all audio output".to_string(),
            keywords: vec!["mute".into(), "sound".into(), "silence".into(), "audio".into(), "speaker".into()],
            control_type: SettingControlType::Switch,
            value_type: SettingValueType::Bool,
            default_value: SettingValue::Bool(false),
            min_value: None,
            max_value: None,
            step: None,
            options: Vec::new(),
            deep_link: "settings://sound?setting=sound.muted".to_string(),
            spotlight_visible: true,
            control_center_integrated: true,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "network.wifi.enabled".to_string(),
            page: "network".to_string(),
            section: "Wi-Fi".to_string(),
            title: "Wi-Fi".to_string(),
            description: "Enable or disable wireless networking".to_string(),
            keywords: vec!["wifi".into(), "wireless".into(), "network".into(), "internet".into(), "ssid".into(), "hotspot".into()],
            control_type: SettingControlType::Switch,
            value_type: SettingValueType::Bool,
            default_value: SettingValue::Bool(true),
            min_value: None,
            max_value: None,
            step: None,
            options: Vec::new(),
            deep_link: "settings://network?setting=network.wifi.enabled".to_string(),
            spotlight_visible: true,
            control_center_integrated: true,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "bluetooth.enabled".to_string(),
            page: "bluetooth".to_string(),
            section: "Bluetooth Adapter".to_string(),
            title: "Bluetooth".to_string(),
            description: "Enable or disable Bluetooth wireless adapter".to_string(),
            keywords: vec!["bluetooth".into(), "wireless".into(), "pair".into(), "devices".into(), "mouse".into(), "keyboard".into(), "headphones".into()],
            control_type: SettingControlType::Switch,
            value_type: SettingValueType::Bool,
            default_value: SettingValue::Bool(true),
            min_value: None,
            max_value: None,
            step: None,
            options: Vec::new(),
            deep_link: "settings://bluetooth?setting=bluetooth.enabled".to_string(),
            spotlight_visible: true,
            control_center_integrated: true,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "desktop.wallpaper".to_string(),
            page: "dock".to_string(),
            section: "Wallpaper".to_string(),
            title: "Desktop Background".to_string(),
            description: "Wallpaper image and desktop style".to_string(),
            keywords: vec!["wallpaper".into(), "background".into(), "desktop".into(), "picture".into(), "theme".into()],
            control_type: SettingControlType::Text,
            value_type: SettingValueType::String,
            default_value: SettingValue::String("default.jpg".to_string()),
            min_value: None,
            max_value: None,
            step: None,
            options: Vec::new(),
            deep_link: "settings://dock?setting=desktop.wallpaper".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "general.about".to_string(),
            page: "about".to_string(),
            section: "System".to_string(),
            title: "About Conjunction".to_string(),
            description: "Operating system, kernel, hardware specifications, and memory".to_string(),
            keywords: vec!["about".into(), "system".into(), "kernel".into(), "cpu".into(), "ram".into(), "memory".into(), "specs".into(), "info".into(), "version".into()],
            control_type: SettingControlType::Action,
            value_type: SettingValueType::String,
            default_value: SettingValue::String("Conjunction Desktop".to_string()),
            min_value: None,
            max_value: None,
            step: None,
            options: Vec::new(),
            deep_link: "settings://about".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        // Category-level navigation descriptors for Spotlight deep linking
        reg.register(SettingDescriptor {
            id: "settings.display".to_string(),
            page: "displays".to_string(),
            section: "Displays".to_string(),
            title: "Displays & Brightness".to_string(),
            description: "Resolution, refresh rate, scaling, and monitor layout".to_string(),
            keywords: vec!["screen".into(), "monitor".into(), "resolution".into(), "brightness".into(), "displays".into()],
            control_type: SettingControlType::Action,
            value_type: SettingValueType::String,
            default_value: SettingValue::String("displays".to_string()),
            min_value: None,
            max_value: None,
            step: None,
            options: Vec::new(),
            deep_link: "settings://displays".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "settings.sound".to_string(),
            page: "sound".to_string(),
            section: "Sound".to_string(),
            title: "Sound & Audio".to_string(),
            description: "Output volume, audio devices, and alert sounds".to_string(),
            keywords: vec!["audio".into(), "volume".into(), "speakers".into(), "sound".into()],
            control_type: SettingControlType::Action,
            value_type: SettingValueType::String,
            default_value: SettingValue::String("sound".to_string()),
            min_value: None,
            max_value: None,
            step: None,
            options: Vec::new(),
            deep_link: "settings://sound".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "settings.network".to_string(),
            page: "network".to_string(),
            section: "Network".to_string(),
            title: "Wi-Fi & Network".to_string(),
            description: "Wireless connections, Ethernet, and network status".to_string(),
            keywords: vec!["wifi".into(), "wireless".into(), "network".into(), "internet".into()],
            control_type: SettingControlType::Action,
            value_type: SettingValueType::String,
            default_value: SettingValue::String("network".to_string()),
            min_value: None,
            max_value: None,
            step: None,
            options: Vec::new(),
            deep_link: "settings://network".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "settings.bluetooth".to_string(),
            page: "bluetooth".to_string(),
            section: "Bluetooth".to_string(),
            title: "Bluetooth".to_string(),
            description: "Connected devices and wireless pairing".to_string(),
            keywords: vec!["bluetooth".into(), "wireless".into(), "pair".into(), "devices".into()],
            control_type: SettingControlType::Action,
            value_type: SettingValueType::String,
            default_value: SettingValue::String("bluetooth".to_string()),
            min_value: None,
            max_value: None,
            step: None,
            options: Vec::new(),
            deep_link: "settings://bluetooth".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "settings.appearance".to_string(),
            page: "appearance".to_string(),
            section: "Appearance".to_string(),
            title: "Appearance & Theme".to_string(),
            description: "Dark mode, light mode, and accent colors".to_string(),
            keywords: vec!["theme".into(), "dark mode".into(), "light mode".into(), "color".into(), "accent".into(), "appearance".into()],
            control_type: SettingControlType::Action,
            value_type: SettingValueType::String,
            default_value: SettingValue::String("appearance".to_string()),
            min_value: None,
            max_value: None,
            step: None,
            options: Vec::new(),
            deep_link: "settings://appearance".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        reg.register(SettingDescriptor {
            id: "settings.dock".to_string(),
            page: "dock".to_string(),
            section: "Dock".to_string(),
            title: "Desktop & Dock".to_string(),
            description: "Dock size, magnification, and auto-hide".to_string(),
            keywords: vec!["dock".into(), "desktop".into(), "magnification".into(), "autohide".into()],
            control_type: SettingControlType::Action,
            value_type: SettingValueType::String,
            default_value: SettingValue::String("dock".to_string()),
            min_value: None,
            max_value: None,
            step: None,
            options: Vec::new(),
            deep_link: "settings://dock".to_string(),
            spotlight_visible: true,
            control_center_integrated: false,
            privilege_required: false,
        });

        reg
    }

    pub fn register(&mut self, descriptor: SettingDescriptor) {
        let idx = self.settings.len();
        self.by_id.insert(descriptor.id.clone(), idx);
        self.settings.push(descriptor);
    }

    pub fn all_settings(&self) -> &[SettingDescriptor] {
        &self.settings
    }

    pub fn find_by_id(&self, id: &str) -> Option<&SettingDescriptor> {
        self.by_id.get(id).map(|&idx| &self.settings[idx])
    }

    pub fn settings_for_page(&self, page: &str) -> Vec<&SettingDescriptor> {
        self.settings.iter().filter(|s| s.page == page).collect()
    }

    /// Search settings by query matching title, description, page, section, or keywords.
    pub fn search(&self, query: &str) -> Vec<SettingSearchResult> {
        let q = query.trim().to_lowercase();
        if q.is_empty() {
            return Vec::new();
        }

        let mut results = Vec::new();

        for s in &self.settings {
            let title_lower = s.title.to_lowercase();
            let page_lower = s.page.to_lowercase();
            let desc_lower = s.description.to_lowercase();
            let sec_lower = s.section.to_lowercase();

            let mut score = 0u32;

            if title_lower == q {
                score = 1000;
            } else if title_lower.starts_with(&q) {
                score = 800;
            } else if title_lower.contains(&q) {
                score = 600;
            } else if s.keywords.iter().any(|kw| kw.to_lowercase() == q) {
                score = 500;
            } else if s.keywords.iter().any(|kw| kw.to_lowercase().starts_with(&q)) {
                score = 450;
            } else if s.keywords.iter().any(|kw| kw.to_lowercase().contains(&q)) {
                score = 350;
            } else if page_lower == q || sec_lower == q {
                score = 400;
            } else if desc_lower.contains(&q) {
                score = 250;
            }

            if score > 0 {
                let icon = match s.page.as_str() {
                    "appearance" => "preferences-desktop-theme",
                    "dock" => "preferences-desktop",
                    "displays" => "video-display",
                    "sound" => "audio-volume-high",
                    "network" => "network-wireless",
                    "bluetooth" => "bluetooth",
                    "about" => "help-about",
                    _ => "preferences-system",
                };

                results.push(SettingSearchResult {
                    setting_id: s.id.clone(),
                    page: s.page.clone(),
                    title: s.title.clone(),
                    section: s.section.clone(),
                    description: s.description.clone(),
                    deep_link: s.deep_link.clone(),
                    icon: icon.to_string(),
                    score,
                });
            }
        }

        results.sort_by(|a, b| b.score.cmp(&a.score));
        results
    }

    /// Serializes registry metadata to a JSON string for consumption by Qt/QML or clients.
    pub fn to_json(&self) -> String {
        serde_json::to_string_pretty(&self.settings).unwrap_or_else(|_| "[]".to_string())
    }
}
