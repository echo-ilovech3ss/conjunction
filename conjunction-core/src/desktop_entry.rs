use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DesktopEntry {
    pub path: PathBuf,
    pub id: String,
    pub entry_type: String,
    pub name: String,
    pub generic_name: Option<String>,
    pub comment: Option<String>,
    pub exec: String,
    pub icon: Option<String>,
    pub terminal: bool,
    pub no_display: bool,
    pub hidden: bool,
    pub try_exec: Option<String>,
    pub mime_types: Vec<String>,
    pub categories: Vec<String>,
    pub url_schemes: Vec<String>,
    pub flatpak_id: Option<String>,
}

#[derive(Debug, PartialEq, Eq)]
pub enum DesktopEntryError {
    IoError(String),
    MissingDesktopEntryGroup,
    NotAnApplication,
    MissingName,
    MissingExec,
    TryExecNotFound(String),
    HiddenOrNoDisplay,
    ConjunctionGenerated,
}

impl std::fmt::Display for DesktopEntryError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::IoError(e) => write!(f, "IO error: {}", e),
            Self::MissingDesktopEntryGroup => write!(f, "missing [Desktop Entry] group"),
            Self::NotAnApplication => write!(f, "not an Application (Type != Application)"),
            Self::MissingName => write!(f, "missing Name key"),
            Self::MissingExec => write!(f, "missing Exec key"),
            Self::TryExecNotFound(t) => write!(f, "TryExec binary '{}' not found", t),
            Self::HiddenOrNoDisplay => write!(f, "entry is Hidden or NoDisplay"),
            Self::ConjunctionGenerated => write!(f, "Conjunction-generated native desktop entry ignored as adapter"),
        }
    }
}

impl std::error::Error for DesktopEntryError {}

impl DesktopEntry {
    pub fn parse_file<P: AsRef<Path>>(path: P) -> Result<Self, DesktopEntryError> {
        let path = path.as_ref();
        let content = fs::read_to_string(path)
            .map_err(|e| DesktopEntryError::IoError(format!("cannot read {}: {}", path.display(), e)))?;
        Self::parse_str(&content, path)
    }

    pub fn parse_str(content: &str, file_path: &Path) -> Result<Self, DesktopEntryError> {
        let filename = file_path
            .file_name()
            .and_then(|f| f.to_str())
            .unwrap_or_default();

        // Rule: Ignore Conjunction's generated desktop files (conj-*.desktop or containing X-Conjunction-AppId)
        if filename.starts_with("conj-") || content.contains("X-Conjunction-AppId=") {
            return Err(DesktopEntryError::ConjunctionGenerated);
        }

        let mut in_desktop_entry = false;
        let mut keys: HashMap<String, String> = HashMap::new();

        for line in content.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }

            if line.starts_with('[') && line.ends_with(']') {
                let group = &line[1..line.len() - 1];
                if group == "Desktop Entry" {
                    in_desktop_entry = true;
                } else if in_desktop_entry {
                    // Left [Desktop Entry] group for another group (e.g. [Desktop Action])
                    break;
                }
                continue;
            }

            if in_desktop_entry {
                if let Some((k, v)) = line.split_once('=') {
                    let key = k.trim().to_string();
                    let val = v.trim().to_string();
                    keys.entry(key).or_insert(val);
                }
            }
        }

        if !in_desktop_entry && keys.is_empty() {
            return Err(DesktopEntryError::MissingDesktopEntryGroup);
        }

        let entry_type = keys
            .get("Type")
            .cloned()
            .unwrap_or_else(|| "Application".to_string());
        if entry_type != "Application" {
            return Err(DesktopEntryError::NotAnApplication);
        }

        let hidden = keys
            .get("Hidden")
            .map(|v| v.eq_ignore_ascii_case("true"))
            .unwrap_or(false);
        let no_display = keys
            .get("NoDisplay")
            .map(|v| v.eq_ignore_ascii_case("true"))
            .unwrap_or(false);

        let name = keys
            .get("Name")
            .cloned()
            .ok_or(DesktopEntryError::MissingName)?;
        if name.trim().is_empty() {
            return Err(DesktopEntryError::MissingName);
        }

        let exec = keys
            .get("Exec")
            .cloned()
            .ok_or(DesktopEntryError::MissingExec)?;
        if exec.trim().is_empty() {
            return Err(DesktopEntryError::MissingExec);
        }

        // TryExec check
        if let Some(try_exec) = keys.get("TryExec") {
            if !try_exec.is_empty() && !is_executable_available(try_exec) {
                return Err(DesktopEntryError::TryExecNotFound(try_exec.clone()));
            }
        }

        let generic_name = keys.get("GenericName").cloned();
        let comment = keys.get("Comment").cloned();
        let icon = keys.get("Icon").cloned();
        let terminal = keys
            .get("Terminal")
            .map(|v| v.eq_ignore_ascii_case("true"))
            .unwrap_or(false);

        let mime_types = parse_semicolon_list(keys.get("MimeType").unwrap_or(&String::new()));
        let categories = parse_semicolon_list(keys.get("Categories").unwrap_or(&String::new()));

        let mut url_schemes = Vec::new();
        for mime in &mime_types {
            if let Some(scheme) = mime.strip_prefix("x-scheme-handler/") {
                url_schemes.push(scheme.to_string());
            }
        }

        // Derive Desktop Entry identity
        // Desktop Entry ID is standardly the filename without .desktop (or subpath relative to applications)
        let id = filename
            .strip_suffix(".desktop")
            .unwrap_or(filename)
            .to_string();

        let flatpak_id = keys.get("X-Flatpak").cloned();

        Ok(DesktopEntry {
            path: file_path.to_path_buf(),
            id,
            entry_type,
            name,
            generic_name,
            comment,
            exec,
            icon,
            terminal,
            no_display,
            hidden,
            try_exec: keys.get("TryExec").cloned(),
            mime_types,
            categories,
            url_schemes,
            flatpak_id,
        })
    }

    /// Safely expands the Exec key into an argv array without a shell.
    pub fn expand_exec(&self, target_args: &[String]) -> Result<Vec<String>, String> {
        let raw_tokens = tokenize_exec(&self.exec)?;
        if raw_tokens.is_empty() {
            return Err("empty Exec command".to_string());
        }

        let mut argv = Vec::new();
        for token in raw_tokens {
            // Check for field codes
            let expanded = expand_field_codes(&token, self, target_args);
            argv.extend(expanded);
        }

        if argv.is_empty() {
            return Err("expanded Exec command is empty".to_string());
        }

        // If no field codes were in the Exec key but extra arguments were supplied to launch,
        // append the extra arguments to argv
        let had_field_code = self.exec.contains('%');
        if !had_field_code && !target_args.is_empty() {
            argv.extend_from_slice(target_args);
        }

        Ok(argv)
    }
}

fn parse_semicolon_list(val: &str) -> Vec<String> {
    val.split(';')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

pub fn is_executable_available(bin: &str) -> bool {
    let p = Path::new(bin);
    if p.is_absolute() {
        return p.exists();
    }
    if let Ok(paths) = std::env::var("PATH") {
        for path_entry in std::env::split_paths(&paths) {
            let candidate = path_entry.join(bin);
            if candidate.exists() {
                return true;
            }
            #[cfg(windows)]
            {
                if path_entry.join(format!("{}.exe", bin)).exists() {
                    return true;
                }
            }
        }
    }
    false
}

/// Tokenizes an Exec string according to Desktop Entry specification.
/// NO shell expansion is performed ($(), ;, |, &, `, >, < are treated as literal characters).
pub fn tokenize_exec(exec_str: &str) -> Result<Vec<String>, String> {
    let mut tokens = Vec::new();
    let mut cur = String::new();
    let mut in_single_quote = false;
    let mut in_double_quote = false;
    let mut chars = exec_str.chars().peekable();

    while let Some(c) = chars.next() {
        if in_single_quote {
            if c == '\'' {
                in_single_quote = false;
            } else {
                cur.push(c);
            }
        } else if in_double_quote {
            if c == '"' {
                in_double_quote = false;
            } else if c == '\\' {
                if let Some(&next) = chars.peek() {
                    if next == '"' || next == '`' || next == '$' || next == '\\' {
                        chars.next();
                        cur.push(next);
                    } else {
                        cur.push('\\');
                    }
                } else {
                    cur.push('\\');
                }
            } else {
                cur.push(c);
            }
        } else {
            match c {
                '\'' => in_single_quote = true,
                '"' => in_double_quote = true,
                '\\' => {
                    if let Some(&next) = chars.peek() {
                        chars.next();
                        match next {
                            's' => cur.push(' '),
                            'n' => cur.push('\n'),
                            't' => cur.push('\t'),
                            'r' => cur.push('\r'),
                            '\\' => cur.push('\\'),
                            other => cur.push(other),
                        }
                    } else {
                        cur.push('\\');
                    }
                }
                c if c.is_whitespace() => {
                    if !cur.is_empty() {
                        tokens.push(cur.clone());
                        cur.clear();
                    }
                }
                c => cur.push(c),
            }
        }
    }

    if in_single_quote || in_double_quote {
        return Err("unclosed quote in Exec key".to_string());
    }

    if !cur.is_empty() {
        tokens.push(cur);
    }

    Ok(tokens)
}

/// Expands Desktop Entry field codes (%f, %F, %u, %U, %i, %c, %k, %%).
fn expand_field_codes(token: &str, entry: &DesktopEntry, target_args: &[String]) -> Vec<String> {
    if !token.contains('%') {
        return vec![token.to_string()];
    }

    // Check if the entire token is a multi-arg field code
    if token == "%F" || token == "%U" {
        return target_args.to_vec();
    }

    if token == "%i" {
        if let Some(icon) = &entry.icon {
            return vec!["--icon".to_string(), icon.clone()];
        } else {
            return Vec::new();
        }
    }

    // Single-arg or embedded replacements
    let mut res = String::new();
    let mut chars = token.chars().peekable();

    while let Some(c) = chars.next() {
        if c == '%' {
            if let Some(code) = chars.next() {
                match code {
                    'f' | 'u' => {
                        if let Some(first) = target_args.first() {
                            res.push_str(first);
                        }
                    }
                    'F' | 'U' => {
                        // Embedded in token: join with space
                        res.push_str(&target_args.join(" "));
                    }
                    'c' => {
                        res.push_str(&entry.name);
                    }
                    'k' => {
                        res.push_str(&entry.path.to_string_lossy());
                    }
                    '%' => {
                        res.push('%');
                    }
                    'i' => {
                        if let Some(icon) = &entry.icon {
                            res.push_str("--icon ");
                            res.push_str(icon);
                        }
                    }
                    // Deprecated or unsupported codes are dropped
                    _ => {}
                }
            }
        } else {
            res.push(c);
        }
    }

    if res.is_empty() {
        Vec::new()
    } else {
        vec![res]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_desktop_entry() {
        let content = r#"
[Desktop Entry]
Type=Application
Name=Text Editor
Exec=gedit %F
Icon=accessories-text-editor
MimeType=text/plain;text/x-chdr;
Terminal=false
"#;
        let entry = DesktopEntry::parse_str(content, Path::new("/usr/share/applications/gedit.desktop")).unwrap();
        assert_eq!(entry.id, "gedit");
        assert_eq!(entry.name, "Text Editor");
        assert_eq!(entry.exec, "gedit %F");
        assert_eq!(entry.icon.as_deref(), Some("accessories-text-editor"));
        assert_eq!(entry.mime_types, vec!["text/plain", "text/x-chdr"]);
        assert!(!entry.terminal);
        assert!(!entry.no_display);
        assert!(!entry.hidden);
    }

    #[test]
    fn test_unicode_name() {
        let content = r#"
[Desktop Entry]
Type=Application
Name=编辑器 🚀
Exec=editor
"#;
        let entry = DesktopEntry::parse_str(content, Path::new("/usr/share/applications/editor.desktop")).unwrap();
        assert_eq!(entry.name, "编辑器 🚀");
    }

    #[test]
    fn test_hidden_and_nodisplay() {
        let content = r#"
[Desktop Entry]
Type=Application
Name=Hidden App
Exec=hidden
Hidden=true
NoDisplay=true
"#;
        let entry = DesktopEntry::parse_str(content, Path::new("/usr/share/applications/hidden.desktop")).unwrap();
        assert!(entry.hidden);
        assert!(entry.no_display);
    }

    #[test]
    fn test_not_application_rejected() {
        let content = r#"
[Desktop Entry]
Type=Link
Name=Example Link
URL=https://example.com
"#;
        let err = DesktopEntry::parse_str(content, Path::new("/usr/share/applications/link.desktop")).unwrap_err();
        assert_eq!(err, DesktopEntryError::NotAnApplication);
    }

    #[test]
    fn test_conjunction_native_desktop_ignored() {
        let content = r#"
[Desktop Entry]
Type=Application
Name=Hello
Exec=/foo/hello
X-Conjunction-AppId=dev.conjunction.test.hello
"#;
        let err = DesktopEntry::parse_str(content, Path::new("/tmp/conj-dev.conjunction.test.hello.desktop")).unwrap_err();
        assert_eq!(err, DesktopEntryError::ConjunctionGenerated);
    }

    #[test]
    fn test_expand_exec_field_codes() {
        let content = r#"
[Desktop Entry]
Type=Application
Name=Viewer
Exec=viewer %f --name %c %%
Icon=viewer-icon
"#;
        let entry = DesktopEntry::parse_str(content, Path::new("/usr/share/applications/viewer.desktop")).unwrap();
        let argv = entry.expand_exec(&["/path/to/doc.pdf".to_string()]).unwrap();
        assert_eq!(argv, vec!["viewer", "/path/to/doc.pdf", "--name", "Viewer", "%"]);
    }

    #[test]
    fn test_expand_exec_multi_file_f() {
        let content = r#"
[Desktop Entry]
Type=Application
Name=Viewer
Exec=viewer %F
"#;
        let entry = DesktopEntry::parse_str(content, Path::new("/usr/share/applications/viewer.desktop")).unwrap();
        let argv = entry.expand_exec(&["file1.txt".to_string(), "file2.txt".to_string()]).unwrap();
        assert_eq!(argv, vec!["viewer", "file1.txt", "file2.txt"]);
    }

    #[test]
    fn test_expand_exec_icon_flag() {
        let content = r#"
[Desktop Entry]
Type=Application
Name=App
Exec=app %i
Icon=test-icon
"#;
        let entry = DesktopEntry::parse_str(content, Path::new("/usr/share/applications/app.desktop")).unwrap();
        let argv = entry.expand_exec(&[]).unwrap();
        assert_eq!(argv, vec!["app", "--icon", "test-icon"]);
    }

    #[test]
    fn test_hostile_exec_semicolon_no_shell() {
        let content = r#"
[Desktop Entry]
Type=Application
Name=Hostile1
Exec=myprog; touch /tmp/pwned_semi
"#;
        let entry = DesktopEntry::parse_str(content, Path::new("/usr/share/applications/hostile1.desktop")).unwrap();
        let argv = entry.expand_exec(&[]).unwrap();
        assert_eq!(argv, vec!["myprog;", "touch", "/tmp/pwned_semi"]);
    }

    #[test]
    fn test_hostile_exec_pipe_no_shell() {
        let content = r#"
[Desktop Entry]
Type=Application
Name=Hostile2
Exec=myprog | touch /tmp/pwned_pipe
"#;
        let entry = DesktopEntry::parse_str(content, Path::new("/usr/share/applications/hostile2.desktop")).unwrap();
        let argv = entry.expand_exec(&[]).unwrap();
        assert_eq!(argv, vec!["myprog", "|", "touch", "/tmp/pwned_pipe"]);
    }

    #[test]
    fn test_hostile_exec_command_substitution_no_shell() {
        let content = r#"
[Desktop Entry]
Type=Application
Name=Hostile3
Exec=myprog "$(touch /tmp/pwned_subst)" "`touch /tmp/pwned_backtick`"
"#;
        let entry = DesktopEntry::parse_str(content, Path::new("/usr/share/applications/hostile3.desktop")).unwrap();
        let argv = entry.expand_exec(&[]).unwrap();
        assert_eq!(argv, vec!["myprog", "$(touch /tmp/pwned_subst)", "`touch /tmp/pwned_backtick`"]);
    }

    #[test]
    fn test_quotes_and_escapes() {
        let content = r#"
[Desktop Entry]
Type=Application
Name=Quoted
Exec=myprog "arg with spaces" 'single quoted' escaped\ space
"#;
        let entry = DesktopEntry::parse_str(content, Path::new("/usr/share/applications/quoted.desktop")).unwrap();
        let argv = entry.expand_exec(&[]).unwrap();
        assert_eq!(argv, vec!["myprog", "arg with spaces", "single quoted", "escaped space"]);
    }
}
