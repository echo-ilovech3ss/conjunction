use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "action")]
pub enum AppdRequest {
    List,
    Inspect { id: String },
    Install { path: PathBuf },
    Uninstall {
        id: String,
        #[serde(default)]
        yes: bool,
    },
    Launch { target: String, args: Vec<String> },
    Reconcile,
    Ping,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppdResponse {
    pub success: bool,
    pub data: Option<serde_json::Value>,
    pub error: Option<String>,
}

impl AppdResponse {
    pub fn ok(data: serde_json::Value) -> Self {
        AppdResponse {
            success: true,
            data: Some(data),
            error: None,
        }
    }

    pub fn err<S: Into<String>>(msg: S) -> Self {
        AppdResponse {
            success: false,
            data: None,
            error: Some(msg.into()),
        }
    }
}

pub fn appd_runtime_dir() -> Result<PathBuf, String> {
    if let Ok(runtime_dir) = std::env::var("XDG_RUNTIME_DIR") {
        if !runtime_dir.is_empty() {
            let p = PathBuf::from(runtime_dir);
            #[cfg(unix)]
            {
                if let Ok(meta) = std::fs::symlink_metadata(&p) {
                    if meta.file_type().is_symlink() {
                        return Err(format!(
                            "security error: XDG_RUNTIME_DIR '{}' is a symlink",
                            p.display()
                        ));
                    }
                }
            }
            return Ok(p);
        }
    }

    // Secure fallback: /tmp/conjunction-run-<UID>
    let uid = get_effective_uid();
    let fallback = PathBuf::from(format!("/tmp/conjunction-run-{}", uid));

    #[cfg(unix)]
    {
        use std::os::unix::fs::{MetadataExt, PermissionsExt};
        if fallback.exists() {
            let meta = std::fs::symlink_metadata(&fallback).map_err(|e| {
                format!(
                    "cannot inspect fallback runtime dir {}: {}",
                    fallback.display(),
                    e
                )
            })?;

            if meta.file_type().is_symlink() {
                return Err(format!(
                    "security error: fallback runtime path '{}' is a symlink",
                    fallback.display()
                ));
            }
            if !meta.is_dir() {
                return Err(format!(
                    "security error: fallback runtime path '{}' is not a directory",
                    fallback.display()
                ));
            }
            if meta.uid() != uid {
                return Err(format!(
                    "security error: fallback runtime dir '{}' is owned by UID {}, expected UID {}",
                    fallback.display(),
                    meta.uid(),
                    uid
                ));
            }
            let mode = meta.mode() & 0o777;
            if mode != 0o700 {
                let _ = std::fs::set_permissions(&fallback, std::fs::Permissions::from_mode(0o700));
            }
        } else {
            std::fs::create_dir(&fallback).map_err(|e| {
                format!(
                    "cannot create fallback runtime dir {}: {}",
                    fallback.display(),
                    e
                )
            })?;
            std::fs::set_permissions(&fallback, std::fs::Permissions::from_mode(0o700))
                .map_err(|e| format!("cannot set mode 0700 on {}: {}", fallback.display(), e))?;
        }
    }

    #[cfg(not(unix))]
    {
        let _ = std::fs::create_dir_all(&fallback);
    }

    Ok(fallback)
}

pub fn appd_socket_path() -> PathBuf {
    if let Ok(p) = std::env::var("CONJUNCTION_APPD_SOCKET") {
        if !p.is_empty() {
            return PathBuf::from(p);
        }
    }
    match appd_runtime_dir() {
        Ok(dir) => dir.join("conjunction").join("appd.sock"),
        Err(_) => {
            let uid = get_effective_uid();
            PathBuf::from(format!("/tmp/conjunction-run-{}/conjunction/appd.sock", uid))
        }
    }
}

pub fn get_effective_uid() -> u32 {
    #[cfg(unix)]
    {
        unsafe { libc_getuid() }
    }
    #[cfg(not(unix))]
    {
        1000
    }
}

#[cfg(unix)]
extern "C" {
    fn getuid() -> u32;
}

#[cfg(unix)]
unsafe fn libc_getuid() -> u32 {
    getuid()
}

pub fn send_appd_request(req: &AppdRequest) -> Result<AppdResponse, String> {
    let sock_path = appd_socket_path();
    send_appd_request_to_path(&sock_path, req)
}

pub fn send_appd_request_to_path(sock_path: &Path, req: &AppdRequest) -> Result<AppdResponse, String> {
    #[cfg(unix)]
    {
        use std::io::Write;
        use std::os::unix::net::UnixStream;
        let mut stream = UnixStream::connect(sock_path).map_err(|e| {
            format!(
                "cannot connect to conj-appd daemon at {}: {} (is conj-appd running?)",
                sock_path.display(),
                e
            )
        })?;

        let req_json = serde_json::to_string(req).map_err(|e| format!("serialization error: {}", e))?;
        stream
            .write_all(req_json.as_bytes())
            .map_err(|e| format!("write error: {}", e))?;
        stream.write_all(b"\n").map_err(|e| format!("write error: {}", e))?;
        stream.flush().map_err(|e| format!("flush error: {}", e))?;

        let mut reader = std::io::BufReader::new(stream);
        let mut line = String::new();
        std::io::BufRead::read_line(&mut reader, &mut line).map_err(|e| format!("read error: {}", e))?;

        let resp: AppdResponse =
            serde_json::from_str(&line).map_err(|e| format!("deserialization error: {}", e))?;
        Ok(resp)
    }

    #[cfg(not(unix))]
    {
        let _ = (sock_path, req);
        Err("Unix domain sockets are not supported on this platform".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ipc_request_serialization() {
        let req = AppdRequest::Inspect {
            id: "dev.conjunction.test.hello".to_string(),
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("Inspect"));
        assert!(json.contains("dev.conjunction.test.hello"));

        let res = AppdResponse::ok(serde_json::json!({"exit_code": 0}));
        let res_json = serde_json::to_string(&res).unwrap();
        assert!(res_json.contains("\"success\":true"));
    }

    #[test]
    fn test_appd_socket_path_resolution() {
        let path = appd_socket_path();
        let s = path.to_string_lossy();
        assert!(s.ends_with("appd.sock"));
    }
}
