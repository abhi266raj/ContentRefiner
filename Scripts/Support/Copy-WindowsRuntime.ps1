# SPDX-License-Identifier: AGPL-3.0-only
function Get-PeMachine([string] $Path) {
    $stream = [IO.File]::OpenRead($Path)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        if ($stream.Length -lt 64 -or $reader.ReadUInt16() -ne 0x5a4d) { return 0 }
        $stream.Position = 0x3c
        $offset = $reader.ReadUInt32()
        if ($offset + 6 -gt $stream.Length) { return 0 }
        $stream.Position = $offset
        if ($reader.ReadUInt32() -ne 0x4550) { return 0 }
        return $reader.ReadUInt16()
    } finally { $reader.Dispose() }
}

function Copy-WindowsRuntime([string] $Products, [string] $Output, [string] $BuildRoot) {
    $targetInfo = (& swiftc -print-target-info | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect Swift runtime paths' }
    $swiftBinary = (Get-Command swiftc).Source
    $paths = @($targetInfo.paths.runtimeLibraryPaths) + @($targetInfo.paths.runtimeLibraryImportPaths) + @($targetInfo.paths.runtimeResourcePath) + @($swiftBinary)
    if ($env:SDKROOT) { $paths += $env:SDKROOT }
    $roots = @($paths | ForEach-Object {
        if ($_ -match '(?i)^(.*?)[\\/]usr[\\/]') { $matches[1] }
        elseif (Test-Path $_ -PathType Container) { $_ }
        elseif (Test-Path $_ -PathType Leaf) { Split-Path (Split-Path $_) }
    } | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique)
    if (-not $roots) { throw 'No installed Swift runtime directories were found' }
    $machine = Get-PeMachine (Join-Path $Output 'ContentRefinerWindows.exe')
    if (-not $machine) { throw 'The app is not a valid Windows executable' }
    $candidates = @{}
    $candidateFiles = @(Get-ChildItem $Products -File -Filter '*.dll')
    foreach ($root in $roots + @($BuildRoot)) {
        $candidateFiles += @(Get-ChildItem $root -Recurse -File -Filter '*.dll')
    }
    foreach ($file in $candidateFiles) {
        if (-not $candidates.ContainsKey($file.Name) -and (Get-PeMachine $file.FullName) -eq $machine) {
            $candidates[$file.Name] = $file.FullName
        }
    }
    $queue = [Collections.Generic.Queue[string]]::new()
    Get-ChildItem $Output -Recurse -File | Where-Object { $_.Extension -in @('.exe', '.dll') -and (Get-PeMachine $_.FullName) -eq $machine } | ForEach-Object { $queue.Enqueue($_.FullName) }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $missing = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    while ($queue.Count) {
        $file = $queue.Dequeue()
        if (-not $seen.Add($file)) { continue }
        $imports = & dumpbin /nologo /dependents $file
        if ($LASTEXITCODE -ne 0) { throw "Could not inspect DLL imports for $file" }
        foreach ($line in $imports) {
            if ($line -match '(?i)^\s+([a-z0-9_.-]+\.dll)\s*$') { $name = $matches[1] } else { continue }
            if ($name -match '^(api-ms-|ext-ms-)' -or (Test-Path (Join-Path $env:SystemRoot "System32/$name"))) { continue }
            $destination = Join-Path $Output $name
            if (-not (Test-Path $destination)) {
                if (-not $candidates.ContainsKey($name)) {
                    foreach ($directory in ($env:Path -split ';' | Select-Object -Unique)) {
                        if (-not $directory) { continue }
                        $candidate = Join-Path $directory $name
                        if ((Test-Path $candidate -PathType Leaf) -and (Get-PeMachine $candidate) -eq $machine) { $candidates[$name] = $candidate; break }
                    }
                }
                if (-not $candidates.ContainsKey($name)) { [void]$missing.Add($name); continue }
                Copy-Item $candidates[$name] $destination
            }
            if ((Get-PeMachine $destination) -ne $machine) { throw "Wrong runtime architecture: $name" }
            $queue.Enqueue([IO.Path]::GetFullPath($destination))
        }
    }
    if ($missing.Count) { throw "Unbundled non-system runtime dependencies: $($missing -join ', ')" }
    $bootstrapper = Get-ChildItem $Output -Recurse -File -Filter 'Microsoft.WindowsAppRuntime.Bootstrap.dll' | Select-Object -First 1
    if (-not $bootstrapper -or (Get-PeMachine $bootstrapper.FullName) -ne $machine) { throw 'Windows App SDK bootstrap resource is missing or has the wrong architecture' }
    if (-not (Test-Path (Join-Path $Output 'swiftCore.dll'))) { throw 'Swift runtime was not bundled' }
    Write-Host "Validated runtime import closure for $($seen.Count) executable/DLL files."
    return $roots
}
