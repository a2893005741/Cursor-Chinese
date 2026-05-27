param(
    [string]$CursorRoot = '',
    [switch]$Yes,
    [switch]$WhatIf,
    [switch]$VerifyOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Info($Message) { Write-Host ("[INFO] " + $Message) -ForegroundColor Cyan }
function Ok($Message) { Write-Host ("[OK] " + $Message) -ForegroundColor Green }
function Warn($Message) { Write-Host ("[WARN] " + $Message) -ForegroundColor Yellow }
function Fail($Message) { Write-Host ("[ERROR] " + $Message) -ForegroundColor Red; exit 1 }

function FullPath($Path) { return [System.IO.Path]::GetFullPath($Path) }

function IsCursorRoot($Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    try { $root = FullPath $Path } catch { return $false }
    return ((Test-Path -Path (Join-Path $root 'Cursor.exe') -PathType Leaf) -and (Test-Path -Path (Join-Path $root 'resources\app\out') -PathType Container))
}

function AddCandidate($List, $Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    try {
        $full = FullPath $Path
        if (-not $List.Contains($full)) { [void]$List.Add($full) }
    } catch {}
}

function FindCursorRoot($ManualRoot) {
    $candidates = New-Object System.Collections.ArrayList
    AddCandidate $candidates $ManualRoot

    try {
        $processes = @(Get-Process -Name 'Cursor' -ErrorAction SilentlyContinue)
        foreach ($process in $processes) {
            try { AddCandidate $candidates (Split-Path $process.MainModule.FileName -Parent) } catch {}
        }
    } catch {}

    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        AddCandidate $candidates (Join-Path $env:LOCALAPPDATA 'Programs\cursor')
        AddCandidate $candidates (Join-Path $env:LOCALAPPDATA 'Programs\Cursor')
    }

    foreach ($candidate in $candidates) {
        if (IsCursorRoot $candidate) { return (FullPath $candidate) }
    }
    return $null
}

function GetCoreFiles($PackageRoot) {
    $relativeFiles = @(
        'resources\app\product.json',
        'resources\app\out\main.js',
        'resources\app\out\nls.keys.json',
        'resources\app\out\nls.messages.json',
        'resources\app\out\vs\workbench\workbench.desktop.main.js',
        'resources\app\out\vs\workbench\contrib\composer\browser\preload-webview-browser.js',
        'locales\en-GB.pak',
        'locales\en-US.pak'
    )

    $files = New-Object System.Collections.ArrayList
    foreach ($relative in $relativeFiles) {
        $source = Join-Path $PackageRoot $relative
        if (-not (Test-Path -Path $source -PathType Leaf)) { Fail ("Package is missing core file: " + $relative) }
        [void]$files.Add([pscustomobject]@{ Source = $source; Relative = $relative })
    }
    return @($files)
}

function EnsureParentDir($Path, $DryRun) {
    if ($DryRun) { return }
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path -Path $dir -PathType Container)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

function BackupExistingTargets($Files, $TargetRoot, $BackupRoot, $DryRun) {
    $count = 0
    foreach ($file in $Files) {
        $target = Join-Path $TargetRoot $file.Relative
        if (-not (Test-Path -Path $target -PathType Leaf)) { continue }
        $backupPath = Join-Path $BackupRoot $file.Relative
        if ($DryRun) {
            Write-Host ("WhatIf: backup " + $target + " -> " + $backupPath)
        } else {
            EnsureParentDir $backupPath $false
            Copy-Item -Path $target -Destination $backupPath -Force
        }
        $count += 1
    }
    return $count
}

function CopyCoreFiles($Files, $TargetRoot, $DryRun) {
    $count = 0
    foreach ($file in $Files) {
        $target = Join-Path $TargetRoot $file.Relative
        if ($DryRun) {
            Write-Host ("WhatIf: copy " + $file.Source + " -> " + $target)
        } else {
            EnsureParentDir $target $false
            Copy-Item -Path $file.Source -Destination $target -Force
        }
        $count += 1
    }
    return $count
}

function AssertFileMatchesPackage($PackageRoot, $TargetRoot, $Relative) {
    $sourcePath = Join-Path $PackageRoot $Relative
    $targetPath = Join-Path $TargetRoot $Relative
    if (-not (Test-Path -Path $sourcePath -PathType Leaf)) { Fail ("Package is missing key file: " + $Relative) }
    if (-not (Test-Path -Path $targetPath -PathType Leaf)) { Fail ("Target is missing installed key file: " + $Relative) }
    $sourceHash = (Get-FileHash -Path $sourcePath -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -Path $targetPath -Algorithm SHA256).Hash
    if ($sourceHash -ne $targetHash) { Fail ("Installed verification failed: target file does not match package file: " + $Relative) }
}

function AssertPackageProductChecksums($Root) {
    $productPath = Join-Path $Root 'resources\app\product.json'
    if (-not (Test-Path -Path $productPath -PathType Leaf)) { Fail 'Missing resources\app\product.json.' }
    $product = Get-Content -Path $productPath -Raw | ConvertFrom-Json
    if ($null -eq $product.checksums) { Fail 'product.json missing checksums.' }
    foreach ($prop in @($product.checksums.PSObject.Properties)) {
        $relative = ($prop.Name -replace '/', '\')
        $filePath = Join-Path $Root (Join-Path 'resources\app\out' $relative)
        if (-not (Test-Path -Path $filePath -PathType Leaf)) { continue }
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try { $actual = [System.Convert]::ToBase64String($sha256.ComputeHash($bytes)).TrimEnd('=') } finally { $sha256.Dispose() }
        if ($actual -ne [string]$prop.Value) { Fail ('Package integrity check failed: product.json checksum does not match bundled file: ' + $prop.Name + '. This package is mixed, outdated, or was edited without syncing checksums. Please use the latest complete package.') }
    }
}

function AssertTargetProductJsonInstalled($PackageRoot, $TargetRoot) {
    AssertFileMatchesPackage $PackageRoot $TargetRoot 'resources\app\product.json'
}

function AssertPackageRoot($PackageRoot) {
    $null = GetCoreFiles $PackageRoot
    $vsixPath = Join-Path $PackageRoot 'ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106-cursor105-fused.vsix'
    if (-not (Test-Path -Path $vsixPath -PathType Leaf)) { Fail 'Package is missing language pack VSIX.' }
    AssertPackageProductChecksums $PackageRoot
}

function AssertInstalledFiles($PackageRoot, $TargetRoot) {
    $files = GetCoreFiles $PackageRoot
    foreach ($file in $files) { AssertFileMatchesPackage $PackageRoot $TargetRoot $file.Relative }
    AssertTargetProductJsonInstalled $PackageRoot $TargetRoot
}

function ShowVsixInstallHint($VsixPath) {
    Write-Host ''
    Warn 'Base UI Chinese is provided by the VSIX language pack.'
    Warn ('Install it manually in Cursor: ' + $VsixPath)
}

$packageRoot = FullPath $PSScriptRoot
$vsixPath = Join-Path $packageRoot 'ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106-cursor105-fused.vsix'
Info ("Package root: " + $packageRoot)

AssertPackageRoot $packageRoot
Ok 'Package structure verified: core patch files + VSIX'

$resolvedCursorRoot = FindCursorRoot $CursorRoot
if ([string]::IsNullOrWhiteSpace($resolvedCursorRoot)) { Fail 'Cursor root was not found. Use -CursorRoot to specify it manually.' }
Ok ("Cursor root: " + $resolvedCursorRoot)

if ($VerifyOnly) {
    AssertInstalledFiles $packageRoot $resolvedCursorRoot
    Write-Host ''
    Ok 'VerifyOnly passed. Core patch files match this package.'
    Warn ('Base UI Chinese depends on installed VSIX: ' + $vsixPath)
    exit 0
}

if (-not $WhatIf) {
    $runningCursor = @(Get-Process -Name 'Cursor' -ErrorAction SilentlyContinue)
    if ($runningCursor.Count -gt 0) {
        Warn 'Cursor is running. Please close Cursor completely before installing.'
        Warn 'No files were copied.'
        exit 2
    }
}

if ((-not $Yes) -and (-not $WhatIf)) {
    Warn 'Real install requires -Yes. For dry run, use -WhatIf.'
    Fail 'Missing -Yes. Stopped.'
}

$files = GetCoreFiles $packageRoot
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $packageRoot (Join-Path 'install-backups' $timestamp)

Info ("Core files to copy: " + $files.Count)
Info ("Backup root: " + $backupRoot)

$backupCount = BackupExistingTargets $files $resolvedCursorRoot $backupRoot $WhatIf
$copyCount = CopyCoreFiles $files $resolvedCursorRoot $WhatIf
ShowVsixInstallHint $vsixPath

if (-not $WhatIf) { AssertInstalledFiles $packageRoot $resolvedCursorRoot }

Write-Host ''
Ok ("Done. Copied core files: " + $copyCount + "; backed up files: " + $backupCount)
Ok ("Cursor root: " + $resolvedCursorRoot)
Ok ("Backup root: " + $backupRoot)
Warn 'Restart Cursor to apply the core patches and language pack.'