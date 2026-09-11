use clap::{Parser, Subcommand};
use conjunction_core::Bundle;
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Parser, Debug)]
#[command(name = "conj-bundle", version = "0.1.0", about = "Conjunction application bundle inspection and validation tool")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    #[command(about = "Validate a Conjunction .app bundle")]
    Validate {
        #[arg(help = "Path to .app bundle directory")]
        path: PathBuf,
    },

    #[command(about = "Inspect a Conjunction .app bundle metadata")]
    Inspect {
        #[arg(help = "Path to .app bundle directory")]
        path: PathBuf,
    },
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    match cli.command {
        Commands::Validate { path } => match Bundle::open(&path) {
            Ok(bundle) => match bundle.validate() {
                Ok(()) => {
                    println!("Valid Conjunction application bundle");
                    ExitCode::SUCCESS
                }
                Err(err) => {
                    eprintln!("error: {}", err);
                    ExitCode::FAILURE
                }
            },
            Err(err) => {
                eprintln!("error: {}", err);
                ExitCode::FAILURE
            }
        },
        Commands::Inspect { path } => match Bundle::open(&path) {
            Ok(bundle) => {
                let m = bundle.manifest();
                println!("Application ID: {}", m.id);
                println!("Name:           {}", m.name);
                println!("Version:        {}", m.version);
                println!("Bundle Format:  {}", m.bundle_format);
                println!("Executable:     {}", m.executable);
                println!("Architectures:  {}", m.architectures.join(", "));

                if let Some(desc) = &m.description {
                    println!("Description:    {}", desc);
                }
                if let Some(cat) = &m.category {
                    println!("Category:       {}", cat);
                }
                if let Some(icon) = &m.icon {
                    println!("Icon:           {}", icon);
                }
                if let Some(mimes) = &m.mime_types {
                    println!("MIME Types:     {}", mimes.join(", "));
                }
                if let Some(schemes) = &m.url_schemes {
                    println!("URL Schemes:    {}", schemes.join(", "));
                }
                if let Some(perms) = &m.permissions {
                    println!("Permissions:    {}", perms.join(", "));
                }
                ExitCode::SUCCESS
            }
            Err(err) => {
                eprintln!("error: {}", err);
                ExitCode::FAILURE
            }
        },
    }
}
