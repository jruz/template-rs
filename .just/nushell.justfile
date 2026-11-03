set working-directory := '..'

check:
    fd \
        --absolute-path \
        --extension nu \
        --exec nu --no-config-file \
        --commands 'if not (nu-check --debug "{}") { exit 1 }'
    nu-lint --config nu-lint.toml .

fix:
    nu-lint \
        --config nu-lint.toml \
        --fix \
        .
