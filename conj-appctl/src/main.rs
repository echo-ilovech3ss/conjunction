use clap::{Parser, Subcommand};
use conjunction_core::{AppRegistry, RegistryItem};
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser, Debug)]
#[command(name = "conj-appctl", version = "0.1.0", about = "Conjunction Application Services control interface")]
struct Cli {
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
    },

    #[command(about = "Launch a Conjunction application by ID or bundle path")]
    Launch {
        #[arg(help = "Application reverse-DNS ID or path to .app bundle")]
        target: String,

        #[arg(trailing_var_arg = true, allow_hyphen_values = true, help = "Arguments to pass to application")]
        args: Vec<String>,
    },

    #[command(about = "Reconcile application registry from filesystem state")]
    Reconcile,
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    let mut registry = AppRegistry::default_for_user();

    match cli.command {
        Commands::List => {
            if let Err(e) = registry.reconcile() {
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
                            "{:<30} {:<20} {:<10} [{}] {}",
                            app.id,
                            app.name,
                            app.version,
                            app.scope,
                            app.bundle_path.display()
                        );
                    }
                    RegistryItem::Conflict(conflict) => {
                        println!(
                            "{:<30} [CONFLICT DETECTED]",
                            conflict.id
                        );
                        for candidate in conflict.candidate_paths {
                            println!("    -> candidate: {}", candidate.display());
                        }
                    }
                }
            }
            ExitCode::SUCCESS
        }

        Commands::Inspect { id } => {
            if let Err(e) = registry.reconcile() {
                eprintln!("error: {}", e);
                return ExitCode::FAILURE;
            }

            match registry.inspect(&id) {
                Ok(RegistryItem::Active(app)) => {
                    println!("Application ID:   {}", app.id);
                    println!("Name:             {}", app.name);
                    println!("Version:          {}", app.version);
                    println!("Scope:            {}", app.scope);
                    println!("Bundle Path:      {}", app.bundle_path.display());
                    println!("Executable Path:  {}", app.executable_path.display());
                    if let Some(icon) = app.icon {
                        println!("Icon:             {}", icon);
                    }
                    if !app.mime_types.is_empty() {
                        println!("MIME Types:       {}", app.mime_types.join(", "));
                    }
                    ExitCode::SUCCESS
                }
                Ok(RegistryItem::Conflict(conflict)) => {
                    eprintln!("Conflict: application ID '{}' has multiple candidate bundles:", conflict.id);
                    for candidate in conflict.candidate_paths {
                        eprintln!("  - {}", candidate.display());
                    }
                    ExitCode::FAILURE
                }
                Err(err) => {
                    eprintln!("error: {}", err);
                    ExitCode::FAILURE
                }
            }
        }

        Commands::Install { path } => {
            match registry.install(&path) {
                Ok(app) => {
                    println!("Installed '{}' ({}) successfully", app.name, app.id);
                    println!("Bundle: {}", app.bundle_path.display());
                    ExitCode::SUCCESS
                }
                Err(err) => {
                    eprintln!("error: {}", err);
                    ExitCode::FAILURE
                }
            }
        }

        Commands::Uninstall { id } => {
            match registry.uninstall(&id) {
                Ok(()) => {
                    println!("Uninstalled '{}' successfully", id);
                    ExitCode::SUCCESS
                }
                Err(err) => {
                    eprintln!("error: {}", err);
                    ExitCode::FAILURE
                }
            }
        }

        Commands::Launch { target, args } => {
            if let Err(e) = registry.reconcile() {
                eprintln!("error: {}", e);
                return ExitCode::FAILURE;
            }

            match registry.launch(&target, &args) {
                Ok(code) => {
                    if code == 0 {
                        ExitCode::SUCCESS
                    } else {
                        ExitCode::from(code as u8)
                    }
                }
                Err(err) => {
                    eprintln!("error: {}", err);
                    ExitCode::FAILURE
                }
            }
        }

        Commands::Reconcile => {
            match registry.reconcile() {
                Ok(()) => {
                    println!("Reconciliation complete.");
                    ExitCode::SUCCESS
                }
                Err(err) => {
                    eprintln!("error: {}", err);
                    ExitCode::FAILURE
                }
            }
        }
    }
}
