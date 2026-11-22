# Agent instructions

`template-rs` is a minimal Rust CLI template using Clap.

## Architecture

- `src/main.rs`: entrypoint, argument parsing, and command dispatch.
- `src/commands/`: one thin module per command.
- `src/core/`: business logic.
- `src/libs/`: self-contained units that could be extracted into their own crate.
- `src/utils/`: small generic helpers.
- `src/commands/version.rs`: version metadata and the version command.
- `build.rs`: Git revision and build timestamp with typed errors using `thiserror`.
- `tests/main.rs`: integration test entrypoint.
- `tests/commands/`: tests that run the binary, one file per command.
- `tests/utils/`: shared test helpers.

## Layers

- `main.rs` calls `commands` and `utils`.
- `commands` calls `core` and `utils`.
- `core` calls `libs` and `utils`.
- `libs` calls `utils`.
- `utils` calls nothing.
- `just rust::architecture-check` enforces these rules with `scripts/architecture-check.nu`.

## Development

- Use `justfile` and `.just/` recipes for development tasks.
- Run Cargo commands through `sandbox`.
- `just check` verifies formatting and lint rules.
- `just test` runs the test suite.
- Run `slop-detector` after changes.

## Configuration tools

- `just tools::check` validates configuration separately from CI.
- `just tools::fix` formats configuration.
- `.tools/` provides its own Nix shell through `.just/tools.justfile`.

## Release

- `just release bump <patch|minor|major>` starts a Woodpecker release using the Cargo version on `origin/main`.
- Retry the same Woodpecker run to resume an interrupted publication without bumping the version again.
- `just release delete <tag>` deletes a published release and its tag.
- `nu tests/release/release.test.nu` runs the release workflow regression tests.
