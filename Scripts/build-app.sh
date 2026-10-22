#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
package=Packages/ContentRefinerMac
swift build --package-path "$package" -c release --product ContentRefinerMac > /private/tmp/content-refiner-package-build.log 2>&1 || { tail -70 /private/tmp/content-refiner-package-build.log >&2; exit 1; }
products="$(swift build --package-path "$package" -c release --show-bin-path)"
app="$PWD/dist/ContentRefiner.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks" "$app/Contents/Resources"
cp "$products/ContentRefinerMac" "$app/Contents/MacOS/ContentRefiner"
agent="$(find "$package/.build/artifacts" -path '*macos*/AgentAtom.framework' -type d | head -1)"
[ -n "$agent" ] || { echo 'AgentAtom framework was not found.' >&2; exit 1; }
/usr/bin/ditto "$agent" "$app/Contents/Frameworks/AgentAtom.framework"
# Binary-linked SwiftPM executables need a relocatable app-local framework path.
install_name_tool -add_rpath '@executable_path/../Frameworks' "$app/Contents/MacOS/ContentRefiner"
version="$(cat "$package/VERSION")"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.abhi266raj.ContentRefinerMac</string>
<key>CFBundleName</key><string>Content Refiner</string>
<key>CFBundleExecutable</key><string>ContentRefiner</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Preserve resources emitted by SwiftPM (SwiftCrossUI dependencies may provide bundles).
while IFS= read -r -d "" resource; do /usr/bin/ditto "$resource" "$app/Contents/Resources/$(basename "$resource")"; done < <(find "$products" -maxdepth 1 -type d \( -name "*.bundle" -o -name "*.resources" \) -print0)
Scripts/collect-notices.sh "$package/.build/checkouts" "$app/Contents/Resources/ThirdPartyNotices"
cp LICENSE THIRD_PARTY_NOTICES.md "$app/Contents/Resources/"
/usr/bin/ditto ThirdPartyNotices "$app/Contents/Resources/ThirdPartyNotices/ProjectNotices"
codesign --force --sign - "$app/Contents/Frameworks/AgentAtom.framework"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
(cd dist && /usr/bin/ditto -c -k --keepParent ContentRefiner.app "ContentRefinerMac-$version.zip")
hdiutil create -volname 'Content Refiner' -srcfolder "$app" -ov -format UDZO "dist/ContentRefinerMac-$version.dmg" >/dev/null
printf 'Built %s\n' "$app"
