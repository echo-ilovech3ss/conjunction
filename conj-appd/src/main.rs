use clap::Parser;
use conjunction_core::watcher::{run_watch_loop, AppWatchConfig};
use conjunction_core::{
    appd_socket_path, system_applications_dir, user_applications_dir, AppRegistry, AppdRequest,
    AppdResponse,
};
use std::fs;
#[cfg(unix)]
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::ExitCode;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

#[derive(Parser, Debug)]
#[command(name = "conj-appd", version = "0.2.0", about = "Conjunction Application Services daemon")]
struct Cli {
    #[arg(long, help = "Run single reconciliation and exit")]
    oneshot: bool,

    #[arg(long, help = "Custom socket path")]
    socket: Option<PathBuf>,
}

fn main() -> ExitCode {
    env_logger::init();
    let cli = Cli::parse();

    // Ensure ~/Applications exists so inotify can attach immediately
    let user_apps = user_applications_dir();
    let _ = fs::create_dir_all(&user_apps);

    let registry = Arc::new(Mutex::new(AppRegistry::default_for_user()));

    if cli.oneshot {
        log::info!("Running oneshot reconciliation...");
        let mut reg = registry.lock().expect("registry mutex");
        return match reg.reconcile() {
            Ok(()) => ExitCode::SUCCESS,
            Err(e) => {
                log::error!("Reconciliation error: {}", e);
                ExitCode::FAILURE
            }
        };
    }

    let sock_path = cli.socket.unwrap_or_else(appd_socket_path);

    #[cfg(unix)]
    {
        use std::os::unix::net::UnixStream;
        if sock_path.exists() {
            if UnixStream::connect(&sock_path).is_ok() {
                eprintln!(
                    "error: conj-appd is already running for this user/session (socket {})",
                    sock_path.display()
                );
                return ExitCode::FAILURE;
            }
            log::warn!("Removing stale socket at {}", sock_path.display());
            let _ = fs::remove_file(&sock_path);
        }
    }

    if let Some(parent) = sock_path.parent() {
        let _ = fs::create_dir_all(parent);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(parent, fs::Permissions::from_mode(0o700));
        }
    }

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        use std::os::unix::net::UnixListener;

        let listener = match UnixListener::bind(&sock_path) {
            Ok(l) => l,
            Err(e) => {
                eprintln!("error: failed to bind socket {}: {}", sock_path.display(), e);
                return ExitCode::FAILURE;
            }
        };
        let _ = fs::set_permissions(&sock_path, fs::Permissions::from_mode(0o600));

        log::info!(
            "Application Services daemon listening at {}",
            sock_path.display()
        );

        // Rebuild all state strictly from disk on startup (no stale database)
        {
            let mut reg = registry.lock().expect("registry mutex");
            if let Err(e) = reg.reconcile() {
                log::error!("Initial reconciliation error: {}", e);
            } else {
                log::info!("Initial reconciliation complete.");
            }
        }

        // Launch real-time filesystem watcher (inotify on Linux)
        let stop_flag = Arc::new(AtomicBool::new(false));
        let stop_watch = Arc::clone(&stop_flag);
        let reg_watch = Arc::clone(&registry);
        let watch_dirs = vec![user_apps, system_applications_dir()];
        let _watch_handle = std::thread::spawn(move || {
            let cfg = AppWatchConfig {
                dirs: watch_dirs,
                ..AppWatchConfig::default()
            };
            match run_watch_loop(cfg, stop_watch, move || {
                if let Ok(mut reg) = reg_watch.lock() {
                    if let Err(e) = reg.reconcile() {
                        log::error!("Watch reconciliation error: {}", e);
                    }
                }
            }) {
                Ok(backend) => log::info!("Watch loop exited cleanly ({:?})", backend),
                Err(e) => log::error!("Watch loop error: {}", e),
            }
        });

        for stream in listener.incoming() {
            match stream {
                Ok(mut sock) => {
                    let mut reader = BufReader::new(sock.try_clone().expect("clone socket"));
                    let mut line = String::new();
                    if reader.read_line(&mut line).is_ok() && !line.is_empty() {
                        let resp = match serde_json::from_str::<AppdRequest>(&line) {
                            Ok(req) => {
                                let mut reg = registry.lock().expect("registry mutex");
                                handle_request(&mut reg, req)
                            }
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
        stop_flag.store(true, Ordering::Relaxed);
        ExitCode::SUCCESS
    }

    #[cfg(not(unix))]
    {
        let _ = registry;
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

        AppdRequest::Uninstall { id, yes, with_data } => {
            match registry.uninstall_with_options_and_data(&id, yes, with_data) {
                Ok(()) => AppdResponse::ok(serde_json::json!({ "uninstalled": id, "with_data": with_data })),
                Err(e) => AppdResponse::err(e.to_string()),
            }
        }

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

        AppdRequest::ListLeftovers => {
            let leftovers = registry.list_leftovers();
            AppdResponse::ok(serde_json::to_value(leftovers).unwrap_or_default())
        }

        AppdRequest::PurgeLeftovers { id } => match registry.purge_leftovers(&id) {
            Ok(count) => AppdResponse::ok(serde_json::json!({ "id": id, "removed": count })),
            Err(e) => AppdResponse::err(e.to_string()),
        },
    }
}
