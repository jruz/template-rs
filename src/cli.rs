const VERSION_STRING: &str = concat!(
    "\nversion: ",
    env!("CARGO_PKG_VERSION"),
    "\nrevision: ",
    env!("REVISION"),
    "\nbuild-time: ",
    env!("BUILD_TIME"),
);

#[derive(Debug, clap::Parser)]
#[command(version = VERSION_STRING, about = "A minimal Rust CLI template")]
pub struct Arguments;
