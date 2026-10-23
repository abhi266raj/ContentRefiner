#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
checkouts="$1"
output="$2"
mkdir -p "$output"
[ -d "$checkouts" ] || exit 0
while IFS= read -r -d '' notice; do
  dependency="$(basename "$(dirname "$notice")")"
  mkdir -p "$output/$dependency"
  cp "$notice" "$output/$dependency/$(basename "$notice")"
done < <(find "$checkouts" -mindepth 2 -maxdepth 2 -type f \( -iname 'license*' -o -iname 'copying*' -o -iname 'notice*' \) -print0)
