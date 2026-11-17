use lib/log.nu
use lib/targets.nu [TARGETS]


def cargo-set-version [version: string]: nothing -> nothing {
    ^sandbox cargo set-version $version
}


def git-add-release-files []: nothing -> nothing {
    ^git add Cargo.toml Cargo.lock
}


def git-commit-version [version: string]: nothing -> nothing {
    ^git commit --message $"[tool] Version: Bump to ($version)"
}


# Set the crate version and commit the bump
def "main bump" [
    version: string # new version in 0.0.0 format
]: nothing -> nothing {
    if ($version !~ '^\d+\.\d+\.\d+$') {
        log error $"invalid version format: ($version) \(expected 0.0.0\)"
        exit 1
    }

    let current = (open Cargo.toml | get package.version)
    cargo-set-version $version
    git-add-release-files
    git-commit-version $version
    log ok $"Bumped ($current) -> ($version)"
}


def find-release [tag: string]: nothing -> list<record> {
    let response = (^gh api --paginate 'repos/{owner}/{repo}/releases')
    $response | from json | where tag_name == $tag
}


def upload-draft [tag: string, artifacts: list<path>]: nothing -> record {
    if (find-release $tag | is-empty) {
        ^gh release create $tag --draft --title $tag
    }
    ^gh release upload $tag ...$artifacts --clobber
    find-release $tag | first
}


def is-manifest-current [version: string]: nothing -> bool {
    if not ('release.json' | path exists) {
        return false
    }
    (open release.json | get version) == $version
}


def commit-manifest [version: string]: nothing -> nothing {
    ^git add -- release.json
    ^git commit --only --message $"[tool] Release: Update flake to ($version)" -- release.json
}


def rebase-on-main []: nothing -> nothing {
    ^git pull --rebase origin main
}


def push-main []: nothing -> nothing {
    ^git push origin HEAD:main
}


def head-commit []: nothing -> string {
    ^git rev-parse HEAD | str trim
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


def write-manifest [version: string, release: record]: nothing -> nothing {
    let platforms = ($TARGETS
        | each {|target| release-platform $release $target }
        | each {|item| {$item.system: $item.platform} }
        | into record)
    ({version: $version, platforms: $platforms}
        | to json --indent 2
        | $"($in)\n"
        | save --force release.json)
}


# Generate release.json from the latest GitHub release assets without committing
def "main manifest-generate" []: nothing -> nothing {
    let response = (^gh api 'repos/{owner}/{repo}/releases/latest')
    let published = ($response | from json)
    let version = ($published.tag_name
        | parse --regex '^v(?<version>\d+\.\d+\.\d+)$'
        | first
        | get version)
    let name = open Cargo.toml | get package.name
    write-manifest $version {name: $name, assets: $published.assets}
    log ok $"release manifest generated: ($published.tag_name)"
}


# Build, draft, commit release.json, then publish the tag on that commit
def "main publish" []: nothing -> nothing {
    let name = open Cargo.toml | get package.name
    let version = open Cargo.toml | get package.version
    let tag = $"v($version)"
    if (is-manifest-current $version) {
        log info $"release.json already at ($version), skipping"
        return
    }
    ^nu scripts/build.nu all release
    let artifacts = glob $"target/dist/($name)-*"
    let draft = upload-draft $tag $artifacts
    write-manifest $version {name: $name, assets: $draft.assets}
    commit-manifest $version
    rebase-on-main
    push-main
    let commit = head-commit
    ^gh release edit $tag --draft=false --target $commit
    log ok $"published ($tag) at ($commit)"
}


# Delete a GitHub release and its tag
def "main delete" [
    tag: string # release tag such as v0.1.0
]: nothing -> nothing {
    ^gh release delete $tag --cleanup-tag --yes
}


# Build, publish, and manage project releases
def main []: nothing -> string {
    help main
}
