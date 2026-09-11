use clap::Parser;
use conjunction_core::AppRegistry;
use std::process::ExitCode;
use std::thread;
use std::time::Duration;

#[derive(Parser, Debug)]
#[command(name = "conj-appd", version = "0.1.0", about = "Conjunction Application Services daemon")]
struct Cli {
    #[arg(long, help = "Run single reconciliation and exit")]
    oneshot: bool,

    #[arg(long, default_value = "2", help = "Polling / watch interval in seconds")]
    interval: u64,
}

fn main() -> ExitCode {
    env_logger::init();
    let cli = Cli::parse();
    let mut registry = AppRegistry::default_for_user();

    log::info!("Starting Conjunction Application Daemon (conj-appd)...");
    if let Err(e) = registry.reconcile() {
        log::error!("Initial reconciliation error: {}", e);
        if cli.oneshot {
            return ExitCode::FAILURE;
        }
    } else {
        log::info!("Initial reconciliation complete.");
    }

    if cli.oneshot {
        return ExitCode::SUCCESS;
    }

    log::info!("Monitoring application directories (interval: {}s)...", cli.interval);
    loop {
        thread::sleep(Duration::from_secs(cli.interval));
        if let Err(e) = registry.reconcile() {
            log::warn!("Reconciliation error: {}", e);
        }
    }
}
