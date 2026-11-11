mod rust '.just/rust.justfile'
mod release '.just/release.justfile'
mod just '.just/just.justfile'

check:
    just just::fmt-check
    just rust::check

fix:
    just just::fmt-fix
    just rust::fix

setup:
    just git-hooks

install:
    just rust::install

test:
    just rust::test

run *ARGS='':
    just rust::run {{ ARGS }}

git-hooks:
    git config --local core.hooksPath .githooks
