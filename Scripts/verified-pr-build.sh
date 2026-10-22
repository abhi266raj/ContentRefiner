#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
repo="${GITHUB_REPOSITORY:-abhi266raj/ContentRefiner}"
commit="$(git rev-parse HEAD)"
pr="$(gh api "repos/$repo/commits/$commit/pulls" --jq ".[] | select(.merged_at != null and .merge_commit_sha == \"$commit\" and .base.ref == \"main\") | .number" | head -1)"
[ -n "$pr" ] || { echo 'Release requires a merged PR.' >&2; exit 1; }
head="$(gh api "repos/$repo/pulls/$pr" --jq '.head.sha')"
source_tree="$(gh api "repos/$repo/git/commits/$head" --jq '.tree.sha')"
[ "$(git rev-parse 'HEAD^{tree}')" = "$source_tree" ] || { echo 'Merged source differs from the tested PR head.' >&2; exit 1; }
run="$(gh api "repos/$repo/actions/workflows/ci.yml/runs?head_sha=$head&event=pull_request&status=success" --jq '.workflow_runs[0].id')"
[ -n "$run" ] && [ "$run" != null ] || { echo 'No successful PR verification run.' >&2; exit 1; }
gh api "repos/$repo/actions/runs/$run/jobs?per_page=100" --jq '[.jobs[] | select(.conclusion == "success") | .name]' |
    ruby -rjson -e 'expected=["Mac SDK and shared app","Linux SDK and shared app","Windows SDK and shared app"]; actual=JSON.parse(STDIN.read); abort "Platform verification is incomplete" unless (expected-actual).empty?' >&2
gh api "repos/$repo/actions/runs/$run/artifacts?per_page=100" --jq '[.artifacts[] | select(.expired == false) | .name]' |
    ruby -rjson -e 'expected=["ContentRefinerMac-dist","ContentRefinerLinux-dist","ContentRefinerWindows-dist"]; actual=JSON.parse(STDIN.read); abort "Verified artifacts are missing or expired" unless (expected-actual).empty?' >&2
printf '%s\n' "$run"
