use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "action")]
pub enum AppdRequest {
    List,
    Inspect { id: String },
    Install { path: PathBuf },
    Uninstall { id: String },
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

pub fn appd_socket_path() -> PathBuf {
    if let Ok(p) = std::env::var("CONJUNCTION_APPD_SOCKET") {
        if !p.is_empty() {
            return PathBuf::from(p);
        }
    }
    if let Ok(runtime_dir) = std::env::var("XDG_RUNTIME_DIR") {
        if !runtime_dir.is_empty() {
            return PathBuf::from(runtime_dir).join("conjunction").join("appd.sock");
        }
    }
    let uid = get_effective_uid();
    PathBuf::from(format!("/tmp/conjunction-appd-{}.sock", uid))
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
