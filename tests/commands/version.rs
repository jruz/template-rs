use crate::utils::binary::{run, stderr, stdout};

#[test]
fn includes_build_metadata() {
    let output = run(&["version"]);
    assert!(output.status.success());
    assert_eq!(stderr(&output), "");
    let version = stdout(&output);
    assert!(version.starts_with(concat!(
        "template-rs \nversion: ",
        env!("CARGO_PKG_VERSION")
    )));
    assert!(version.contains(concat!("revision: ", env!("REVISION"))));
    assert!(version.contains(concat!("build-time: ", env!("BUILD_TIME"))));
}

#[test]
fn long_flag_matches_command() {
    let command = run(&["version"]);
    let flag = run(&["--version"]);
    assert!(flag.status.success());
    assert_eq!(stdout(&flag), stdout(&command));
}

#[test]
fn short_flag_matches_command() {
    let command = run(&["version"]);
    let flag = run(&["-V"]);
    assert!(flag.status.success());
    assert_eq!(stdout(&flag), stdout(&command));
}
