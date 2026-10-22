#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
platform="${1:-Linux}"
package="Packages/ContentRefiner$platform"
swift build --package-path "$package" -c release --product "ContentRefiner$platform" --static-swift-stdlib
products="$(swift build --package-path "$package" -c release --show-bin-path)"
version="$(cat "$package/VERSION")"
output="dist/ContentRefiner$platform-$version"
mkdir -p "$output"
cp "$products/ContentRefiner$platform" "$output/"
cp Assets/ContentRefiner.png Assets/ContentRefiner.svg "$output/"
cp LICENSE THIRD_PARTY_NOTICES.md "$output/"
Scripts/collect-notices.sh "$package/.build/checkouts" "$output/ThirdPartyNotices"
cp -R ThirdPartyNotices "$output/ThirdPartyNotices/ProjectNotices"
while IFS= read -r -d '' resource; do cp -R "$resource" "$output/"; done < <(find "$products" -maxdepth 1 -name '*.resources' -type d -print0)
printf 'Run ./ContentRefiner%s on a desktop session. Linux requires GTK 4 runtime (libgtk-4-1).\n' "$platform" > "$output/README.txt"
tar -czf "$output.tar.gz" -C dist "ContentRefiner$platform-$version"
