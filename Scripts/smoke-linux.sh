#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
package=Packages/ContentRefinerLinux
version="$(cat "$package/VERSION")"
# Hide build-time fallbacks so the packaged app must load its own resources.
mv "$package/.build" "$package/.build-smoke"
trap 'mv "$package/.build-smoke" "$package/.build"' EXIT
set +e
GSK_RENDERER=cairo xvfb-run -a timeout --signal=TERM 10s "dist/ContentRefinerLinux-$version/ContentRefinerLinux" > /tmp/content-refiner-linux-smoke.log 2>&1
result=$?
set -e
cat /tmp/content-refiner-linux-smoke.log
test "$result" -eq 124 || { echo "Packaged app exited during startup ($result)." >&2; exit 1; }
