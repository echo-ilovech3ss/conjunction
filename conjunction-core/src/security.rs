use std::collections::BTreeMap;
use std::fmt;
use std::fs;
use std::io::{self, Read};
use std::path::{Component, Path, PathBuf};
use std::process::Command;

pub const MANIFEST_SHA256_REL: &str = "Contents/Manifest.sha256";
pub const MANIFEST_SIG_REL: &str = "Contents/Manifest.sig";
pub const XATTR_QUARANTINE: &str = "user.conjunction.quarantine";
pub const XATTR_ORIGIN_URL: &str = "user.xdg.origin.url";

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SecurityError {
    Io(String),
    SymlinkEscape { path: PathBuf, target: PathBuf },
    MissingManifest(PathBuf),
    MalformedManifest(String),
    HashMismatch { path: String, expected: String, actual: String },
    MissingFile(String),
    UnexpectedFile(String),
    MissingSignature(PathBuf),
    InvalidSignature(String),
    ToolUnavailable(String),
}

impl fmt::Display for SecurityError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            SecurityError::Io(e) => write!(f, "security I/O error: {}", e),
            SecurityError::SymlinkEscape { path, target } => write!(
                f,
                "symlink '{}' resolves outside bundle boundary to '{}'",
                path.display(),
                target.display()
            ),
            SecurityError::MissingManifest(p) => {
                write!(f, "missing integrity manifest: {}", p.display())
            }
            SecurityError::MalformedManifest(e) => {
                write!(f, "malformed Manifest.sha256: {}", e)
            }
            SecurityError::HashMismatch {
                path,
                expected,
                actual,
            } => write!(
                f,
                "hash mismatch for '{}': expected {}, got {}",
                path, expected, actual
            ),
            SecurityError::MissingFile(p) => {
                write!(f, "manifest file missing from bundle: {}", p)
            }
            SecurityError::UnexpectedFile(p) => {
                write!(f, "unexpected unsealed file inside bundle: {}", p)
            }
            SecurityError::MissingSignature(p) => {
                write!(f, "missing signature file: {}", p.display())
            }
            SecurityError::InvalidSignature(e) => {
                write!(f, "signature verification failed: {}", e)
            }
            SecurityError::ToolUnavailable(e) => write!(f, "required security tool unavailable: {}", e),
        }
    }
}

impl std::error::Error for SecurityError {}

impl From<io::Error> for SecurityError {
    fn from(e: io::Error) -> Self {
        SecurityError::Io(e.to_string())
    }
}

/// Pure-Rust FIPS 180-4 SHA-256 implementation (zero external crate dependency).
pub struct Sha256 {
    state: [u32; 8],
    bit_len: u64,
    buffer: [u8; 64],
    buf_len: usize,
}

impl Default for Sha256 {
    fn default() -> Self {
        Self::new()
    }
}

impl Sha256 {
    const K: [u32; 64] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    pub fn new() -> Self {
        Self {
            state: [
                0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
            ],
            bit_len: 0,
            buffer: [0u8; 64],
            buf_len: 0,
        }
    }

    pub fn update(&mut self, data: &[u8]) {
        let mut offset = 0;
        self.bit_len = self.bit_len.wrapping_add((data.len() as u64).wrapping_mul(8));

        if self.buf_len > 0 {
            let take = (64 - self.buf_len).min(data.len());
            self.buffer[self.buf_len..self.buf_len + take].copy_from_slice(&data[..take]);
            self.buf_len += take;
            offset += take;
            if self.buf_len == 64 {
                let block = self.buffer;
                Self::compress(&mut self.state, &block);
                self.buf_len = 0;
            }
        }

        while offset + 64 <= data.len() {
            let mut block = [0u8; 64];
            block.copy_from_slice(&data[offset..offset + 64]);
            Self::compress(&mut self.state, &block);
            offset += 64;
        }

        if offset < data.len() {
            let rem = data.len() - offset;
            self.buffer[..rem].copy_from_slice(&data[offset..]);
            self.buf_len = rem;
        }
    }

    pub fn finalize(mut self) -> [u8; 32] {
        self.buffer[self.buf_len] = 0x80;
        self.buf_len += 1;

        if self.buf_len > 56 {
            for b in &mut self.buffer[self.buf_len..] {
                *b = 0;
            }
            let block = self.buffer;
            Self::compress(&mut self.state, &block);
            self.buf_len = 0;
        }

        for b in &mut self.buffer[self.buf_len..56] {
            *b = 0;
        }
        self.buffer[56..64].copy_from_slice(&self.bit_len.to_be_bytes());
        let block = self.buffer;
        Self::compress(&mut self.state, &block);

        let mut out = [0u8; 32];
        for (i, word) in self.state.iter().enumerate() {
            out[i * 4..i * 4 + 4].copy_from_slice(&word.to_be_bytes());
        }
        out
    }

    fn compress(state: &mut [u32; 8], block: &[u8; 64]) {
        let mut w = [0u32; 64];
        for i in 0..16 {
            w[i] = u32::from_be_bytes([
                block[i * 4],
                block[i * 4 + 1],
                block[i * 4 + 2],
                block[i * 4 + 3],
            ]);
        }
        for i in 16..64 {
            let s0 = w[i - 15].rotate_right(7) ^ w[i - 15].rotate_right(18) ^ (w[i - 15] >> 3);
            let s1 = w[i - 2].rotate_right(17) ^ w[i - 2].rotate_right(19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16]
                .wrapping_add(s0)
                .wrapping_add(w[i - 7])
                .wrapping_add(s1);
        }

        let [mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut h] = *state;
        for i in 0..64 {
            let s1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
            let ch = (e & f) ^ ((!e) & g);
            let temp1 = h
                .wrapping_add(s1)
                .wrapping_add(ch)
                .wrapping_add(Self::K[i])
                .wrapping_add(w[i]);
            let s0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
            let maj = (a & b) ^ (a & c) ^ (b & c);
            let temp2 = s0.wrapping_add(maj);

            h = g;
            g = f;
            f = e;
            e = d.wrapping_add(temp1);
            d = c;
            c = b;
            b = a;
            a = temp1.wrapping_add(temp2);
        }

        state[0] = state[0].wrapping_add(a);
        state[1] = state[1].wrapping_add(b);
        state[2] = state[2].wrapping_add(c);
        state[3] = state[3].wrapping_add(d);
        state[4] = state[4].wrapping_add(e);
        state[5] = state[5].wrapping_add(f);
        state[6] = state[6].wrapping_add(g);
        state[7] = state[7].wrapping_add(h);
    }
}

pub fn sha256_bytes(data: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(data);
    hex_encode(&hasher.finalize())
}

pub fn sha256_file(path: &Path) -> io::Result<String> {
    let mut file = fs::File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buf = [0u8; 32768];
    loop {
        let n = file.read(&mut buf)?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Ok(hex_encode(&hasher.finalize()))
}

fn hex_encode(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for &b in bytes {
        out.push(HEX[(b >> 4) as usize] as char);
        out.push(HEX[(b & 0x0f) as usize] as char);
    }
    out
}

/// Ensures every symlink inside `bundle_root/Contents` resolves strictly within canonical `bundle_root`.
pub fn check_bundle_symlinks_contained(bundle_root: &Path) -> Result<(), SecurityError> {
    let canonical_root = bundle_root.canonicalize()?;
    let contents_dir = bundle_root.join("Contents");
    if !contents_dir.exists() {
        return Ok(());
    }
    let meta = fs::symlink_metadata(&contents_dir)?;
    if meta.file_type().is_symlink() {
        let canon = contents_dir.canonicalize().map_err(|_| SecurityError::SymlinkEscape {
            path: contents_dir.clone(),
            target: fs::read_link(&contents_dir).unwrap_or_default(),
        })?;
        if !canon.starts_with(&canonical_root) {
            return Err(SecurityError::SymlinkEscape {
                path: contents_dir,
                target: canon,
            });
        }
    }

    let mut stack = vec![contents_dir];
    while let Some(dir) = stack.pop() {
        let entries = match fs::read_dir(&dir) {
            Ok(e) => e,
            Err(e) => return Err(SecurityError::Io(e.to_string())),
        };
        for entry in entries {
            let entry = entry?;
            let path = entry.path();
            let ft = entry.file_type()?;
            if ft.is_symlink() {
                let raw_target = fs::read_link(&path).unwrap_or_default();
                let canon_target = path.canonicalize().map_err(|_| SecurityError::SymlinkEscape {
                    path: path.clone(),
                    target: raw_target.clone(),
                })?;
                if !canon_target.starts_with(&canonical_root) {
                    return Err(SecurityError::SymlinkEscape {
                        path,
                        target: canon_target,
                    });
                }
            } else if ft.is_dir() {
                stack.push(path);
            }
        }
    }
    Ok(())
}

/// Computes deterministic `<sha256>  Contents/...` entries for all files under `Contents/`.
pub fn compute_manifest_entries(bundle_root: &Path) -> Result<BTreeMap<String, String>, SecurityError> {
    check_bundle_symlinks_contained(bundle_root)?;
    let contents_dir = bundle_root.join("Contents");
    let mut entries = BTreeMap::new();
    if !contents_dir.is_dir() {
        return Ok(entries);
    }

    let mut stack = vec![contents_dir];
    while let Some(dir) = stack.pop() {
        for entry in fs::read_dir(&dir)? {
            let entry = entry?;
            let path = entry.path();
            let rel = path
                .strip_prefix(bundle_root)
                .map_err(|e| SecurityError::Io(e.to_string()))?;
            let rel_str = rel
                .components()
                .map(|c| c.as_os_str().to_string_lossy().into_owned())
                .collect::<Vec<_>>()
                .join("/");

            if rel_str == MANIFEST_SHA256_REL || rel_str == MANIFEST_SIG_REL {
                continue;
            }

            let ft = entry.file_type()?;
            if ft.is_symlink() {
                let target = fs::read_link(&path)?;
                let digest = sha256_bytes(format!("symlink:{}", target.to_string_lossy()).as_bytes());
                entries.insert(rel_str, digest);
            } else if ft.is_dir() {
                stack.push(path);
            } else if ft.is_file() {
                let digest = sha256_file(&path)?;
                entries.insert(rel_str, digest);
            }
        }
    }
    Ok(entries)
}

/// Writes `Contents/Manifest.sha256` for a bundle.
pub fn seal_bundle_manifest(bundle_root: &Path) -> Result<PathBuf, SecurityError> {
    let entries = compute_manifest_entries(bundle_root)?;
    let mut out = String::new();
    for (rel, digest) in entries {
        out.push_str(&format!("{}  {}\n", digest, rel));
    }
    let manifest_path = bundle_root.join(MANIFEST_SHA256_REL);
    fs::write(&manifest_path, out)?;
    Ok(manifest_path)
}

fn validate_manifest_rel_path(rel: &str) -> Result<(), SecurityError> {
    if rel.is_empty() || rel.starts_with('/') || rel.starts_with('\\') || rel.contains('\0') {
        return Err(SecurityError::MalformedManifest(format!(
            "invalid relative path '{}'",
            rel
        )));
    }
    let p = Path::new(rel);
    for comp in p.components() {
        match comp {
            Component::ParentDir | Component::RootDir | Component::Prefix(_) => {
                return Err(SecurityError::MalformedManifest(format!(
                    "unsafe path component in '{}'",
                    rel
                )));
            }
            _ => {}
        }
    }
    if !rel.starts_with("Contents/") {
        return Err(SecurityError::MalformedManifest(format!(
            "manifest path '{}' must reside inside Contents/",
            rel
        )));
    }
    Ok(())
}

/// Verifies `Contents/Manifest.sha256` against actual files inside `bundle_root`.
pub fn verify_bundle_manifest(bundle_root: &Path) -> Result<usize, SecurityError> {
    let manifest_path = bundle_root.join(MANIFEST_SHA256_REL);
    if !manifest_path.is_file() {
        return Err(SecurityError::MissingManifest(manifest_path));
    }

    let content = fs::read_to_string(&manifest_path)?;
    let mut expected: BTreeMap<String, String> = BTreeMap::new();
    for (idx, line) in content.lines().enumerate() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        let Some((hash_part, path_part)) = trimmed.split_once("  ") else {
            return Err(SecurityError::MalformedManifest(format!(
                "line {} missing two-space separator",
                idx + 1
            )));
        };
        if hash_part.len() != 64 || !hash_part.bytes().all(|b| b.is_ascii_hexdigit()) {
            return Err(SecurityError::MalformedManifest(format!(
                "line {} has invalid SHA-256 hex digest",
                idx + 1
            )));
        }
        validate_manifest_rel_path(path_part)?;
        expected.insert(path_part.to_string(), hash_part.to_ascii_lowercase());
    }

    let actual = compute_manifest_entries(bundle_root)?;

    for (path, exp_hash) in &expected {
        match actual.get(path) {
            None => return Err(SecurityError::MissingFile(path.clone())),
            Some(act_hash) if act_hash != exp_hash => {
                return Err(SecurityError::HashMismatch {
                    path: path.clone(),
                    expected: exp_hash.clone(),
                    actual: act_hash.clone(),
                });
            }
            _ => {}
        }
    }

    for path in actual.keys() {
        if !expected.contains_key(path) {
            return Err(SecurityError::UnexpectedFile(path.clone()));
        }
    }

    Ok(expected.len())
}

/// Signs `Contents/Manifest.sha256` using OpenSSL (`pkeyutl` raw signature, supporting Ed25519/RSA/EC PEM keys).
pub fn sign_bundle_manifest(bundle_root: &Path, private_key_pem: &Path) -> Result<PathBuf, SecurityError> {
    let manifest_path = bundle_root.join(MANIFEST_SHA256_REL);
    if !manifest_path.is_file() {
        seal_bundle_manifest(bundle_root)?;
    }
    let sig_path = bundle_root.join(MANIFEST_SIG_REL);
    let output = Command::new("openssl")
        .args([
            "pkeyutl",
            "-sign",
            "-inkey",
            &private_key_pem.to_string_lossy(),
            "-rawin",
            "-in",
            &manifest_path.to_string_lossy(),
            "-out",
            &sig_path.to_string_lossy(),
        ])
        .output()
        .map_err(|e| SecurityError::ToolUnavailable(format!("openssl: {}", e)))?;

    if !output.status.success() {
        return Err(SecurityError::InvalidSignature(
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        ));
    }
    Ok(sig_path)
}

/// Verifies `Contents/Manifest.sig` over `Contents/Manifest.sha256` using an OpenSSL PEM public key.
pub fn verify_bundle_signature(bundle_root: &Path, public_key_pem: &Path) -> Result<(), SecurityError> {
    let manifest_path = bundle_root.join(MANIFEST_SHA256_REL);
    let sig_path = bundle_root.join(MANIFEST_SIG_REL);
    if !manifest_path.is_file() {
        return Err(SecurityError::MissingManifest(manifest_path));
    }
    if !sig_path.is_file() {
        return Err(SecurityError::MissingSignature(sig_path));
    }
    let output = Command::new("openssl")
        .args([
            "pkeyutl",
            "-verify",
            "-pubin",
            "-inkey",
            &public_key_pem.to_string_lossy(),
            "-rawin",
            "-in",
            &manifest_path.to_string_lossy(),
            "-sigfile",
            &sig_path.to_string_lossy(),
        ])
        .output()
        .map_err(|e| SecurityError::ToolUnavailable(format!("openssl: {}", e)))?;

    if !output.status.success() {
        return Err(SecurityError::InvalidSignature(
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        ));
    }
    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QuarantineInfo {
    pub quarantine: Option<String>,
    pub origin_url: Option<String>,
}

impl QuarantineInfo {
    pub fn is_quarantined(&self) -> bool {
        if let Some(ref q) = self.quarantine {
            return !q.is_empty() && q != "cleared";
        }
        false
    }
}

pub fn set_quarantine(path: &Path, origin_url: Option<&str>) -> io::Result<()> {
    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let q_val = match origin_url {
        Some(url) if !url.is_empty() => format!("quarantined;ts={};url={}", ts, url),
        _ => format!("quarantined;ts={}", ts),
    };
    set_xattr(path, XATTR_QUARANTINE, q_val.as_bytes())?;
    if let Some(url) = origin_url {
        if !url.is_empty() {
            set_xattr(path, XATTR_ORIGIN_URL, url.as_bytes())?;
        }
    }
    Ok(())
}

pub fn get_quarantine(path: &Path) -> io::Result<QuarantineInfo> {
    let quarantine = get_xattr(path, XATTR_QUARANTINE)?;
    let origin_url = get_xattr(path, XATTR_ORIGIN_URL)?;
    Ok(QuarantineInfo {
        quarantine: quarantine.map(|b| String::from_utf8_lossy(&b).into_owned()),
        origin_url: origin_url.map(|b| String::from_utf8_lossy(&b).into_owned()),
    })
}

pub fn clear_quarantine(path: &Path) -> io::Result<()> {
    remove_xattr(path, XATTR_QUARANTINE)?;
    Ok(())
}

#[cfg(target_os = "linux")]
fn set_xattr(path: &Path, name: &str, value: &[u8]) -> io::Result<()> {
    use std::ffi::CString;
    use std::os::unix::ffi::OsStrExt;
    let c_path = CString::new(path.as_os_str().as_bytes())
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "NUL in path"))?;
    let c_name = CString::new(name)
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "NUL in xattr name"))?;
    let rc = unsafe {
        libc::lsetxattr(
            c_path.as_ptr(),
            c_name.as_ptr(),
            value.as_ptr() as *const libc::c_void,
            value.len(),
            0,
        )
    };
    if rc == 0 {
        Ok(())
    } else {
        Err(io::Error::last_os_error())
    }
}

#[cfg(target_os = "linux")]
fn get_xattr(path: &Path, name: &str) -> io::Result<Option<Vec<u8>>> {
    use std::ffi::CString;
    use std::os::unix::ffi::OsStrExt;
    let c_path = CString::new(path.as_os_str().as_bytes())
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "NUL in path"))?;
    let c_name = CString::new(name)
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "NUL in xattr name"))?;
    let size = unsafe { libc::lgetxattr(c_path.as_ptr(), c_name.as_ptr(), std::ptr::null_mut(), 0) };
    if size < 0 {
        let err = io::Error::last_os_error();
        if err.raw_os_error() == Some(libc::ENODATA) || err.raw_os_error() == Some(libc::ENOTSUP) {
            return Ok(None);
        }
        return Err(err);
    }
    let mut buf = vec![0u8; size as usize];
    let read = unsafe {
        libc::lgetxattr(
            c_path.as_ptr(),
            c_name.as_ptr(),
            buf.as_mut_ptr() as *mut libc::c_void,
            buf.len(),
        )
    };
    if read < 0 {
        return Err(io::Error::last_os_error());
    }
    buf.truncate(read as usize);
    Ok(Some(buf))
}

#[cfg(target_os = "linux")]
fn remove_xattr(path: &Path, name: &str) -> io::Result<()> {
    use std::ffi::CString;
    use std::os::unix::ffi::OsStrExt;
    let c_path = CString::new(path.as_os_str().as_bytes())
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "NUL in path"))?;
    let c_name = CString::new(name)
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "NUL in xattr name"))?;
    let rc = unsafe { libc::lremovexattr(c_path.as_ptr(), c_name.as_ptr()) };
    if rc == 0 {
        Ok(())
    } else {
        let err = io::Error::last_os_error();
        if err.raw_os_error() == Some(libc::ENODATA) || err.raw_os_error() == Some(libc::ENOTSUP) {
            Ok(())
        } else {
            Err(err)
        }
    }
}

#[cfg(target_os = "macos")]
fn set_xattr(path: &Path, name: &str, value: &[u8]) -> io::Result<()> {
    use std::ffi::CString;
    use std::os::unix::ffi::OsStrExt;
    let c_path = CString::new(path.as_os_str().as_bytes())
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "NUL in path"))?;
    let c_name = CString::new(name)
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "NUL in xattr name"))?;
    let rc = unsafe {
        libc::setxattr(
            c_path.as_ptr(),
            c_name.as_ptr(),
            value.as_ptr() as *const libc::c_void,
            value.len(),
            0,
            libc::XATTR_NOFOLLOW,
        )
    };
    if rc == 0 {
        Ok(())
    } else {
        Err(io::Error::last_os_error())
    }
}

#[cfg(target_os = "macos")]
fn get_xattr(path: &Path, name: &str) -> io::Result<Option<Vec<u8>>> {
    use std::ffi::CString;
    use std::os::unix::ffi::OsStrExt;
    let c_path = CString::new(path.as_os_str().as_bytes())
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "NUL in path"))?;
    let c_name = CString::new(name)
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "NUL in xattr name"))?;
    let size = unsafe {
        libc::getxattr(
            c_path.as_ptr(),
            c_name.as_ptr(),
            std::ptr::null_mut(),
            0,
            0,
            libc::XATTR_NOFOLLOW,
        )
    };
    if size < 0 {
        let err = io::Error::last_os_error();
        if err.raw_os_error() == Some(libc::ENOATTR) || err.raw_os_error() == Some(libc::ENOTSUP) {
            return Ok(None);
        }
        return Err(err);
    }
    let mut buf = vec![0u8; size as usize];
    let read = unsafe {
        libc::getxattr(
            c_path.as_ptr(),
            c_name.as_ptr(),
            buf.as_mut_ptr() as *mut libc::c_void,
            buf.len(),
            0,
            libc::XATTR_NOFOLLOW,
        )
    };
    if read < 0 {
        return Err(io::Error::last_os_error());
    }
    buf.truncate(read as usize);
    Ok(Some(buf))
}

#[cfg(target_os = "macos")]
fn remove_xattr(path: &Path, name: &str) -> io::Result<()> {
    use std::ffi::CString;
    use std::os::unix::ffi::OsStrExt;
    let c_path = CString::new(path.as_os_str().as_bytes())
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "NUL in path"))?;
    let c_name = CString::new(name)
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "NUL in xattr name"))?;
    let rc = unsafe { libc::removexattr(c_path.as_ptr(), c_name.as_ptr(), libc::XATTR_NOFOLLOW) };
    if rc == 0 {
        Ok(())
    } else {
        let err = io::Error::last_os_error();
        if err.raw_os_error() == Some(libc::ENOATTR) || err.raw_os_error() == Some(libc::ENOTSUP) {
            Ok(())
        } else {
            Err(err)
        }
    }
}

#[cfg(not(any(target_os = "linux", target_os = "macos")))]
fn set_xattr(_path: &Path, _name: &str, _value: &[u8]) -> io::Result<()> {
    Ok(())
}

#[cfg(not(any(target_os = "linux", target_os = "macos")))]
fn get_xattr(_path: &Path, _name: &str) -> io::Result<Option<Vec<u8>>> {
    Ok(None)
}

#[cfg(not(any(target_os = "linux", target_os = "macos")))]
fn remove_xattr(_path: &Path, _name: &str) -> io::Result<()> {
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sha256_known_vector() {
        assert_eq!(
            sha256_bytes(b"abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
        assert_eq!(
            sha256_bytes(b""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );
    }

    #[test]
    fn test_seal_and_verify_detects_tamper_and_extra_files() {
        let tmp = std::env::temp_dir().join("conj_sec_test_seal");
        let _ = fs::remove_dir_all(&tmp);
        let app = tmp.join("Sample.app");
        fs::create_dir_all(app.join("Contents/MacOS")).unwrap();
        fs::write(app.join("Contents/Info.toml"), "id = \"org.example.s\"\n").unwrap();
        fs::write(app.join("Contents/MacOS/app"), "#!/bin/sh\necho ok\n").unwrap();

        seal_bundle_manifest(&app).unwrap();
        assert_eq!(verify_bundle_manifest(&app).unwrap(), 2);

        // Tamper existing file
        fs::write(app.join("Contents/MacOS/app"), "#!/bin/sh\necho evil\n").unwrap();
        assert!(matches!(
            verify_bundle_manifest(&app),
            Err(SecurityError::HashMismatch { .. })
        ));

        // Re-seal and inject unexpected file
        seal_bundle_manifest(&app).unwrap();
        fs::write(app.join("Contents/MacOS/trojan"), "evil").unwrap();
        assert!(matches!(
            verify_bundle_manifest(&app),
            Err(SecurityError::UnexpectedFile(_))
        ));

        let _ = fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_quarantine_xattr_roundtrip() {
        let tmp = std::env::temp_dir().join("conj_sec_test_xattr");
        let _ = fs::remove_dir_all(&tmp);
        fs::create_dir_all(&tmp).unwrap();
        let app = tmp.join("Downloaded.app");
        fs::create_dir_all(&app).unwrap();

        set_quarantine(&app, Some("https://example.com/Downloaded.cdmg")).unwrap();
        let info = get_quarantine(&app).unwrap();
        assert!(info.is_quarantined());
        assert_eq!(
            info.origin_url.as_deref(),
            Some("https://example.com/Downloaded.cdmg")
        );

        clear_quarantine(&app).unwrap();
        let after = get_quarantine(&app).unwrap();
        assert!(!after.is_quarantined());

        let _ = fs::remove_dir_all(&tmp);
    }
}
