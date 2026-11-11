# template-rust

A minimal Rust CLI template using Clap.

## Development

- `just run`
- `just check`
- `just test`
- `just install`

## Install from releases

Download the binary for your platform from [the latest release](https://github.com/jruz/template-rust/releases/latest):

| Platform | Download |
| --- | --- |
| Linux x86_64 | [Download](https://github.com/jruz/template-rust/releases/latest/download/template-rust-unknown-linux-musl-x86_64) |
| Linux ARM64 | [Download](https://github.com/jruz/template-rust/releases/latest/download/template-rust-unknown-linux-musl-aarch64) |
| macOS Intel | [Download](https://github.com/jruz/template-rust/releases/latest/download/template-rust-apple-darwin-x86_64) |
| macOS Apple Silicon | [Download](https://github.com/jruz/template-rust/releases/latest/download/template-rust-apple-darwin-aarch64) |

For example, on Linux x86_64:

```sh
curl --fail --location --output template-rust \
  https://github.com/jruz/template-rust/releases/latest/download/template-rust-unknown-linux-musl-x86_64
chmod +x template-rust
./template-rust --version
```

Move the binary into a directory on your `PATH` to run it from anywhere.

## Install with Nix

Requires Nix with flakes enabled.

```sh
nix profile add github:jruz/template-rust
```

Installs a published binary without compiling Rust. Supports Linux and macOS on x86_64 and aarch64.

Verify the installation:

```sh
template-rust --version
```

Upgrade:

```sh
nix profile upgrade template-rust
```

Run without installing:

```sh
nix run github:jruz/template-rust -- --help
```

Build from source instead:

```sh
nix build github:jruz/template-rust#source
```

## Licence

Licensed under the [EUPL 1.2](LICENSE).
