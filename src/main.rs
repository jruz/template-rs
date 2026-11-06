mod cli;
mod version;

use clap::Parser as _;

fn main() {
    cli::Arguments::parse();
}
