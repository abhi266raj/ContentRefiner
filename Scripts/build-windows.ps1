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
. (Join-Path $PSScriptRoot 'Support/Copy-WindowsRuntime.ps1')
Get-ChildItem $products -Directory | Where-Object { ($_.Name -like '*.resources' -or $_.Name -like '*.bundle') } | Copy-Item -Destination $output -Recurse
if (-not (Get-ChildItem $output -Recurse -File -Filter 'ContentRefiner.png' | Where-Object { $_.FullName -match 'ContentRefinerBase_ContentRefinerBase' })) { throw 'Shared UI resource bundle is missing' }
$swiftRoots = @(Copy-WindowsRuntime -Products $products -Output $output -BuildRoot "$package/.build")
$bootstrapper = Get-ChildItem $output -Recurse -File -Filter 'Microsoft.WindowsAppRuntime.Bootstrap.dll' | Select-Object -First 1
if (-not $bootstrapper -or (Get-PeMachine $bootstrapper.FullName) -ne (Get-PeMachine "$output/ContentRefinerWindows.exe")) { throw 'Windows App SDK bootstrap resource is missing or has the wrong architecture' }
Copy-Item Assets/ContentRefiner.png, Assets/ContentRefiner.ico $output
Copy-Item LICENSE, THIRD_PARTY_NOTICES.md $output
'Run ContentRefinerWindows.exe. The Visual C++ x64 runtime and matching Windows App Runtime for SwiftCrossUI WinUIBackend must be installed; see README.' | Set-Content "$output/README.txt"
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
foreach ($swiftRoot in ($swiftRoots + @("$package/.build/artifacts"))) {
    if (-not (Test-Path $swiftRoot)) { continue }
    Get-ChildItem $swiftRoot -Recurse -File | Where-Object { $_.Name -match '^(LICENSE|LICENCE|COPYING|NOTICE)([.\-]|$)' } | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($swiftRoot, $_.FullName)
        $destination = Join-Path (Join-Path $notices ("SwiftRuntime/" + (Split-Path $swiftRoot -Leaf))) $relative
        New-Item -ItemType Directory -Force (Split-Path $destination) | Out-Null
        Copy-Item $_.FullName $destination
    }
}
Compress-Archive -Path "$output/*" -DestinationPath "$output.zip" -Force
