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
# Validate every changed app artifact before creating any immutable tags.
ruby -rjson -e 'JSON.parse(File.read(ARGV[0])).each{|x| case x["name"]; when "ContentRefinerMac"; puts "dist/ContentRefinerMac-#{x["version"]}.zip", "dist/ContentRefinerMac-#{x["version"]}.dmg"; when "ContentRefinerLinux"; puts "dist/ContentRefinerLinux-#{x["version"]}.tar.gz"; when "ContentRefinerWindows"; puts "dist/ContentRefinerWindows-#{x["version"]}.zip"; end}' "$changes" > "$changes.assets"
trap 'rm -f "$changes" "$changes.assets" "$notes"' EXIT
while IFS= read -r asset; do test -s "$asset" || { echo "Missing verified artifact: $asset" >&2; exit 1; }; done < "$changes.assets"
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
    ContentRefiner) while IFS= read -r file; do assets+=("$file"); done < "$changes.assets";;
  esac
  for asset in "${assets[@]}"; do test -s "$asset"; done
  gh release create "$tag" "${assets[@]}" --repo "$repo" --verify-tag --title "$name $version" --notes-file "$notes" --latest=false
 done
# The semver SDK release is the main entry point; component releases keep their own versions.
if gh release view "$(cat VERSION)" --repo "$repo" >/dev/null 2>&1; then gh release edit "$(cat VERSION)" --repo "$repo" --latest; fi
