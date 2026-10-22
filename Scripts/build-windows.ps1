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
Copy-Item Assets/ContentRefiner.png, Assets/ContentRefiner.ico $output
Copy-Item LICENSE, THIRD_PARTY_NOTICES.md $output
'Run ContentRefinerWindows.exe. A matching Windows App Runtime for SwiftCrossUI WinUIBackend must be installed; see README.' | Set-Content "$output/README.txt"
$notices = Join-Path $output 'ThirdPartyNotices'
New-Item -ItemType Directory -Force $notices | Out-Null
Copy-Item ThirdPartyNotices (Join-Path $notices 'ProjectNotices') -Recurse -Force
Get-ChildItem "$package/.build/checkouts" -Directory | ForEach-Object {
    $dependency = $_
    $licenseFiles = Get-ChildItem $dependency.FullName -File | Where-Object { $_.Name -match '^(LICENSE|LICENCE|COPYING|NOTICE)([.\-]|$)' }
    if ($licenseFiles) {
        $destination = Join-Path $notices $dependency.Name
        New-Item -ItemType Directory -Force $destination | Out-Null
        $licenseFiles | Copy-Item -Destination $destination
    }
}
if (Test-Path $swiftRoot) {
    Get-ChildItem $swiftRoot -Recurse -File | Where-Object { $_.Name -match '^(LICENSE|LICENCE|COPYING|NOTICE)([.\-]|$)' } | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($swiftRoot, $_.FullName)
        $destination = Join-Path (Join-Path $notices 'SwiftRuntime') $relative
        New-Item -ItemType Directory -Force (Split-Path $destination) | Out-Null
        Copy-Item $_.FullName $destination
    }
}
Compress-Archive -Path "$output/*" -DestinationPath "$output.zip" -Force
