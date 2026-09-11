use std::collections::HashMap;
use std::fmt;
use std::path::{Component, Path, PathBuf};
use serde::{Deserialize, Serialize};

pub const CURRENT_BUNDLE_FORMAT: &str = "conjunction.app/1";
pub const SUPPORTED_ARCHITECTURES: &[&str] = &["x86_64", "aarch64"];

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
                "unsupported bundle format version: '{}' (expected '{}')",
                v, CURRENT_BUNDLE_FORMAT
            ),
            BundleError::MissingApplicationId => write!(f, "manifest is missing required 'id' field"),
            BundleError::InvalidApplicationId(id) => write!(
                f,
                "invalid application ID '{}': must follow reverse-DNS format (e.g. org.example.app)",
                id
            ),
            BundleError::MissingExecutableDeclaration => write!(f, "manifest is missing required 'executable' field"),
            BundleError::AbsoluteExecutablePath(p) => write!(f, "executable path must be relative: '{}'", p),
            BundleError::ExecutablePathTraversal(p) => write!(f, "executable path contains traversal: '{}'", p),
            BundleError::MissingExecutableFile(p) => write!(f, "executable file not found: {}", p.display()),
            BundleError::ExecutableEscapesBundle(p) => write!(f, "executable escapes application bundle: {}", p.display()),
            BundleError::ExecutableNotRegularFile(p) => write!(f, "executable is not a regular file: {}", p.display()),
            BundleError::ExecutableNotExecutable(p) => write!(f, "executable lacks execute permission: {}", p.display()),
            BundleError::UnsupportedArchitecture(arch) => write!(
                f,
                "unsupported architecture '{}': supported architectures are {:?}",
                arch, SUPPORTED_ARCHITECTURES
            ),
            BundleError::EmptyArchitectures => write!(f, "architectures list cannot be empty"),
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
pub struct Manifest {
    pub bundle_format: String,
    pub id: String,
    pub name: String,
    pub version: String,
    pub executable: String,
    pub architectures: Vec<String>,
    #[serde(default)]
    pub icon: Option<String>,
    #[serde(default)]
    pub mime_types: Option<Vec<String>>,
    #[serde(default)]
    pub url_schemes: Option<Vec<String>>,
    #[serde(default)]
    pub category: Option<String>,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub permissions: Option<Vec<String>>,
    #[serde(default)]
    pub data: Option<HashMap<String, String>>,
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

    pub fn validate(&self) -> Result<(), BundleError> {
        self.validate_manifest()?;
        self.resolve_executable()?;
        Ok(())
    }

    pub fn validate_manifest(&self) -> Result<(), BundleError> {
        if self.manifest.bundle_format != CURRENT_BUNDLE_FORMAT {
            return Err(BundleError::UnsupportedFormatVersion(
                self.manifest.bundle_format.clone(),
            ));
        }

        Self::validate_id(&self.manifest.id)?;

        if self.manifest.executable.trim().is_empty() {
            return Err(BundleError::MissingExecutableDeclaration);
        }

        Self::validate_executable_path_syntax(&self.manifest.executable)?;

        if self.manifest.architectures.is_empty() {
            return Err(BundleError::EmptyArchitectures);
        }

        for arch in &self.manifest.architectures {
            if !SUPPORTED_ARCHITECTURES.contains(&arch.as_str()) {
                return Err(BundleError::UnsupportedArchitecture(arch.clone()));
            }
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

    pub fn resolve_executable(&self) -> Result<PathBuf, BundleError> {
        Self::validate_executable_path_syntax(&self.manifest.executable)?;

        let declared_path = self.path.join(&self.manifest.executable);
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

    pub fn executable_path(&self) -> Result<PathBuf, BundleError> {
        self.resolve_executable()
    }
}
