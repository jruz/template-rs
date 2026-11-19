#!/usr/bin/env nu

use std/assert

const RELEASES = 'repos/{owner}/{repo}/releases'

def publish [request: record, releases: list<record>]: nothing -> nothing {
    let remote = $env.NU_RELEASE_TEST_REMOTE
    ^git --git-dir $remote merge-base --is-ancestor $request.commit main
    let published_commit = (^git --git-dir $remote log --max-count=1 --format=%H main -- release.json | str trim)
    assert equal $request.commit $published_commit
    assert equal $request.draft $"($request.tag)-draft-($request.commit)"
    let release = ($releases | where tag_name == $request.draft | first)
    assert equal $release.draft true
    ^git --git-dir $remote tag $request.tag $request.commit
    [($release | update tag_name $request.tag | update draft false)] | to json | save --force $env.NU_RELEASE_TEST_STATE
}

def --wrapped main [
    ...arguments: string # GitHub CLI arguments
]: nothing -> nothing {
    let state = $env.NU_RELEASE_TEST_STATE
    let releases = (open $state)
    let call = ($arguments | to nuon)
    $"($call)\n" | save --append $"($state).calls"
    match $arguments {
        [api 'repos/{owner}/{repo}/releases/latest'] => {
            $releases | first | to json | print --no-newline
        }
        [api --paginate --slurp $RELEASES] => { [$releases] | to json | print --no-newline }
        [release create $draft --draft --title $tag --notes ''] => {
            assert ($releases | all {|release| $release.tag_name != $draft })
            $releases | append {tag_name: $draft, draft: true, assets: []} | to json | save --force $state
        }
        [release upload $draft ..$files] => {
            if $env.NU_RELEASE_TEST_MODE == 'upload-fails' {
                exit 17
            }
            assert equal ($files | last) '--clobber'
            let assets = ($files | drop | each {|file|
                let digest = (open --raw $file | hash sha256)
                {name: ($file | path basename), digest: $"sha256:($digest)"}
            })
            $releases | update 0.assets $assets | to json | save --force $state
        }
        [release delete $draft --yes] => {
            $releases | where tag_name != $draft | to json | save --force $state
        }
        [release edit $draft --tag $tag --draft=false --target $commit] => {
            if $env.NU_RELEASE_TEST_MODE == 'interrupt' {
                exit 130
            }
            publish {draft: $draft, tag: $tag, commit: $commit} $releases
        }
        _ => { exit 99 }
    }
}
