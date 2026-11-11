set working-directory := '..'

fmt-check:
    just \
        --unstable \
        --fmt \
        --check

fmt-fix:
    just \
        --unstable \
        --fmt
