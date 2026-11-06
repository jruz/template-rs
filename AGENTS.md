# Agent instructions

`template-rust` is a minimal Rust CLI template using Clap.

## Architecture

- `src/main.rs`: entrypoint.
- `src/cli.rs`: argument parsing and version display.
- `build.rs`: Git revision and build timestamp with typed errors using `thiserror`.
- `tests/cli.rs`: CLI integration tests.

## Development

- Use `justfile` and `.just/` recipes for development tasks.
- Run Cargo commands through `sandbox`.
- Run `just check`, `just test`, and `slop-detector` after changes.
