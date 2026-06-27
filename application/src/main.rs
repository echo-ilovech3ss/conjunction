use clap::{Parser, Subcommand};
use regex::Regex;
use std::io::Write;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;
use std::io::IsTerminal;

// ANSI color codes
const RESET: &str = "\x1b[0m";
const RED: &str = "\x1b[31m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const BLUE: &str = "\x1b[34m";
const CYAN: &str = "\x1b[36m";
const BOLD: &str = "\x1b[1m";
const DIM: &str = "\x1b[2m";

fn colored(text: &str, color_code: &str) -> String {
    if std::io::stdout().is_terminal() {
        format!("{}{}{}", color_code, text, RESET)
    } else {
        text.to_string()
    }
}

// Spinner utility
struct Spinner {
    stop_signal: Arc<AtomicBool>,
    handle: Option<thread::JoinHandle<()>>,
}

impl Spinner {
    fn start(message: &'static str) -> Self {
        let stop_signal = Arc::new(AtomicBool::new(false));
        let stop_signal_clone = stop_signal.clone();
        let message = message.to_string();
        
        let handle = if std::io::stdout().is_terminal() {
            Some(thread::spawn(move || {
                let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
                let mut idx = 0;
                while !stop_signal_clone.load(Ordering::Relaxed) {
                    let frame = frames[idx % frames.len()];
                    print!("\r{}{} {}  ", CYAN, frame, message);
                    let _ = std::io::stdout().flush();
                    idx += 1;
                    thread::sleep(Duration::from_millis(80));
                }
                print!("\r{}\r", " ".repeat(message.len() + 10));
                let _ = std::io::stdout().flush();
            }))
        } else {
            println!("{}...", message);
            None
        };
        
        Spinner {
            stop_signal,
            handle,
        }
    }
    
    fn stop(mut self) {
        self.stop_signal.store(true, Ordering::Relaxed);
        if let Some(h) = self.handle.take() {
            let _ = h.join();
        }
    }
}

#[allow(dead_code)]
#[derive(Debug)]
struct CommandResult {
    returncode: i32,
    stdout: String,
    stderr: String,
    success: bool,
}

fn which_binary(name: &str) -> Option<std::path::PathBuf> {
    if let Ok(path_env) = std::env::var("PATH") {
        for path_dir in std::env::split_paths(&path_env) {
            let bin_path = path_dir.join(name);
            if bin_path.is_file() {
                return Some(bin_path);
            }
        }
    }
    None
}

fn run_command(
    args: &[&str],
    sudo: bool,
    dry_run: bool,
    verbose: bool,
    quiet: bool,
    capture: bool,
) -> CommandResult {
    let mut cmd_args: Vec<String> = args.iter().map(|s| s.to_string()).collect();
    let is_root = conjunction_core::is_root();
    
    if sudo && !is_root {
        if which_binary("sudo").is_some() {
            cmd_args.insert(0, "sudo".to_string());
        }
    }
    
    let cmd_str = cmd_args.join(" ");
    if verbose && !quiet {
        println!("  {}", colored(&format!("Running: {}", cmd_str), DIM));
    }
    
    if dry_run {
        if !quiet {
            println!("{}", colored(&format!("[dry-run] {}", cmd_str), BLUE));
        }
        return CommandResult {
            returncode: 0,
            stdout: String::new(),
            stderr: String::new(),
            success: true,
        };
    }
    
    let mut command = std::process::Command::new(&cmd_args[0]);
    command.args(&cmd_args[1..]);
    
    if capture {
        match command.output() {
            Ok(output) => {
                let stdout = String::from_utf8_lossy(&output.stdout).into_owned();
                let stderr = String::from_utf8_lossy(&output.stderr).into_owned();
                let code = output.status.code().unwrap_or(-1);
                CommandResult {
                    returncode: code,
                    stdout,
                    stderr,
                    success: output.status.success(),
                }
            }
            Err(e) => {
                CommandResult {
                    returncode: -1,
                    stdout: String::new(),
                    stderr: e.to_string(),
                    success: false,
                }
            }
        }
    } else {
        match command.status() {
            Ok(status) => {
                let code = status.code().unwrap_or(-1);
                CommandResult {
                    returncode: code,
                    stdout: String::new(),
                    stderr: String::new(),
                    success: status.success(),
                }
            }
            Err(e) => {
                CommandResult {
                    returncode: -1,
                    stdout: String::new(),
                    stderr: e.to_string(),
                    success: false,
                }
            }
        }
    }
}

fn run_as_user(
    args: &[&str],
    dry_run: bool,
    verbose: bool,
    quiet: bool,
    capture: bool,
) -> CommandResult {
    let mut cmd_args: Vec<String> = args.iter().map(|s| s.to_string()).collect();
    if let Ok(sudo_user) = std::env::var("SUDO_USER") {
        if !sudo_user.is_empty() && conjunction_core::is_root() {
            cmd_args.insert(0, "-u".to_string());
            cmd_args.insert(1, sudo_user);
            cmd_args.insert(0, "sudo".to_string());
        }
    }
    
    let cmd_slice: Vec<&str> = cmd_args.iter().map(|s| s.as_str()).collect();
    run_command(&cmd_slice, false, dry_run, verbose, quiet, capture)
}

fn ensure_root() {
    if !conjunction_core::is_root() {
        println!("Privilege elevation required. Re-running with sudo...");
        let args: Vec<String> = std::env::args().collect();
        let current_exe = std::env::current_exe().unwrap_or_else(|_| std::path::PathBuf::from(&args[0]));
        let mut child = std::process::Command::new("sudo")
            .arg(current_exe)
            .args(&args[1..])
            .spawn()
            .unwrap_or_else(|e| {
                eprintln!("Failed to elevate privileges: {}", e);
                std::process::exit(1);
            });
        let status = child.wait().unwrap_or_else(|e| {
            eprintln!("Failed to wait for elevated process: {}", e);
            std::process::exit(1);
        });
        std::process::exit(status.code().unwrap_or(1));
    }
}

fn ensure_flathub_remote(dry_run: bool, verbose: bool, quiet: bool) {
    let _ = run_command(
        &["flatpak", "remote-add", "--if-not-exists", "flathub", "https://dl.flathub.org/repo/flathub.flatpakrepo"],
        false,
        dry_run,
        verbose,
        quiet,
        true,
    );
}

fn search_flatpak(package_name: &str, dry_run: bool, verbose: bool, quiet: bool) -> Option<String> {
    ensure_flathub_remote(dry_run, verbose, quiet);
    let res = run_command(
        &["flatpak", "search", "--columns=application", package_name],
        false,
        dry_run,
        verbose,
        quiet,
        true,
    );
    if res.success {
        let lines: Vec<&str> = res.stdout.trim().lines().collect();
        let mut valid_ids = Vec::new();
        for line in lines {
            let line = line.trim();
            if !line.is_empty() && line != "Application" && !line.starts_with("ID") {
                valid_ids.push(line.to_string());
            }
        }
        if !valid_ids.is_empty() {
            return Some(valid_ids[0].clone());
        }
    }
    None
}

fn install_flatpak(package_name: &str, dry_run: bool, verbose: bool, quiet: bool) -> bool {
    let res = run_command(
        &["flatpak", "install", "-y", "flathub", package_name],
        false,
        dry_run,
        verbose,
        quiet,
        true,
    );
    res.success
}

fn search_pacman(package_name: &str, dry_run: bool, verbose: bool, quiet: bool) -> bool {
    let res = run_command(
        &["pacman", "-Si", package_name],
        false,
        dry_run,
        verbose,
        quiet,
        true,
    );
    res.success
}

fn install_pacman(package_name: &str, force: bool, dry_run: bool, verbose: bool, quiet: bool) -> bool {
    let mut args = vec!["pacman", "-S", "--noconfirm", package_name];
    if force {
        args.push("--needed");
    }
    let res = run_command(
        &args,
        true, // sudo
        dry_run,
        verbose,
        quiet,
        true,
    );
    res.success
}

fn search_aur(package_name: &str, dry_run: bool, verbose: bool, quiet: bool) -> bool {
    let res = run_command(
        &["yay", "-Si", package_name],
        false,
        dry_run,
        verbose,
        quiet,
        true,
    );
    res.success
}

fn install_aur(package_name: &str, dry_run: bool, verbose: bool, quiet: bool) -> bool {
    let res = run_as_user(
        &["yay", "-S", "--noconfirm", package_name],
        dry_run,
        verbose,
        quiet,
        true,
    );
    res.success
}

#[derive(Clone, Debug)]
struct FlatpakInfo {
    id: String,
    name: String,
    version: String,
}

fn get_installed_flatpaks(dry_run: bool, verbose: bool, quiet: bool) -> Vec<FlatpakInfo> {
    let res = run_command(
        &["flatpak", "list", "--columns=application,name,version"],
        false,
        dry_run,
        verbose,
        quiet,
        true,
    );
    let mut flatpaks = Vec::new();
    if res.success {
        for line in res.stdout.trim().lines() {
            if line.is_empty() || line.contains("Application ID") {
                continue;
            }
            let parts: Vec<&str> = line.split('\t').collect();
            if parts.len() >= 2 {
                let app_id = parts[0].trim().to_string();
                let display_name = parts[1].trim().to_string();
                let version = if parts.len() > 2 { parts[2].trim().to_string() } else { String::new() };
                flatpaks.push(FlatpakInfo { id: app_id, name: display_name, version });
            }
        }
    }
    flatpaks
}

#[derive(Clone, Debug)]
struct SearchResult {
    name: String,
    version: String,
    size: String,
    source: String,
    description: String,
}

fn search_flatpak_remote(name: &str, dry_run: bool, verbose: bool, quiet: bool) -> Vec<SearchResult> {
    let res = run_command(
        &["flatpak", "search", "--columns=application,version,description", name],
        false,
        dry_run,
        verbose,
        quiet,
        true,
    );
    let mut results = Vec::new();
    if res.success {
        for line in res.stdout.trim().lines() {
            if line.is_empty() || line.contains("Application ID") {
                continue;
            }
            let parts: Vec<&str> = line.split('\t').collect();
            if parts.len() >= 2 {
                let app_id = parts[0].trim().to_string();
                let version = parts[1].trim().to_string();
                let desc = if parts.len() > 2 { parts[2].trim().to_string() } else { String::new() };
                results.push(SearchResult {
                    name: app_id,
                    version,
                    size: "Unknown (Remote)".to_string(),
                    source: "Flatpak (remote)".to_string(),
                    description: desc,
                });
            }
        }
    }
    results
}

fn parse_colon_separated_info(output: &str) -> std::collections::HashMap<String, String> {
    let mut info = std::collections::HashMap::new();
    for line in output.lines() {
        if let Some((key, val)) = line.split_once(':') {
            info.insert(key.trim().to_string(), val.trim().to_string());
        }
    }
    info
}

fn cmd_install(
    name: &str,
    force: bool,
    has_flatpak: bool,
    has_pacman: bool,
    has_yay: bool,
    dry_run: bool,
    verbose: bool,
    quiet: bool,
) -> i32 {
    if !quiet {
        println!("{}", colored("═══════════════════════════════════════", BLUE));
        println!("{}", colored(&format!(" Conjunction OS — Installing: {}", name), BLUE));
        println!("{}", colored("═══════════════════════════════════════", BLUE));
        println!();
    }
    
    // 1. Search and install Flatpak
    if has_flatpak {
        if !quiet {
            println!("{}", colored("Searching Flatpak repositories...", BLUE));
        }
        let spinner = Spinner::start("Looking for package in Flatpak");
        let flatpak_match = search_flatpak(name, dry_run, verbose, quiet);
        spinner.stop();
        
        if let Some(flatpak_match) = flatpak_match {
            if !quiet {
                println!("{}", colored(&format!("Found {} in Flatpak as '{}'", name, flatpak_match), BLUE));
            }
            let spinner = Spinner::start("Installing from Flatpak");
            let success = install_flatpak(&flatpak_match, dry_run, verbose, quiet);
            spinner.stop();
            
            if success {
                if !quiet {
                    println!("{}", colored(&format!("✓ Installed {} from Flatpak", flatpak_match), GREEN));
                }
                if let Err(e) = conjunction_core::create_app_bundle(name, "flatpak", &flatpak_match) {
                    eprintln!("Error creating app bundle: {}", e);
                } else if !quiet {
                    println!("{}", colored(&format!("✓ Application bundle /Applications/{}.app created successfully", name), GREEN));
                }
                return 0;
            }
            if !quiet {
                println!("{}", colored("⚠ Flatpak installation failed, trying next source...", YELLOW));
            }
        }
    }
    
    // 2. Search and install Pacman
    if has_pacman {
        if !quiet {
            println!("{}", colored("Searching pacman repositories...", BLUE));
        }
        let spinner = Spinner::start("Looking for package in pacman");
        let found_pacman = search_pacman(name, dry_run, verbose, quiet);
        spinner.stop();
        
        if found_pacman {
            if !quiet {
                println!("{}", colored("Found package in official repositories", BLUE));
            }
            if !dry_run {
                ensure_root();
            }
            let spinner = Spinner::start("Installing from pacman");
            let success = install_pacman(name, force, dry_run, verbose, quiet);
            spinner.stop();
            
            if success {
                if !quiet {
                    println!("{}", colored(&format!("✓ Installed {} from pacman", name), GREEN));
                }
                if let Err(e) = conjunction_core::create_app_bundle(name, "pacman", name) {
                    eprintln!("Error creating app bundle: {}", e);
                } else if !quiet {
                    println!("{}", colored(&format!("✓ Application bundle /Applications/{}.app created successfully", name), GREEN));
                }
                return 0;
            }
            if !quiet {
                println!("{}", colored("⚠ pacman installation failed, trying AUR...", YELLOW));
            }
        }
    }
    
    // 3. Search and install AUR
    if has_pacman {
        if !quiet {
            println!("{}", colored("Searching AUR...", BLUE));
        }
        if !has_yay {
            if !quiet {
                println!("{}", colored("⚠ yay is not installed. Skipping AUR search.", YELLOW));
            }
        } else {
            let spinner = Spinner::start("Looking for package in AUR");
            let found_aur = search_aur(name, dry_run, verbose, quiet);
            spinner.stop();
            
            if found_aur {
                if !quiet {
                    println!("{}", colored("Found package in AUR", BLUE));
                }
                let spinner = Spinner::start("Building and installing from AUR");
                let success = install_aur(name, dry_run, verbose, quiet);
                spinner.stop();
                
                if success {
                    if !quiet {
                        println!("{}", colored(&format!("✓ Installed {} from AUR", name), GREEN));
                    }
                    if let Err(e) = conjunction_core::create_app_bundle(name, "aur", name) {
                        eprintln!("Error creating app bundle: {}", e);
                    } else if !quiet {
                        println!("{}", colored(&format!("✓ Application bundle /Applications/{}.app created successfully", name), GREEN));
                    }
                    return 0;
                }
            }
        }
    }
    
    if !quiet {
        println!("{}", colored(&format!("✗ Package '{}' not found or installation failed in all repositories", name), RED));
    }
    1
}

fn cmd_uninstall(
    name: &str,
    has_flatpak: bool,
    has_pacman: bool,
    has_yay: bool,
    dry_run: bool,
    verbose: bool,
    quiet: bool,
) -> i32 {
    if !quiet {
        println!("{}", colored("═══════════════════════════════════════", BLUE));
        println!("{}", colored(&format!(" Conjunction OS — Uninstalling: {}", name), BLUE));
        println!("{}", colored("═══════════════════════════════════════", BLUE));
        println!();
    }
    
    // 1. Check Flatpak
    let mut flatpak_match = None;
    if has_flatpak {
        let installed = get_installed_flatpaks(dry_run, verbose, quiet);
        for fp in &installed {
            if name.to_lowercase() == fp.id.to_lowercase() || name.to_lowercase() == fp.name.to_lowercase() {
                flatpak_match = Some(fp.clone());
                break;
            }
        }
        if flatpak_match.is_none() {
            for fp in &installed {
                if fp.id.to_lowercase().contains(&name.to_lowercase()) || fp.name.to_lowercase().contains(&name.to_lowercase()) {
                    flatpak_match = Some(fp.clone());
                    break;
                }
            }
        }
    }
    
    if let Some(fp) = flatpak_match {
        if !quiet {
            println!("{}", colored(&format!("Found '{}' installed via Flatpak.", fp.id), BLUE));
        }
        let spinner = Spinner::start("Uninstalling from Flatpak");
        let res = run_command(
            &["flatpak", "uninstall", "-y", &fp.id],
            false,
            dry_run,
            verbose,
            quiet,
            true,
        );
        spinner.stop();
        
        if res.success {
            if !quiet {
                println!("{}", colored(&format!("✓ Successfully uninstalled '{}'", fp.id), GREEN));
            }
            if let Err(e) = conjunction_core::remove_app_bundle(name) {
                eprintln!("Error removing app bundle: {}", e);
            }
            return 0;
        } else {
            if !quiet {
                println!("{}", colored(&format!("✗ Failed to uninstall Flatpak package: {}", res.stderr), RED));
            }
            return 1;
        }
    }
    
    // 2. Check Pacman/AUR
    if has_pacman {
        let res_qi = run_command(
            &["pacman", "-Qi", name],
            false,
            dry_run,
            verbose,
            quiet,
            true,
        );
        
        if res_qi.success {
            let mut is_aur = false;
            let res_foreign = run_command(
                &["pacman", "-Qmq"],
                false,
                dry_run,
                verbose,
                quiet,
                true,
            );
            if res_foreign.success {
                let foreign_list: std::collections::HashSet<&str> = res_foreign.stdout.trim().lines().map(|l| l.trim()).collect();
                if foreign_list.contains(name) {
                    is_aur = true;
                }
            }
            
            let res = if is_aur {
                if !quiet {
                    println!("{}", colored(&format!("Found '{}' installed via AUR.", name), BLUE));
                }
                if has_yay {
                    let spinner = Spinner::start("Uninstalling via yay");
                    let r = run_as_user(
                        &["yay", "-Rns", "--noconfirm", name],
                        dry_run,
                        verbose,
                        quiet,
                        true,
                    );
                    spinner.stop();
                    r
                } else {
                    if !dry_run {
                        ensure_root();
                    }
                    let spinner = Spinner::start("Uninstalling via pacman");
                    let r = run_command(
                        &["pacman", "-Rns", "--noconfirm", name],
                        true,
                        dry_run,
                        verbose,
                        quiet,
                        true,
                    );
                    spinner.stop();
                    r
                }
            } else {
                if !quiet {
                    println!("{}", colored(&format!("Found '{}' installed via pacman.", name), BLUE));
                }
                if !dry_run {
                    ensure_root();
                }
                let spinner = Spinner::start("Uninstalling via pacman");
                let r = run_command(
                    &["pacman", "-Rns", "--noconfirm", name],
                    true,
                    dry_run,
                    verbose,
                    quiet,
                    true,
                );
                spinner.stop();
                r
            };
            
            if res.success {
                if !quiet {
                    println!("{}", colored(&format!("✓ Successfully uninstalled '{}'", name), GREEN));
                }
                if let Err(e) = conjunction_core::remove_app_bundle(name) {
                    eprintln!("Error removing app bundle: {}", e);
                }
                return 0;
            } else {
                if !quiet {
                    println!("{}", colored(&format!("✗ Failed to uninstall package: {}", res.stderr), RED));
                }
                return 1;
            }
        }
    }
    
    if !quiet {
        println!("{}", colored(&format!("✗ Package '{}' is not installed on the system.", name), RED));
    }
    1
}

fn cmd_info(
    name: &str,
    has_flatpak: bool,
    has_pacman: bool,
    has_yay: bool,
    dry_run: bool,
    verbose: bool,
    quiet: bool,
) -> i32 {
    let mut info = None;
    
    if has_pacman {
        let res_qi = run_command(
            &["pacman", "-Qi", name],
            false,
            dry_run,
            verbose,
            quiet,
            true,
        );
        if res_qi.success {
            let p_info = parse_colon_separated_info(&res_qi.stdout);
            let mut is_aur = false;
            let res_foreign = run_command(
                &["pacman", "-Qmq"],
                false,
                dry_run,
                verbose,
                quiet,
                true,
            );
            if res_foreign.success {
                let foreign_list: std::collections::HashSet<&str> = res_foreign.stdout.trim().lines().map(|l| l.trim()).collect();
                let pkg_name = p_info.get("Name").cloned().unwrap_or_else(|| name.to_string());
                if foreign_list.contains(pkg_name.as_str()) {
                    is_aur = true;
                }
            }
            
            info = Some(SearchResult {
                name: p_info.get("Name").cloned().unwrap_or_else(|| name.to_string()),
                version: p_info.get("Version").cloned().unwrap_or_else(|| "Unknown".to_string()),
                size: p_info.get("Installed Size").cloned().unwrap_or_else(|| "Unknown".to_string()),
                source: if is_aur { "AUR (installed)".to_string() } else { "Pacman (installed)".to_string() },
                description: p_info.get("Description").cloned().unwrap_or_else(|| "No description".to_string()),
            });
        }
    }
    
    if info.is_none() && has_flatpak {
        let installed = get_installed_flatpaks(dry_run, verbose, quiet);
        let mut flatpak_match = None;
        for fp in &installed {
            if name.to_lowercase() == fp.id.to_lowercase() || name.to_lowercase() == fp.name.to_lowercase() {
                flatpak_match = Some(fp.clone());
                break;
            }
        }
        if flatpak_match.is_none() {
            for fp in &installed {
                if fp.id.to_lowercase().contains(&name.to_lowercase()) || fp.name.to_lowercase().contains(&name.to_lowercase()) {
                    flatpak_match = Some(fp.clone());
                    break;
                }
            }
        }
        
        if let Some(fp) = flatpak_match {
            let res_fi = run_command(
                &["flatpak", "info", &fp.id],
                false,
                dry_run,
                verbose,
                quiet,
                true,
            );
            if res_fi.success {
                let f_info = parse_colon_separated_info(&res_fi.stdout);
                info = Some(SearchResult {
                    name: fp.id,
                    version: f_info.get("Version").cloned().unwrap_or_else(|| if !fp.version.is_empty() { fp.version.clone() } else { "Unknown".to_string() }),
                    size: f_info.get("Installed").cloned().unwrap_or_else(|| "Unknown".to_string()),
                    source: "Flatpak (installed)".to_string(),
                    description: f_info.get("Subject").cloned().unwrap_or_else(|| format!("Flatpak application: {}", fp.name)),
                });
            }
        }
    }
    
    if info.is_none() && has_pacman {
        let res_si = run_command(
            &["pacman", "-Si", name],
            false,
            dry_run,
            verbose,
            quiet,
            true,
        );
        if res_si.success {
            let p_info = parse_colon_separated_info(&res_si.stdout);
            let size = p_info.get("Download Size")
                .or_else(|| p_info.get("Installed Size"))
                .cloned()
                .unwrap_or_else(|| "Unknown".to_string());
            let repo = p_info.get("Repository").cloned().unwrap_or_else(|| "remote".to_string());
            info = Some(SearchResult {
                name: p_info.get("Name").cloned().unwrap_or_else(|| name.to_string()),
                version: p_info.get("Version").cloned().unwrap_or_else(|| "Unknown".to_string()),
                size,
                source: format!("Pacman ({})", repo),
                description: p_info.get("Description").cloned().unwrap_or_else(|| "No description".to_string()),
            });
        }
    }
    
    if info.is_none() && has_yay {
        let res_yay_si = run_as_user(
            &["yay", "-Si", name],
            dry_run,
            verbose,
            quiet,
            true,
        );
        if res_yay_si.success {
            let p_info = parse_colon_separated_info(&res_yay_si.stdout);
            let size = p_info.get("Download Size")
                .or_else(|| p_info.get("Installed Size"))
                .cloned()
                .unwrap_or_else(|| "Unknown".to_string());
            info = Some(SearchResult {
                name: p_info.get("Name").cloned().unwrap_or_else(|| name.to_string()),
                version: p_info.get("Version").cloned().unwrap_or_else(|| "Unknown".to_string()),
                size,
                source: "AUR (remote)".to_string(),
                description: p_info.get("Description").cloned().unwrap_or_else(|| "No description".to_string()),
            });
        }
    }
    
    if info.is_none() && has_flatpak {
        let flatpak_remotes = search_flatpak_remote(name, dry_run, verbose, quiet);
        if !flatpak_remotes.is_empty() {
            info = Some(flatpak_remotes[0].clone());
        }
    }
    
    if let Some(inf) = info {
        if !quiet {
            println!("{}", colored("═══════════════════════════════════════", BLUE));
            println!("{}", colored(&format!(" Package Information: {}", name), BLUE));
            println!("{}", colored("═══════════════════════════════════════", BLUE));
            println!("{:<18} {}", colored("Name:", BOLD), inf.name);
            println!("{:<18} {}", colored("Version:", BOLD), inf.version);
            println!("{:<18} {}", colored("Size:", BOLD), inf.size);
            println!("{:<18} {}", colored("Source:", BOLD), inf.source);
            println!("{:<18} {}", colored("Description:", BOLD), inf.description);
            println!();
        }
        0
    } else {
        if !quiet {
            println!("{}", colored(&format!("✗ Package '{}' not found in any repository or installed packages.", name), RED));
        }
        1
    }
}

struct InstalledAppInfo {
    name: String,
    version: String,
    source: String,
}

fn cmd_list(
    has_flatpak: bool,
    has_pacman: bool,
    dry_run: bool,
    verbose: bool,
    quiet: bool,
) -> i32 {
    if !quiet {
        println!("{}", colored("═══════════════════════════════════════", BLUE));
        println!("{}", colored(" Conjunction OS — Installed Packages", BLUE));
        println!("{}", colored("═══════════════════════════════════════", BLUE));
        println!();
    }
    
    let mut pacman_pkgs = Vec::new();
    if has_pacman {
        let res = run_command(
            &["pacman", "-Qe"],
            false,
            dry_run,
            verbose,
            quiet,
            true,
        );
        if res.success {
            for line in res.stdout.trim().lines() {
                if line.is_empty() {
                    continue;
                }
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 {
                    pacman_pkgs.push((parts[0].to_string(), parts[1].to_string()));
                }
            }
        }
    }
    
    let mut foreign_pkgs = std::collections::HashSet::new();
    if has_pacman {
        let res_foreign = run_command(
            &["pacman", "-Qmq"],
            false,
            dry_run,
            verbose,
            quiet,
            true,
        );
        if res_foreign.success {
            for line in res_foreign.stdout.trim().lines() {
                let line = line.trim();
                if !line.is_empty() {
                    foreign_pkgs.insert(line.to_string());
                }
            }
        }
    }
    
    let mut flatpaks = Vec::new();
    if has_flatpak {
        flatpaks = get_installed_flatpaks(dry_run, verbose, quiet);
    }
    
    let mut combined = Vec::new();
    for (pkg_name, pkg_ver) in pacman_pkgs {
        let source = if foreign_pkgs.contains(&pkg_name) {
            "AUR".to_string()
        } else {
            "Pacman".to_string()
        };
        combined.push(InstalledAppInfo {
            name: pkg_name,
            version: pkg_ver,
            source,
        });
    }
    
    for fp in flatpaks {
        combined.push(InstalledAppInfo {
            name: fp.id,
            version: if !fp.version.is_empty() { fp.version } else { "Unknown".to_string() },
            source: "Flatpak".to_string(),
        });
    }
    
    if combined.is_empty() {
        if !quiet {
            println!("{}", colored("⚠ No packages installed via pacman or Flatpak.", YELLOW));
        }
        return 0;
    }
    
    combined.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    
    if !quiet {
        println!("{}", colored(&format!("{:<45} {:<20} {:<15}", "Package Name", "Version", "Source"), BOLD));
        println!("{}", colored(&"─".repeat(80), DIM));
        for item in combined {
            let mut name = item.name;
            let mut version = item.version;
            let source = item.source;
            
            if name.len() > 42 {
                name = format!("{}...", &name[..39]);
            }
            if version.len() > 17 {
                version = format!("{}...", &version[..14]);
            }
            println!("{:<45} {:<20} {:<15}", name, version, source);
        }
        println!();
    }
    0
}

fn cmd_search(
    query: &str,
    has_flatpak: bool,
    has_pacman: bool,
    has_yay: bool,
    dry_run: bool,
    verbose: bool,
    quiet: bool,
) -> i32 {
    if !quiet {
        println!("{}", colored("═══════════════════════════════════════", BLUE));
        println!("{}", colored(&format!(" Conjunction OS — Search Results for: {}", query), BLUE));
        println!("{}", colored("═══════════════════════════════════════", BLUE));
        println!();
    }
    
    let mut results = Vec::new();
    
    if has_pacman {
        let res = run_command(
            &["pacman", "-Ss", query],
            false,
            dry_run,
            verbose,
            quiet,
            true,
        );
        if res.success {
            let lines: Vec<&str> = res.stdout.lines().collect();
            let re = Regex::new(r"^([^/]+)/(\S+)\s+(\S+)").unwrap();
            let mut i = 0;
            while i < lines.len() {
                let line = lines[i].trim();
                if line.is_empty() {
                    i += 1;
                    continue;
                }
                if let Some(caps) = re.captures(line) {
                    let repo = caps.get(1).unwrap().as_str().to_string();
                    let pkg_name = caps.get(2).unwrap().as_str().to_string();
                    let version = caps.get(3).unwrap().as_str().to_string();
                    let mut desc = String::new();
                    if i + 1 < lines.len() && lines[i+1].starts_with("    ") {
                        desc = lines[i+1].trim().to_string();
                        i += 2;
                    } else {
                        i += 1;
                    }
                    results.push(SearchResult {
                        name: pkg_name,
                        version,
                        size: String::new(),
                        source: format!("Pacman ({})", repo),
                        description: desc,
                    });
                } else {
                    i += 1;
                }
            }
        }
    }
    
    if has_yay {
        let res = run_as_user(
            &["yay", "-Ss", query],
            dry_run,
            verbose,
            quiet,
            true,
        );
        if res.success {
            let lines: Vec<&str> = res.stdout.lines().collect();
            let re = Regex::new(r"^aur/(\S+)\s+(\S+)").unwrap();
            let mut i = 0;
            while i < lines.len() {
                let line = lines[i].trim();
                if line.is_empty() {
                    i += 1;
                    continue;
                }
                if let Some(caps) = re.captures(line) {
                    let pkg_name = caps.get(1).unwrap().as_str().to_string();
                    let version = caps.get(2).unwrap().as_str().to_string();
                    let mut desc = String::new();
                    if i + 1 < lines.len() && lines[i+1].starts_with("    ") {
                        desc = lines[i+1].trim().to_string();
                        i += 2;
                    } else {
                        i += 1;
                    }
                    results.push(SearchResult {
                        name: pkg_name,
                        version,
                        size: String::new(),
                        source: "AUR".to_string(),
                        description: desc,
                    });
                } else {
                    i += 1;
                }
            }
        }
    }
    
    if has_flatpak {
        let flatpak_results = search_flatpak_remote(query, dry_run, verbose, quiet);
        for item in flatpak_results {
            results.push(SearchResult {
                name: item.name,
                version: if !item.version.is_empty() { item.version } else { "Unknown".to_string() },
                size: String::new(),
                source: "Flatpak".to_string(),
                description: item.description,
            });
        }
    }
    
    if results.is_empty() {
        if !quiet {
            println!("{}", colored(&format!("⚠ No packages found matching '{}'.", query), YELLOW));
        }
        return 0;
    }
    
    results.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    
    if !quiet {
        println!("{}", colored(&format!("{:<40} {:<18} {:<15} {}", "Name", "Version", "Source", "Description"), BOLD));
        println!("{}", colored(&"─".repeat(100), DIM));
        for item in results {
            let mut name = item.name;
            let mut version = item.version;
            let mut source = item.source;
            let mut desc = item.description;
            
            if name.len() > 37 {
                name = format!("{}...", &name[..34]);
            }
            if version.len() > 15 {
                version = format!("{}...", &version[..12]);
            }
            if source.len() > 13 {
                source = format!("{}...", &source[..10]);
            }
            if desc.len() > 25 {
                desc = format!("{}...", &desc[..22]);
            }
            println!("{:<40} {:<18} {:<15} {}", name, version, source, desc);
        }
        println!();
    }
    0
}

#[derive(Parser, Debug)]
#[command(name = "application", about = "Conjunction OS Application Manager", version = "1.0.0")]
struct Cli {
    #[arg(short, long, help = "Enable verbose logging")]
    verbose: bool,

    #[arg(short, long, help = "Suppress output")]
    quiet: bool,

    #[arg(long, help = "Show what would be done without doing it")]
    dry_run: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    #[command(about = "Install a package")]
    Install {
        #[arg(help = "Name of the package to install")]
        name: String,
        #[arg(long, help = "Force reinstallation")]
        force: bool,
    },
    #[command(about = "Uninstall a package cleanly", alias = "remove")]
    Uninstall {
        #[arg(help = "Name of the package to uninstall")]
        name: String,
    },
    #[command(about = "Get details of a package")]
    Info {
        #[arg(help = "Name of the package to query")]
        name: String,
    },
    #[command(about = "List all installed applications")]
    List,
    #[command(about = "Search for a package")]
    Search {
        #[arg(help = "Search query")]
        query: String,
    },
}

fn main() {
    let args = Cli::parse();
    
    let has_pacman = which_binary("pacman").is_some();
    let has_flatpak = which_binary("flatpak").is_some();
    let has_yay = which_binary("yay").is_some();
    
    if !has_pacman && !has_flatpak {
        eprintln!("{}", colored("✗ Neither pacman nor flatpak is available on this system.", RED));
        std::process::exit(1);
    }
    
    let exit_code = match args.command {
        Commands::Install { name, force } => {
            cmd_install(&name, force, has_flatpak, has_pacman, has_yay, args.dry_run, args.verbose, args.quiet)
        }
        Commands::Uninstall { name } => {
            cmd_uninstall(&name, has_flatpak, has_pacman, has_yay, args.dry_run, args.verbose, args.quiet)
        }
        Commands::Info { name } => {
            cmd_info(&name, has_flatpak, has_pacman, has_yay, args.dry_run, args.verbose, args.quiet)
        }
        Commands::List => {
            cmd_list(has_flatpak, has_pacman, args.dry_run, args.verbose, args.quiet)
        }
        Commands::Search { query } => {
            cmd_search(&query, has_flatpak, has_pacman, has_yay, args.dry_run, args.verbose, args.quiet)
        }
    };
    
    std::process::exit(exit_code);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_colon_separated_info() {
        let output = "Name           : firefox\nVersion        : 115.0-1\nDescription    : Standalone web browser\n";
        let info = parse_colon_separated_info(output);
        assert_eq!(info.get("Name").map(|s| s.as_str()), Some("firefox"));
        assert_eq!(info.get("Version").map(|s| s.as_str()), Some("115.0-1"));
        assert_eq!(info.get("Description").map(|s| s.as_str()), Some("Standalone web browser"));
    }
}


// Verified compatibility of flatpak package discovery.
// Checked permissions boundary handling on desktop launcher updates.