#[cfg(test)]
mod tests {
    fn run(arguments: &[&str]) -> std::process::Output {
        std::process::Command::new(env!("CARGO_BIN_EXE_template-rust"))
            .args(arguments)
            .output()
            .expect("run CLI")
    }

    #[test]
    fn help_describes_template() {
        let output = run(&["--help"]);
        assert!(output.status.success());
        let help = String::from_utf8(output.stdout).expect("UTF-8 help");
        assert!(help.contains("template-rust"));
        assert!(help.contains("--help"));
        assert!(help.contains("--version"));
        assert!(!help.contains("Commands:"));
    }

    #[test]
    fn version_includes_build_metadata() {
        for argument in ["--version", "-V"] {
            let output = run(&[argument]);
            assert!(output.status.success());
            let version = String::from_utf8(output.stdout).expect("UTF-8 version");
            assert!(version.starts_with("template-rust \n"));
            assert!(version.contains(concat!("version: ", env!("CARGO_PKG_VERSION"))));
            assert!(version.contains(concat!("revision: ", env!("REVISION"))));
            assert!(version.contains(concat!("build-time: ", env!("BUILD_TIME"))));
        }
    }

    #[test]
    fn no_arguments_succeeds() {
        let output = run(&[]);
        assert!(output.status.success());
        let empty: &[u8] = &[];
        assert_eq!(output.stdout, empty);
        assert_eq!(output.stderr, empty);
    }

    #[test]
    fn removed_commands_are_rejected() {
        for command in ["pull", "plan", "push", "schema"] {
            let output = run(&[command]);
            assert!(!output.status.success());
            let error = String::from_utf8(output.stderr).expect("UTF-8 error");
            assert!(error.contains("unexpected argument"));
        }
    }
}
