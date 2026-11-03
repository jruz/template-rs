use log.nu

const BUILD_IMAGE = 'docker.io/messense/cargo-zigbuild:0.23.4'
const TARGETS = [
    {os: unknown-linux-musl, arch: x86_64}
    {os: unknown-linux-musl, arch: aarch64}
    {os: apple-darwin, arch: x86_64}
    {os: apple-darwin, arch: aarch64}
]


def select-targets [target: string]: nothing -> list<record> {
    let selected = $TARGETS | where $target == all or $"($it.arch)-($it.os)" == $target
    if ($selected | is-empty) {
        let expected = $TARGETS
            | each {|item| $"($item.arch)-($item.os)" }
            | prepend all
            | str join ', '
        error make {msg: $"unknown release target: ($target)\nexpected: ($expected)"}
    }
    $selected
}


def build-command [build: record]: nothing -> string {
    let triples = $build.targets | each {|target| $"($target.arch)-($target.os)" }
    let install_targets = $triples | str join ','
    let build_targets = $triples | each {|triple| $"--target ($triple)" } | str join ' '
    let copies = $build.targets | each {|target|
        let source = $"/build-cache/($target.arch)-($target.os)/release/($build.name)"
        let destination = $"($build.name)-($target.os)-($target.arch)"
        $"cp ($source) ($destination)"
    }
    [
        'set -euo pipefail'
        $"rustup toolchain install ($build.toolchain) --profile minimal --no-self-update --target ($install_targets)"
        $"cargo zigbuild --locked --release ($build_targets)"
        ...$copies
    ] | str join (char newline)
}


def project-cache-prefix []: nothing -> string {
    let remote = (^git remote get-url origin | complete)
    if $remote.exit_code != 0 {
        error make {msg: ($remote.stderr | str trim)}
    }
    let name = $remote.stdout | str trim | path basename | str replace --regex '\.git$' ''
    $"($name)-release"
}


def run-build [build: record]: nothing -> nothing {
    log info $"building ($build.name) for ($build.targets | length) release targets"
    let cache_prefix = project-cache-prefix
    let image_key = $BUILD_IMAGE | hash sha256 | str substring 0..11
    let target_volume = $"($cache_prefix)-target-($build.toolchain)-($image_key)"
    (^podman run
        --rm
        --volume $"(pwd):/workspace"
        --volume $"($cache_prefix)-rustup:/usr/local/rustup:nocopy"
        --volume $"($cache_prefix)-registry:/usr/local/cargo/registry:nocopy"
        --volume $"($cache_prefix)-git:/usr/local/cargo/git:nocopy"
        --volume $"($target_volume):/build-cache:nocopy"
        --workdir /workspace
        --env REVISION
        --env $"RUSTUP_TOOLCHAIN=($build.toolchain)"
        --env CARGO_TARGET_DIR=/build-cache
        --env XDG_CACHE_HOME=/build-cache/cache
        $BUILD_IMAGE
        bash -c (build-command $build))
}


def fail [label: string, stderr: string]: nothing -> error {
    let trimmed = ($stderr | str trim)
    let message = if ($trimmed | is-empty) {
        $"($label) failed"
    } else {
        $"($label) failed: ($trimmed)"
    }
    error make {msg: $message}
}


def cargo-set-version [version: string]: nothing -> nothing {
    let result = (^sandbox cargo set-version $version | complete)
    if $result.exit_code != 0 {
        fail "cargo set-version" $result.stderr
    }
}


def git-add-release-files []: nothing -> nothing {
    let result = (^git add Cargo.toml Cargo.lock | complete)
    if $result.exit_code != 0 {
        fail "git add" $result.stderr
    }
}


def git-commit-version [version: string]: nothing -> nothing {
    let result = (^git commit --message $"[tool] Version: Bump to ($version)" | complete)
    if $result.exit_code != 0 {
        fail "git commit" $result.stderr
    }
}


def "main build" [target: string]: nothing -> nothing {
    try {
        let build = {
            name: (open Cargo.toml | get package.name)
            toolchain: (open rust-toolchain.toml | get toolchain.channel)
            targets: (select-targets $target)
        }
        run-build $build
        for target in $build.targets {
            log ok $"($build.name)-($target.os)-($target.arch)"
        }
    } catch {|err|
        print --stderr $"ERROR: ($err.msg)"
        exit 1
    }
}


def "main bump" [version: string]: nothing -> nothing {
    if ($version !~ '^\d+\.\d+\.\d+$') {
        print --stderr $"ERROR: invalid version format: ($version) \(expected 0.0.0\)"
        exit 1
    }

    try {
        let current = (open Cargo.toml | get package.version)
        cargo-set-version $version
        git-add-release-files
        git-commit-version $version
        log ok $"Bumped ($current) -> ($version)"
    } catch {|err|
        print --stderr $"ERROR: ($err.msg)"
        exit 1
    }
}


def "main upload" [tag: string]: nothing -> nothing {
    try {
        let release = (^gh release view $tag | complete)
        if $release.exit_code != 0 {
            ^gh release create $tag --title $tag --verify-tag
        }
        let artifacts = glob $"($env.CI_REPO_NAME)-*"
        ^gh release upload $tag ...$artifacts --clobber
    } catch {|err|
        print --stderr $"ERROR: ($err.msg)"
        exit 1
    }
}


def release-platform [release: record, target: record]: nothing -> record {
    let asset_name = $"($release.name)-($target.os)-($target.arch)"
    let asset = ($release.assets | where name == $asset_name | first)
    let digest = ($asset.digest | parse --regex '^sha256:(?<hex>[0-9a-f]{64})$' | first)
    let hash = ($digest.hex | decode hex | encode base64)
    let os = if $target.os == unknown-linux-musl { 'linux' } else { 'darwin' }
    {
        system: $"($target.arch)-($os)"
        platform: {asset: $asset_name, hash: $"sha256-($hash)"}
    }
}


def "main flake-update" []: nothing -> nothing {
    try {
        let response = (^gh api 'repos/{owner}/{repo}/releases/latest' | complete)
        if $response.exit_code != 0 {
            fail 'latest release' $response.stderr
        }
        let published = ($response.stdout | from json)
        let version = ($published.tag_name
            | parse --regex '^v(?<version>\d+\.\d+\.\d+)$'
            | first
            | get version)
        let release = {name: (open Cargo.toml | get package.name), assets: $published.assets}
        let platforms = ($TARGETS
            | each {|target| release-platform $release $target }
            | reduce --fold {} {|item, result|
                $result | insert $item.system $item.platform
            })
        {version: $version, platforms: $platforms}
            | to json --indent 2
            | $"($in)\n"
            | save --force release.json
        log ok $"flake release updated: ($published.tag_name)"
    } catch {|err|
        print --stderr $"ERROR: ($err.msg)"
        exit 1
    }
}


def "main delete" [tag: string]: nothing -> nothing {
    try {
        ^gh release delete $tag --cleanup-tag --yes
    } catch {|err|
        print --stderr $"ERROR: ($err.msg)"
        exit 1
    }
}


def main []: nothing -> string {
    help main
}
