use clap::Parser;
use conjunction_core::{send_appd_request, AppRegistry, AppdRequest};
use std::process::ExitCode;

use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(name = "conj-open", version = "0.1.0", about = "Conjunction application and document opener")]
struct Cli {
    #[arg(long, value_names = ["MIME", "DESKTOP_ID"], num_args = 2, help = "Set default application for MIME type or URI scheme")]
    set_default: Option<Vec<String>>,

    #[arg(help = "Path to .app bundle, file, or application ID", required_unless_present = "set_default")]
    target: Option<String>,

    #[arg(trailing_var_arg = true, allow_hyphen_values = true, help = "Arguments to pass")]
    args: Vec<String>,
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    if let Some(pair) = cli.set_default {
        let mime = &pair[0];
        let desktop_id = &pair[1];
        let home = std::env::var("HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("/"));
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

    let target = cli.target.unwrap_or_default();
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
        Err(_) => {
            // Fallback to standalone read-only launch if daemon is unavailable
            let mut registry = AppRegistry::default_for_user();
            let _ = registry.scan_readonly();
            match registry.launch_captured(&target, &cli.args) {
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
