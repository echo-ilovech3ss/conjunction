use std::path::Path;
use conjunction_core::bundle::CURRENT_BUNDLE_FORMAT;
use conjunction_core::desktop_entry::DesktopEntry;

#[test]
fn test_terminal_bundle_spec_valid() {
    let mut bundle_path = Path::new("../data/Terminal.app");
    if !bundle_path.exists() {
        bundle_path = Path::new("data/Terminal.app");
    }
    assert!(bundle_path.exists(), "Terminal.app must exist");

    let manifest_path = bundle_path.join("Contents/Info.toml");
    assert!(manifest_path.exists(), "Terminal.app/Contents/Info.toml must exist");

    let content = std::fs::read_to_string(&manifest_path).expect("Failed to read Info.toml");
    let val: toml::Value = toml::from_str(&content).expect("Info.toml must be valid TOML");

    assert_eq!(val.get("bundle_format").and_then(|v| v.as_str()), Some(CURRENT_BUNDLE_FORMAT));
    assert_eq!(val.get("id").and_then(|v| v.as_str()), Some("org.conjunction.terminal"));
    assert_eq!(val.get("name").and_then(|v| v.as_str()), Some("Terminal"));
    assert_eq!(val.get("version").and_then(|v| v.as_str()), Some("1.0.0"));
    assert_eq!(val.get("executable").and_then(|v| v.as_str()), Some("Contents/Executable/conjunction-terminal"));

    let archs = val.get("architectures").and_then(|v| v.as_array()).expect("architectures must be array");
    assert!(archs.iter().any(|a| a.as_str() == Some("x86_64")));
}

#[test]
fn test_terminal_desktop_entry_validation() {
    let mut desktop_path = Path::new("../data/conjunction-terminal.desktop");
    if !desktop_path.exists() {
        desktop_path = Path::new("data/conjunction-terminal.desktop");
    }
    assert!(desktop_path.exists(), "conjunction-terminal.desktop must exist");

    let parsed = DesktopEntry::parse_file(desktop_path).expect("Desktop file must parse cleanly");
    assert_eq!(parsed.name, "Terminal");
    assert_eq!(parsed.exec, "conjunction-terminal");
    assert!(parsed.categories.iter().any(|c| c == "TerminalEmulator"));
}

#[test]
fn test_shell_escaping_security_contract() {
    fn escape_arg(arg: &str) -> String {
        if arg.is_empty() {
            return "''".to_string();
        }
        let is_safe = !arg.starts_with('-') && !arg.starts_with('+') && arg.chars().all(|c| {
            c.is_ascii_alphanumeric() || matches!(c, '_' | '-' | '.' | '/' | ':' | '@' | '%')
        });
        if is_safe {
            return arg.to_string();
        }
        let replaced = arg.replace('\'', "'\\''");
        format!("'{}'", replaced)
    }

    assert_eq!(escape_arg("/usr/bin/ls"), "/usr/bin/ls");
    assert_eq!(escape_arg("/home/user/My Files/doc.pdf"), "'/home/user/My Files/doc.pdf'");
    assert_eq!(escape_arg("it's a test"), r"'it'\''s a test'");
    assert_eq!(escape_arg("$(whoami); rm -rf /"), "'$(whoami); rm -rf /'");
    assert_eq!(escape_arg("--dangerous-flag"), "'--dangerous-flag'");
    assert_eq!(escape_arg("-rf"), "'-rf'");
    assert_eq!(escape_arg(""), "''");
}

#[test]
fn test_process_close_warning_decision() {
    fn requires_confirmation(term_pid: i32, fg_pid: i32, fg_name: &str) -> bool {
        if fg_pid <= 0 || fg_pid == term_pid {
            return false;
        }
        let name = fg_name.trim();
        if name.is_empty() {
            return false;
        }
        let base = Path::new(name).file_name().and_then(|s| s.to_str()).unwrap_or(name);
        !matches!(base, "bash" | "zsh" | "fish" | "sh" | "dash" | "csh" | "tcsh")
    }

    // Idle shell (term_pid == fg_pid or fg_pid is shell)
    assert!(!requires_confirmation(1001, 1001, "bash"));
    assert!(!requires_confirmation(1001, -1, ""));
    assert!(!requires_confirmation(1001, 1002, "bash"));
    assert!(!requires_confirmation(1001, 1002, "/usr/bin/zsh"));

    // Active foreground program (vim, python, gcc, cargo, nano, top)
    assert!(requires_confirmation(1001, 2045, "vim"));
    assert!(requires_confirmation(1001, 2046, "/usr/bin/python3"));
    assert!(requires_confirmation(1001, 2047, "cargo"));
    assert!(requires_confirmation(1001, 2048, "nano"));
}

#[test]
fn test_tab_title_priority_contract() {
    fn resolve_title(fg_proc: &str, cwd: &str, profile: &str, home: &str) -> String {
        let fg_trimmed = fg_proc.trim();
        if !fg_trimmed.is_empty() {
            let base = Path::new(fg_trimmed).file_name().and_then(|s| s.to_str()).unwrap_or(fg_trimmed);
            if !matches!(base, "bash" | "zsh" | "fish" | "sh" | "dash") {
                return base.to_string();
            }
        }
        if !cwd.is_empty() {
            if cwd == home {
                return "~".to_string();
            }
            if let Some(dir_name) = Path::new(cwd).file_name().and_then(|s| s.to_str()) {
                if !dir_name.is_empty() {
                    return dir_name.to_string();
                }
            }
        }
        if !profile.is_empty() && profile != "Built-in" {
            return profile.to_string();
        }
        "Terminal".to_string()
    }

    assert_eq!(resolve_title("vim", "/home/conjunction/src", "Default", "/home/conjunction"), "vim");
    assert_eq!(resolve_title("bash", "/home/conjunction/src", "Default", "/home/conjunction"), "src");
    assert_eq!(resolve_title("bash", "/home/conjunction", "Default", "/home/conjunction"), "~");
    assert_eq!(resolve_title("", "", "CustomProfile", "/home/conjunction"), "CustomProfile");
    assert_eq!(resolve_title("", "", "Built-in", "/home/conjunction"), "Terminal");
}
