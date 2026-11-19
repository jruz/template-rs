use std/assert

const SCRIPT = path self | path dirname | path join ../../scripts/release.nu
const MOCK = path self | path dirname | path join release.mock.nu
const FILES = [
    fixture-unknown-linux-musl-x86_64
    fixture-unknown-linux-musl-aarch64
    fixture-apple-darwin-x86_64
    fixture-apple-darwin-aarch64
]
const VERSION = '0.2.0'


def main []: nothing -> nothing {
    test-bump-triggers-manual-pipeline
    test-bump-rejects-invalid-kind
    test-manifest-generate
    test-release-rebuilds-once-if-main-advances
    test-release-stops-if-main-advances-twice
    test-release-does-not-retry-unrelated-push-errors
    test-release-does-not-push-if-upload-fails
    test-release-resumes-after-push-without-rebuilding
    print '8 release regression tests passed'
}


def fixture []: nothing -> record {
    let root = (mktemp --directory)
    let repo = ($root | path join project)
    let remote = ($root | path join remote.git)
    let state = ($root | path join releases.json)
    ^git init --quiet --bare --initial-branch=main $remote
    mkdir $repo ($root | path join bin)
    cp $MOCK ($root | path join bin gh)
    cd $repo
    ^git init --quiet --initial-branch=main
    ^git config user.name Fixture
    ^git config user.email fixture@example.com
    ^git config commit.gpgsign false
    ^git config core.hooksPath /dev/null
    ^git --git-dir $remote config user.name Fixture
    ^git --git-dir $remote config user.email fixture@example.com
    ^git remote add origin $"file://($remote)"
    '[package]
name = "fixture"
version = "0.1.0"
' | save Cargo.toml
    'version = "0.1.0"' | save Cargo.lock
    '[]' | save $state
    write-build-script
    write-mocks ($root | path join bin)
    ^git add Cargo.toml Cargo.lock scripts/build.nu
    ^git commit --quiet --message initial
    push-fixture
    {
        root: $root
        repo: $repo
        remote: $remote
        state: $state
        base: (remote-head $remote)
    }
}


def push-fixture []: nothing -> nothing {
    ^git push --quiet origin main
}


def write-build-script []: nothing -> nothing {
    mkdir scripts
    '
        def main [targets: string, profile: string] {
            let remote = $env.NU_RELEASE_TEST_REMOTE
            let log = $"($env.NU_RELEASE_TEST_STATE).builds"
            $"($env.REVISION)\n" | save --append $log
            let build = (open --raw $log | lines | length)
            if $build <= ($env.NU_RELEASE_TEST_ADVANCES | into int) {
                let parent = (^git --git-dir $remote rev-parse main | str trim)
                let next = (^git --git-dir $remote commit-tree "main^{tree}" -p $parent -m concurrent | str trim)
                ^git --git-dir $remote update-ref refs/heads/main $next $parent
            }
            mkdir target/dist
            for file in ($env.NU_RELEASE_TEST_FILES | from nuon) {
                $"($env.REVISION):($file)" | encode utf-8 | append 0x[FF00] | save --raw --force $"target/dist/($file)"
            }
        }
    ' | save scripts/build.nu
}


def write-mocks [bin: path]: nothing -> nothing {
    let sandbox = ($bin | path join sandbox)
    '#!/usr/bin/env nu
        def main [cargo: string, action: string, version: string] {
            for file in [Cargo.toml Cargo.lock] {
                open --raw $file | str replace "0.1.0" $version | save --force $file
            }
        }
    ' | save $sandbox
    let nix = ($bin | path join nix)
    '#!/usr/bin/env nu
        use std/assert
        def --wrapped main [...args: string] {
            assert equal $args [develop --no-update-lock-file --command just check test]
            $"($env.REVISION)\n" | save --append $"($env.NU_RELEASE_TEST_STATE).checks"
        }
    ' | save $nix
    let woodpecker = ($bin | path join woodpecker-cli)
    '#!/usr/bin/env nu
        def --wrapped main [...args: string] {
            print ($args | to nuon)
        }
    ' | save $woodpecker
    ^chmod +x ($bin | path join gh) $sandbox $nix $woodpecker
}


def remote-head [remote: path]: nothing -> string {
    ^git --git-dir $remote rev-parse main | str trim
}


def invoke [f: record, args: list<string>, --mode: string, --advances: int, --repo: path]: nothing -> record {
    cd (if $repo == null { $f.repo } else { $repo })
    with-env {
        PATH: ($env.PATH | prepend ($f.root | path join bin))
        NU_RELEASE_TEST_STATE: $f.state
        NU_RELEASE_TEST_REMOTE: $f.remote
        NU_RELEASE_TEST_MODE: (if $mode == null { 'normal' } else { $mode })
        NU_RELEASE_TEST_ADVANCES: (if $advances == null { '0' } else { $advances | into string })
        NU_RELEASE_TEST_FILES: ($FILES | to nuon)
    } {
        ^nu $SCRIPT ...$args | complete
    }
}


def builds [f: record]: nothing -> list<string> {
    open --raw $"($f.state).builds" | lines
}


def writes [f: record]: nothing -> list<list<string>> {
    (open --raw $"($f.state).calls"
        | lines
        | each {|line| $line | from nuon }
        | where $it.0 == 'release')
}


def test-bump-triggers-manual-pipeline []: nothing -> nothing {
    let cwd = $env.PWD
    let f = fixture
    cd $f.repo
    open --raw Cargo.toml | str replace '0.1.0' '1.2.3' | save --force Cargo.toml
    ^git commit --quiet --message 'Advance version on main' -- Cargo.toml
    push-fixture
    let remote_head = (remote-head $f.remote)
    ^git switch --quiet --detach $f.base
    ^git update-ref refs/remotes/origin/main $f.base

    let cases = [[kind version url];
        [patch '1.2.4' 'git@github.com:fixture-owner/fixture-repo.git']
        [minor '1.3.0' 'https://github.com/fixture-owner/fixture-repo']
        [major '2.0.0' 'ssh://git@github.com/fixture-owner/fixture-repo.git']
    ]
    for case in $cases {
        ^git remote set-url origin $case.url
        ^git config --add $"url.file://($f.remote).insteadOf" $case.url
        let result = (invoke $f [bump $case.kind])
        assert equal $result.exit_code 0 $result.stderr
        let version_arg = $"RELEASE_VERSION=($case.version)"
        assert equal ($result.stdout | from nuon) [pipeline create --branch main --var $version_arg fixture-owner/fixture-repo]
    }
    assert equal (^git rev-parse HEAD | str trim) $f.base
    assert equal (open Cargo.toml | get package.version) '0.1.0'
    assert equal (remote-head $f.remote) $remote_head
    cd $cwd
    rm --permanent --recursive $f.root
}


def test-bump-rejects-invalid-kind []: nothing -> nothing {
    let f = fixture
    let result = (invoke $f [bump typo])
    assert equal $result.exit_code 1
    assert str contains $result.stderr 'Expected patch, minor, or major'
    rm --permanent --recursive $f.root
}


def test-manifest-generate []: nothing -> nothing {
    let f = fixture
    let digest = 'sha256:0000000000000000000000000000000000000000000000000000000000000000'
    let assets = ($FILES | each {|name| {name: $name, digest: $digest} })
    [
        {tag_name: v1.2.3, assets: $assets}
    ] | to json | save --force $f.state
    let result = (invoke $f [manifest-generate])
    assert equal $result.exit_code 0 $result.stderr
    let manifest = (open ($f.repo | path join release.json))
    assert equal $manifest.version '1.2.3'
    assert equal $manifest.platforms.x86_64-linux.hash 'sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
    assert equal (remote-head $f.remote) $f.base
    rm --permanent --recursive $f.root
}


def test-release-rebuilds-once-if-main-advances []: nothing -> nothing {
    let f = fixture
    let result = (invoke $f [publish $VERSION] --advances 1)
    assert equal $result.exit_code 0 $result.stderr
    let head = (remote-head $f.remote)
    let parent = (^git --git-dir $f.remote rev-parse 'main^' | str trim)
    assert equal (builds $f) [$f.base $parent]
    assert equal (open --raw $"($f.state).checks" | lines) [$f.base $parent]
    let files = (^git --git-dir $f.remote diff-tree --no-commit-id --name-only -r $head)
    assert equal ($files | lines) [Cargo.lock Cargo.toml release.json]
    let version_file = (^git --git-dir $f.remote show main:Cargo.toml)
    assert equal ($version_file | from toml | get package.version) $VERSION
    let manifest = (^git --git-dir $f.remote show main:release.json | from json)
    assert equal $manifest.version $VERSION
    let tag = (^git --git-dir $f.remote rev-parse v0.2.0 | str trim)
    assert equal $tag $head
    assert equal (open $f.state | length) 1
    assert equal (open $f.state | first | get draft) false
    rm --permanent --recursive $f.root
}


def test-release-stops-if-main-advances-twice []: nothing -> nothing {
    let f = fixture
    let result = (invoke $f [publish $VERSION] --advances 2)
    assert equal $result.exit_code 1
    assert str contains $result.stderr 'main advanced again'
    assert equal (builds $f | length) 2
    let commits = (^git --git-dir $f.remote log --format=%s $"($f.base)..main" | lines)
    assert equal $commits [concurrent concurrent]
    assert equal (open $f.state) []
    rm --permanent --recursive $f.root
}


def test-release-does-not-retry-unrelated-push-errors []: nothing -> nothing {
    let f = fixture
    let hook = ($f.remote | path join hooks pre-receive)
    '#!/bin/sh
exit 1
' | save $hook
    ^chmod +x $hook
    let result = (invoke $f [publish $VERSION])
    assert equal $result.exit_code 1
    assert str contains $result.stderr 'pre-receive hook declined'
    assert equal (builds $f) [$f.base]
    assert equal (remote-head $f.remote) $f.base
    assert equal (open $f.state | first | get draft) true
    rm --permanent --recursive $f.root
}


def test-release-does-not-push-if-upload-fails []: nothing -> nothing {
    let f = fixture
    let result = (invoke $f [publish $VERSION] --mode upload-fails)
    assert equal $result.exit_code 17
    assert equal (remote-head $f.remote) $f.base
    assert equal (open $f.state | first | get draft) true
    rm --permanent --recursive $f.root
}


def test-release-resumes-after-push-without-rebuilding []: nothing -> nothing {
    let f = fixture
    let interrupted = (invoke $f [publish $VERSION] --mode interrupt)
    assert equal $interrupted.exit_code 130 $interrupted.stderr
    let commit = (remote-head $f.remote)
    assert not equal $commit $f.base
    assert equal (open $f.state | first | get draft) true
    let next = (^git --git-dir $f.remote commit-tree 'main^{tree}' -p $commit -m newer | str trim)
    ^git --git-dir $f.remote update-ref refs/heads/main $next $commit
    let retry = ($f.root | path join retry)
    ^git clone --quiet --depth=1 $"file://($f.remote)" $retry
    rm $"($f.state).calls"
    let resumed = (invoke $f [publish $VERSION] --repo $retry)
    assert equal $resumed.exit_code 0 $resumed.stderr
    assert equal (builds $f) [$f.base]
    assert equal (remote-head $f.remote) $next
    let draft = $"v0.2.0-draft-($commit)"
    let publication = [release edit $draft --tag v0.2.0 --draft=false --target $commit]
    assert equal (writes $f) [$publication]
    let repeated = (invoke $f [publish $VERSION] --repo $retry)
    assert equal $repeated.exit_code 0 $repeated.stderr
    assert equal (writes $f | length) 1
    rm --permanent --recursive $f.root
}
