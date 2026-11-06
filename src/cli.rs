use crate::version;

#[derive(Debug, clap::Parser)]
#[command(version = version::clap_version(), about = "A minimal Rust CLI template")]
pub struct Arguments;
