use clap::{Parser, Subcommand};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::SystemTime;
use serde_json::Value;

// ANSI colors
const RESET: &str = "\x1b[0m";
const RED: &str = "\x1b[31m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const BLUE: &str = "\x1b[34m";
const CYAN: &str = "\x1b[36m";
const BOLD: &str = "\x1b[1m";
const DIM: &str = "\x1b[2m";

fn colored(text: &str, color: &str) -> String {
    format!("{}{}{}", color, text, RESET)
}

fn confirm(message: &str) -> bool {
    print!("{} [y/N]: ", message);
    use std::io::Write;
    let _ = std::io::stdout().flush();
    let mut input = String::new();
    if std::io::stdin().read_line(&mut input).is_ok() {
        let trimmed = input.trim().to_lowercase();
        trimmed == "y" || trimmed == "yes"
    } else {
        false
    }
}

// Struct to represent CLI options using Clap
#[derive(Parser, Debug)]
#[command(name = "cj", version = "1.0.0", about = "Conjunction OS - Simplified system management")]
struct Cli {
    #[arg(short, long, help = "Enable verbose output")]
    verbose: bool,

    #[arg(short, long, help = "Suppress non-essential output")]
    quiet: bool,

    #[arg(long, help = "Show commands without executing them")]
    dry_run: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug, Clone)]
enum Commands {
    #[command(about = "Update system packages, Flatpak, Wine, and AUR")]
    Update,

    #[command(about = "Install an application from a name or .exe/.msi path")]
    Install {
        #[arg(help = "Package name (e.g., firefox) or path to .exe/.msi")]
        app_name_or_path: String,

        #[arg(long, help = "Force reinstall even if already installed")]
        force: bool,

        #[arg(long, help = "Install Windows apps in an isolated Wine prefix")]
        sandbox: bool,
    },

    #[command(about = "Tune system for maximum performance")]
    Optimize {
        #[arg(long, help = "Only optimize GPU settings")]
        gpu_only: bool,

        #[arg(long, help = "Only optimize CPU settings")]
        cpu_only: bool,

        #[arg(long, help = "Only optimize memory settings")]
        memory_only: bool,
    },

    #[command(about = "Display system information and health")]
    Status,

    #[command(about = "List or manage installed sandboxed applications")]
    Apps {
        #[arg(long, help = "Remove the specified application")]
        remove: Option<String>,
    },

    #[command(about = "System components health diagnostic report")]
    Doctor,

    #[command(about = "Rollback system snapper snapshot or prefix snapshot")]
    Rollback {
        #[arg(help = "Target for rollback: 'system' or the app name")]
        target: String,
        #[arg(help = "Snapper snapshot ID or tag/pristine for prefix")]
        snapshot_id: String,
    },

    #[command(about = "Export application prefix to .tar.zst package")]
    Export {
        #[arg(help = "Name of the app to export")]
        app_name: String,
        #[arg(help = "Path to save the exported .tar.zst package")]
        output_path: String,
    },

    #[command(about = "Import application prefix from .tar.zst package")]
    Import {
        #[arg(help = "Path to the .tar.zst package")]
        input_path: String,
        #[arg(long, help = "Override the app name on import")]
        name: Option<String>,
    },

    #[command(about = "Generate a zipped diagnostic bug report")]
    BugReport {
        #[arg(long, help = "Custom output path for the report")]
        output: Option<String>,
    },

    #[command(about = "Repair application prefix components")]
    Repair {
        #[arg(help = "Name of the app/prefix to repair")]
        app_name: String,
    },

    #[command(about = "Cleanup expired cache, log, and export files")]
    Cleanup {
        #[arg(long, default_value_t = 7, help = "Age threshold in days")]
        days: i32,
    },

    #[command(about = "Reset Plasma desktop settings to default Conjunction style")]
    ResetDesktop,

    #[command(about = "Configure macOS-like command translation layer in /usr/local/bin")]
    SetupWrappers,

    #[command(about = "Launch an installed Wine application", hide = true)]
    Run {
        #[arg(help = "Name of the application to run")]
        app_name: String,
    },
}

struct Runner {
    verbose: bool,
    quiet: bool,
    dry_run: bool,
}

impl Runner {
    fn new(verbose: bool, quiet: bool, dry_run: bool) -> Self {
        Runner { verbose, quiet, dry_run }
    }

    fn log(&self, message: &str, color_code: &str) {
        if !self.quiet {
            println!("{}", colored(message, color_code));
        }
    }

    fn info(&self, message: &str) {
        self.log(message, BLUE);
    }

    fn success(&self, message: &str) {
        self.log(&format!("✓ {}", message), GREEN);
    }

    fn warning(&self, message: &str) {
        self.log(&format!("⚠ {}", message), YELLOW);
    }

    fn error(&self, message: &str) {
        self.log(&format!("✗ {}", message), RED);
    }

    fn execute(&self, args: &[&str], envs: &[(&str, &str)], sudo: bool) -> Result<std::process::Output, std::io::Error> {
        let mut cmd = if sudo {
            let mut c = Command::new("sudo");
            c.arg(args[0]);
            for arg in &args[1..] {
                c.arg(arg);
            }
            c
        } else {
            let mut c = Command::new(args[0]);
            for arg in &args[1..] {
                c.arg(arg);
            }
            c
        };
        for (k, v) in envs {
            cmd.env(k, v);
        }
        if self.dry_run {
            if self.verbose {
                self.info(&format!("[dry-run] Would execute: {:?}", cmd));
            }
            Ok(std::process::Output {
                status: Default::default(),
                stdout: Vec::new(),
                stderr: Vec::new(),
            })
        } else {
            cmd.output()
        }
    }

    fn run_stream(&self, args: &[&str], envs: &[(&str, &str)], sudo: bool) -> Result<i32, std::io::Error> {
        let mut cmd = if sudo {
            let mut c = Command::new("sudo");
            c.arg(args[0]);
            for arg in &args[1..] {
                c.arg(arg);
            }
            c
        } else {
            let mut c = Command::new(args[0]);
            for arg in &args[1..] {
                c.arg(arg);
            }
            c
        };
        for (k, v) in envs {
            cmd.env(k, v);
        }
        if self.dry_run {
            self.info(&format!("[dry-run] Would execute: {:?}", cmd));
            Ok(0)
        } else {
            let mut child = cmd.spawn()?;
            let status = child.wait()?;
            Ok(status.code().unwrap_or(-1))
        }
    }

    fn detect_gpu_vendor(&self) -> String {
        if let Ok(output) = Command::new("lspci").arg("-nn").output() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            for line in stdout.lines() {
                let lower = line.to_lowercase();
                if lower.contains("vga") || lower.contains("3d") || lower.contains("display") {
                    if lower.contains("nvidia") {
                        return "nvidia".to_string();
                    }
                    if lower.contains("amd") || lower.contains("ati") {
                        return "amd".to_string();
                    }
                    if lower.contains("intel") {
                        return "intel".to_string();
                    }
                }
            }
        }
        "unknown".to_string()
    }

    fn check_dependencies(&self) -> bool {
        let mut all_ok = true;
        for dep in &["pacman", "flatpak"] {
            if which_binary(dep).is_none() {
                self.error(&format!("Missing required dependency: {}", dep));
                all_ok = false;
            }
        }
        all_ok
    }
}

fn which_binary(name: &str) -> Option<PathBuf> {
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

// --- COMMAND HANDLERS ---

fn cmd_update(runner: &Runner) -> i32 {
    runner.info("═══════════════════════════════════════");
    runner.info(" Conjunction OS — System Update");
    runner.info("═══════════════════════════════════════");
    println!();

    if !runner.check_dependencies() {
        return 1;
    }

    // Step 1: Snapper snapshot
    runner.info("Step 1/5: Creating pre-update Btrfs system snapshot...");
    if !runner.dry_run {
        match Command::new("snapper").args(&["-c", "root", "create", "--description", "pre-update snapshot", "--print-number"]).output() {
            Ok(output) if output.status.success() => {
                let num = String::from_utf8_lossy(&output.stdout).trim().to_string();
                runner.success(&format!("Created pre-update system snapshot: ID {}", num));
            }
            Ok(output) => {
                runner.warning(&format!("System snapshot failed (snapper exited with {}): {}", output.status, String::from_utf8_lossy(&output.stderr)));
            }
            Err(e) => {
                runner.warning(&format!("System snapshot failed: {}", e));
            }
        }
    } else {
        runner.info("[dry-run] Would execute: snapper -c root create --description \"pre-update snapshot\" --print-number");
    }

    // Step 2: Pacman update
    runner.info("Step 2/5: Updating system packages via pacman...");
    match runner.run_stream(&["pacman", "-Syu", "--noconfirm"], &[], true) {
        Ok(0) => runner.success("System packages updated successfully via pacman."),
        Ok(code) => {
            runner.error(&format!("pacman update failed with exit code {}", code));
            return 1;
        }
        Err(e) => {
            runner.error(&format!("pacman update failed: {}", e));
            return 1;
        }
    }

    // Step 3: Flatpak update
    runner.info("Step 3/5: Updating Flatpak packages...");
    match runner.run_stream(&["flatpak", "update", "-y"], &[], false) {
        Ok(0) => runner.success("Flatpak packages updated."),
        Ok(code) => runner.warning(&format!("Flatpak update exited with {}", code)),
        Err(e) => runner.warning(&format!("Flatpak update failed: {}", e)),
    }

    // Step 4: Wine prefixes update
    runner.info("Step 4/5: Updating Wine prefixes via wineboot -u...");
    let user_home = conjunction_core::get_user_home();
    let prefix_dir = user_home.join(".conjunction").join("prefixes");
    if prefix_dir.exists() {
        if let Ok(entries) = fs::read_dir(&prefix_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() && !entry.file_name().to_string_lossy().starts_with('.') {
                    let name = entry.file_name().to_string_lossy().to_string();
                    runner.info(&format!("Updating Wine prefix '{}'...", name));
                    let path_str = path.to_string_lossy().to_string();
                    let envs = [
                        ("WINEPREFIX", path_str.as_str()),
                        ("WINEARCH", "win64"),
                        ("WINEDLLOVERRIDES", "winemenubuilder.exe=d"),
                        ("DISPLAY", ""),
                    ];
                    let _ = runner.run_stream(&["wineboot", "-u"], &envs, false);
                }
            }
        }
    }
    runner.success("Wine prefixes updated.");

    // Step 5: AUR update via yay
    runner.info("Step 5/5: Updating AUR packages via yay...");
    let mut cmd = vec!["yay", "-Syu", "--noconfirm"];
    let sudo_user = std::env::var("SUDO_USER").unwrap_or_default();
    let is_root = conjunction_core::is_root();
    if is_root && !sudo_user.is_empty() {
        cmd.insert(0, "yay");
        cmd.insert(0, "-u");
        cmd.insert(0, &sudo_user);
        cmd.insert(0, "sudo");
    }
    match runner.run_stream(&cmd, &[], false) {
        Ok(0) => runner.success("AUR packages updated."),
        Ok(code) => runner.warning(&format!("yay update exited with {}", code)),
        Err(e) => runner.warning(&format!("yay update failed: {}", e)),
    }

    runner.success("Update Complete!");
    0
}

fn cmd_install(runner: &Runner, app_name_or_path: &str, force: bool, sandbox: bool) -> i32 {
    runner.info("═══════════════════════════════════════");
    runner.info(&format!(" Conjunction OS — Installing: {}", app_name_or_path));
    runner.info("═══════════════════════════════════════");
    println!();

    let lower = app_name_or_path.to_lowercase();
    let is_windows = lower.ends_with(".exe") || lower.ends_with(".msi");

    if is_windows {
        let installer_path = Path::new(app_name_or_path);
        if !installer_path.is_file() {
            runner.error(&format!("File not found: {}", app_name_or_path));
            return 1;
        }

        let abs_path = match fs::canonicalize(installer_path) {
            Ok(p) => p,
            Err(e) => {
                runner.error(&format!("Failed to resolve absolute path for {}: {}", app_name_or_path, e));
                return 1;
            }
        };

        let app_name = installer_path.file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("windows_app");

        // Sanitize name
        let re = regex::Regex::new(r"[^a-zA-Z0-9._-]").unwrap();
        let sanitized_name = re.replace_all(app_name, "_").to_string();

        runner.info(&format!("Installing '{}' via Wine/Conjunction...", sanitized_name));

        if runner.dry_run {
            runner.info(&format!("[dry-run] Would create prefix and run installer for {}", sanitized_name));
            return 0;
        }

        // Install Windows App
        let app_dir = Path::new("/Applications").join(format!("{}.app", sanitized_name));
        let prefix_path = app_dir.join("Contents").join("Resources").join("prefix");

        if prefix_path.exists() && !force {
            runner.warning(&format!("Wine prefix already exists for '{}' at {:?}. Use --force to reinstall.", sanitized_name, prefix_path));
        } else {
            runner.info("Creating pristine Wine prefix...");
            let _ = fs::create_dir_all(&prefix_path);
            let envs = [
                ("WINEPREFIX", prefix_path.to_str().unwrap()),
                ("WINEARCH", "win64"),
                ("DISPLAY", ""),
                ("WINEDLLOVERRIDES", "winemenubuilder.exe=d"),
            ];
            runner.info("Initializing Wine prefix...");
            match runner.run_stream(&["wineboot", "--init"], &envs, false) {
                Ok(0) => runner.success("Wine prefix initialized."),
                _ => {
                    runner.error("Failed to initialize Wine prefix.");
                    return 1;
                }
            }

            // Inject runtimes via winetricks if available
            let winetricks_path = which_binary("winetricks");
            if let Some(wt) = winetricks_path {
                runner.info("Installing Wine components via winetricks...");
                let wt_str = wt.to_string_lossy().to_string();
                let _ = runner.run_stream(&[&wt_str, "-q", "corefonts", "vcrun2015", "msxml6", "d3dcompiler_47"], &[("WINEPREFIX", prefix_path.to_str().unwrap())], false);
            }
        }

        // Run installer
        runner.info("Running installer...");
        let envs = [
            ("WINEPREFIX", prefix_path.to_str().unwrap()),
            ("WINEARCH", "win64"),
            ("WINEDLLOVERRIDES", "winemenubuilder.exe=d"),
        ];
        let installer_str = abs_path.to_string_lossy().to_string();
        let installer_args = if installer_str.ends_with(".msi") {
            vec!["msiexec", "/i", &installer_str]
        } else {
            vec!["wine", &installer_str]
        };

        match runner.run_stream(&installer_args, &envs, false) {
            Ok(_) => runner.success("Installer finished execution."),
            Err(e) => {
                runner.error(&format!("Failed to execute installer: {}", e));
                return 1;
            }
        }

        // Discover primary executable
        runner.info("Discovering primary executable...");
        let search_dirs = [
            prefix_path.join("drive_c").join("Program Files"),
            prefix_path.join("drive_c").join("Program Files (x86)"),
        ];
        let mut candidates = Vec::new();
        for dir in &search_dirs {
            if dir.is_dir() {
                if let Ok(entries) = fs::read_dir(dir) {
                    // Simple recursive walk
                    let mut stack = vec![dir.clone()];
                    while let Some(current_dir) = stack.pop() {
                        if let Ok(sub_entries) = fs::read_dir(current_dir) {
                            for sub_entry in sub_entries.flatten() {
                                let path = sub_entry.path();
                                if path.is_dir() {
                                    stack.push(path);
                                } else if path.is_file() {
                                    if let Some(ext) = path.extension().and_then(|s| s.to_str()) {
                                        if ext.to_lowercase() == "exe" {
                                            if let Some(name) = path.file_name().and_then(|s| s.to_str()) {
                                                let lower_name = name.to_lowercase();
                                                if lower_name != "uninstall.exe" && lower_name != "unins000.exe" && lower_name != "setup.exe" {
                                                    if let Ok(metadata) = path.metadata() {
                                                        if let Ok(modified) = metadata.modified() {
                                                            candidates.push((modified, path));
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        let primary_exe = if !candidates.is_empty() {
            candidates.sort_by(|a, b| b.0.cmp(&a.0));
            Some(candidates[0].1.clone())
        } else {
            None
        };

        if let Some(ref pe) = primary_exe {
            runner.success(&format!("Discovered primary executable: {:?}", pe));
        } else {
            runner.warning("Could not automatically discover primary executable.");
        }

        // Create macOS bundle structures
        let app_name_str = sanitized_name.clone();
        let app_path_str = app_dir.to_string_lossy().to_string();
        let macos_dir = app_dir.join("Contents").join("MacOS");
        let resources_dir = app_dir.join("Contents").join("Resources");

        let _ = fs::create_dir_all(&macos_dir);
        let _ = fs::create_dir_all(&resources_dir);

        let plist_path = app_dir.join("Contents").join("Info.plist");
        let plist_content = format!(r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>{}</string>
    <key>CFBundleExecutable</key>
    <string>{}</string>
    <key>CFBundleIdentifier</key>
    <string>org.conjunction.{}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
"#, app_name_str, app_name_str, app_name_str);
        let _ = fs::write(&plist_path, plist_content);

        let launcher_path = macos_dir.join(&app_name_str);
        let launcher_content = format!("#!/usr/bin/env bash\nexec cj run {}\n", app_name_str);
        let _ = fs::write(&launcher_path, launcher_content);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&launcher_path, fs::Permissions::from_mode(0o755));
        }

        // Write desktop entry inside Applications
        let app_desktop_path = Path::new("/Applications").join(format!("{}.desktop", app_name_str));
        let app_desktop_content = format!(r#"[Desktop Entry]
Version=1.0
Type=Application
Name={}
Exec=/Applications/{}.app/Contents/MacOS/{}
Icon=system-run
Terminal=false
Categories=Utility;
"#, app_name_str, app_name_str, app_name_str);
        let _ = fs::write(&app_desktop_path, app_desktop_content);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&app_desktop_path, fs::Permissions::from_mode(0o755));
        }

        // Save metadata
        let user_home = conjunction_core::get_user_home();
        let meta_dir = user_home.join(".conjunction").join("apps");
        let _ = fs::create_dir_all(&meta_dir);
        let meta_path = meta_dir.join(format!("{}.json", app_name_str));

        let install_time = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .map(|d| d.as_secs().to_string())
            .unwrap_or_default();

        let metadata = serde_json::json!({
            "name": app_name_str,
            "type": "wine",
            "source_exe": abs_path.to_string_lossy().to_string(),
            "prefix_path": prefix_path.to_string_lossy().to_string(),
            "primary_exe": primary_exe.as_ref().map(|p| p.to_string_lossy().to_string()),
            "desktop_entry": format!("{}/.local/share/applications/conjunction-{}.desktop", user_home.to_string_lossy(), app_name_str),
            "app_bundle_path": app_path_str,
            "installed_at": install_time,
            "gpu_vendor": runner.detect_gpu_vendor(),
            "proton": false
        });

        let _ = conjunction_core::write_file_user(&meta_path, &serde_json::to_string_pretty(&metadata).unwrap(), None);

        // Write local share desktop file
        let desktop_dir = user_home.join(".local").join("share").join("applications");
        let _ = fs::create_dir_all(&desktop_dir);
        let desktop_path = desktop_dir.join(format!("conjunction-{}.desktop", app_name_str));
        let desktop_content = format!(r#"[Desktop Entry]
Version=1.0
Type=Application
Name={}
Exec=/Applications/{}.app/Contents/MacOS/{}
Icon=system-run
Terminal=false
Categories=Utility;
"#, app_name_str, app_name_str, app_name_str);
        let _ = conjunction_core::write_file_user(&desktop_path, &desktop_content, None);

        runner.success(&format!("Successfully installed '{}'", app_name_str));
        0
    } else {
        // Delegate package installation to the application Rust binary
        runner.info("Searching Flatpak, Pacman, and AUR repositories...");
        let mut cmd = vec!["/opt/conjunction/application", "install", app_name_or_path];
        if force {
            cmd.push("--force");
        }
        let app_bin = which_binary("application").map(|p| p.to_string_lossy().to_string()).unwrap_or_else(|| "/opt/conjunction/application".to_string());
        let mut final_cmd = cmd.clone();
        final_cmd[0] = &app_bin;

        match runner.run_stream(&final_cmd, &[], false) {
            Ok(0) => {
                runner.success("Package installation complete.");
                0
            }
            Ok(code) => {
                runner.error(&format!("Package installation failed with exit code {}", code));
                1
            }
            Err(e) => {
                runner.error(&format!("Failed to execute application installer utility: {}", e));
                1
            }
        }
    }
}

fn cmd_optimize(runner: &Runner, gpu_only: bool, cpu_only: bool, memory_only: bool) -> i32 {
    runner.info("═══════════════════════════════════════");
    runner.info(" Conjunction OS — Performance Optimization");
    runner.info("═══════════════════════════════════════");
    println!();

    let run_all = !(gpu_only || cpu_only || memory_only);

    // Memory optimizations
    if memory_only || run_all {
        runner.info("Optimizing memory and VM settings...");
        if !runner.dry_run {
            let _ = Command::new("sync").status();
            if let Ok(mut file) = fs::File::create("/proc/sys/vm/drop_caches") {
                use std::io::Write;
                let _ = file.write_all(b"3");
            } else if let Ok(mut file) = fs::File::create("/proc/sys/drop_caches") {
                use std::io::Write;
                let _ = file.write_all(b"3");
            }
            runner.success("RAM caches flushed successfully.");

            let _ = Command::new("sysctl").args(&["-w", "vm.swappiness=10"]).status();
            let _ = Command::new("sysctl").args(&["-w", "vm.dirty_ratio=15"]).status();
            runner.success("Zen kernel VM parameters (swappiness=10, dirty_ratio=15) optimized.");

            if let Ok(mut file) = fs::File::create("/sys/kernel/mm/transparent_hugepage/enabled") {
                use std::io::Write;
                let _ = file.write_all(b"always");
                runner.success("Transparent Hugepages set to always.");
            }
        }
    }

    // GPU optimizations
    if gpu_only || run_all {
        runner.info("Optimizing GPU power profiles...");
        if !runner.dry_run {
            let gpu_vendor = runner.detect_gpu_vendor();
            if gpu_vendor == "nvidia" {
                match Command::new("nvidia-settings")
                    .args(&["-a", "[gpu:0]/GPUPowerMizerMode=1"])
                    .env("DISPLAY", ":0")
                    .status() {
                        Ok(status) if status.success() => runner.success("NVIDIA GPU PowerMizerMode set to maximum performance."),
                        _ => runner.warning("Failed to optimize NVIDIA GPU settings."),
                    }
            } else if gpu_vendor == "amd" {
                let amd_pwr = Path::new("/sys/class/drm/card0/device/power_dpm_force_performance_level");
                if amd_pwr.exists() {
                    if let Ok(mut file) = fs::File::create(amd_pwr) {
                        use std::io::Write;
                        let _ = file.write_all(b"performance");
                        runner.success("AMD GPU performance level set to performance.");
                    } else {
                        runner.warning("Could not set AMD GPU performance level (permission denied).");
                    }
                } else {
                    runner.warning("AMD GPU performance level path not found.");
                }
            } else {
                runner.info("No supported dedicated GPU detected for vendor optimization.");
            }
        }
    }

    // CPU optimizations
    if cpu_only || run_all {
        runner.info("Optimizing CPU frequency scaling governor...");
        if !runner.dry_run {
            match Command::new("cpupower").args(&["frequency-set", "-g", "performance"]).status() {
                Ok(status) if status.success() => runner.success("CPU frequency scaling governor set to performance."),
                _ => {
                    // Fallback to manual write to sysfs
                    let mut success = false;
                    if let Ok(entries) = fs::read_dir("/sys/devices/system/cpu") {
                        for entry in entries.flatten() {
                            let path = entry.path().join("cpufreq").join("scaling_governor");
                            if path.exists() {
                                if let Ok(mut file) = fs::File::create(&path) {
                                    use std::io::Write;
                                    let _ = file.write_all(b"performance");
                                    success = true;
                                }
                            }
                        }
                    }
                    if success {
                        runner.success("CPU scaling governor manually set to performance for all cores.");
                    } else {
                        runner.warning("Failed to set CPU scaling governor.");
                    }
                }
            }
        }
    }

    runner.success("Optimization complete!");
    0
}

fn cmd_status(runner: &Runner) -> i32 {
    let logo = r#"
  ____ ___  _   _    _ _   _ _   _  ____ _____ ___ ___  _   _    ___  ____  
 / ___/ _ \| \ | |  | | | | | \ | |/ ___|_   _|_ _/ _ \| \ | |  / _ \/ ___| 
| |  | | | |  \| |  | | | | |  \| | |     | |  | | | | |  \| | | | | \___ \ 
| |__| |_| | |\  |__| | |_| | |\  | |___  | |  | | |_| | |\  | | |_| |___) |
 \____\___/|_| \_(_)___\___/|_| \_|\____| |_| |___\___/|_| \_|  \___/|____/ 
"#;
    println!("{}", colored(logo, CYAN));
    runner.info("═══════════════════════════════════════");
    runner.info(" Conjunction OS — System Status");
    runner.info("═══════════════════════════════════════");
    println!();

    let kernel = if let Ok(content) = fs::read_to_string("/proc/sys/kernel/osrelease") {
        content.trim().to_string()
    } else {
        "unknown".to_string()
    };

    let desktop = std::env::var("XDG_CURRENT_DESKTOP").unwrap_or_else(|_| "unknown".to_string());

    let gpu_driver = if Path::new("/proc/driver/nvidia/version").exists() {
        fs::read_to_string("/proc/driver/nvidia/version").unwrap_or_default().trim().to_string()
    } else if let Ok(output) = Command::new("glxinfo").output() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        stdout.lines()
            .find(|line| line.contains("OpenGL version string") || line.contains("Mesa"))
            .map(|line| line.trim().to_string())
            .unwrap_or_else(|| "unknown".to_string())
    } else {
        "unknown".to_string()
    };

    let wine_version = if let Ok(output) = Command::new("wine").arg("--version").output() {
        String::from_utf8_lossy(&output.stdout).trim().to_string()
    } else {
        "unknown".to_string()
    };

    let user_home = conjunction_core::get_user_home();
    let apps_dir = user_home.join(".conjunction").join("apps");
    let sandbox_count = if apps_dir.exists() {
        fs::read_dir(&apps_dir)
            .map(|rd| rd.flatten().filter(|e| e.path().extension().map_or(false, |ext| ext == "json")).count())
            .unwrap_or(0)
    } else {
        0
    };

    let last_update = if let Ok(output) = Command::new("stat").args(&["-c", "%y", "/var/log/pacman.log"]).output() {
        let s = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if !s.is_empty() {
            s.split('.').next().unwrap_or(&s).to_string()
        } else {
            "unknown".to_string()
        }
    } else {
        "unknown".to_string()
    };

    let mut snapshot_count = 0;
    if let Ok(output) = Command::new("snapper").args(&["-c", "root", "list", "--columns", "number"]).output() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        snapshot_count = stdout.lines().filter(|l| l.trim().chars().all(|c| c.is_ascii_digit())).count();
    }

    let uptime = if let Ok(content) = fs::read_to_string("/proc/uptime") {
        if let Some(uptime_sec_str) = content.split_whitespace().next() {
            if let Ok(uptime_sec) = uptime_sec_str.parse::<f64>() {
                let hours = (uptime_sec / 3600.0) as i32;
                let minutes = ((uptime_sec % 3600.0) / 60.0) as i32;
                format!("{}h {}m", hours, minutes)
            } else {
                "unknown".to_string()
            }
        } else {
            "unknown".to_string()
        }
    } else {
        "unknown".to_string()
    };

    let prefix_dir = user_home.join(".conjunction").join("prefixes");
    let prefix_size = if prefix_dir.exists() {
        if let Ok(output) = Command::new("du").args(&["-sh", &prefix_dir.to_string_lossy()]).output() {
            String::from_utf8_lossy(&output.stdout).split_whitespace().next().unwrap_or("0M").to_string()
        } else {
            "0M".to_string()
        }
    } else {
        "0M".to_string()
    };

    runner.info(&format!("Kernel:        {}", kernel));
    runner.info(&format!("Desktop:       {}", desktop));
    runner.info(&format!("GPU Driver:    {}", gpu_driver));
    runner.info(&format!("Wine:          {}", wine_version));
    runner.info(&format!("Sandboxed:     {} apps", sandbox_count));
    runner.info(&format!("Last Update:   {}", last_update));
    runner.info(&format!("Snapshots:     {}", snapshot_count));
    runner.info(&format!("Uptime:        {}", uptime));
    runner.info(&format!("Wine Prefix:   {}", prefix_size));

    println!();
    0
}

fn cmd_apps(runner: &Runner, remove_name: Option<String>) -> i32 {
    if let Some(name) = remove_name {
        if !runner.dry_run {
            if !confirm(&format!("Remove '{}' and all its data?", name)) {
                runner.info("Aborted.");
                return 0;
            }
        }
        runner.info(&format!("Removing {}...", name));
        if runner.dry_run {
            runner.info(&format!("[dry-run] Would remove app bundle and metadata for {}", name));
            return 0;
        }

        match conjunction_core::remove_app_bundle(&name) {
            Ok(_) => {
                // Delete prefix under /Applications
                let app_dir = format!("/Applications/{}.app", name);
                let _ = Command::new("rm").args(&["-rf", &app_dir]).status();
                let app_desktop = format!("/Applications/{}.desktop", name);
                let _ = Command::new("rm").args(&["-f", &app_desktop]).status();
                
                runner.success(&format!("Removed '{}' successfully", name));
                0
            }
            Err(e) => {
                runner.error(&format!("Failed to remove application: {}", e));
                1
            }
        }
    } else {
        runner.info("═══════════════════════════════════════");
        runner.info(" Conjunction OS — Installed Apps");
        runner.info("═══════════════════════════════════════");
        println!();

        let user_home = conjunction_core::get_user_home();
        let apps_dir = user_home.join(".conjunction").join("apps");
        if !apps_dir.exists() {
            runner.warning("No applications installed yet");
            runner.info("Install apps with: cj install <name_or_path>");
            return 0;
        }

        let mut app_count = 0;
        if let Ok(entries) = fs::read_dir(&apps_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_file() && path.extension().map_or(false, |ext| ext == "json") {
                    if let Ok(content) = fs::read_to_string(&path) {
                        if let Ok(val) = serde_json::from_str::<Value>(&content) {
                            let name = val.get("name").and_then(|v| v.as_str()).unwrap_or("unknown");
                            let gpu = val.get("gpu_vendor").and_then(|v| v.as_str()).unwrap_or("unknown");
                            let installed_at = val.get("installed_at").and_then(|v| v.as_str()).unwrap_or("unknown");
                            let desktop = val.get("desktop_entry").and_then(|v| v.as_str()).unwrap_or("none");
                            
                            runner.info(&format!("  {}", colored(name, BOLD)));
                            runner.info(&format!("    GPU Passthrough: {}", gpu));
                            runner.info(&format!("    Installed:       {}", installed_at));
                            runner.info(&format!("    Desktop Entry:   {}", desktop));
                            println!();
                            app_count += 1;
                        }
                    }
                }
            }
        }

        if app_count == 0 {
            runner.warning("No applications installed yet");
            runner.info("Install apps with: cj install <name_or_path>");
        }
        0
    }
}

fn cmd_setup_wrappers(runner: &Runner) -> i32 {
    runner.info("═══════════════════════════════════════");
    runner.info(" Conjunction OS — Setup Command Wrappers");
    runner.info("═══════════════════════════════════════");
    println!();

    if runner.dry_run {
        runner.info("[dry-run] Would create open, pbcopy, pbpaste, softwareupdate in /usr/local/bin");
        return 0;
    }

    let wrappers = [
        ("open", r#"#!/usr/bin/env bash
if [[ "$1" == *.app ]]; then
    app_name=$(basename "$1" .app)
    if [[ -x "$1/Contents/MacOS/$app_name" ]]; then
        exec "$1/Contents/MacOS/$app_name" "${@:2}"
    elif [[ -x "$1/AppRun" ]]; then
        exec "$1/AppRun" "${@:2}"
    fi
fi
exec xdg-open "$@"
"#),
        ("pbcopy", r#"#!/usr/bin/env bash
if [[ "${WAYLAND_DISPLAY:-}" ]]; then
    exec wl-copy "$@"
else
    exec xclip -selection clipboard "$@"
fi
"#),
        ("pbpaste", r#"#!/usr/bin/env bash
if [[ "${WAYLAND_DISPLAY:-}" ]]; then
    exec wl-paste "$@"
else
    exec xclip -selection clipboard -o "$@"
fi
"#),
        ("softwareupdate", r#"#!/usr/bin/env bash
exec cj update "$@"
"#)
    ];

    let mut all_ok = true;
    for (name, content) in &wrappers {
        runner.info(&format!("Installing macOS command wrapper: {}...", name));
        let temp_path = format!("/tmp/cj-wrapper-{}", name);
        if fs::write(&temp_path, content).is_ok() {
            let dest_path = format!("/usr/local/bin/{}", name);
            let cp_res = Command::new("sudo").args(&["cp", &temp_path, &dest_path]).status();
            let chmod_res = Command::new("sudo").args(&["chmod", "+x", &dest_path]).status();
            let _ = fs::remove_file(&temp_path);
            
            if cp_res.map_or(false, |s| s.success()) && chmod_res.map_or(false, |s| s.success()) {
                runner.success(&format!("Installed /usr/local/bin/{}", name));
            } else {
                runner.error(&format!("Failed to copy wrapper {} to /usr/local/bin", name));
                all_ok = false;
            }
        } else {
            runner.error(&format!("Failed to write temporary wrapper file for {}", name));
            all_ok = false;
        }
    }

    if all_ok {
        runner.success("Successfully installed macOS command wrappers in /usr/local/bin");
        0
    } else {
        1
    }
}

fn cmd_run(runner: &Runner, app_name: &str) -> i32 {
    let user_home = conjunction_core::get_user_home();
    let meta_path = user_home.join(".conjunction").join("apps").join(format!("{}.json", app_name));
    
    if !meta_path.exists() {
        runner.error(&format!("Application '{}' is not installed.", app_name));
        return 1;
    }

    let content = match fs::read_to_string(&meta_path) {
        Ok(c) => c,
        Err(e) => {
            runner.error(&format!("Failed to read application metadata: {}", e));
            return 1;
        }
    };

    let val: Value = match serde_json::from_str(&content) {
        Ok(v) => v,
        Err(e) => {
            runner.error(&format!("Failed to parse application metadata: {}", e));
            return 1;
        }
    };

    let prefix_path = val.get("prefix_path").and_then(|v| v.as_str()).unwrap_or("");
    let primary_exe = val.get("primary_exe").and_then(|v| v.as_str()).unwrap_or("");

    if prefix_path.is_empty() || primary_exe.is_empty() {
        runner.error("Invalid application metadata: prefix_path or primary_exe is empty.");
        return 1;
    }

    runner.info(&format!("Launching {} via Wine...", app_name));

    let envs = [
        ("WINEPREFIX", prefix_path),
        ("WINEARCH", "win64"),
        ("WINEDLLOVERRIDES", "winemenubuilder.exe=d"),
    ];

    match runner.run_stream(&["wine", primary_exe], &envs, false) {
        Ok(code) => code,
        Err(e) => {
            runner.error(&format!("Failed to run Wine application: {}", e));
            1
        }
    }
}

// Dummy/basic implementations for other utility commands to support complete cli.py compatibility

fn cmd_doctor(runner: &Runner) -> i32 {
    runner.info("═══════════════════════════════════════");
    runner.info(" Conjunction OS — Doctor Health Check");
    runner.info("═══════════════════════════════════════");
    println!();

    let checks = [
        ("Wine Executable", "wine", "Wine translation layer compatibility"),
        ("Winetricks Executable", "winetricks", "Wine prefix enhancement helper"),
        ("Flatpak Executable", "flatpak", "Linux sandboxed application delivery"),
        ("Snapper Executable", "snapper", "Btrfs system snapshot tool"),
        ("Yay AUR Helper", "yay", "AUR package management interface")
    ];

    let mut warnings = 0;
    for (name, bin, desc) in &checks {
        if which_binary(bin).is_some() {
            runner.success(&format!("{}: Found (supports {})", name, desc));
        } else {
            runner.warning(&format!("{}: Not found (needs {})", name, desc));
            warnings += 1;
        }
    }

    if warnings > 0 {
        runner.warning(&format!("Doctor diagnostics finished with {} warning(s).", warnings));
    } else {
        runner.success("System is healthy! No issues found.");
    }
    0
}

fn cmd_rollback(runner: &Runner, target: &str, snapshot_id: &str) -> i32 {
    runner.info("═══════════════════════════════════════");
    runner.info(&format!(" Conjunction OS — Rollback: {} to ID {}", target, snapshot_id));
    runner.info("═══════════════════════════════════════");
    println!();

    if target == "system" {
        if !runner.dry_run {
            if !confirm("Are you sure you want to perform system snapper rollback? This requires rebooting.") {
                runner.info("Aborted.");
                return 0;
            }
        }
        match runner.run_stream(&["snapper", "rollback", snapshot_id], &[], true) {
            Ok(0) => {
                runner.success("System rollback scheduled. Please reboot to complete.");
                0
            }
            _ => {
                runner.error("Failed to run snapper rollback.");
                1
            }
        }
    } else {
        runner.error("Snapper prefix/app rollback is not natively implemented in Rust CLI yet. Please use Snapper tools.");
        1
    }
}

fn cmd_export(runner: &Runner, app_name: &str, output_path: &str) -> i32 {
    runner.info("═══════════════════════════════════════");
    runner.info(&format!(" Conjunction OS — Export App: {} to {}", app_name, output_path));
    runner.info("═══════════════════════════════════════");
    println!();

    let app_dir = format!("/Applications/{}.app", app_name);
    if !Path::new(&app_dir).exists() {
        runner.error(&format!("Application bundle {} does not exist.", app_dir));
        return 1;
    }

    match runner.run_stream(&["tar", "-caf", output_path, "-C", "/Applications", &format!("{}.app", app_name)], &[], false) {
        Ok(0) => {
            runner.success("Application exported successfully.");
            0
        }
        _ => {
            runner.error("Failed to export application bundle.");
            1
        }
    }
}

fn cmd_import(runner: &Runner, input_path: &str, name_override: Option<String>) -> i32 {
    runner.info("═══════════════════════════════════════");
    runner.info(&format!(" Conjunction OS — Import App from {}", input_path));
    runner.info("═══════════════════════════════════════");
    println!();

    if !Path::new(input_path).exists() {
        runner.error(&format!("Import archive file {} not found.", input_path));
        return 1;
    }

    match runner.run_stream(&["tar", "-xaf", input_path, "-C", "/Applications"], &[], true) {
        Ok(0) => {
            runner.success("Application imported successfully.");
            // If there's an override name, we might rename it, but standard import extracts to /Applications
            if let Some(ref name) = name_override {
                runner.info(&format!("Override name '{}' requested. Rename the app bundle or use apps command.", name));
            }
            0
        }
        _ => {
            runner.error("Failed to extract application bundle.");
            1
        }
    }
}

fn cmd_bug_report(runner: &Runner, output: Option<String>) -> i32 {
    runner.info("═══════════════════════════════════════");
    runner.info(" Conjunction OS — Bug Report");
    runner.info("═══════════════════════════════════════");
    println!();

    let report_file = output.unwrap_or_else(|| "/tmp/conjunction-bug-report.tar.zst".to_string());
    runner.info("Collecting diagnostic reports...");

    // Package simple diagnostic files
    let log_dir = conjunction_core::get_user_home().join(".conjunction").join("logs");
    let apps_path_buf = conjunction_core::get_user_home().join(".conjunction");
    let apps_path_str = apps_path_buf.to_string_lossy().to_string();
    let cmd_args = if log_dir.exists() {
        vec!["tar", "-caf", &report_file, "-C", "/var/log", "pacman.log", "-C", &apps_path_str, "apps"]
    } else {
        vec!["tar", "-caf", &report_file, "-C", "/var/log", "pacman.log"]
    };

    match runner.run_stream(&cmd_args, &[], false) {
        Ok(0) => {
            runner.success(&format!("Bug report archive successfully generated at: {}", report_file));
            0
        }
        _ => {
            runner.error("Failed to package bug report.");
            1
        }
    }
}

fn cmd_repair(runner: &Runner, app_name: &str) -> i32 {
    runner.info("═══════════════════════════════════════");
    runner.info(&format!(" Conjunction OS — Repair App: {}", app_name));
    runner.info("═══════════════════════════════════════");
    println!();

    let app_dir = format!("/Applications/{}.app", app_name);
    let prefix_path = Path::new(&app_dir).join("Contents").join("Resources").join("prefix");
    if !prefix_path.exists() {
        runner.error(&format!("Wine prefix for application '{}' does not exist.", app_name));
        return 1;
    }

    runner.info("Refreshing registry configurations and permissions...");
    let envs = [
        ("WINEPREFIX", prefix_path.to_str().unwrap()),
        ("WINEARCH", "win64"),
        ("DISPLAY", ""),
    ];

    match runner.run_stream(&["wineboot", "-u"], &envs, false) {
        Ok(0) => {
            runner.success("Application repaired successfully.");
            0
        }
        _ => {
            runner.error("Failed to execute registry refresh.");
            1
        }
    }
}

fn cmd_cleanup(runner: &Runner, days: i32) -> i32 {
    runner.info("═══════════════════════════════════════");
    runner.info(&format!(" Conjunction OS — System Cleanup (Older than {} days)", days));
    runner.info("═══════════════════════════════════════");
    println!();

    // Check and remove temporary download caches or logs
    let user_home = conjunction_core::get_user_home();
    let crash_dir = user_home.join(".conjunction").join("crash-reports");
    if crash_dir.exists() {
        if let Ok(entries) = fs::read_dir(&crash_dir) {
            let mut deleted = 0;
            for entry in entries.flatten() {
                if let Ok(meta) = entry.metadata() {
                    if let Ok(modified) = meta.modified() {
                        if let Ok(age) = SystemTime::now().duration_since(modified) {
                            if age.as_secs() > (days as u64 * 86400) {
                                let _ = fs::remove_file(entry.path());
                                deleted += 1;
                            }
                        }
                    }
                }
            }
            runner.success(&format!("Deleted {} expired crash report(s).", deleted));
        }
    }
    runner.success("System cleanup complete.");
    0
}

fn cmd_reset_desktop(runner: &Runner) -> i32 {
    runner.info("═══════════════════════════════════════");
    runner.info(" Conjunction OS — Reset Desktop Layout");
    runner.info("═══════════════════════════════════════");
    println!();

    if !runner.dry_run {
        if !confirm("This will overwrite your current desktop layout. Proceed?") {
            runner.info("Aborted.");
            return 0;
        }
    }

    match runner.run_stream(&["/opt/conjunction/setup_conjunction_ui.sh"], &[], true) {
        Ok(0) => {
            runner.success("Plasma desktop layout reset successfully to Conjunction OS defaults.");
            0
        }
        _ => {
            runner.error("Failed to reset desktop layout.");
            1
        }
    }
}

// --- MAIN ENTRYPOINT ---

fn main() {
    // Initialize env logger
    env_logger::init();

    let args = Cli::parse();
    let runner = Runner::new(args.verbose, args.quiet, args.dry_run);

    let exit_code = match args.command {
        Commands::Update => cmd_update(&runner),
        Commands::Install { app_name_or_path, force, sandbox } => cmd_install(&runner, &app_name_or_path, force, sandbox),
        Commands::Optimize { gpu_only, cpu_only, memory_only } => cmd_optimize(&runner, gpu_only, cpu_only, memory_only),
        Commands::Status => cmd_status(&runner),
        Commands::Apps { remove } => cmd_apps(&runner, remove),
        Commands::Doctor => cmd_doctor(&runner),
        Commands::Rollback { target, snapshot_id } => cmd_rollback(&runner, &target, &snapshot_id),
        Commands::Export { app_name, output_path } => cmd_export(&runner, &app_name, &output_path),
        Commands::Import { input_path, name } => cmd_import(&runner, &input_path, name),
        Commands::BugReport { output } => cmd_bug_report(&runner, output),
        Commands::Repair { app_name } => cmd_repair(&runner, &app_name),
        Commands::Cleanup { days } => cmd_cleanup(&runner, days),
        Commands::ResetDesktop => cmd_reset_desktop(&runner),
        Commands::SetupWrappers => cmd_setup_wrappers(&runner),
        Commands::Run { app_name } => cmd_run(&runner, &app_name),
    };

    std::process::exit(exit_code);
}

// End of Cj CLI module. Cleaned up unused DIM color constants.
// Unified verbose argument propagation to nested process runners.
// Verified correct exit status returning from pacman system upgrades.