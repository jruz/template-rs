mod rust '.just/rust.justfile'
mod just '.just/just.justfile'
mod oxfmt '.just/oxfmt.justfile'
mod git '.just/git.justfile'
mod tools '.just/tools.justfile'

check:
    just just::fmt-check
    just oxfmt::fmt-check
    just rust::check

fix:
    just just::fmt-fix
    just oxfmt::fmt-fix
    just rust::fix

setup:
    just git::hooks-setup

install:
    just rust::install

test:
    just rust::test

run *ARGS='':
    just rust::run {{ ARGS }}

[positional-arguments]
release +ARGS:
    nu scripts/release.nu "$@"
