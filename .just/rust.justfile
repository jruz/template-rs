set working-directory := '..'

musl-target := arch() + '-unknown-linux-musl'
package-name := `nu --commands 'open Cargo.toml | get package.name'`

architecture-check:
    nu scripts/architecture-check.nu src

build:
    sandbox cargo build --all-targets

cargo-check:
    sandbox cargo check --all-targets

check:
    just rust::cargo-check
    just rust::fmt-check
    just rust::clippy-check
    just rust::machete
    just rust::architecture-check

clippy-check *ARGS='':
    sandbox cargo clippy --all-targets {{ARGS}}

clippy-fix *ARGS='':
    sandbox cargo clippy \
        --fix \
        --all-targets \
        --allow-dirty \
        {{ARGS}}

fix:
    just rust::fmt-fix
    just rust::clippy-fix

fmt-check:
    sandbox cargo fmt --all -- --check

fmt-fix:
    sandbox cargo fmt --all

install:
    sandbox cargo install \
        --path . \
        --locked \
        --force \
        --profile fast \
        --target {{musl-target}} \
        --root target/dist
    install \
        --directory \
        --mode=755 \
        "$HOME/.cargo/bin"
    install \
        --mode=755 \
        target/dist/bin/* \
        "$HOME/.cargo/bin"

machete:
    sandbox cargo machete

outdated:
    sandbox cargo outdated

run *ARGS='':
    sandbox cargo build --target {{musl-target}}
    target/docker/{{musl-target}}/debug/{{package-name}} {{ARGS}}

test *FILTER='':
    sandbox cargo nextest run \
        --no-tests=pass \
        {{FILTER}}

upgrade:
    sandbox cargo upgrade --incompatible
    sandbox cargo update

watch:
    sandbox cargo watch --exec run
