use clap::Parser;
use conjunction_core::AppRegistry;
use std::process::ExitCode;

#[derive(Parser, Debug)]
#[command(name = "conj-open", version = "0.1.0", about = "Conjunction application and document opener")]
struct Cli {
    #[arg(help = "Path to .app bundle, file, or application ID")]
    target: String,

    #[arg(trailing_var_arg = true, allow_hyphen_values = true, help = "Arguments to pass")]
    args: Vec<String>,
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    let mut registry = AppRegistry::default_for_user();

    if let Err(e) = registry.reconcile() {
        eprintln!("error: {}", e);
        return ExitCode::FAILURE;
    }

    match registry.launch(&cli.target, &cli.args) {
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
