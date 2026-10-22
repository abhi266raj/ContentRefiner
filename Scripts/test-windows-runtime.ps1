# SPDX-License-Identifier: AGPL-3.0-only
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
. (Join-Path $PSScriptRoot 'Support/Copy-WindowsRuntime.ps1')
$products = swift build -c debug --show-bin-path
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('ContentRefinerRuntime-' + [guid]::NewGuid())
New-Item -ItemType Directory $fixture | Out-Null
Copy-Item "$products/content-refiner.exe" $fixture
$runtimeRoots = @(Copy-WindowsRuntime -Products $products -Output $fixture -BuildRoot '.build' -ExecutableName 'content-refiner.exe')
$savedRuntimePath = $env:Path
try {
    # Prove the packaged command works without Swift's developer PATH.
    $env:Path = "$fixture;$env:SystemRoot/System32;$env:SystemRoot"
    & "$fixture/content-refiner.exe" --version
    if ($LASTEXITCODE -ne 0) { throw "Standalone command failed: $LASTEXITCODE" }
} finally {
    $env:Path = $savedRuntimePath
    Remove-Item $fixture -Recurse -Force
}
