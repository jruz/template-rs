use crate::utils::binary::{run, stderr, stdout};

#[test]
fn describes_template() {
    let output = run(&["--help"]);
    assert!(output.status.success());
    let help = stdout(&output);
    assert!(help.contains("template-rs"));
    assert!(help.contains("--help"));
    assert!(help.contains("--version"));
    assert!(help.contains("version  Show version and build metadata"));
}

#[test]
fn no_arguments_succeeds() {
    let output = run(&[]);
    assert!(output.status.success());
    assert_eq!(stdout(&output), "");
    assert_eq!(stderr(&output), "");
}

#[test]
fn nonexistent_command_is_rejected() {
    let output = run(&["nonexistent-command"]);
    let exit_code: i32 = 2;
    assert_eq!(output.status.code(), Some(exit_code));
    assert_eq!(stdout(&output), "");
    assert!(stderr(&output).contains("unrecognized subcommand 'nonexistent-command'"));
}
