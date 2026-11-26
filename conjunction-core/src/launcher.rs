use crate::bundle::{Bundle, BundleError, RuntimeKind};
use crate::desktop_entry::is_executable_available;
use crate::registry::LaunchResult;
use crate::security::{get_quarantine, sha256_bytes};
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Clone)]
pub struct LaunchPlan {
    pub program: PathBuf,
    pub args: Vec<String>,
    pub env: BTreeMap<String, String>,
    pub current_dir: Option<PathBuf>,
}

#[derive(Debug)]
pub enum LaunchError {
    Bundle(BundleError),
    Quarantined { path: PathBuf, origin: Option<String> },
    RuntimeMissing(String),
    Io(String),
}

impl std::fmt::Display for LaunchError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LaunchError::Bundle(e) => write!(f, "{}", e),
            LaunchError::Quarantined { path, origin } => match origin {
                Some(url) => write!(
                    f,
                    "bundle '{}' is quarantined (downloaded from {}); pass --allow-quarantined or clear quarantine first",
                    path.display(),
                    url
                ),
                None => write!(
                    f,
                    "bundle '{}' is quarantined; pass --allow-quarantined or clear quarantine first",
                    path.display()
                ),
            },
            LaunchError::RuntimeMissing(msg) => write!(f, "{}", msg),
            LaunchError::Io(msg) => write!(f, "I/O error: {}", msg),
        }
    }
}

impl std::error::Error for LaunchError {}

impl From<BundleError> for LaunchError {
    fn from(e: BundleError) -> Self {
        LaunchError::Bundle(e)
    }
}

impl From<std::io::Error> for LaunchError {
    fn from(e: std::io::Error) -> Self {
        LaunchError::Io(e.to_string())
    }
}

pub fn build_bundle_launch_plan(
    bundle: &Bundle,
    user_args: &[String],
    allow_quarantined: bool,
) -> Result<LaunchPlan, LaunchError> {
    if !allow_quarantined {
        if let Ok(q) = get_quarantine(bundle.path()) {
            if q.is_quarantined() {
                return Err(LaunchError::Quarantined {
                    path: bundle.path().to_path_buf(),
                    origin: q.origin_url,
                });
            }
        }
    }

    bundle.validate()?;
    let runtime = bundle.runtime_kind()?;
    let canon_bundle = bundle
        .path()
        .canonicalize()
        .unwrap_or_else(|_| bundle.path().to_path_buf());

    let mut env = BTreeMap::new();
    env.insert(
        "CONJUNCTION_BUNDLE_PATH".to_string(),
        canon_bundle.to_string_lossy().into_owned(),
    );
    env.insert(
        "CONJUNCTION_BUNDLE_ID".to_string(),
        bundle.manifest().id.clone(),
    );
    env.insert(
        "CONJUNCTION_RUNTIME".to_string(),
        runtime.as_str().to_string(),
    );

    let res_dir = canon_bundle.join("Contents/Resources");
    if res_dir.is_dir() {
        env.insert(
            "CONJUNCTION_RESOURCES_PATH".to_string(),
            res_dir.to_string_lossy().into_owned(),
        );
        let share_dir = res_dir.join("share");
        if share_dir.is_dir() {
            let existing = std::env::var("XDG_DATA_DIRS").unwrap_or_else(|_| "/usr/local/share:/usr/share".to_string());
            env.insert(
                "XDG_DATA_DIRS".to_string(),
                format!("{}:{}", share_dir.display(), existing),
            );
        }
    }

    // Inject Contents/Frameworks (and Contents/Libraries) into LD_LIBRARY_PATH
    let fw_dirs = bundle.frameworks_dirs()?;
    if !fw_dirs.is_empty() {
        let mut fw_parts: Vec<String> = fw_dirs
            .iter()
            .map(|d| d.to_string_lossy().into_owned())
            .collect();
        if let Ok(existing_ld) = std::env::var("LD_LIBRARY_PATH") {
            if !existing_ld.is_empty() {
                fw_parts.push(existing_ld);
            }
        }
        let joined = fw_parts.join(":");
        env.insert("LD_LIBRARY_PATH".to_string(), joined.clone());
        #[cfg(target_os = "macos")]
        env.insert("DYLD_LIBRARY_PATH".to_string(), joined);

        if let Some(first_fw) = fw_dirs.first() {
            env.insert(
                "CONJUNCTION_FRAMEWORKS_PATH".to_string(),
                first_fw.to_string_lossy().into_owned(),
            );
        }
    }

    let plugins_qt = canon_bundle.join("Contents/PlugIns/qt6");
    if plugins_qt.is_dir() {
        let existing = std::env::var("QT_PLUGIN_PATH").unwrap_or_default();
        let val = if existing.is_empty() {
            plugins_qt.to_string_lossy().into_owned()
        } else {
            format!("{}:{}", plugins_qt.display(), existing)
        };
        env.insert("QT_PLUGIN_PATH".to_string(), val);
    }

    match runtime {
        RuntimeKind::Conjunction1 | RuntimeKind::Static => {
            let exec_path = bundle.resolve_executable_for_host()?;
            Ok(LaunchPlan {
                program: exec_path,
                args: user_args.to_vec(),
                env,
                current_dir: None,
            })
        }

        RuntimeKind::AppImage => {
            let payload_path = if let Some(ref ai) = bundle.manifest().appimage {
                if let Some(ref rel) = ai.payload {
                    Bundle::validate_relative_path("appimage.payload", rel)?;
                    let p = canon_bundle.join(rel);
                    let canon_p = p.canonicalize().map_err(|_| BundleError::MissingExecutableFile(p))?;
                    if !canon_p.starts_with(&canon_bundle) {
                        return Err(BundleError::ExecutableEscapesBundle(canon_p).into());
                    }
                    canon_p
                } else {
                    bundle.resolve_executable_for_host()?
                }
            } else {
                bundle.resolve_executable_for_host()?
            };

            let allow_extract_fallback = bundle
                .manifest()
                .appimage
                .as_ref()
                .and_then(|a| a.extract_and_run_fallback)
                .unwrap_or(true);

            // If /dev/fuse is missing or inaccessible (e.g. inside containers), enable APPIMAGE_EXTRACT_AND_RUN
            if allow_extract_fallback && !fuse_device_usable() {
                env.insert("APPIMAGE_EXTRACT_AND_RUN".to_string(), "1".to_string());
            }

            Ok(LaunchPlan {
                program: payload_path,
                args: user_args.to_vec(),
                env,
                current_dir: None,
            })
        }

        RuntimeKind::Flatpak => {
            bundle.check_minimum_os()?;
            let fp = bundle.manifest().flatpak.as_ref().ok_or_else(|| {
                BundleError::InvalidSpec("missing [flatpak] section".to_string())
            })?;
            if !is_executable_available("flatpak") {
                return Err(LaunchError::RuntimeMissing(
                    "flatpak is not installed on this system".to_string(),
                ));
            }
            let mut args = vec!["run".to_string()];
            if let Some(ref scope) = fp.scope {
                if scope == "user" {
                    args.push("--user".to_string());
                } else if scope == "system" {
                    args.push("--system".to_string());
                }
            }
            args.push(fp.id.clone());
            args.extend_from_slice(user_args);
            Ok(LaunchPlan {
                program: PathBuf::from("flatpak"),
                args,
                env,
                current_dir: None,
            })
        }

        RuntimeKind::Wine => {
            bundle.check_minimum_os()?;
            let wine_spec = bundle.manifest().wine.as_ref().ok_or_else(|| {
                BundleError::InvalidSpec("missing [wine] section".to_string())
            })?;

            Bundle::validate_relative_path("wine.prefix", &wine_spec.prefix)?;
            Bundle::validate_relative_path("wine.target_exe", &wine_spec.target_exe)?;

            let raw_prefix = canon_bundle.join(&wine_spec.prefix);
            let raw_exe = canon_bundle.join(&wine_spec.target_exe);
            if !raw_exe.exists() {
                return Err(BundleError::MissingExecutableFile(raw_exe).into());
            }
            let canon_exe = raw_exe.canonicalize()?;
            if !canon_exe.starts_with(&canon_bundle) {
                return Err(BundleError::ExecutableEscapesBundle(canon_exe).into());
            }

            // If bundle is read-only (e.g. inside a mounted .cdmg), use a writable shadow prefix
            let prefix_dir = ensure_writable_wine_prefix(&canon_bundle, &raw_prefix, &bundle.manifest().id)?;

            let wine_arch = wine_spec.arch.as_deref().unwrap_or("win64");
            env.insert(
                "WINEPREFIX".to_string(),
                prefix_dir.to_string_lossy().into_owned(),
            );
            env.insert("WINEARCH".to_string(), wine_arch.to_string());
            env.insert(
                "WINEDLLOVERRIDES".to_string(),
                "winemenubuilder.exe=d".to_string(),
            );
            env.insert(
                "WINEESYNC".to_string(),
                if wine_spec.esync.unwrap_or(true) { "1" } else { "0" }.to_string(),
            );
            env.insert(
                "WINEFSYNC".to_string(),
                if wine_spec.fsync.unwrap_or(true) { "1" } else { "0" }.to_string(),
            );
            env.insert(
                "WINEDEBUG".to_string(),
                wine_spec.wine_debug.clone().unwrap_or_else(|| "-all".to_string()),
            );
            if let Some(ref hud) = wine_spec.dxvk_hud {
                env.insert("DXVK_HUD".to_string(), hud.clone());
            }
            env.insert(
                "DXVK_STATE_CACHE_PATH".to_string(),
                prefix_dir.join("dxvk_state_cache").to_string_lossy().into_owned(),
            );

            // Pick Proton if requested and available, else wine / wine64
            let (program, mut args) = if wine_spec.use_proton.unwrap_or(false)
                && is_executable_available("proton")
            {
                (PathBuf::from("proton"), vec!["run".to_string(), canon_exe.to_string_lossy().into_owned()])
            } else if let Some(wine_bin) = find_wine_binary() {
                (PathBuf::from(wine_bin), vec![canon_exe.to_string_lossy().into_owned()])
            } else {
                return Err(LaunchError::RuntimeMissing(
                    "neither wine nor proton is installed on this system".to_string(),
                ));
            };

            args.extend(wine_spec.args.clone());
            args.extend_from_slice(user_args);

            Ok(LaunchPlan {
                program,
                args,
                env,
                current_dir: canon_exe.parent().map(|p| p.to_path_buf()),
            })
        }
    }
}

fn find_wine_binary() -> Option<&'static str> {
    if is_executable_available("wine") {
        Some("wine")
    } else if is_executable_available("wine64") {
        Some("wine64")
    } else {
        None
    }
}

fn fuse_device_usable() -> bool {
    let p = Path::new("/dev/fuse");
    if !p.exists() {
        return false;
    }
    fs::OpenOptions::new().read(true).write(true).open(p).is_ok()
}

fn ensure_writable_wine_prefix(
    canon_bundle: &Path,
    raw_prefix: &Path,
    bundle_id: &str,
) -> Result<PathBuf, LaunchError> {
    if raw_prefix.exists() {
        let canon_prefix = raw_prefix.canonicalize()?;
        if !canon_prefix.starts_with(canon_bundle) {
            return Err(BundleError::PathEscapesBundle {
                field: "wine.prefix".to_string(),
                path: canon_prefix,
            }
            .into());
        }
        // Check writability by testing a probe temp file inside the prefix directory
        if is_dir_writable(&canon_prefix) {
            return Ok(canon_prefix);
        }
        // Read-only mount (e.g. .cdmg): mirror to per-bundle cache prefix so it still runs
        let cache_base = crate::get_user_home()
            .join(".cache/conjunction/ro-wine")
            .join(format!(
                "{}-{}",
                bundle_id,
                &sha256_bytes(canon_bundle.to_string_lossy().as_bytes())[..8]
            ));
        if !cache_base.exists() {
            crate::registry::copy_dir_all(&canon_prefix, &cache_base)?;
        }
        return Ok(cache_base);
    }

    // Lazy creation for portable .exe bundles with no pre-initialized prefix
    if is_dir_writable(canon_bundle) {
        fs::create_dir_all(raw_prefix)?;
        return Ok(raw_prefix.canonicalize().unwrap_or_else(|_| raw_prefix.to_path_buf()));
    }

    let cache_base = crate::get_user_home()
        .join(".cache/conjunction/ro-wine")
        .join(format!(
            "{}-{}",
            bundle_id,
            &sha256_bytes(canon_bundle.to_string_lossy().as_bytes())[..8]
        ));
    fs::create_dir_all(&cache_base)?;
    Ok(cache_base)
}

fn is_dir_writable(dir: &Path) -> bool {
    let probe = dir.join(format!(".conj_probe_{}", std::process::id()));
    match fs::OpenOptions::new().write(true).create_new(true).open(&probe) {
        Ok(_) => {
            let _ = fs::remove_file(&probe);
            true
        }
        Err(_) => false,
    }
}

pub fn execute_plan_captured(plan: &LaunchPlan) -> Result<LaunchResult, LaunchError> {
    let mut cmd = build_command(plan);
    let output = cmd.output().map_err(|e| {
        LaunchError::Io(format!("failed to execute {}: {}", plan.program.display(), e))
    })?;
    Ok(LaunchResult {
        exit_code: output.status.code().unwrap_or(0),
        stdout: String::from_utf8_lossy(&output.stdout).into_owned(),
        stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
    })
}

#[cfg(unix)]
pub fn exec_plan_replace(plan: &LaunchPlan) -> Result<(), LaunchError> {
    use std::os::unix::process::CommandExt;
    let mut cmd = build_command(plan);
    let err = cmd.exec();
    Err(LaunchError::Io(format!(
        "failed to exec {}: {}",
        plan.program.display(),
        err
    )))
}

pub fn spawn_plan_detached(plan: &LaunchPlan) -> Result<u32, LaunchError> {
    let mut cmd = build_command(plan);
    cmd.stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null());
    let child = cmd.spawn().map_err(|e| {
        LaunchError::Io(format!("failed to spawn {}: {}", plan.program.display(), e))
    })?;
    Ok(child.id())
}

fn build_command(plan: &LaunchPlan) -> Command {
    let mut cmd = Command::new(&plan.program);
    cmd.args(&plan.args);
    for (k, v) in &plan.env {
        cmd.env(k, v);
    }
    if let Some(ref cwd) = plan.current_dir {
        cmd.current_dir(cwd);
    }
    cmd
}
