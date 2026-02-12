mod config;
mod policy;
mod registry;

use std::path::PathBuf;

use anyhow::Result;
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "edge-profile", about = "Portable Edge settings via HKCU registry policies")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Write policies to the registry from config
    Apply {
        /// Print what would be written without modifying the registry
        #[arg(long)]
        dry_run: bool,

        /// Path to config file (default: ~/.edge-profile/config.toml)
        #[arg(long)]
        config: Option<PathBuf>,
    },
    /// Print current HKCU Edge policies
    Dump,
    /// Remove only the policies this tool manages
    Clean {
        /// Skip confirmation prompt
        #[arg(short)]
        y: bool,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Command::Apply { dry_run, config } => {
            let cfg = config::load(config.as_deref())?;
            let entries = policy::build_entries(&cfg);

            if dry_run {
                println!("Dry run — the following policies would be written:\n");
                for entry in &entries {
                    println!("  {}", entry);
                }
                println!("\n({} values total)", entries.len());
            } else {
                registry::check_hklm_conflicts(&entries);
                registry::apply(&entries)?;
                println!("Applied {} policy values.", entries.len());
            }
        }
        Command::Dump => {
            registry::dump()?;
        }
        Command::Clean { y } => {
            if !y {
                eprint!("Remove all edge-profile managed policies? [y/N] ");
                let mut input = String::new();
                std::io::stdin().read_line(&mut input)?;
                if !input.trim().eq_ignore_ascii_case("y") {
                    println!("Aborted.");
                    return Ok(());
                }
            }
            registry::clean()?;
            println!("Cleaned managed policies.");
        }
    }

    Ok(())
}
