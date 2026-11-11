mod commands;
mod utils;

use std::process::ExitCode;

use clap::Parser as _;
use commands::version;
use utils::output::Output;

#[derive(Debug, clap::Parser)]
#[command(version = version::text(), about = "A minimal Rust CLI template")]
struct Arguments {
    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Clone, Copy, Debug, clap::Subcommand)]
enum Command {
    #[command(about = "Show version and build metadata")]
    Version,
}

fn run(command: Command) -> Output {
    match command {
        Command::Version => version::run(),
    }
}

fn main() -> ExitCode {
    let arguments = Arguments::parse();
    let Some(command) = arguments.command else {
        return ExitCode::SUCCESS;
    };
    let output = run(command);
    print!("{}", output.text);
    if output.success {
        return ExitCode::SUCCESS;
    }
    ExitCode::FAILURE
}
