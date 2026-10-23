#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
version="${1:-}"
for module in ContentRefiner ContentRefinerSource; do
  consumer="$(mktemp -d)"
  mkdir -p "$consumer/Sources/Probe"
  if [ -n "$version" ]; then dependency=".package(url: \"https://github.com/abhi266raj/ContentRefiner.git\", exact: \"$version\")"; else dependency=".package(name: \"ContentRefiner\", path: \"$root\")"; fi
  cat > "$consumer/Package.swift" <<MANIFEST
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Probe", platforms: [.macOS(.v15)], dependencies: [$dependency], targets: [.executableTarget(name: "Probe", dependencies: [.product(name: "$module", package: "ContentRefiner")], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path"])])])
MANIFEST
  cat > "$consumer/Sources/Probe/main.swift" <<SWIFT
import Foundation
import $module
struct Backend: RefinementBackend {
    let id = "consumer"
    func refine(_ input: ContentRefinementInput) async throws -> String {
        String(decoding: try JSONEncoder().encode(ContentRefinementOutput(variations: [.init(index: 1, content: "Consumer result")], instruction: "Keep meaning")), as: UTF8.self)
    }
}
let session = try RefinementSession(originalContent: "Original", client: .init(backends: [Backend()]))
let result = try await session.refine("Improve")
precondition(result.output.variations[0].content == "Consumer result")
precondition(ContentRefinerVersion.current == "$(cat VERSION)")
print("$module consumer passed")
SWIFT
  swift build --package-path "$consumer" > "$consumer/build.log" 2>&1 || { tail -60 "$consumer/build.log"; exit 1; }
  products="$(swift build --package-path "$consumer" --show-bin-path)"
  if [ "$module" = ContentRefiner ]; then
    agent="$(find "$consumer/.build/artifacts" -path '*macos*/AgentAtom.framework' -type d | head -1)"
    /usr/bin/ditto "$agent" "$products/AgentAtom.framework"
  fi
  "$products/Probe"
  rm -rf "$consumer"
done
