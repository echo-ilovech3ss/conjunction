use clap::Parser;
use conjunction_core::package::is_valid_package_name;
use serde::{Deserialize, Serialize};
use std::fs;
#[cfg(unix)]
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Command, ExitCode};

#[derive(Parser, Debug)]
#[command(name = "conj-sysd", version = "0.1.0", about = "Conjunction Privileged System Service")]
struct Cli {
    #[arg(long, help = "Custom socket path")]
    socket: Option<PathBuf>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "action")]
pub enum SysdRequest {
    RemovePacmanPackage { package: String },
    Ping,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SysdResponse {
    pub success: bool,
    pub error: Option<String>,
}

impl SysdResponse {
    pub fn ok() -> Self {
        SysdResponse {
            success: true,
            error: None,
        }
    }
    pub fn err<S: Into<String>>(msg: S) -> Self {
        SysdResponse {
            success: false,
            error: Some(msg.into()),
        }
    }
}

pub const DEFAULT_SYSD_SOCKET: &str = "/run/conjunction/sysd.sock";

fn main() -> ExitCode {
    env_logger::init();
    let cli = Cli::parse();
    let sock_path = cli
        .socket
        .unwrap_or_else(|| PathBuf::from(DEFAULT_SYSD_SOCKET));

    log::info!("Starting Conjunction Privileged System Service (conj-sysd)...");

    if let Some(parent) = sock_path.parent() {
        let _ = fs::create_dir_all(parent);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(parent, fs::Permissions::from_mode(0o755));
        }
    }

    if sock_path.exists() {
        let _ = fs::remove_file(&sock_path);
    }

    #[cfg(unix)]
    {
        use std::os::unix::net::UnixListener;
        let listener = match UnixListener::bind(&sock_path) {
            Ok(l) => l,
            Err(e) => {
                log::error!("Failed to bind socket {}: {}", sock_path.display(), e);
                return ExitCode::FAILURE;
            }
        };

        // Make socket accessible to users on the system (0o666)
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(&sock_path, fs::Permissions::from_mode(0o666));

        log::info!("conj-sysd listening at {}", sock_path.display());

        for stream in listener.incoming() {
            match stream {
                Ok(mut sock) => {
                    let mut reader = BufReader::new(sock.try_clone().expect("clone socket"));
                    let mut line = String::new();
                    if reader.read_line(&mut line).is_ok() && !line.is_empty() {
                        let resp = match serde_json::from_str::<SysdRequest>(&line) {
                            Ok(req) => handle_request(req),
                            Err(e) => SysdResponse::err(format!("malformed request: {}", e)),
                        };
                        let resp_json = serde_json::to_string(&resp).unwrap_or_default();
                        let _ = sock.write_all(resp_json.as_bytes());
                        let _ = sock.write_all(b"\n");
                        let _ = sock.flush();
                    }
                }
                Err(e) => {
                    log::warn!("Connection failed: {}", e);
                }
            }
        }
        ExitCode::SUCCESS
    }

    #[cfg(not(unix))]
    {
        log::warn!("conj-sysd requires a unix environment");
        ExitCode::SUCCESS
    }
}

#[allow(dead_code)]
fn handle_request(req: SysdRequest) -> SysdResponse {
    match req {
        SysdRequest::Ping => SysdResponse::ok(),
        SysdRequest::RemovePacmanPackage { package } => {
            // Strict package name validation
            if !is_valid_package_name(&package) {
                return SysdResponse::err(format!(
                    "security error: invalid package name '{}'",
                    package
                ));
            }

            log::info!("Request to remove package '{}' received", package);

            // Verify package is actually installed
            let check = Command::new("pacman").args(["-Q", &package]).output();
            match check {
                Ok(out) => {
                    if !out.status.success() {
                        return SysdResponse::err(format!(
                            "package '{}' is not installed",
                            package
                        ));
                    }
                }
                Err(e) => {
                    return SysdResponse::err(format!("cannot execute pacman -Q: {}", e));
                }
            }

            // Execute pacman removal: NO shell!
            let rm = Command::new("pacman")
                .args(["-R", "--noconfirm", &package])
                .output();

            match rm {
                Ok(out) => {
                    if out.status.success() {
                        log::info!("Package '{}' removed successfully", package);
                        SysdResponse::ok()
                    } else {
                        let err_msg = String::from_utf8_lossy(&out.stderr);
                        log::error!("pacman -R failed: {}", err_msg);
                        SysdResponse::err(format!("pacman -R failed: {}", err_msg.trim()))
                    }
                }
                Err(e) => SysdResponse::err(format!("cannot execute pacman -R: {}", e)),
            }
        }
    }
}
