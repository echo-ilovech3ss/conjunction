use clap::Parser;
use conjunction_core::package::is_valid_package_name;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};
use std::sync::Mutex;

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
pub const POLKIT_PACKAGE_REMOVE_ACTION: &str = "org.conjunction.packages.remove";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PeerCaller {
    pub pid: u32,
    pub uid: u32,
    pub gid: u32,
    pub start_time: u64,
}

pub fn get_process_start_time(pid: u32) -> Result<u64, String> {
    let stat_path = format!("/proc/{}/stat", pid);
    let content = std::fs::read_to_string(&stat_path)
        .map_err(|e| format!("cannot read {}: {}", stat_path, e))?;
    // Format: pid (comm) state ... starttime (field 22)
    // Find last ')' to skip comm which may contain spaces and parentheses
    let rparen_idx = content
        .rfind(')')
        .ok_or_else(|| format!("invalid format in {}", stat_path))?;
    let rest = &content[rparen_idx + 1..];
    let tokens: Vec<&str> = rest.split_whitespace().collect();
    // token 0 = state (field 3) ... token 19 = starttime (field 22)
    if tokens.len() <= 19 {
        return Err(format!("insufficient fields in {}", stat_path));
    }
    tokens[19]
        .parse::<u64>()
        .map_err(|e| format!("invalid starttime '{}' in {}: {}", tokens[19], stat_path, e))
}

#[cfg(unix)]
pub fn get_peer_credentials(stream: &std::os::unix::net::UnixStream) -> Result<PeerCaller, String> {
    #[cfg(target_os = "linux")]
    {
        use std::mem;
        use std::os::unix::io::AsRawFd;
        let fd = stream.as_raw_fd();
        let mut ucred: libc::ucred = unsafe { mem::zeroed() };
        let mut len = mem::size_of::<libc::ucred>() as libc::socklen_t;
        let ret = unsafe {
            libc::getsockopt(
                fd,
                libc::SOL_SOCKET,
                libc::SO_PEERCRED,
                &mut ucred as *mut _ as *mut libc::c_void,
                &mut len,
            )
        };
        if ret < 0 {
            return Err(format!(
                "getsockopt(SO_PEERCRED) failed: {}",
                std::io::Error::last_os_error()
            ));
        }
        let pid = ucred.pid as u32;
        let uid = ucred.uid as u32;
        let gid = ucred.gid as u32;
        let start_time = get_process_start_time(pid).unwrap_or(0);
        Ok(PeerCaller {
            pid,
            uid,
            gid,
            start_time,
        })
    }
    #[cfg(not(target_os = "linux"))]
    {
        // Fallback for non-Linux unix
        Ok(PeerCaller {
            pid: std::process::id(),
            uid: 0,
            gid: 0,
            start_time: 0,
        })
    }
}

pub trait Authorizer: Send + Sync {
    fn check_authorization(&self, caller: &PeerCaller, action: &str) -> Result<(), String>;
}

pub struct PolkitAuthorizer {
    pub pkcheck_path: PathBuf,
}

impl PolkitAuthorizer {
    pub fn new() -> Self {
        let path = if Path::new("/usr/bin/pkcheck").exists() {
            PathBuf::from("/usr/bin/pkcheck")
        } else {
            PathBuf::from("pkcheck")
        };
        Self { pkcheck_path: path }
    }
}

impl Authorizer for PolkitAuthorizer {
    fn check_authorization(&self, caller: &PeerCaller, action: &str) -> Result<(), String> {
        let process_spec = if caller.start_time > 0 {
            format!("{},{},{}", caller.pid, caller.start_time, caller.uid)
        } else {
            format!("{},{}", caller.pid, caller.uid)
        };

        let mut cmd = Command::new(&self.pkcheck_path);
        cmd.args(["--action-id", action, "--process", &process_spec])
            .env_clear()
            .envs([("PATH", "/usr/bin:/bin"), ("LC_ALL", "C")]);

        match cmd.output() {
            Ok(output) => {
                if output.status.success() {
                    Ok(())
                } else {
                    let stderr = String::from_utf8_lossy(&output.stderr);
                    let clean_err = stderr.trim();
                    let detail = if clean_err.is_empty() {
                        "not authorized by policy"
                    } else {
                        clean_err
                    };
                    Err(format!(
                        "authorization denied: caller (UID {}, PID {}) is not authorized for action '{}': {}",
                        caller.uid, caller.pid, action, detail
                    ))
                }
            }
            Err(e) => Err(format!("failed to execute pkcheck: {}", e)),
        }
    }
}

pub trait PacmanRunner: Send + Sync {
    fn check_installed(&self, package: &str) -> Result<bool, String>;
    fn remove_package(&self, package: &str) -> Result<(), String>;
}

pub struct SystemPacmanRunner {
    pub pacman_path: PathBuf,
}

impl SystemPacmanRunner {
    pub fn new() -> Self {
        let path = if Path::new("/usr/bin/pacman").exists() {
            PathBuf::from("/usr/bin/pacman")
        } else {
            PathBuf::from("pacman")
        };
        Self { pacman_path: path }
    }
}

impl PacmanRunner for SystemPacmanRunner {
    fn check_installed(&self, package: &str) -> Result<bool, String> {
        let mut cmd = Command::new(&self.pacman_path);
        cmd.args(["-Q", package])
            .env_clear()
            .envs([("PATH", "/usr/bin:/bin"), ("LC_ALL", "C")]);

        match cmd.output() {
            Ok(out) => Ok(out.status.success()),
            Err(e) => Err(format!("cannot execute pacman -Q: {}", e)),
        }
    }

    fn remove_package(&self, package: &str) -> Result<(), String> {
        let mut cmd = Command::new(&self.pacman_path);
        cmd.args(["-R", "--noconfirm", package])
            .env_clear()
            .envs([("PATH", "/usr/bin:/bin"), ("LC_ALL", "C")]);

        match cmd.output() {
            Ok(out) => {
                if out.status.success() {
                    Ok(())
                } else {
                    let err = String::from_utf8_lossy(&out.stderr);
                    Err(format!("pacman -R failed: {}", err.trim()))
                }
            }
            Err(e) => Err(format!("cannot execute pacman -R: {}", e)),
        }
    }
}

pub fn handle_request(
    req: SysdRequest,
    caller: &PeerCaller,
    authorizer: &dyn Authorizer,
    runner: &dyn PacmanRunner,
    lock: &Mutex<()>,
) -> SysdResponse {
    match req {
        SysdRequest::Ping => SysdResponse::ok(),
        SysdRequest::RemovePacmanPackage { package } => {
            // 1. Strict package name syntax validation
            if !is_valid_package_name(&package) {
                return SysdResponse::err(format!(
                    "security error: invalid package name '{}'",
                    package
                ));
            }

            // 2. Authorize caller via Polkit BEFORE touching package manager
            if let Err(auth_err) = authorizer.check_authorization(caller, POLKIT_PACKAGE_REMOVE_ACTION) {
                log::warn!("Unauthorized removal attempt by UID {}: {}", caller.uid, auth_err);
                return SysdResponse::err(auth_err);
            }

            // 3. Concurrency serialization: Prevent concurrent pacman mutations
            let _guard = match lock.try_lock() {
                Ok(g) => g,
                Err(_) => {
                    return SysdResponse::err("system busy: another package transaction is currently in progress");
                }
            };

            log::info!(
                "Authorized request by UID {} (PID {}) to remove package '{}'",
                caller.uid,
                caller.pid,
                package
            );

            // 4. Independently verify package is installed
            match runner.check_installed(&package) {
                Ok(true) => {}
                Ok(false) => {
                    return SysdResponse::err(format!("package '{}' is not installed", package));
                }
                Err(e) => {
                    return SysdResponse::err(e);
                }
            }

            // 5. Execute fixed pacman removal command without shell
            match runner.remove_package(&package) {
                Ok(()) => {
                    log::info!("Package '{}' removed successfully", package);
                    SysdResponse::ok()
                }
                Err(e) => {
                    log::error!("Removal of package '{}' failed: {}", package, e);
                    SysdResponse::err(e)
                }
            }
        }
    }
}

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
        use std::io::{BufRead, BufReader, Write};
        use std::os::unix::net::UnixListener;
        use std::sync::Arc;

        let listener = match UnixListener::bind(&sock_path) {
            Ok(l) => l,
            Err(e) => {
                log::error!("Failed to bind socket {}: {}", sock_path.display(), e);
                return ExitCode::FAILURE;
            }
        };

        // Socket is transport endpoint accessible to local users; authorization enforced via SO_PEERCRED + Polkit
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(&sock_path, fs::Permissions::from_mode(0o666));

        log::info!("conj-sysd listening at {}", sock_path.display());

        let authorizer = Arc::new(PolkitAuthorizer::new());
        let runner = Arc::new(SystemPacmanRunner::new());
        let lock = Arc::new(Mutex::new(()));

        for stream in listener.incoming() {
            match stream {
                Ok(mut sock) => {
                    let caller = match get_peer_credentials(&sock) {
                        Ok(c) => c,
                        Err(e) => {
                            log::warn!("Failed to obtain peer credentials: {}", e);
                            let resp = SysdResponse::err(format!("failed to identify caller: {}", e));
                            let resp_json = serde_json::to_string(&resp).unwrap_or_default();
                            let _ = sock.write_all(resp_json.as_bytes());
                            let _ = sock.write_all(b"\n");
                            let _ = sock.flush();
                            continue;
                        }
                    };

                    let mut reader = BufReader::new(sock.try_clone().expect("clone socket"));
                    let mut line = String::new();
                    if reader.read_line(&mut line).is_ok() && !line.is_empty() {
                        let resp = match serde_json::from_str::<SysdRequest>(&line) {
                            Ok(req) => handle_request(
                                req,
                                &caller,
                                authorizer.as_ref(),
                                runner.as_ref(),
                                &lock,
                            ),
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};

    struct MockAuthorizer {
        pub authorized_uids: Vec<u32>,
        pub check_count: AtomicUsize,
    }

    impl MockAuthorizer {
        fn new(uids: Vec<u32>) -> Self {
            Self {
                authorized_uids: uids,
                check_count: AtomicUsize::new(0),
            }
        }
    }

    impl Authorizer for MockAuthorizer {
        fn check_authorization(&self, caller: &PeerCaller, action: &str) -> Result<(), String> {
            self.check_count.fetch_add(1, Ordering::SeqCst);
            if self.authorized_uids.contains(&caller.uid) {
                Ok(())
            } else {
                Err(format!(
                    "authorization denied: caller (UID {}, PID {}) is not authorized for action '{}'",
                    caller.uid, caller.pid, action
                ))
            }
        }
    }

    struct MockPacmanRunner {
        pub installed_packages: Vec<String>,
        pub check_calls: AtomicUsize,
        pub remove_calls: AtomicUsize,
        pub last_removed: Mutex<Option<String>>,
    }

    impl MockPacmanRunner {
        fn new(installed: Vec<&str>) -> Self {
            Self {
                installed_packages: installed.into_iter().map(String::from).collect(),
                check_calls: AtomicUsize::new(0),
                remove_calls: AtomicUsize::new(0),
                last_removed: Mutex::new(None),
            }
        }
    }

    impl PacmanRunner for MockPacmanRunner {
        fn check_installed(&self, package: &str) -> Result<bool, String> {
            self.check_calls.fetch_add(1, Ordering::SeqCst);
            Ok(self.installed_packages.contains(&package.to_string()))
        }

        fn remove_package(&self, package: &str) -> Result<(), String> {
            self.remove_calls.fetch_add(1, Ordering::SeqCst);
            *self.last_removed.lock().unwrap() = Some(package.to_string());
            Ok(())
        }
    }

    #[test]
    fn test_unauthorized_caller_rejected() {
        let authorizer = MockAuthorizer::new(vec![1000]);
        let runner = MockPacmanRunner::new(vec!["demo-pkg"]);
        let lock = Mutex::new(());

        let attacker = PeerCaller {
            pid: 1234,
            uid: 1001, // Unauthorized
            gid: 1001,
            start_time: 100,
        };

        let req = SysdRequest::RemovePacmanPackage {
            package: "demo-pkg".to_string(),
        };

        let resp = handle_request(req, &attacker, &authorizer, &runner, &lock);
        assert!(!resp.success);
        assert!(resp.error.unwrap().contains("authorization denied"));
        // Ensure pacman was never invoked
        assert_eq!(runner.check_calls.load(Ordering::SeqCst), 0);
        assert_eq!(runner.remove_calls.load(Ordering::SeqCst), 0);
    }

    #[test]
    fn test_authorization_happens_before_pacman_spawn() {
        let authorizer = MockAuthorizer::new(vec![1000]);
        let runner = MockPacmanRunner::new(vec!["demo-pkg"]);
        let lock = Mutex::new(());

        let attacker = PeerCaller {
            pid: 5678,
            uid: 9999,
            gid: 9999,
            start_time: 200,
        };

        let req = SysdRequest::RemovePacmanPackage {
            package: "demo-pkg".to_string(),
        };

        let resp = handle_request(req, &attacker, &authorizer, &runner, &lock);
        assert!(!resp.success);
        assert_eq!(authorizer.check_count.load(Ordering::SeqCst), 1);
        assert_eq!(runner.check_calls.load(Ordering::SeqCst), 0);
        assert_eq!(runner.remove_calls.load(Ordering::SeqCst), 0);
    }

    #[test]
    fn test_malformed_package_rejected_before_authorization() {
        let authorizer = MockAuthorizer::new(vec![1000]);
        let runner = MockPacmanRunner::new(vec!["demo-pkg"]);
        let lock = Mutex::new(());

        let caller = PeerCaller {
            pid: 100,
            uid: 1000,
            gid: 1000,
            start_time: 50,
        };

        let bad_names = vec![
            "pkg; rm -rf /",
            "pkg $(touch /tmp/pwn)",
            "--cached",
            "-R",
            "pkg|whoami",
            "",
        ];

        for bad_pkg in bad_names {
            let req = SysdRequest::RemovePacmanPackage {
                package: bad_pkg.to_string(),
            };
            let resp = handle_request(req, &caller, &authorizer, &runner, &lock);
            assert!(!resp.success, "bad package '{}' should be rejected", bad_pkg);
            assert!(resp.error.unwrap().contains("invalid package name"));
        }

        // Authorization check must not even have been called for malformed syntax
        assert_eq!(authorizer.check_count.load(Ordering::SeqCst), 0);
        assert_eq!(runner.remove_calls.load(Ordering::SeqCst), 0);
    }

    #[test]
    fn test_authorized_caller_executes_pacman() {
        let authorizer = MockAuthorizer::new(vec![1000]);
        let runner = MockPacmanRunner::new(vec!["demo-pkg"]);
        let lock = Mutex::new(());

        let authorized_caller = PeerCaller {
            pid: 4321,
            uid: 1000,
            gid: 1000,
            start_time: 150,
        };

        let req = SysdRequest::RemovePacmanPackage {
            package: "demo-pkg".to_string(),
        };

        let resp = handle_request(req, &authorized_caller, &authorizer, &runner, &lock);
        assert!(resp.success, "error: {:?}", resp.error);
        assert_eq!(authorizer.check_count.load(Ordering::SeqCst), 1);
        assert_eq!(runner.check_calls.load(Ordering::SeqCst), 1);
        assert_eq!(runner.remove_calls.load(Ordering::SeqCst), 1);
        assert_eq!(
            *runner.last_removed.lock().unwrap(),
            Some("demo-pkg".to_string())
        );
    }

    #[test]
    fn test_uninstalled_package_rejected() {
        let authorizer = MockAuthorizer::new(vec![1000]);
        let runner = MockPacmanRunner::new(vec![]); // not installed
        let lock = Mutex::new(());

        let authorized_caller = PeerCaller {
            pid: 4321,
            uid: 1000,
            gid: 1000,
            start_time: 150,
        };

        let req = SysdRequest::RemovePacmanPackage {
            package: "missing-pkg".to_string(),
        };

        let resp = handle_request(req, &authorized_caller, &authorizer, &runner, &lock);
        assert!(!resp.success);
        assert!(resp.error.unwrap().contains("is not installed"));
        assert_eq!(runner.check_calls.load(Ordering::SeqCst), 1);
        assert_eq!(runner.remove_calls.load(Ordering::SeqCst), 0);
    }

    #[test]
    fn test_concurrency_busy_error() {
        let authorizer = MockAuthorizer::new(vec![1000]);
        let runner = MockPacmanRunner::new(vec!["demo-pkg"]);
        let lock = Mutex::new(());

        let caller = PeerCaller {
            pid: 4321,
            uid: 1000,
            gid: 1000,
            start_time: 150,
        };

        // Simulate another thread holding the transaction lock
        let held_guard = lock.lock().unwrap();

        let req = SysdRequest::RemovePacmanPackage {
            package: "demo-pkg".to_string(),
        };

        let resp = handle_request(req, &caller, &authorizer, &runner, &lock);
        assert!(!resp.success);
        assert!(resp.error.unwrap().contains("system busy"));
        assert_eq!(runner.remove_calls.load(Ordering::SeqCst), 0);

        drop(held_guard);
    }

    #[test]
    fn test_user_cannot_supply_arbitrary_pacman_flags_or_executable_path() {
        let authorizer = MockAuthorizer::new(vec![1000]);
        let runner = MockPacmanRunner::new(vec!["valid-pkg"]);
        let lock = Mutex::new(());

        let caller = PeerCaller {
            pid: 4321,
            uid: 1000,
            gid: 1000,
            start_time: 150,
        };

        // Attempts to supply flags or custom executable paths
        let hostile_inputs = vec![
            "-Rdd --nodeps valid-pkg",
            "--nodeps",
            "--force",
            "/bin/evil-pacman",
            "/usr/bin/pacman -R valid-pkg",
            "valid-pkg --dbpath /tmp/evil",
        ];

        for hostile in hostile_inputs {
            let req = SysdRequest::RemovePacmanPackage {
                package: hostile.to_string(),
            };
            let resp = handle_request(req, &caller, &authorizer, &runner, &lock);
            assert!(
                !resp.success,
                "hostile input '{}' should have been rejected",
                hostile
            );
            assert!(resp.error.unwrap().contains("invalid package name"));
        }

        // Neither check nor remove was called
        assert_eq!(runner.check_calls.load(Ordering::SeqCst), 0);
        assert_eq!(runner.remove_calls.load(Ordering::SeqCst), 0);
    }
}
