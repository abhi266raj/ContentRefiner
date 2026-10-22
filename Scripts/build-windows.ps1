# SPDX-License-Identifier: AGPL-3.0-only
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$package = 'Packages/ContentRefinerWindows'
swift build --package-path $package -c release --product ContentRefinerWindows
if ($LASTEXITCODE -ne 0) { throw 'Windows app build failed' }
$products = swift build --package-path $package -c release --show-bin-path
$version = (Get-Content "$package/VERSION").Trim()
$output = "dist/ContentRefinerWindows-$version"
New-Item -ItemType Directory -Force $output | Out-Null
Copy-Item "$products/ContentRefinerWindows.exe" $output
Get-ChildItem $products -Filter '*.dll' | Copy-Item -Destination $output
# Bundle Swift runtime DLLs from the installed toolchain, preserving third-party notices.
$swiftRoot = Join-Path $env:ProgramFiles 'Swift'
if (Test-Path $swiftRoot) {
    Get-ChildItem $swiftRoot -Recurse -File -Filter '*.dll' | Where-Object { $_.Name -match '^(swift|Foundation|BlocksRuntime|dispatch|icu|_Foundation|Observation)' } | ForEach-Object { Copy-Item $_.FullName $output -Force }
}
Get-ChildItem $products -Directory | Where-Object { $_.Name -like '*.resources' } | Copy-Item -Destination $output -Recurse
Copy-Item LICENSE, THIRD_PARTY_NOTICES.md $output
'Run ContentRefinerWindows.exe. A matching Windows App Runtime for SwiftCrossUI WinUIBackend must be installed; see README.' | Set-Content "$output/README.txt"
Compress-Archive -Path "$output/*" -DestinationPath "$output.zip" -Force
