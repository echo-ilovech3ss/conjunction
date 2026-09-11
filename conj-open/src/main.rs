use clap::Parser;
use conjunction_core::{send_appd_request, AppRegistry, AppdRequest};
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

    let req = AppdRequest::Launch {
        target: cli.target.clone(),
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
        Err(_) => {
            // Fallback to standalone if daemon is unavailable
            let mut registry = AppRegistry::default_for_user();
            let _ = registry.reconcile();
            match registry.launch_captured(&cli.target, &cli.args) {
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
            }
        }
    }
}
