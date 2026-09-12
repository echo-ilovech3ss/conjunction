use clap::{Parser, Subcommand};
use conjunction_core::{
    appd_socket_path, ipc::send_appd_request_to_path, AppRegistry, AppdRequest, InstalledApp,
    RegistryItem,
};
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser, Debug)]
#[command(
    name = "conj-appctl",
    version = "0.1.0",
    about = "Conjunction Application Services control interface"
)]
struct Cli {
    #[arg(long, help = "Custom daemon socket path")]
    socket: Option<PathBuf>,

    #[arg(
        long,
        help = "Execute directly without daemon (standalone recovery mode)"
    )]
    standalone: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    #[command(about = "List installed Conjunction applications")]
    List,

    #[command(about = "Inspect an installed application by ID")]
    Inspect {
        #[arg(help = "Application reverse-DNS identifier")]
        id: String,
    },

    #[command(about = "Install a Conjunction .app bundle into user Applications")]
    Install {
        #[arg(help = "Path to .app bundle")]
        path: PathBuf,
    },

    #[command(about = "Uninstall a Conjunction application by ID")]
    Uninstall {
        #[arg(help = "Application reverse-DNS identifier")]
        id: String,

        #[arg(short, long, help = "Confirm removal of package providing multiple applications")]
        yes: bool,
    },

    #[command(about = "Launch a Conjunction application by ID or bundle path")]
    Launch {
        #[arg(help = "Application reverse-DNS ID or path to .app bundle")]
        target: String,

        #[arg(
            trailing_var_arg = true,
            allow_hyphen_values = true,
            help = "Arguments to pass to application"
        )]
        args: Vec<String>,
    },

    #[command(about = "Reconcile application registry from filesystem state")]
    Reconcile,

    #[command(about = "Ping the conj-appd daemon")]
    Ping,
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    let sock_path = cli.socket.unwrap_or_else(appd_socket_path);

    if cli.standalone {
        return run_standalone(cli.command);
    }

    // Default: Dispatch through authoritative conj-appd daemon via session IPC
    let req = match &cli.command {
        Commands::List => AppdRequest::List,
        Commands::Inspect { id } => AppdRequest::Inspect { id: id.clone() },
        Commands::Install { path } => AppdRequest::Install { path: path.clone() },
        Commands::Uninstall { id, yes } => AppdRequest::Uninstall {
            id: id.clone(),
            yes: *yes,
        },
        Commands::Launch { target, args } => AppdRequest::Launch {
            target: target.clone(),
            args: args.clone(),
        },
        Commands::Reconcile => AppdRequest::Reconcile,
        Commands::Ping => AppdRequest::Ping,
    };

    let resp = match send_appd_request_to_path(&sock_path, &req) {
        Ok(r) => r,
        Err(err) => {
            eprintln!("error: {}", err);
            return ExitCode::FAILURE;
        }
    };

    if !resp.success {
        if let Some(err) = resp.error {
            eprintln!("error: {}", err);
        } else {
            eprintln!("error: operation failed");
        }
        return ExitCode::FAILURE;
    }

    match cli.command {
        Commands::List => {
            if let Some(data) = resp.data {
                let items: Vec<RegistryItem> = serde_json::from_value(data).unwrap_or_default();
                if items.is_empty() {
                    println!("No applications installed.");
                    return ExitCode::SUCCESS;
                }
                for item in items {
                    match item {
                        RegistryItem::Active(app) => {
                            println!(
                                "{:<32} {:<20} {:<10} [{}] [{}] {}",
                                app.id,
                                app.name,
                                app.version,
                                app.scope,
                                app.backend,
                                app.bundle_path.display()
                            );
                        }
                        RegistryItem::Conflict(conflict) => {
                            println!("{:<32} [CONFLICT DETECTED]", conflict.id);
                            for candidate in conflict.candidate_paths {
                                println!("    -> candidate: {}", candidate.display());
                            }
                        }
                    }
                }
            }
            ExitCode::SUCCESS
        }

        Commands::Inspect { .. } => {
            if let Some(data) = resp.data {
                match serde_json::from_value::<RegistryItem>(data) {
                    Ok(RegistryItem::Active(app)) => {
                        println!("Application ID:   {}", app.id);
                        println!("Name:             {}", app.name);
                        println!("Version:          {}", app.version);
                        println!("Scope:            {}", app.scope);
                        println!("Backend:          {}", app.backend);
                        println!("Bundle Path:      {}", app.bundle_path.display());
                        println!("Executable Path:  {}", app.executable_path.display());
                        if let Some(pkg) = &app.package_name {
                            let ver_str = app.package_version.as_deref().map(|v| format!(" {}", v)).unwrap_or_default();
                            println!("Package:          {}{}", pkg, ver_str);
                        }
                        if !app.sibling_apps.is_empty() {
                            println!("Sibling Apps:     {}", app.sibling_apps.join(", "));
                        }
                        if let Some(fp_id) = &app.flatpak_id {
                            println!("Flatpak ID:       {}", fp_id);
                        }
                        if let Some(icon) = app.icon {
                            println!("Icon:             {}", icon);
                        }
                        if !app.mime_types.is_empty() {
                            println!("MIME Types:       {}", app.mime_types.join(", "));
                        }
                        ExitCode::SUCCESS
                    }
                    Ok(RegistryItem::Conflict(conflict)) => {
                        eprintln!(
                            "Conflict: application ID '{}' has multiple candidate bundles:",
                            conflict.id
                        );
                        for candidate in conflict.candidate_paths {
                            eprintln!("  - {}", candidate.display());
                        }
                        ExitCode::FAILURE
                    }
                    Err(e) => {
                        eprintln!("error: failed to parse response: {}", e);
                        ExitCode::FAILURE
                    }
                }
            } else {
                ExitCode::FAILURE
            }
        }

        Commands::Install { .. } => {
            if let Some(data) = resp.data {
                if let Ok(app) = serde_json::from_value::<InstalledApp>(data) {
                    println!("Installed '{}' ({}) successfully", app.name, app.id);
                    println!("Bundle: {}", app.bundle_path.display());
                }
            }
            ExitCode::SUCCESS
        }

        Commands::Uninstall { id, .. } => {
            println!("Uninstalled '{}' successfully", id);
            ExitCode::SUCCESS
        }

        Commands::Launch { .. } => {
            if let Some(data) = resp.data {
                if let Some(stdout) = data.get("stdout").and_then(|s| s.as_str()) {
                    print!("{}", stdout);
                }
                if let Some(stderr) = data.get("stderr").and_then(|s| s.as_str()) {
                    eprint!("{}", stderr);
                }
                let code = data.get("exit_code").and_then(|c| c.as_i64()).unwrap_or(0);
                if code == 0 {
                    ExitCode::SUCCESS
                } else {
                    ExitCode::from(code as u8)
                }
            } else {
                ExitCode::SUCCESS
            }
        }

        Commands::Reconcile => {
            println!("Reconciliation complete.");
            ExitCode::SUCCESS
        }

        Commands::Ping => {
            println!("pong");
            ExitCode::SUCCESS
        }
    }
}

fn run_standalone(cmd: Commands) -> ExitCode {
    let mut registry = AppRegistry::default_for_user();
    match cmd {
        Commands::List => {
            if let Err(e) = registry.scan_readonly() {
                eprintln!("error: {}", e);
                return ExitCode::FAILURE;
            }
            let items = registry.list();
            if items.is_empty() {
                println!("No applications installed.");
                return ExitCode::SUCCESS;
            }
            for item in items {
                match item {
                    RegistryItem::Active(app) => {
                        println!(
                            "{:<32} {:<20} {:<10} [{}] [{}] {}",
                            app.id,
                            app.name,
                            app.version,
                            app.scope,
                            app.backend,
                            app.bundle_path.display()
                        );
                    }
                    RegistryItem::Conflict(conflict) => {
                        println!("{:<32} [CONFLICT DETECTED]", conflict.id);
                        for candidate in conflict.candidate_paths {
                            println!("    -> candidate: {}", candidate.display());
                        }
                    }
                }
            }
            ExitCode::SUCCESS
        }
        Commands::Inspect { id } => {
            let _ = registry.scan_readonly();
            match registry.inspect(&id) {
                Ok(RegistryItem::Active(app)) => {
                    println!("Application ID:   {}", app.id);
                    println!("Name:             {}", app.name);
                    println!("Version:          {}", app.version);
                    println!("Scope:            {}", app.scope);
                    println!("Backend:          {}", app.backend);
                    println!("Bundle Path:      {}", app.bundle_path.display());
                    println!("Executable Path:  {}", app.executable_path.display());
                    if let Some(pkg) = &app.package_name {
                        let ver_str = app.package_version.as_deref().map(|v| format!(" {}", v)).unwrap_or_default();
                        println!("Package:          {}{}", pkg, ver_str);
                    }
                    if !app.sibling_apps.is_empty() {
                        println!("Sibling Apps:     {}", app.sibling_apps.join(", "));
                    }
                    if let Some(fp_id) = &app.flatpak_id {
                        println!("Flatpak ID:       {}", fp_id);
                    }
                    if let Some(icon) = app.icon {
                        println!("Icon:             {}", icon);
                    }
                    if !app.mime_types.is_empty() {
                        println!("MIME Types:       {}", app.mime_types.join(", "));
                    }
                    ExitCode::SUCCESS
                }
                Ok(RegistryItem::Conflict(conflict)) => {
                    eprintln!("Conflict: {}", conflict.id);
                    ExitCode::FAILURE
                }
                Err(e) => {
                    eprintln!("error: {}", e);
                    ExitCode::FAILURE
                }
            }
        }
        Commands::Install { .. } => {
            eprintln!(
                "error: mutating operation 'install' cannot be performed in standalone mode; start conj-appd to mutate application state"
            );
            ExitCode::FAILURE
        }
        Commands::Uninstall { .. } => {
            eprintln!(
                "error: mutating operation 'uninstall' cannot be performed in standalone mode; start conj-appd to mutate application state"
            );
            ExitCode::FAILURE
        }
        Commands::Reconcile => {
            eprintln!(
                "error: mutating operation 'reconcile' cannot be performed in standalone mode; start conj-appd to mutate application state"
            );
            ExitCode::FAILURE
        }
        Commands::Launch { target, args } => {
            let _ = registry.scan_readonly();
            match registry.launch_captured(&target, &args) {
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
        }
        Commands::Ping => {
            println!("pong (standalone)");
            ExitCode::SUCCESS
        }
    }
}
