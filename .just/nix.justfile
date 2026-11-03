set working-directory := '..'

check:
    fd \
        --extension nix \
        --exec nixfmt --check
    statix check .
    deadnix --fail .

fix:
    fd \
        --extension nix \
        --exec nixfmt
    statix fix .
    deadnix --edit .
