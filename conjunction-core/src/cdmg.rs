use crate::bundle::Bundle;
use crate::registry::copy_dir_all;
use crate::security::{check_bundle_symlinks_contained, seal_bundle_manifest, sha256_bytes, sign_bundle_manifest};
use serde::{Deserialize, Serialize};
use std::fmt;
use std::fs;
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::process::Command;

pub const CDMG_FORMAT_VERSION: &str = "conjunction.cdmg/1";
pub const CDMG_EXTENSION: &str = "cdmg";
pub const CDMG_MIME_TYPE: &str = "application/x-conjunction-disk-image";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CdmgFilesystem {
    SquashFs,
    Erofs,
}

impl fmt::Display for CdmgFilesystem {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CdmgFilesystem::SquashFs => write!(f, "squashfs"),
            CdmgFilesystem::Erofs => write!(f, "erofs"),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum MountBackend {
    Auto,
    SquashFuse,
    ErofsFuse,
    Udisks2,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VolumeMeta {
    pub cdmg_format: String,
    pub volume_name: String,
    pub app_bundle: String,
    pub app_id: String,
    pub filesystem: String,
    #[serde(default)]
    pub background: Option<String>,
    #[serde(default)]
    pub window_width: u32,
    #[serde(default)]
    pub window_height: u32,
    #[serde(default)]
    pub icon_size: u32,
    #[serde(default)]
    pub app_position: [u32; 2],
    #[serde(default)]
    pub applications_position: [u32; 2],
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MountRecord {
    pub id: String,
    pub cdmg_path: PathBuf,
    pub mount_point: PathBuf,
    pub volume_name: String,
    pub backend: String,
    #[serde(default)]
    pub loop_device: Option<String>,
}

#[derive(Debug)]
pub enum CdmgError {
    InvalidBundle(String),
    Io(String),
    ToolMissing(String),
    PackFailed(String),
    InvalidDiskImage(String),
    MountFailed(String),
    NotMounted(PathBuf),
    UnmountFailed(String),
}

impl fmt::Display for CdmgError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CdmgError::InvalidBundle(e) => write!(f, "invalid bundle: {}", e),
            CdmgError::Io(e) => write!(f, "I/O error: {}", e),
            CdmgError::ToolMissing(t) => write!(f, "required tool not found: {}", t),
            CdmgError::PackFailed(e) => write!(f, "failed to pack .cdmg disk image: {}", e),
            CdmgError::InvalidDiskImage(e) => write!(f, "invalid .cdmg disk image: {}", e),
            CdmgError::MountFailed(e) => write!(f, "failed to mount .cdmg disk image: {}", e),
            CdmgError::NotMounted(p) => write!(f, "disk image is not mounted: {}", p.display()),
            CdmgError::UnmountFailed(e) => write!(f, "failed to eject disk image: {}", e),
        }
    }
}

impl std::error::Error for CdmgError {}

impl From<std::io::Error> for CdmgError {
    fn from(e: std::io::Error) -> Self {
        CdmgError::Io(e.to_string())
    }
}

pub struct PackOptions {
    pub bundle_path: PathBuf,
    pub output_path: PathBuf,
    pub volume_name: Option<String>,
    pub filesystem: CdmgFilesystem,
    pub applications_target: String,
    pub background: Option<PathBuf>,
    pub seal: bool,
    pub sign_key: Option<PathBuf>,
}

impl Default for PackOptions {
    fn default() -> Self {
        Self {
            bundle_path: PathBuf::new(),
            output_path: PathBuf::new(),
            volume_name: None,
            filesystem: CdmgFilesystem::SquashFs,
            applications_target: "/Applications".to_string(),
            background: None,
            seal: true,
            sign_key: None,
        }
    }
}

pub fn pack_cdmg(opts: &PackOptions) -> Result<PathBuf, CdmgError> {
    let bundle = Bundle::open(&opts.bundle_path)
        .map_err(|e| CdmgError::InvalidBundle(e.to_string()))?;
    bundle
        .validate()
        .map_err(|e| CdmgError::InvalidBundle(e.to_string()))?;
    check_bundle_symlinks_contained(&opts.bundle_path)
        .map_err(|e| CdmgError::InvalidBundle(e.to_string()))?;

    let bundle_dir_name = opts
        .bundle_path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| CdmgError::InvalidBundle("invalid bundle directory name".to_string()))?;

    let volume_name = opts
        .volume_name
        .clone()
        .unwrap_or_else(|| bundle.manifest().name.clone());

    let unique_ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    let stage_root = std::env::temp_dir().join(format!("conj_cdmg_stage_{}", unique_ts));
    fs::create_dir_all(&stage_root)?;

    let res = (|| -> Result<PathBuf, CdmgError> {
        let staged_bundle = stage_root.join(bundle_dir_name);
        copy_dir_all(&opts.bundle_path, &staged_bundle)?;

        if opts.seal || opts.sign_key.is_some() {
            seal_bundle_manifest(&staged_bundle)
                .map_err(|e| CdmgError::PackFailed(format!("failed to seal bundle: {}", e)))?;
        }
        if let Some(ref key) = opts.sign_key {
            sign_bundle_manifest(&staged_bundle, key)
                .map_err(|e| CdmgError::PackFailed(format!("failed to sign bundle: {}", e)))?;
        }

        // Create Applications symlink inside disk image root (just like macOS .dmg)
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(
                &opts.applications_target,
                stage_root.join("Applications"),
            )?;
        }

        // Optional background image
        let mut bg_rel = None;
        if let Some(ref bg_src) = opts.background {
            if bg_src.is_file() {
                let bg_dir = stage_root.join(".background");
                fs::create_dir_all(&bg_dir)?;
                let fname = bg_src
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("background.png");
                fs::copy(bg_src, bg_dir.join(fname))?;
                bg_rel = Some(format!(".background/{}", fname));
            }
        }

        // Optional volume icon copied from bundle
        if let Some(icon_src) = bundle.resolve_icon_file() {
            let ext = icon_src
                .extension()
                .and_then(|e| e.to_str())
                .unwrap_or("png");
            let vol_icon_name = format!(".VolumeIcon.{}", ext);
            let _ = fs::copy(&icon_src, stage_root.join(&vol_icon_name));
            let dir_meta = format!("[Desktop Entry]\nIcon=./{}\n", vol_icon_name);
            let _ = fs::write(stage_root.join(".directory"), dir_meta);
        }

        let meta = VolumeMeta {
            cdmg_format: CDMG_FORMAT_VERSION.to_string(),
            volume_name: volume_name.clone(),
            app_bundle: bundle_dir_name.to_string(),
            app_id: bundle.manifest().id.clone(),
            filesystem: opts.filesystem.to_string(),
            background: bg_rel,
            window_width: 640,
            window_height: 400,
            icon_size: 96,
            app_position: [160, 200],
            applications_position: [480, 200],
        };
        let meta_toml = toml::to_string_pretty(&meta)
            .map_err(|e| CdmgError::PackFailed(format!("TOML serialize failed: {}", e)))?;
        fs::write(stage_root.join(".VolumeMeta.toml"), meta_toml)?;

        if let Some(parent) = opts.output_path.parent() {
            if !parent.as_os_str().is_empty() {
                fs::create_dir_all(parent)?;
            }
        }
        if opts.output_path.exists() {
            fs::remove_file(&opts.output_path)?;
        }

        match opts.filesystem {
            CdmgFilesystem::SquashFs => {
                if !crate::desktop_entry::is_executable_available("mksquashfs") {
                    return Err(CdmgError::ToolMissing("mksquashfs (squashfs-tools)".to_string()));
                }
                let out = Command::new("mksquashfs")
                    .arg(&stage_root)
                    .arg(&opts.output_path)
                    .args(["-noappend", "-comp", "zstd", "-all-root", "-no-progress"])
                    .output()?;
                if !out.status.success() {
                    // Fallback to gzip if zstd compression is unsupported in older mksquashfs
                    let _ = fs::remove_file(&opts.output_path);
                    let out2 = Command::new("mksquashfs")
                        .arg(&stage_root)
                        .arg(&opts.output_path)
                        .args(["-noappend", "-comp", "gzip", "-all-root", "-no-progress"])
                        .output()?;
                    if !out2.status.success() {
                        return Err(CdmgError::PackFailed(
                            String::from_utf8_lossy(&out2.stderr).trim().to_string(),
                        ));
                    }
                }
            }
            CdmgFilesystem::Erofs => {
                if !crate::desktop_entry::is_executable_available("mkfs.erofs") {
                    return Err(CdmgError::ToolMissing("mkfs.erofs (erofs-utils)".to_string()));
                }
                let out = Command::new("mkfs.erofs")
                    .arg(&opts.output_path)
                    .arg(&stage_root)
                    .output()?;
                if !out.status.success() {
                    return Err(CdmgError::PackFailed(
                        String::from_utf8_lossy(&out.stderr).trim().to_string(),
                    ));
                }
            }
        }

        Ok(opts.output_path.clone())
    })();

    let _ = fs::remove_dir_all(&stage_root);
    res
}

pub fn detect_cdmg_filesystem(path: &Path) -> Result<CdmgFilesystem, CdmgError> {
    let mut f = fs::File::open(path)?;
    let mut magic4 = [0u8; 4];
    f.read_exact(&mut magic4)
        .map_err(|_| CdmgError::InvalidDiskImage("file too small to be a .cdmg image".to_string()))?;
    if &magic4 == b"hsqs" || &magic4 == b"sqsh" {
        return Ok(CdmgFilesystem::SquashFs);
    }
    // EROFS superblock starts at offset 1024 with magic 0xE0F5E1E2 (LE: E2 E1 F5 E0)
    if f.seek(SeekFrom::Start(1024)).is_ok() {
        let mut erofs_magic = [0u8; 4];
        if f.read_exact(&mut erofs_magic).is_ok() && erofs_magic == [0xE2, 0xE1, 0xF5, 0xE0] {
            return Ok(CdmgFilesystem::Erofs);
        }
    }
    Err(CdmgError::InvalidDiskImage(format!(
        "unrecognized disk image magic in '{}'",
        path.display()
    )))
}

pub fn cdmg_mounts_dir() -> PathBuf {
    let base = crate::ipc::appd_runtime_dir()
        .unwrap_or_else(|_| std::env::temp_dir())
        .join("conjunction")
        .join("mounts");
    let _ = fs::create_dir_all(&base);
    base
}

fn sanitize_mount_name(name: &str) -> String {
    let cleaned: String = name
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() || c == '-' || c == '_' { c } else { '_' })
        .collect();
    if cleaned.is_empty() {
        "disk".to_string()
    } else {
        cleaned
    }
}

pub fn list_mounted_cdmgs() -> Vec<MountRecord> {
    let dir = cdmg_mounts_dir();
    let mut records = Vec::new();
    if let Ok(entries) = fs::read_dir(&dir) {
        for entry in entries.flatten() {
            let p = entry.path();
            if p.extension().is_some_and(|e| e == "json") {
                if let Ok(content) = fs::read_to_string(&p) {
                    if let Ok(rec) = serde_json::from_str::<MountRecord>(&content) {
                        if is_path_mounted(&rec.mount_point) {
                            records.push(rec);
                        } else {
                            let _ = fs::remove_file(&p);
                        }
                    }
                }
            }
        }
    }
    records
}

pub fn mount_cdmg(cdmg_path: &Path, backend: MountBackend) -> Result<MountRecord, CdmgError> {
    let canon_cdmg = cdmg_path
        .canonicalize()
        .map_err(|e| CdmgError::InvalidDiskImage(format!("{}: {}", cdmg_path.display(), e)))?;
    let fs_kind = detect_cdmg_filesystem(&canon_cdmg)?;

    // Reuse existing active mount if already mounted
    for existing in list_mounted_cdmgs() {
        if existing.cdmg_path == canon_cdmg {
            return Ok(existing);
        }
    }

    let stem = canon_cdmg
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("volume");
    let short_hash = &sha256_bytes(canon_cdmg.to_string_lossy().as_bytes())[..8];
    let mount_id = format!("{}-{}", sanitize_mount_name(stem), short_hash);
    let mounts_dir = cdmg_mounts_dir();
    let mount_point = mounts_dir.join(&mount_id);
    fs::create_dir_all(&mount_point)?;

    let rec = match backend {
        MountBackend::SquashFuse => mount_with_fuse("squashfuse", &canon_cdmg, &mount_point, &mount_id, stem)?,
        MountBackend::ErofsFuse => mount_with_fuse("erofsfuse", &canon_cdmg, &mount_point, &mount_id, stem)?,
        MountBackend::Udisks2 => mount_with_udisks2(&canon_cdmg, &mount_id, stem)?,
        MountBackend::Auto => match fs_kind {
            CdmgFilesystem::SquashFs => {
                if crate::desktop_entry::is_executable_available("squashfuse") {
                    mount_with_fuse("squashfuse", &canon_cdmg, &mount_point, &mount_id, stem)?
                } else {
                    mount_with_udisks2(&canon_cdmg, &mount_id, stem)?
                }
            }
            CdmgFilesystem::Erofs => {
                if crate::desktop_entry::is_executable_available("erofsfuse") {
                    mount_with_fuse("erofsfuse", &canon_cdmg, &mount_point, &mount_id, stem)?
                } else {
                    mount_with_udisks2(&canon_cdmg, &mount_id, stem)?
                }
            }
        },
    };

    // Read .VolumeMeta.toml inside mount to refine volume_name if available
    let mut final_rec = rec;
    let vol_meta_path = final_rec.mount_point.join(".VolumeMeta.toml");
    if let Ok(content) = fs::read_to_string(&vol_meta_path) {
        if let Ok(meta) = toml::from_str::<VolumeMeta>(&content) {
            if !meta.volume_name.trim().is_empty() {
                final_rec.volume_name = meta.volume_name;
            }
        }
    }

    let state_file = mounts_dir.join(format!("{}.mount.json", final_rec.id));
    let json = serde_json::to_string_pretty(&final_rec).unwrap_or_default();
    fs::write(state_file, json)?;

    Ok(final_rec)
}

fn mount_with_fuse(
    fuse_bin: &str,
    cdmg_path: &Path,
    mount_point: &Path,
    mount_id: &str,
    stem: &str,
) -> Result<MountRecord, CdmgError> {
    if !crate::desktop_entry::is_executable_available(fuse_bin) {
        return Err(CdmgError::ToolMissing(fuse_bin.to_string()));
    }

    let out = Command::new(fuse_bin)
        .args(["-o", "ro"])
        .arg(cdmg_path)
        .arg(mount_point)
        .output()?;

    if !out.status.success() {
        let _ = fs::remove_dir(mount_point);
        return Err(CdmgError::MountFailed(
            String::from_utf8_lossy(&out.stderr).trim().to_string(),
        ));
    }

    Ok(MountRecord {
        id: mount_id.to_string(),
        cdmg_path: cdmg_path.to_path_buf(),
        mount_point: mount_point.to_path_buf(),
        volume_name: stem.to_string(),
        backend: fuse_bin.to_string(),
        loop_device: None,
    })
}

fn mount_with_udisks2(cdmg_path: &Path, mount_id: &str, stem: &str) -> Result<MountRecord, CdmgError> {
    if !crate::desktop_entry::is_executable_available("udisksctl") {
        return Err(CdmgError::ToolMissing(
            "udisksctl (udisks2) or squashfuse".to_string(),
        ));
    }

    let loop_out = Command::new("udisksctl")
        .args(["loop-setup", "-r", "-f"])
        .arg(cdmg_path)
        .arg("--no-user-interaction")
        .output()?;

    if !loop_out.status.success() {
        return Err(CdmgError::MountFailed(format!(
            "udisksctl loop-setup failed: {}",
            String::from_utf8_lossy(&loop_out.stderr).trim()
        )));
    }

    let loop_stdout = String::from_utf8_lossy(&loop_out.stdout);
    let loop_dev = loop_stdout
        .split_whitespace()
        .find(|w| w.starts_with("/dev/loop"))
        .map(|s| s.trim_end_matches('.').to_string())
        .ok_or_else(|| {
            CdmgError::MountFailed(format!(
                "could not parse loop device from udisksctl output: {}",
                loop_stdout.trim()
            ))
        })?;

    let mount_out = Command::new("udisksctl")
        .args(["mount", "-b", &loop_dev, "-o", "ro", "--no-user-interaction"])
        .output()?;

    if !mount_out.status.success() {
        let _ = Command::new("udisksctl")
            .args(["loop-delete", "-b", &loop_dev, "--no-user-interaction"])
            .output();
        return Err(CdmgError::MountFailed(format!(
            "udisksctl mount failed: {}",
            String::from_utf8_lossy(&mount_out.stderr).trim()
        )));
    }

    let mount_stdout = String::from_utf8_lossy(&mount_out.stdout);
    let mp = mount_stdout
        .split(" at ")
        .nth(1)
        .map(|s| PathBuf::from(s.trim().trim_end_matches('.')))
        .ok_or_else(|| {
            CdmgError::MountFailed(format!(
                "could not parse mount point from udisksctl output: {}",
                mount_stdout.trim()
            ))
        })?;

    Ok(MountRecord {
        id: mount_id.to_string(),
        cdmg_path: cdmg_path.to_path_buf(),
        mount_point: mp,
        volume_name: stem.to_string(),
        backend: "udisks2".to_string(),
        loop_device: Some(loop_dev),
    })
}

pub fn eject_cdmg(target: &Path) -> Result<(), CdmgError> {
    let canon_target = target.canonicalize().unwrap_or_else(|_| target.to_path_buf());
    let records = list_mounted_cdmgs();
    let found = records.into_iter().find(|r| {
        r.mount_point == canon_target
            || r.cdmg_path == canon_target
            || r.mount_point == target
            || r.cdmg_path == target
            || r.id == target.to_string_lossy()
    });

    let rec = match found {
        Some(r) => r,
        None => {
            if is_path_mounted(&canon_target) {
                unmount_raw_fuse_or_umount(&canon_target)?;
                return Ok(());
            }
            return Err(CdmgError::NotMounted(target.to_path_buf()));
        }
    };

    if rec.backend == "udisks2" {
        if let Some(ref loop_dev) = rec.loop_device {
            let unm = Command::new("udisksctl")
                .args(["unmount", "-b", loop_dev, "--no-user-interaction"])
                .output()?;
            if !unm.status.success() {
                return Err(CdmgError::UnmountFailed(
                    String::from_utf8_lossy(&unm.stderr).trim().to_string(),
                ));
            }
            let _ = Command::new("udisksctl")
                .args(["loop-delete", "-b", loop_dev, "--no-user-interaction"])
                .output();
        }
    } else {
        unmount_raw_fuse_or_umount(&rec.mount_point)?;
        let _ = fs::remove_dir(&rec.mount_point);
    }

    let state_file = cdmg_mounts_dir().join(format!("{}.mount.json", rec.id));
    let _ = fs::remove_file(state_file);
    Ok(())
}

fn unmount_raw_fuse_or_umount(mount_point: &Path) -> Result<(), CdmgError> {
    let candidates = ["fusermount3", "fusermount", "umount"];
    for bin in candidates {
        if crate::desktop_entry::is_executable_available(bin) {
            let mut cmd = Command::new(bin);
            if bin != "umount" {
                cmd.arg("-u");
            }
            let out = cmd.arg(mount_point).output()?;
            if out.status.success() {
                return Ok(());
            }
        }
    }
    Err(CdmgError::UnmountFailed(format!(
        "could not unmount {}",
        mount_point.display()
    )))
}

fn is_path_mounted(path: &Path) -> bool {
    let canon = path.canonicalize().unwrap_or_else(|_| path.to_path_buf());
    let target_str = canon.to_string_lossy();
    if let Ok(mounts) = fs::read_to_string("/proc/mounts") {
        for line in mounts.lines() {
            let mut parts = line.split_whitespace();
            let _src = parts.next();
            if let Some(mp) = parts.next() {
                // /proc/mounts encodes spaces as \040
                let decoded = mp.replace("\\040", " ");
                if decoded == target_str {
                    return true;
                }
            }
        }
        return false;
    }
    false
}
