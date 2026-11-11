set working-directory := '..'

run +ARGS:
    nu scripts/release.nu {{ ARGS }}
