#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
repo=abhi266raj/ContentRefiner
source_commit="$(git rev-parse HEAD)"
test -z "$(git status --porcelain)"
changes="$(mktemp)"
notes="$(mktemp)"
trap 'rm -f "$changes" "$notes"' EXIT
ruby Scripts/versions.rb "${1:-}" > "$changes"
ruby -rjson -e 'JSON.parse(File.read(ARGV[0])).each{|x|puts [x["name"],x["version"],x["tag"]].join(" ")}' "$changes" |
while read -r name version tag; do
  existing="$(git rev-parse --verify "refs/tags/$tag^{commit}" 2>/dev/null || true)"
  if [ -n "$existing" ]; then test "$existing" = "$source_commit"; else
    git -c user.name='github-actions[bot]' -c user.email='41898282+github-actions[bot]@users.noreply.github.com' -c tag.gpgsign=false tag -a "$tag" -m "$name $version"
    git push origin "refs/tags/$tag"
  fi
  if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then continue; fi
  printf '# %s %s\n\nCorresponding source: %s\n\n' "$name" "$version" "$source_commit" > "$notes"
  cat docs/releases/0.1.0.md >> "$notes"
  assets=()
  case "$name" in
    ContentRefinerMac) assets=("dist/ContentRefinerMac-$version.zip" "dist/ContentRefinerMac-$version.dmg");;
    ContentRefinerLinux) assets=("dist/ContentRefinerLinux-$version.tar.gz");;
    ContentRefinerWindows) assets=("dist/ContentRefinerWindows-$version.zip");;
    ContentRefiner) while IFS= read -r file; do assets+=("$file"); done < <(find dist -maxdepth 1 -type f \( -name '*.zip' -o -name '*.dmg' -o -name '*.tar.gz' \) | sort);;
  esac
  for asset in "${assets[@]}"; do test -s "$asset"; done
  gh release create "$tag" "${assets[@]}" --repo "$repo" --verify-tag --title "$name $version" --notes-file "$notes" --latest=false
 done
# The semver SDK release is the main entry point; component releases keep their own versions.
if gh release view "$(cat VERSION)" --repo "$repo" >/dev/null 2>&1; then gh release edit "$(cat VERSION)" --repo "$repo" --latest; fi
