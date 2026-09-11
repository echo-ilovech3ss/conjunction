use clap::Parser;
use conjunction_core::{appd_socket_path, AppRegistry, AppdRequest, AppdResponse};
use std::fs;
#[cfg(unix)]
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser, Debug)]
#[command(name = "conj-appd", version = "0.1.0", about = "Conjunction Application Services daemon")]
struct Cli {
    #[arg(long, help = "Run single reconciliation and exit")]
    oneshot: bool,

    #[arg(long, help = "Custom socket path")]
    socket: Option<PathBuf>,
}

fn main() -> ExitCode {
    env_logger::init();
    let cli = Cli::parse();
    let mut registry = AppRegistry::default_for_user();

    log::info!("Starting Conjunction Application Daemon (conj-appd)...");
    if let Err(e) = registry.reconcile() {
        log::error!("Initial reconciliation error: {}", e);
        if cli.oneshot {
            return ExitCode::FAILURE;
        }
    } else {
        log::info!("Initial reconciliation complete.");
    }

    if cli.oneshot {
        return ExitCode::SUCCESS;
    }

    let sock_path = cli.socket.unwrap_or_else(appd_socket_path);
    if let Some(parent) = sock_path.parent() {
        let _ = fs::create_dir_all(parent);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(parent, fs::Permissions::from_mode(0o700));
        }
    }

    // Clean up stale socket
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

        // Set socket file permissions to user-only (0o600)
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(&sock_path, fs::Permissions::from_mode(0o600));

        log::info!("Application Services daemon listening at {}", sock_path.display());

        for stream in listener.incoming() {
            match stream {
                Ok(mut sock) => {
                    let mut reader = BufReader::new(sock.try_clone().expect("clone socket"));
                    let mut line = String::new();
                    if reader.read_line(&mut line).is_ok() && !line.is_empty() {
                        let resp = match serde_json::from_str::<AppdRequest>(&line) {
                            Ok(req) => handle_request(&mut registry, req),
                            Err(e) => AppdResponse::err(format!("invalid request JSON: {}", e)),
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
        log::warn!("Daemon IPC socket is disabled on non-unix platforms");
        ExitCode::SUCCESS
    }
}

#[allow(dead_code)]
fn handle_request(registry: &mut AppRegistry, req: AppdRequest) -> AppdResponse {
    match req {
        AppdRequest::Ping => AppdResponse::ok(serde_json::json!("pong")),

        AppdRequest::List => match registry.reconcile() {
            Ok(()) => {
                let items = registry.list();
                AppdResponse::ok(serde_json::to_value(items).unwrap_or_default())
            }
            Err(e) => AppdResponse::err(e.to_string()),
        },

        AppdRequest::Inspect { id } => match registry.reconcile() {
            Ok(()) => match registry.inspect(&id) {
                Ok(item) => AppdResponse::ok(serde_json::to_value(item).unwrap_or_default()),
                Err(e) => AppdResponse::err(e.to_string()),
            },
            Err(e) => AppdResponse::err(e.to_string()),
        },

        AppdRequest::Install { path } => match registry.install(&path) {
            Ok(app) => AppdResponse::ok(serde_json::to_value(app).unwrap_or_default()),
            Err(e) => AppdResponse::err(e.to_string()),
        },

        AppdRequest::Uninstall { id } => match registry.uninstall(&id) {
            Ok(()) => AppdResponse::ok(serde_json::json!({ "uninstalled": id })),
            Err(e) => AppdResponse::err(e.to_string()),
        },

        AppdRequest::Launch { target, args } => match registry.reconcile() {
            Ok(()) => match registry.launch_captured(&target, &args) {
                Ok(launch_res) => {
                    AppdResponse::ok(serde_json::to_value(launch_res).unwrap_or_default())
                }
                Err(e) => AppdResponse::err(e.to_string()),
            },
            Err(e) => AppdResponse::err(e.to_string()),
        },

        AppdRequest::Reconcile => match registry.reconcile() {
            Ok(()) => AppdResponse::ok(serde_json::json!({ "reconciled": true })),
            Err(e) => AppdResponse::err(e.to_string()),
        },
    }
}
