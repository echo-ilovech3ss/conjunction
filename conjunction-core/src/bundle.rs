use crate::security::{check_bundle_symlinks_contained, verify_bundle_manifest, MANIFEST_SHA256_REL};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fmt;
use std::path::{Component, Path, PathBuf};

pub const BUNDLE_FORMAT_V1: &str = "conjunction.app/1";
pub const BUNDLE_FORMAT_V2: &str = "conjunction.app/2";
pub const CURRENT_BUNDLE_FORMAT: &str = BUNDLE_FORMAT_V2;
pub const SUPPORTED_BUNDLE_FORMATS: &[&str] = &[BUNDLE_FORMAT_V1, BUNDLE_FORMAT_V2];
pub const SUPPORTED_ARCHITECTURES: &[&str] = &["x86_64", "aarch64", "noarch"];
pub const DEFAULT_RUNTIME: &str = "conjunction-1";
pub const SUPPORTED_RUNTIMES: &[&str] = &[
    "conjunction-1",
    "conjunction-runtime-1",
    "native",
    "appimage",
    "flatpak",
    "wine",
    "static",
    "none",
];

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum RuntimeKind {
    Conjunction1,
    AppImage,
    Flatpak,
    Wine,
    Static,
}

impl RuntimeKind {
    pub fn parse(raw: Option<&str>) -> Result<Self, BundleError> {
        let s = raw.unwrap_or(DEFAULT_RUNTIME).trim().to_ascii_lowercase();
        match s.as_str() {
            "" | "conjunction-1" | "conjunction-runtime-1" | "native" => Ok(RuntimeKind::Conjunction1),
            "appimage" => Ok(RuntimeKind::AppImage),
            "flatpak" => Ok(RuntimeKind::Flatpak),
            "wine" => Ok(RuntimeKind::Wine),
            "static" | "none" => Ok(RuntimeKind::Static),
            other => Err(BundleError::UnsupportedRuntime(other.to_string())),
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            RuntimeKind::Conjunction1 => "conjunction-1",
            RuntimeKind::AppImage => "appimage",
            RuntimeKind::Flatpak => "flatpak",
            RuntimeKind::Wine => "wine",
            RuntimeKind::Static => "static",
        }
    }
}

impl fmt::Display for RuntimeKind {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

pub fn host_arch() -> &'static str {
    match std::env::consts::ARCH {
        "x86_64" | "amd64" => "x86_64",
        "aarch64" | "arm64" => "aarch64",
        other => other,
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum BundleError {
    NotADirectory(PathBuf),
    MissingContents(PathBuf),
    MissingManifest(PathBuf),
    UnreadableManifest(String),
    MalformedManifest(String),
    UnsupportedFormatVersion(String),
    MissingApplicationId,
    InvalidApplicationId(String),
    MissingExecutableDeclaration,
    AbsoluteExecutablePath(String),
    ExecutablePathTraversal(String),
    MissingExecutableFile(PathBuf),
    ExecutableEscapesBundle(PathBuf),
    ExecutableNotRegularFile(PathBuf),
    ExecutableNotExecutable(PathBuf),
    UnsupportedArchitecture(String),
    EmptyArchitectures,
    UnsupportedHostArchitecture {
        host_arch: String,
        supported: Vec<String>,
        detail: String,
    },
    UnsupportedRuntime(String),
    MinimumOsNotMet {
        required: String,
        actual: String,
    },
    InvalidRelativePath {
        field: String,
        path: String,
    },
    PathEscapesBundle {
        field: String,
        path: PathBuf,
    },
    IntegrityError(String),
    InvalidSpec(String),
    IoError(String),
}

impl fmt::Display for BundleError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            BundleError::NotADirectory(p) => write!(f, "path is not a directory: {}", p.display()),
            BundleError::MissingContents(p) => write!(f, "missing Contents directory: {}", p.display()),
            BundleError::MissingManifest(p) => write!(f, "missing Info.toml manifest: {}", p.display()),
            BundleError::UnreadableManifest(e) => write!(f, "failed to read Info.toml: {}", e),
            BundleError::MalformedManifest(e) => write!(f, "malformed Info.toml manifest: {}", e),
            BundleError::UnsupportedFormatVersion(v) => write!(
                f,
                "unsupported bundle format version: '{}' (expected {:?})",
                v, SUPPORTED_BUNDLE_FORMATS
            ),
            BundleError::MissingApplicationId => write!(f, "manifest is missing required 'id' field"),
            BundleError::InvalidApplicationId(id) => write!(
                f,
                "invalid application ID '{}': must follow reverse-DNS format (e.g. org.example.app)",
                id
            ),
            BundleError::MissingExecutableDeclaration => {
                write!(f, "manifest is missing required 'executable' declaration")
            }
            BundleError::AbsoluteExecutablePath(p) => {
                write!(f, "executable path must be relative: '{}'", p)
            }
            BundleError::ExecutablePathTraversal(p) => {
                write!(f, "executable path contains traversal: '{}'", p)
            }
            BundleError::MissingExecutableFile(p) => {
                write!(f, "executable file not found: {}", p.display())
            }
            BundleError::ExecutableEscapesBundle(p) => {
                write!(f, "executable escapes application bundle: {}", p.display())
            }
            BundleError::ExecutableNotRegularFile(p) => {
                write!(f, "executable is not a regular file: {}", p.display())
            }
            BundleError::ExecutableNotExecutable(p) => {
                write!(f, "executable lacks execute permission: {}", p.display())
            }
            BundleError::UnsupportedArchitecture(arch) => write!(
                f,
                "unsupported architecture '{}': supported architectures are {:?}",
                arch, SUPPORTED_ARCHITECTURES
            ),
            BundleError::EmptyArchitectures => write!(f, "architectures list cannot be empty"),
            BundleError::UnsupportedHostArchitecture {
                host_arch,
                supported,
                detail,
            } => write!(
                f,
                "bundle does not support host architecture '{}' (declared: {:?}): {}",
                host_arch, supported, detail
            ),
            BundleError::UnsupportedRuntime(rt) => write!(
                f,
                "unsupported runtime '{}': supported runtimes are {:?}",
                rt, SUPPORTED_RUNTIMES
            ),
            BundleError::MinimumOsNotMet { required, actual } => write!(
                f,
                "minimum OS version '{}' required, but host OS is '{}'",
                required, actual
            ),
            BundleError::InvalidRelativePath { field, path } => {
                write!(f, "field '{}' must be a safe relative path, got '{}'", field, path)
            }
            BundleError::PathEscapesBundle { field, path } => {
                write!(f, "field '{}' escapes application bundle: {}", field, path.display())
            }
            BundleError::IntegrityError(e) => write!(f, "bundle integrity check failed: {}", e),
            BundleError::InvalidSpec(e) => write!(f, "invalid bundle specification: {}", e),
            BundleError::IoError(e) => write!(f, "I/O error: {}", e),
        }
    }
}

impl std::error::Error for BundleError {}

impl From<std::io::Error> for BundleError {
    fn from(e: std::io::Error) -> Self {
        BundleError::IoError(e.to_string())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DocumentType {
    pub name: String,
    #[serde(default)]
    pub role: Option<String>,
    #[serde(default)]
    pub mime_types: Vec<String>,
    #[serde(default)]
    pub extensions: Vec<String>,
    #[serde(default)]
    pub icon: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FlatpakSpec {
    pub id: String,
    #[serde(default)]
    pub remote: Option<String>,
    #[serde(default)]
    pub scope: Option<String>,
}

fn default_wine_prefix() -> String {
    "Contents/WinePrefix".to_string()
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct WineSpec {
    #[serde(default = "default_wine_prefix")]
    pub prefix: String,
    pub target_exe: String,
    #[serde(default)]
    pub args: Vec<String>,
    #[serde(default)]
    pub arch: Option<String>,
    #[serde(default)]
    pub esync: Option<bool>,
    #[serde(default)]
    pub fsync: Option<bool>,
    #[serde(default)]
    pub dxvk_hud: Option<String>,
    #[serde(default)]
    pub wine_debug: Option<String>,
    #[serde(default)]
    pub use_proton: Option<bool>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppImageSpec {
    #[serde(default)]
    pub payload: Option<String>,
    #[serde(default)]
    pub extract_and_run_fallback: Option<bool>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Manifest {
    pub bundle_format: String,
    pub id: String,
    pub name: String,
    pub version: String,
    #[serde(default)]
    pub executable: String,
    #[serde(default)]
    pub executables: Option<HashMap<String, String>>,
    pub architectures: Vec<String>,
    #[serde(default)]
    pub runtime: Option<String>,
    #[serde(default)]
    pub minimum_os: Option<String>,
    #[serde(default)]
    pub icon: Option<String>,
    #[serde(default)]
    pub mime_types: Option<Vec<String>>,
    #[serde(default)]
    pub document_types: Option<Vec<DocumentType>>,
    #[serde(default)]
    pub url_schemes: Option<Vec<String>>,
    #[serde(default)]
    pub category: Option<String>,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub terminal: Option<bool>,
    #[serde(default)]
    pub permissions: Option<Vec<String>>,
    #[serde(default)]
    pub data: Option<HashMap<String, String>>,
    #[serde(default)]
    pub flatpak: Option<FlatpakSpec>,
    #[serde(default)]
    pub wine: Option<WineSpec>,
    #[serde(default)]
    pub appimage: Option<AppImageSpec>,
}

impl Manifest {
    pub fn runtime_kind(&self) -> Result<RuntimeKind, BundleError> {
        RuntimeKind::parse(self.runtime.as_deref())
    }

    pub fn effective_mime_types(&self) -> Vec<String> {
        let mut out = Vec::new();
        if let Some(ref mimes) = self.mime_types {
            for m in mimes {
                let m = m.trim();
                if !m.is_empty() && !out.iter().any(|x| x == m) {
                    out.push(m.to_string());
                }
            }
        }
        if let Some(ref doc_types) = self.document_types {
            for dt in doc_types {
                for m in &dt.mime_types {
                    let m = m.trim();
                    if !m.is_empty() && !out.iter().any(|x| x == m) {
                        out.push(m.to_string());
                    }
                }
            }
        }
        if let Some(ref schemes) = self.url_schemes {
            for s in schemes {
                let scheme = s.trim().trim_end_matches(':');
                if !scheme.is_empty() {
                    let handler = format!("x-scheme-handler/{}", scheme);
                    if !out.iter().any(|x| x == &handler) {
                        out.push(handler);
                    }
                }
            }
        }
        out
    }
}

#[derive(Debug, Clone)]
pub struct Bundle {
    path: PathBuf,
    manifest: Manifest,
}

impl Bundle {
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self, BundleError> {
        let path = path.as_ref().to_path_buf();
        if !path.exists() || !path.is_dir() {
            return Err(BundleError::NotADirectory(path));
        }

        let contents_dir = path.join("Contents");
        if !contents_dir.is_dir() {
            return Err(BundleError::MissingContents(contents_dir));
        }

        let info_path = contents_dir.join("Info.toml");
        if !info_path.is_file() {
            return Err(BundleError::MissingManifest(info_path));
        }

        let content = std::fs::read_to_string(&info_path)
            .map_err(|e| BundleError::UnreadableManifest(e.to_string()))?;
        let manifest: Manifest = toml::from_str(&content)
            .map_err(|e| BundleError::MalformedManifest(e.to_string()))?;

        Ok(Bundle { path, manifest })
    }

    pub fn manifest(&self) -> &Manifest {
        &self.manifest
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn runtime_kind(&self) -> Result<RuntimeKind, BundleError> {
        self.manifest.runtime_kind()
    }

    pub fn validate(&self) -> Result<(), BundleError> {
        self.validate_manifest()?;
        check_bundle_symlinks_contained(&self.path)
            .map_err(|e| BundleError::PathEscapesBundle {
                field: "Contents".to_string(),
                path: PathBuf::from(e.to_string()),
            })?;
        self.validate_frameworks_containment()?;
        self.validate_icon_containment()?;
        self.validate_all_declared_executables()?;
        self.validate_runtime_payloads()?;
        if self.path.join(MANIFEST_SHA256_REL).exists() {
            verify_bundle_manifest(&self.path)
                .map_err(|e| BundleError::IntegrityError(e.to_string()))?;
        }
        Ok(())
    }

    pub fn validate_manifest(&self) -> Result<(), BundleError> {
        if !SUPPORTED_BUNDLE_FORMATS.contains(&self.manifest.bundle_format.as_str()) {
            return Err(BundleError::UnsupportedFormatVersion(
                self.manifest.bundle_format.clone(),
            ));
        }

        if self.manifest.name.trim().is_empty() {
            return Err(BundleError::InvalidSpec("manifest 'name' cannot be empty".to_string()));
        }

        Self::validate_id(&self.manifest.id)?;

        let has_map = self
            .manifest
            .executables
            .as_ref()
            .is_some_and(|m| !m.is_empty());
        if self.manifest.executable.trim().is_empty() && !has_map {
            return Err(BundleError::MissingExecutableDeclaration);
        }

        if !self.manifest.executable.trim().is_empty() {
            Self::validate_executable_path_syntax(&self.manifest.executable)?;
        }

        if let Some(ref map) = self.manifest.executables {
            for (arch, rel) in map {
                if !SUPPORTED_ARCHITECTURES.contains(&arch.as_str()) {
                    return Err(BundleError::UnsupportedArchitecture(arch.clone()));
                }
                Self::validate_executable_path_syntax(rel)?;
            }
        }

        if self.manifest.architectures.is_empty() {
            return Err(BundleError::EmptyArchitectures);
        }

        for arch in &self.manifest.architectures {
            if !SUPPORTED_ARCHITECTURES.contains(&arch.as_str()) {
                return Err(BundleError::UnsupportedArchitecture(arch.clone()));
            }
        }

        let runtime = self.manifest.runtime_kind()?;

        if let Some(ref min_os) = self.manifest.minimum_os {
            if parse_os_version_components(min_os).is_none() {
                return Err(BundleError::InvalidSpec(format!(
                    "invalid minimum_os version '{}'",
                    min_os
                )));
            }
        }

        if let Some(ref schemes) = self.manifest.url_schemes {
            for s in schemes {
                let trimmed = s.trim();
                if trimmed.is_empty()
                    || !trimmed
                        .chars()
                        .all(|c| c.is_ascii_alphanumeric() || matches!(c, '+' | '-' | '.'))
                {
                    return Err(BundleError::InvalidSpec(format!(
                        "invalid URL scheme '{}'",
                        s
                    )));
                }
            }
        }

        if let Some(ref data_map) = self.manifest.data {
            for (k, v) in data_map {
                if v.contains('/') || v.contains('\\') || v.contains("..") || v.trim().is_empty() {
                    return Err(BundleError::InvalidSpec(format!(
                        "unsafe data namespace for '{}': '{}'",
                        k, v
                    )));
                }
            }
        }

        match runtime {
            RuntimeKind::Flatpak => {
                if let Some(ref fp) = self.manifest.flatpak {
                    Self::validate_id(&fp.id)?;
                    if let Some(ref scope) = fp.scope {
                        if scope != "user" && scope != "system" {
                            return Err(BundleError::InvalidSpec(format!(
                                "flatpak scope must be 'user' or 'system', got '{}'",
                                scope
                            )));
                        }
                    }
                } else {
                    return Err(BundleError::InvalidSpec(
                        "runtime 'flatpak' requires a [flatpak] table with 'id'".to_string(),
                    ));
                }
            }
            RuntimeKind::Wine => {
                if let Some(ref wine) = self.manifest.wine {
                    Self::validate_relative_path("wine.prefix", &wine.prefix)?;
                    Self::validate_relative_path("wine.target_exe", &wine.target_exe)?;
                } else {
                    return Err(BundleError::InvalidSpec(
                        "runtime 'wine' requires a [wine] table with 'target_exe'".to_string(),
                    ));
                }
            }
            RuntimeKind::AppImage => {
                if let Some(ref ai) = self.manifest.appimage {
                    if let Some(ref payload) = ai.payload {
                        Self::validate_relative_path("appimage.payload", payload)?;
                    }
                }
            }
            RuntimeKind::Conjunction1 | RuntimeKind::Static => {}
        }

        Ok(())
    }

    pub fn validate_id(id: &str) -> Result<(), BundleError> {
        let trimmed = id.trim();
        if trimmed.is_empty() {
            return Err(BundleError::MissingApplicationId);
        }

        if trimmed != id {
            return Err(BundleError::InvalidApplicationId(id.to_string()));
        }

        if id.starts_with('.') || id.ends_with('.') || id.contains("..") {
            return Err(BundleError::InvalidApplicationId(id.to_string()));
        }

        let segments: Vec<&str> = id.split('.').collect();
        if segments.len() < 2 {
            return Err(BundleError::InvalidApplicationId(id.to_string()));
        }

        for seg in segments {
            if seg.is_empty() {
                return Err(BundleError::InvalidApplicationId(id.to_string()));
            }

            if seg.starts_with('-') || seg.ends_with('-') || seg.starts_with('_') || seg.ends_with('_') {
                return Err(BundleError::InvalidApplicationId(id.to_string()));
            }

            for ch in seg.chars() {
                if !ch.is_ascii_alphanumeric() && ch != '-' && ch != '_' {
                    return Err(BundleError::InvalidApplicationId(id.to_string()));
                }
            }
        }

        Ok(())
    }

    pub fn validate_relative_path(field: &str, rel_path: &str) -> Result<(), BundleError> {
        if rel_path.trim().is_empty() || rel_path.contains('\0') {
            return Err(BundleError::InvalidRelativePath {
                field: field.to_string(),
                path: rel_path.to_string(),
            });
        }
        let p = Path::new(rel_path);
        if p.is_absolute()
            || rel_path.starts_with('/')
            || rel_path.starts_with('\\')
            || (rel_path.len() >= 2 && rel_path.as_bytes()[1] == b':')
        {
            return Err(BundleError::InvalidRelativePath {
                field: field.to_string(),
                path: rel_path.to_string(),
            });
        }
        for comp in p.components() {
            match comp {
                Component::ParentDir | Component::RootDir | Component::Prefix(_) => {
                    return Err(BundleError::InvalidRelativePath {
                        field: field.to_string(),
                        path: rel_path.to_string(),
                    });
                }
                _ => {}
            }
        }
        Ok(())
    }

    pub fn validate_executable_path_syntax(exec_path_str: &str) -> Result<(), BundleError> {
        let p = Path::new(exec_path_str);

        if p.is_absolute()
            || exec_path_str.starts_with('/')
            || exec_path_str.starts_with('\\')
            || (exec_path_str.len() >= 2 && exec_path_str.as_bytes()[1] == b':')
        {
            return Err(BundleError::AbsoluteExecutablePath(exec_path_str.to_string()));
        }

        for comp in p.components() {
            match comp {
                Component::ParentDir => {
                    return Err(BundleError::ExecutablePathTraversal(exec_path_str.to_string()));
                }
                Component::RootDir | Component::Prefix(_) => {
                    return Err(BundleError::AbsoluteExecutablePath(exec_path_str.to_string()));
                }
                _ => {}
            }
        }

        Ok(())
    }

    fn resolve_contained_executable_rel(&self, rel: &str) -> Result<PathBuf, BundleError> {
        Self::validate_executable_path_syntax(rel)?;
        let declared_path = self.path.join(rel);
        if !declared_path.exists() {
            return Err(BundleError::MissingExecutableFile(declared_path));
        }

        let canonical_bundle = self
            .path
            .canonicalize()
            .map_err(|e| BundleError::IoError(format!("cannot canonicalize bundle: {}", e)))?;

        let canonical_exec = declared_path
            .canonicalize()
            .map_err(|e| BundleError::IoError(format!("cannot canonicalize executable: {}", e)))?;

        if !canonical_exec.starts_with(&canonical_bundle) || canonical_exec == canonical_bundle {
            return Err(BundleError::ExecutableEscapesBundle(canonical_exec));
        }

        let meta = std::fs::metadata(&canonical_exec)
            .map_err(|e| BundleError::IoError(format!("failed to read executable metadata: {}", e)))?;

        if !meta.is_file() {
            return Err(BundleError::ExecutableNotRegularFile(canonical_exec));
        }

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mode = meta.permissions().mode();
            if mode & 0o111 == 0 {
                return Err(BundleError::ExecutableNotExecutable(canonical_exec));
            }
        }

        Ok(canonical_exec)
    }

    fn validate_all_declared_executables(&self) -> Result<(), BundleError> {
        if self.manifest.architectures.iter().any(|a| a == "noarch") {
            self.resolve_executable_for_arch("noarch")?;
            return Ok(());
        }
        let current_host = host_arch();
        for arch in &self.manifest.architectures {
            if let Err(err) = self.resolve_executable_for_arch(arch) {
                if arch != current_host {
                    if let BundleError::UnsupportedHostArchitecture { detail, .. } = err {
                        return Err(BundleError::InvalidSpec(format!(
                            "declared architecture '{}' is missing executable ({})",
                            arch, detail
                        )));
                    }
                }
                return Err(err);
            }
        }
        Ok(())
    }

    pub fn resolve_executable_for_arch(&self, target_arch: &str) -> Result<PathBuf, BundleError> {
        if !SUPPORTED_ARCHITECTURES.contains(&target_arch) {
            return Err(BundleError::UnsupportedArchitecture(target_arch.to_string()));
        }

        let arch_declared = target_arch == "noarch"
            || self
                .manifest
                .architectures
                .iter()
                .any(|a| a == target_arch || a == "noarch");

        // 1. Explicit [executables] map
        if let Some(ref map) = self.manifest.executables {
            if let Some(rel) = map.get(target_arch) {
                if !arch_declared {
                    return Err(BundleError::UnsupportedHostArchitecture {
                        host_arch: target_arch.to_string(),
                        supported: self.manifest.architectures.clone(),
                        detail: format!("architecture '{}' is not listed in manifest.architectures", target_arch),
                    });
                }
                return self.resolve_contained_executable_rel(rel);
            }
            if let Some(rel) = map.get("noarch") {
                if arch_declared {
                    return self.resolve_contained_executable_rel(rel);
                }
            }
            if self.manifest.executable.trim().is_empty() {
                return Err(BundleError::UnsupportedHostArchitecture {
                    host_arch: target_arch.to_string(),
                    supported: self.manifest.architectures.clone(),
                    detail: format!(
                        "missing [executables].{} entry in universal bundle",
                        target_arch
                    ),
                });
            }
        }

        let raw_exec = self.manifest.executable.trim();
        if raw_exec.is_empty() {
            return Err(BundleError::MissingExecutableDeclaration);
        }
        Self::validate_executable_path_syntax(raw_exec)?;

        // 2. Placeholder form: Contents/MacOS/{arch}/myapp or ${arch}
        if raw_exec.contains("{arch}") || raw_exec.contains("${arch}") {
            if !arch_declared {
                return Err(BundleError::UnsupportedHostArchitecture {
                    host_arch: target_arch.to_string(),
                    supported: self.manifest.architectures.clone(),
                    detail: format!("architecture '{}' is not listed in manifest.architectures", target_arch),
                });
            }
            let substituted = raw_exec
                .replace("${arch}", target_arch)
                .replace("{arch}", target_arch);
            return self.resolve_contained_executable_rel(&substituted);
        }

        // 3. Universal layout probing: Contents/MacOS/<arch>/<basename>
        if let Some(basename) = Path::new(raw_exec).file_name().and_then(|s| s.to_str()) {
            if target_arch != "noarch" {
                let arch_rel = format!("Contents/MacOS/{}/{}", target_arch, basename);
                if self.path.join(&arch_rel).exists() || self.path.join(&arch_rel).is_symlink() {
                    if !arch_declared {
                        return Err(BundleError::UnsupportedHostArchitecture {
                            host_arch: target_arch.to_string(),
                            supported: self.manifest.architectures.clone(),
                            detail: format!(
                                "architecture '{}' is not declared in architectures",
                                target_arch
                            ),
                        });
                    }
                    return self.resolve_contained_executable_rel(&arch_rel);
                }

                // Check if another arch directory exists while target_arch is missing
                let other_arch_exists = ["x86_64", "aarch64"]
                    .iter()
                    .filter(|&&a| a != target_arch)
                    .any(|a| self.path.join(format!("Contents/MacOS/{}/{}", a, basename)).exists());

                if other_arch_exists && !self.path.join(raw_exec).exists() {
                    return Err(BundleError::UnsupportedHostArchitecture {
                        host_arch: target_arch.to_string(),
                        supported: self.manifest.architectures.clone(),
                        detail: format!(
                            "missing universal binary Contents/MacOS/{}/{}",
                            target_arch, basename
                        ),
                    });
                }
            }
        }

        // 4. Direct relative path (or Contents/MacOS/<name> if bare filename)
        if !arch_declared {
            return Err(BundleError::UnsupportedHostArchitecture {
                host_arch: target_arch.to_string(),
                supported: self.manifest.architectures.clone(),
                detail: format!(
                    "bundle only declares architectures {:?}; '{}' is not supported",
                    self.manifest.architectures, target_arch
                ),
            });
        }

        let direct_candidate = self.path.join(raw_exec);
        if direct_candidate.exists() || direct_candidate.is_symlink() {
            return self.resolve_contained_executable_rel(raw_exec);
        }

        if !raw_exec.contains('/') && !raw_exec.contains('\\') {
            let macos_rel = format!("Contents/MacOS/{}", raw_exec);
            if self.path.join(&macos_rel).exists() || self.path.join(&macos_rel).is_symlink() {
                return self.resolve_contained_executable_rel(&macos_rel);
            }
        }

        self.resolve_contained_executable_rel(raw_exec)
    }

    pub fn resolve_executable(&self) -> Result<PathBuf, BundleError> {
        let arch = host_arch();
        if self.manifest.architectures.iter().any(|a| a == arch || a == "noarch") {
            return self.resolve_executable_for_arch(arch);
        }
        if let Some(first) = self.manifest.architectures.first() {
            return self.resolve_executable_for_arch(first);
        }
        Err(BundleError::EmptyArchitectures)
    }

    pub fn resolve_executable_for_host(&self) -> Result<PathBuf, BundleError> {
        self.check_minimum_os()?;
        self.resolve_executable_for_arch(host_arch())
    }

    pub fn executable_path(&self) -> Result<PathBuf, BundleError> {
        self.resolve_executable()
    }

    pub fn check_minimum_os(&self) -> Result<(), BundleError> {
        let Some(ref req) = self.manifest.minimum_os else {
            return Ok(());
        };
        let Some(actual) = detect_host_os_version() else {
            return Ok(());
        };
        let Some(req_parts) = parse_os_version_components(req) else {
            return Err(BundleError::InvalidSpec(format!(
                "invalid minimum_os '{}'",
                req
            )));
        };
        let Some(act_parts) = parse_os_version_components(&actual) else {
            return Ok(());
        };

        if compare_versions(&act_parts, &req_parts) == std::cmp::Ordering::Less {
            return Err(BundleError::MinimumOsNotMet {
                required: req.clone(),
                actual,
            });
        }
        Ok(())
    }

    fn validate_frameworks_containment(&self) -> Result<(), BundleError> {
        let _ = self.frameworks_dirs()?;
        Ok(())
    }

    /// Returns canonicalized framework/library directories (`Contents/Frameworks[/<arch>]`,
    /// `Contents/Libraries[/<arch>]`) strictly inside the bundle root.
    pub fn frameworks_dirs(&self) -> Result<Vec<PathBuf>, BundleError> {
        let canonical_bundle = self
            .path
            .canonicalize()
            .map_err(|e| BundleError::IoError(e.to_string()))?;
        let arch = host_arch();
        let candidates = [
            format!("Contents/Frameworks/{}", arch),
            "Contents/Frameworks".to_string(),
            format!("Contents/Libraries/{}", arch),
            "Contents/Libraries".to_string(),
        ];

        let mut dirs = Vec::new();
        for rel in &candidates {
            let p = self.path.join(rel);
            if p.exists() || p.is_symlink() {
                let canon = p.canonicalize().map_err(|_| BundleError::PathEscapesBundle {
                    field: rel.clone(),
                    path: p.clone(),
                })?;
                if !canon.starts_with(&canonical_bundle) || canon == canonical_bundle {
                    return Err(BundleError::PathEscapesBundle {
                        field: rel.clone(),
                        path: canon,
                    });
                }
                if canon.is_dir() && !dirs.contains(&canon) {
                    dirs.push(canon);
                }
            }
        }
        Ok(dirs)
    }

    fn validate_icon_containment(&self) -> Result<(), BundleError> {
        let Some(ref icon_val) = self.manifest.icon else {
            return Ok(());
        };
        if icon_val.trim().is_empty() {
            return Err(BundleError::InvalidRelativePath {
                field: "icon".to_string(),
                path: icon_val.clone(),
            });
        }
        if icon_val.contains('/') || icon_val.contains('\\') || icon_val.contains("..") {
            Self::validate_relative_path("icon", icon_val)?;
            let canonical_bundle = self.path.canonicalize()?;
            for cand in [
                self.path.join(icon_val),
                self.path.join("Contents/Resources").join(icon_val),
                self.path.join("Contents/Icons").join(icon_val),
            ] {
                if cand.exists() || cand.is_symlink() {
                    let canon = cand.canonicalize().map_err(|_| BundleError::PathEscapesBundle {
                        field: "icon".to_string(),
                        path: cand.clone(),
                    })?;
                    if !canon.starts_with(&canonical_bundle) {
                        return Err(BundleError::PathEscapesBundle {
                            field: "icon".to_string(),
                            path: canon,
                        });
                    }
                }
            }
        }
        Ok(())
    }

    fn validate_runtime_payloads(&self) -> Result<(), BundleError> {
        if let Some(ref wine) = self.manifest.wine {
            let canonical_bundle = self.path.canonicalize()?;
            for (field, rel) in [("wine.prefix", &wine.prefix), ("wine.target_exe", &wine.target_exe)] {
                Self::validate_relative_path(field, rel)?;
                let p = self.path.join(rel);
                if p.exists() || p.is_symlink() {
                    let canon = p.canonicalize().map_err(|_| BundleError::PathEscapesBundle {
                        field: field.to_string(),
                        path: p.clone(),
                    })?;
                    if !canon.starts_with(&canonical_bundle) {
                        return Err(BundleError::PathEscapesBundle {
                            field: field.to_string(),
                            path: canon,
                        });
                    }
                }
            }
        }
        if let Some(ref ai) = self.manifest.appimage {
            if let Some(ref payload) = ai.payload {
                Self::validate_relative_path("appimage.payload", payload)?;
                let p = self.path.join(payload);
                if p.exists() || p.is_symlink() {
                    let canonical_bundle = self.path.canonicalize()?;
                    let canon = p.canonicalize().map_err(|_| BundleError::PathEscapesBundle {
                        field: "appimage.payload".to_string(),
                        path: p.clone(),
                    })?;
                    if !canon.starts_with(&canonical_bundle) {
                        return Err(BundleError::PathEscapesBundle {
                            field: "appimage.payload".to_string(),
                            path: canon,
                        });
                    }
                }
            }
        }
        Ok(())
    }

    /// Resolves a physical icon file inside the bundle (if one exists) without escaping the bundle.
    pub fn resolve_icon_file(&self) -> Option<PathBuf> {
        let canonical_bundle = self.path.canonicalize().ok()?;
        let mut candidates = Vec::new();
        if let Some(ref icon_val) = self.manifest.icon {
            let looks_like_file = icon_val.contains('/')
                || icon_val.ends_with(".png")
                || icon_val.ends_with(".svg")
                || icon_val.ends_with(".ico")
                || icon_val.ends_with(".xpm")
                || icon_val.ends_with(".webp")
                || icon_val.ends_with(".jpg");
            if looks_like_file && Self::validate_relative_path("icon", icon_val).is_ok() {
                candidates.push(self.path.join(icon_val));
                candidates.push(self.path.join("Contents/Resources").join(icon_val));
                candidates.push(self.path.join("Contents/Icons").join(icon_val));
            } else if !icon_val.contains('/') && !icon_val.contains('\\') && !icon_val.contains("..") {
                candidates.push(self.path.join(format!("Contents/Resources/{}.svg", icon_val)));
                candidates.push(self.path.join(format!("Contents/Resources/{}.png", icon_val)));
                candidates.push(self.path.join(format!("Contents/Icons/{}.svg", icon_val)));
                candidates.push(self.path.join(format!("Contents/Icons/{}.png", icon_val)));
            }
        }
        for name in ["icon.svg", "icon.png", "AppIcon.svg", "AppIcon.png"] {
            candidates.push(self.path.join("Contents/Resources").join(name));
            candidates.push(self.path.join("Contents/Icons").join(name));
        }

        for cand in candidates {
            if cand.is_file() {
                if let Ok(canon) = cand.canonicalize() {
                    if canon.starts_with(&canonical_bundle) {
                        return Some(canon);
                    }
                }
            }
        }
        None
    }

    /// Resolves icon theme name if `manifest.icon` is a theme identifier rather than a relative file path.
    pub fn icon_theme_name(&self) -> Option<String> {
        let icon = self.manifest.icon.as_deref()?;
        if !icon.contains('/')
            && !icon.contains('\\')
            && !icon.ends_with(".png")
            && !icon.ends_with(".svg")
            && !icon.ends_with(".ico")
            && !icon.trim().is_empty()
        {
            Some(icon.to_string())
        } else {
            None
        }
    }
}

fn parse_os_version_components(raw: &str) -> Option<Vec<u64>> {
    let trimmed = raw
        .trim()
        .strip_prefix("conjunction-")
        .or_else(|| raw.trim().strip_prefix("fedora-"))
        .unwrap_or(raw.trim());
    if trimmed.is_empty() {
        return None;
    }
    let mut parts = Vec::new();
    for seg in trimmed.split('.') {
        if seg.is_empty() {
            return None;
        }
        let num = seg.parse::<u64>().ok()?;
        parts.push(num);
    }
    if parts.is_empty() {
        None
    } else {
        Some(parts)
    }
}

fn compare_versions(a: &[u64], b: &[u64]) -> std::cmp::Ordering {
    let len = a.len().max(b.len());
    for i in 0..len {
        let va = *a.get(i).unwrap_or(&0);
        let vb = *b.get(i).unwrap_or(&0);
        match va.cmp(&vb) {
            std::cmp::Ordering::Equal => continue,
            ord => return ord,
        }
    }
    std::cmp::Ordering::Equal
}

pub fn detect_host_os_version() -> Option<String> {
    if let Ok(ver) = std::env::var("CONJUNCTION_OS_VERSION") {
        let trimmed = ver.trim().to_string();
        if !trimmed.is_empty() {
            return Some(trimmed);
        }
    }
    #[cfg(target_os = "linux")]
    {
        if let Ok(content) = std::fs::read_to_string("/etc/os-release") {
            for line in content.lines() {
                if let Some(val) = line.strip_prefix("VERSION_ID=") {
                    let clean = val.trim().trim_matches('"').trim_matches('\'').to_string();
                    if !clean.is_empty() {
                        return Some(clean);
                    }
                }
            }
        }
    }
    None
}
