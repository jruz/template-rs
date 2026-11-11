# Agent instructions

`template-rs` is a minimal Rust CLI template using Clap.

## Architecture

- `src/main.rs`: entrypoint, argument parsing, and command dispatch.
- `src/commands/`: one thin module per command.
- `src/core/`: business logic.
- `src/libs/`: self-contained units that could be extracted into their own crate.
- `src/utils/`: small generic helpers.
- `src/commands/version.rs`: version metadata from the release skill.
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
- Run `just check`, `just test`, and `slop-detector` after changes.

## Template maintenance

- `.tools/` contains template-only configuration validators.
- Run `nix develop ./.tools --command just --justfile .tools/justfile check` after configuration changes.
- Run `nix develop ./.tools --command just --justfile .tools/justfile fix` to format configuration.
- Delete `.tools/` and this section in generated projects.
- `template.json` excludes these tools from downstream syncs.

## Release

- `just release::run bump <version>` updates Cargo manifests and commits the version bump.
- Push the bump to `main`; CI handles tagging and publishing.
- `just release::run delete <tag>` deletes a published release and its tag.
