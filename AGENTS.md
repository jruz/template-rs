# Agent instructions

`template-rs` is a minimal Rust CLI template using Clap.

## Architecture

- `src/main.rs`: entrypoint.
- `src/cli.rs`: argument parsing.
- `src/version.rs`: version metadata from the release skill.
- `build.rs`: Git revision and build timestamp with typed errors using `thiserror`.
- `tests/cli.rs`: CLI integration tests.

## Development

- Use `justfile` and `.just/` recipes for development tasks.
- Run Cargo commands through `sandbox`.
- Run `just check`, `just test`, and `slop-detector` after changes.

## Release

- `just release bump <version>` updates Cargo manifests and commits the version bump.
- Push the bump to `main`; CI handles tagging and publishing.
- `just release delete <tag>` deletes a published release and its tag.
