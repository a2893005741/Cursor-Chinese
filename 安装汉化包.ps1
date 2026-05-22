param(
    [string]$CursorRoot = '',
    [switch]$Yes,
    [switch]$WhatIf
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Info($Message) {
    Write-Host ("[INFO] " + $Message) -ForegroundColor Cyan
}

function Ok($Message) {
    Write-Host ("[OK] " + $Message) -ForegroundColor Green
}

function Warn($Message) {
    Write-Host ("[WARN] " + $Message) -ForegroundColor Yellow
}

function Fail($Message) {
    Write-Host ("[ERROR] " + $Message) -ForegroundColor Red
    exit 1
}

function FullPath($Path) {
    return [System.IO.Path]::GetFullPath($Path)
}

function IsCursorRoot($Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    try {
        $root = FullPath $Path
    } catch {
        return $false
    }

    $cursorExe = Join-Path $root 'Cursor.exe'
    $outDir = Join-Path $root 'resources\app\out'
    $workbenchDir = Join-Path $outDir 'vs\workbench'
    $nlsFile = Join-Path $outDir 'nls.messages.json'

    if (-not (Test-Path -LiteralPath $cursorExe -PathType Leaf)) {
        return $false
    }
    if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
        return $false
    }
    if ((Test-Path -LiteralPath $workbenchDir -PathType Container) -or (Test-Path -LiteralPath $nlsFile -PathType Leaf)) {
        return $true
    }

    return $false
}

function AddCandidate($List, $Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    try {
        $full = FullPath $Path
        if (-not $List.Contains($full)) {
            [void]$List.Add($full)
        }
    } catch {
    }
}

function AddRegistryCandidates($List) {
    $roots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($root in $roots) {
        try {
            $items = Get-ItemProperty -Path $root -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                $displayName = ''
                $installLocation = ''
                $displayIcon = ''

                if ($null -ne $item.DisplayName) { $displayName = [string]$item.DisplayName }
                if ($null -ne $item.InstallLocation) { $installLocation = [string]$item.InstallLocation }
                if ($null -ne $item.DisplayIcon) { $displayIcon = [string]$item.DisplayIcon }

                if (($displayName -like '*Cursor*') -or ($installLocation -like '*\cursor') -or ($installLocation -like '*\Cursor')) {
                    if (-not [string]::IsNullOrWhiteSpace($installLocation)) {
                        AddCandidate $List $installLocation
                    } elseif (-not [string]::IsNullOrWhiteSpace($displayIcon)) {
                        AddCandidate $List (Split-Path ($displayIcon.Trim('"')) -Parent)
                    }
                }
            }
        } catch {
        }
    }
}

function AddProcessCandidates($List) {
    try {
        $processes = @(Get-Process -Name 'Cursor' -ErrorAction SilentlyContinue)
        foreach ($process in $processes) {
            try {
                $exePath = $process.MainModule.FileName
                if (-not [string]::IsNullOrWhiteSpace($exePath)) {
                    AddCandidate $List (Split-Path $exePath -Parent)
                }
            } catch {
            }
        }
    } catch {
    }
}

function AddAppPathCandidates($List) {
    $keys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\Cursor.exe',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\Cursor.exe',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\Cursor.exe'
    )

    foreach ($key in $keys) {
        try {
            $item = Get-Item -LiteralPath $key -ErrorAction SilentlyContinue
            if ($null -ne $item) {
                $exePath = [string]$item.GetValue('')
                if (-not [string]::IsNullOrWhiteSpace($exePath)) {
                    AddCandidate $List (Split-Path ($exePath.Trim('"')) -Parent)
                }
            }
        } catch {
        }
    }
}

function AddAllUserLocalAppDataCandidates($List) {
    $systemDrive = [Environment]::GetEnvironmentVariable('SystemDrive')
    if ([string]::IsNullOrWhiteSpace($systemDrive)) {
        $systemDrive = 'C:'
    }

    $usersRoot = Join-Path $systemDrive 'Users'
    if (-not (Test-Path -LiteralPath $usersRoot -PathType Container)) {
        return
    }

    try {
        Get-ChildItem -LiteralPath $usersRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            AddCandidate $List (Join-Path $_.FullName 'AppData\Local\Programs\cursor')
            AddCandidate $List (Join-Path $_.FullName 'AppData\Local\Programs\Cursor')
        }
    } catch {
    }
}

function AddNearbyCandidates($List) {
    $roots = New-Object System.Collections.ArrayList

    try {
        $current = FullPath $PSScriptRoot
        for ($i = 0; $i -lt 4; $i += 1) {
            if ([string]::IsNullOrWhiteSpace($current)) {
                break
            }
            if (-not $roots.Contains($current)) {
                [void]$roots.Add($current)
            }
            $parent = Split-Path $current -Parent
            if ($parent -eq $current) {
                break
            }
            $current = $parent
        }
    } catch {
    }

    foreach ($root in $roots) {
        AddCandidate $List (Join-Path $root 'cursor')
        AddCandidate $List (Join-Path $root 'Cursor')

        try {
            Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                AddCandidate $List $_.FullName
                AddCandidate $List (Join-Path $_.FullName 'cursor')
                AddCandidate $List (Join-Path $_.FullName 'Cursor')
            }
        } catch {
        }
    }
}

function FindCursorRoot($ManualRoot) {
    $candidates = New-Object System.Collections.ArrayList

    AddCandidate $candidates $ManualRoot
    AddProcessCandidates $candidates
    AddAppPathCandidates $candidates

    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        AddCandidate $candidates (Join-Path $env:LOCALAPPDATA 'Programs\cursor')
        AddCandidate $candidates (Join-Path $env:LOCALAPPDATA 'Programs\Cursor')

        $programs = Join-Path $env:LOCALAPPDATA 'Programs'
        if (Test-Path -LiteralPath $programs -PathType Container) {
            try {
                Get-ChildItem -LiteralPath $programs -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -ieq 'cursor' } |
                    ForEach-Object { AddCandidate $candidates $_.FullName }
            } catch {
            }
        }
    }

    AddAllUserLocalAppDataCandidates $candidates

    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        AddCandidate $candidates (Join-Path $env:ProgramFiles 'Cursor')
    }

    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        AddCandidate $candidates (Join-Path $programFilesX86 'Cursor')
    }

    AddRegistryCandidates $candidates
    AddNearbyCandidates $candidates

    foreach ($candidate in $candidates) {
        if (IsCursorRoot $candidate) {
            return (FullPath $candidate)
        }
    }

    return $null
}

function AssertPackageRoot($PackageRoot) {
    $requiredFiles = @(
        'resources\app\out\nls.messages.json',
        'resources\app\out\vs\workbench\workbench.desktop.main.js'
    )

    foreach ($relative in $requiredFiles) {
        $path = Join-Path $PackageRoot $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Fail ("Package is missing required file: " + $relative)
        }
    }

    $requiredDirs = @('resources', 'locales')
    foreach ($relative in $requiredDirs) {
        $path = Join-Path $PackageRoot $relative
        if (-not (Test-Path -LiteralPath $path -PathType Container)) {
            Fail ("Package is missing required directory: " + $relative)
        }
    }
}

function GetPackageFiles($PackageRoot) {
    $files = New-Object System.Collections.ArrayList
    $copyRoots = @('resources', 'locales')

    foreach ($copyRoot in $copyRoots) {
        $rootPath = Join-Path $PackageRoot $copyRoot
        if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
            continue
        }

        Get-ChildItem -LiteralPath $rootPath -Recurse -File | ForEach-Object {
            $relative = $_.FullName.Substring($PackageRoot.Length).TrimStart('\', '/')
            if ($relative -notmatch '^resources[\\/]app[\\/]extensions[\\/]') {
                [void]$files.Add([pscustomobject]@{
                    Source = $_.FullName
                    Relative = $relative
                })
            }
        }
    }

    return @($files)
}

function EnsureParentDir($Path, $DryRun) {
    $dir = Split-Path $Path -Parent
    if ($DryRun) {
        return
    }
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

function BackupExistingTargets($Files, $TargetRoot, $BackupRoot, $DryRun) {
    $count = 0

    foreach ($file in $Files) {
        $target = Join-Path $TargetRoot $file.Relative
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            continue
        }

        $backupPath = Join-Path $BackupRoot $file.Relative
        if ($DryRun) {
            Write-Host ("WhatIf: backup " + $target + " -> " + $backupPath)
        } else {
            EnsureParentDir $backupPath $false
            Copy-Item -LiteralPath $target -Destination $backupPath -Force
        }
        $count += 1
    }

    return $count
}

function CopyPackageFiles($Files, $TargetRoot, $DryRun) {
    $count = 0

    foreach ($file in $Files) {
        $target = Join-Path $TargetRoot $file.Relative
        if ($DryRun) {
            Write-Host ("WhatIf: copy " + $file.Source + " -> " + $target)
        } else {
            EnsureParentDir $target $false
            Copy-Item -LiteralPath $file.Source -Destination $target -Force
        }
        $count += 1
    }

    return $count
}

function AssertInstalledFiles($TargetRoot) {
    $requiredFiles = @(
        'resources\app\out\nls.messages.json',
        'resources\app\out\vs\workbench\workbench.desktop.main.js'
    )

    foreach ($relative in $requiredFiles) {
        $path = Join-Path $TargetRoot $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Fail ("Target is missing installed key file: " + $relative)
        }
    }
}

$packageRoot = FullPath $PSScriptRoot
Info ("Package root: " + $packageRoot)

AssertPackageRoot $packageRoot
Ok 'Package structure verified'

$resolvedCursorRoot = FindCursorRoot $CursorRoot
if ([string]::IsNullOrWhiteSpace($resolvedCursorRoot)) {
    Fail 'Cursor root was not found. Use -CursorRoot to specify it manually.'
}

if (-not (IsCursorRoot $resolvedCursorRoot)) {
    Fail ("Invalid Cursor root: " + $resolvedCursorRoot)
}
Ok ("Cursor root: " + $resolvedCursorRoot)

if (-not $WhatIf) {
    $runningCursor = @(Get-Process -Name 'Cursor' -ErrorAction SilentlyContinue)
    if ($runningCursor.Count -gt 0) {
        Warn 'Cursor is running. Please close Cursor completely before installing.'
        Warn 'No files were copied.'
        exit 2
    }
}

$files = GetPackageFiles $packageRoot
if ($files.Count -eq 0) {
    Fail 'No package files found.'
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $packageRoot (Join-Path 'install-backups' $timestamp)

Info ("Files to copy: " + $files.Count)
Info ("Backup root: " + $backupRoot)

if ((-not $Yes) -and (-not $WhatIf)) {
    Warn 'Real install requires -Yes. For dry run, use -WhatIf.'
    Fail 'Missing -Yes. Stopped.'
}

$backupCount = BackupExistingTargets $files $resolvedCursorRoot $backupRoot $WhatIf
$copyCount = CopyPackageFiles $files $resolvedCursorRoot $WhatIf

if (-not $WhatIf) {
    AssertInstalledFiles $resolvedCursorRoot
}

Write-Host ''
Ok ("Done. Copied files: " + $copyCount + "; backed up files: " + $backupCount)
Ok ("Cursor root: " + $resolvedCursorRoot)
Ok ("Backup root: " + $backupRoot)
Warn 'Restart Cursor to apply the patched workbench bundle.'