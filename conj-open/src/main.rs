use clap::Parser;
use conjunction_core::cdmg::{detect_cdmg_filesystem, eject_cdmg, mount_cdmg, MountBackend};
use conjunction_core::desktop_entry::is_executable_available;
use conjunction_core::launcher::{build_bundle_launch_plan, exec_plan_replace, execute_plan_captured};
use conjunction_core::security::{clear_quarantine, get_quarantine};
use conjunction_core::{
    send_appd_request, AppBackend, AppRegistry, AppdRequest, Bundle, RegistryItem,
};
use std::io::IsTerminal;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

#[derive(Parser, Debug)]
#[command(name = "conj-open", version = "0.2.0", about = "Conjunction application, bundle, and disk image opener")]
struct Cli {
    #[arg(long, value_names = ["MIME", "DESKTOP_ID"], num_args = 2, help = "Set default application for MIME type or URI scheme")]
    set_default: Option<Vec<String>>,

    #[arg(long, help = "Launch a .app bundle directly (replaces process via exec)")]
    bundle: Option<PathBuf>,

    #[arg(long, help = "Eject a mounted .cdmg disk image by path or mount point")]
    eject: Option<PathBuf>,

    #[arg(long, help = "Allow opening quarantined bundles/disk images (and clear quarantine on confirmation)")]
    allow_quarantined: bool,

    #[arg(long, help = "Do not open file manager after mounting a .cdmg disk image")]
    no_open: bool,

    #[arg(long, help = "Wait and capture output instead of exec-replacing (used for scripts/tests)")]
    wait: bool,

    #[arg(help = "Path to .app bundle, .cdmg disk image, file, URI, or application ID", required_unless_present_any = ["set_default", "bundle", "eject"])]
    target: Option<String>,

    #[arg(trailing_var_arg = true, allow_hyphen_values = true, help = "Arguments to pass")]
    args: Vec<String>,
}

fn confirm_quarantine_open(path: &Path, origin: Option<&str>) -> bool {
    if std::env::var("CONJUNCTION_QUARANTINE_ALLOW").as_deref() == Ok("1") {
        let _ = clear_quarantine(path);
        return true;
    }

    let origin_note = origin
        .map(|u| format!("\n\nSource: {}", u))
        .unwrap_or_default();
    let msg = format!(
        "'{}' is an application downloaded from the internet. Are you sure you want to open it?{}",
        path.file_name().and_then(|s| s.to_str()).unwrap_or("Bundle"),
        origin_note
    );

    if is_executable_available("kdialog") && std::env::var("DISPLAY").or_else(|_| std::env::var("WAYLAND_DISPLAY")).is_ok() {
        if let Ok(status) = Command::new("kdialog")
            .args(["--warningyesno", &msg, "--title", "Conjunction Security"])
            .status()
        {
            if status.success() {
                let _ = clear_quarantine(path);
                return true;
            }
            return false;
        }
    }

    if std::io::stdin().is_terminal() {
        eprint!("{} [y/N]: ", msg);
        let mut line = String::new();
        if std::io::stdin().read_line(&mut line).is_ok() {
            let ok = matches!(line.trim().to_ascii_lowercase().as_str(), "y" | "yes");
            if ok {
                let _ = clear_quarantine(path);
            }
            return ok;
        }
    }

    false
}

fn open_bundle(bundle_path: &Path, args: &[String], allow_quarantined: bool, wait: bool) -> ExitCode {
    let bundle = match Bundle::open(bundle_path) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("error: {}", e);
            return ExitCode::FAILURE;
        }
    };

    let mut effective_allow = allow_quarantined;
    if !effective_allow {
        if let Ok(q) = get_quarantine(bundle.path()) {
            if q.is_quarantined() {
                if confirm_quarantine_open(bundle.path(), q.origin_url.as_deref()) {
                    effective_allow = true;
                } else {
                    eprintln!(
                        "error: '{}' is quarantined (origin: {}); open cancelled",
                        bundle.path().display(),
                        q.origin_url.as_deref().unwrap_or("unknown")
                    );
                    return ExitCode::FAILURE;
                }
            }
        }
    }

    let plan = match build_bundle_launch_plan(&bundle, args, effective_allow) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("error: {}", e);
            return ExitCode::FAILURE;
        }
    };

    if wait {
        match execute_plan_captured(&plan) {
            Ok(res) => {
                print!("{}", res.stdout);
                eprint!("{}", res.stderr);
                if res.exit_code == 0 {
                    ExitCode::SUCCESS
                } else {
                    ExitCode::from(res.exit_code as u8)
                }
            }
            Err(e) => {
                eprintln!("error: {}", e);
                ExitCode::FAILURE
            }
        }
    } else {
        #[cfg(unix)]
        {
            match exec_plan_replace(&plan) {
                Ok(()) => ExitCode::SUCCESS,
                Err(e) => {
                    eprintln!("error: {}", e);
                    ExitCode::FAILURE
                }
            }
        }
        #[cfg(not(unix))]
        {
            match execute_plan_captured(&plan) {
                Ok(res) => ExitCode::from(res.exit_code as u8),
                Err(e) => {
                    eprintln!("error: {}", e);
                    ExitCode::FAILURE
                }
            }
        }
    }
}

fn open_cdmg(cdmg_path: &Path, allow_quarantined: bool, no_open: bool) -> ExitCode {
    if !allow_quarantined {
        if let Ok(q) = get_quarantine(cdmg_path) {
            if q.is_quarantined() && !confirm_quarantine_open(cdmg_path, q.origin_url.as_deref()) {
                eprintln!("error: disk image '{}' is quarantined; mount cancelled", cdmg_path.display());
                return ExitCode::FAILURE;
            }
        }
    }

    let rec = match mount_cdmg(cdmg_path, MountBackend::Auto) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("error: {}", e);
            return ExitCode::FAILURE;
        }
    };

    println!("Mounted '{}' at {}", rec.volume_name, rec.mount_point.display());
    if !no_open {
        open_directory_in_file_manager(&rec.mount_point);
    }
    ExitCode::SUCCESS
}

fn open_directory_in_file_manager(dir: &Path) {
    for fm in ["conjunction-files", "dolphin", "xdg-open"] {
        if is_executable_available(fm) {
            let _ = Command::new(fm).arg(dir).spawn();
            return;
        }
    }
}

fn is_cdmg_target(path: &Path) -> bool {
    if !path.is_file() {
        return false;
    }
    if path.extension().is_some_and(|e| e.eq_ignore_ascii_case("cdmg")) {
        return true;
    }
    detect_cdmg_filesystem(path).is_ok()
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    if let Some(pair) = cli.set_default {
        let mime = &pair[0];
        let desktop_id = &pair[1];
        let home = conjunction_core::get_user_home();
        if let Err(err) = conjunction_core::mime::set_default_handler(mime, desktop_id, &home) {
            eprintln!("error: {}", err);
            return ExitCode::FAILURE;
        }
        if mime == "x-scheme-handler/http" {
            let _ = conjunction_core::mime::set_default_handler("x-scheme-handler/https", desktop_id, &home);
        } else if mime == "x-scheme-handler/https" {
            let _ = conjunction_core::mime::set_default_handler("x-scheme-handler/http", desktop_id, &home);
        }
        println!("Set default handler for {} to {}", mime, desktop_id);
        return ExitCode::SUCCESS;
    }

    if let Some(ref eject_target) = cli.eject {
        return match eject_cdmg(eject_target) {
            Ok(()) => {
                println!("Ejected {}", eject_target.display());
                ExitCode::SUCCESS
            }
            Err(e) => {
                eprintln!("error: {}", e);
                ExitCode::FAILURE
            }
        };
    }

    if let Some(ref bundle_path) = cli.bundle {
        let mut bundle_args = Vec::new();
        if let Some(t) = cli.target {
            bundle_args.push(t);
        }
        bundle_args.extend(cli.args);
        return open_bundle(bundle_path, &bundle_args, cli.allow_quarantined, cli.wait);
    }

    let target = cli.target.unwrap_or_default();
    let target_path = Path::new(&target);

    if target_path.is_dir() && target.ends_with(".app") {
        return open_bundle(target_path, &cli.args, cli.allow_quarantined, cli.wait);
    }

    if is_cdmg_target(target_path) {
        return open_cdmg(target_path, cli.allow_quarantined, cli.no_open);
    }

    // Check if target resolves to an installed .app bundle in the registry so we exec directly
    let mut registry = AppRegistry::default_for_user();
    let _ = registry.scan_readonly();
    if let Ok(RegistryItem::Active(app)) = registry.inspect(&target) {
        if matches!(
            app.backend,
            AppBackend::Native | AppBackend::AppImage | AppBackend::Wine
        ) || (app.backend == AppBackend::Flatpak && app.bundle_path.extension().is_some_and(|e| e == "app"))
        {
            return open_bundle(&app.bundle_path, &cli.args, cli.allow_quarantined, cli.wait);
        }
    }

    let req = AppdRequest::Launch {
        target: target.clone(),
        args: cli.args.clone(),
    };

    match send_appd_request(&req) {
        Ok(resp) => {
            if resp.success {
                if let Some(data) = resp.data.as_ref() {
                    if let Some(stdout) = data.get("stdout").and_then(|s| s.as_str()) {
                        print!("{}", stdout);
                    }
                    if let Some(stderr) = data.get("stderr").and_then(|s| s.as_str()) {
                        eprint!("{}", stderr);
                    }
                }
                let code = resp
                    .data
                    .and_then(|d| d.get("exit_code").and_then(|c| c.as_i64()))
                    .unwrap_or(0);
                if code == 0 {
                    ExitCode::SUCCESS
                } else {
                    ExitCode::from(code as u8)
                }
            } else {
                eprintln!("error: {}", resp.error.unwrap_or_else(|| "launch failed".to_string()));
                ExitCode::FAILURE
            }
        }
        Err(_) => match registry.launch_captured(&target, &cli.args) {
            Ok(res) => {
                print!("{}", res.stdout);
                eprint!("{}", res.stderr);
                if res.exit_code == 0 {
                    ExitCode::SUCCESS
                } else {
                    ExitCode::from(res.exit_code as u8)
                }
            }
            Err(err) => {
                eprintln!("error: {}", err);
                ExitCode::FAILURE
            }
        },
    }
}
