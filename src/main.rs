mod cli;

use clap::Parser as _;

fn main() {
    cli::Arguments::parse();
}
