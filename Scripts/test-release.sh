#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
versions="$(mktemp)"
trap 'rm -f "$versions"' EXIT
ruby Scripts/versions.rb > "$versions"
ruby -rjson -e 'raise unless JSON.parse(File.read(ARGV[0])).length == 5' "$versions"
for file in Sources/ContentRefiner/*.swift; do sed 's/import AgentAtomSource/import AgentAtom/' "Sources/ContentRefinerSource/$(basename "$file")" | cmp "$file" -; done
version="$(cat VERSION)"
rg -q "version: \"$version\"" Sources/ContentRefiner/ContentRefinerSpec.swift
rg -q "current = \"$version\"" Sources/ContentRefinerCore/RefinementRules.swift
if rg -q 'SwiftCrossUI|SwiftUI' Package.swift Sources/ContentRefiner/*.swift Sources/ContentRefinerCore/*.swift; then echo 'SDK must not depend on UI' >&2; exit 1; fi
