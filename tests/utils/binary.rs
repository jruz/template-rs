use std::process::{Command, Output};

pub fn run(arguments: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_template-rs"))
        .args(arguments)
        .output()
        .expect("run CLI")
}

pub fn stdout(output: &Output) -> String {
    let bytes = output.stdout.clone();
    String::from_utf8(bytes).expect("UTF-8 output")
}

pub fn stderr(output: &Output) -> String {
    let bytes = output.stderr.clone();
    String::from_utf8(bytes).expect("UTF-8 output")
}
