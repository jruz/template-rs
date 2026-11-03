mod rust '.just/rust.justfile'
mod nix '.just/nix.justfile'
mod nushell '.just/nushell.justfile'
import '.just/release.justfile'

check:
    just just-fmt-check
    just nix::check
    just nushell::check
    just rust::check
    just woodpecker-check

fix:
    just just-fmt-fix
    just nix::fix
    just nushell::fix
    just rust::fix

setup:
    just git-hooks

install:
    just rust::install

test:
    just rust::test

run *ARGS='':
    just rust::run {{ ARGS }}

woodpecker-check:
    woodpecker-cli lint .woodpecker/*.yml

just-fmt-check:
    just \
        --unstable \
        --fmt \
        --check

just-fmt-fix:
    just \
        --unstable \
        --fmt

git-hooks:
    git config --local core.hooksPath .githooks
