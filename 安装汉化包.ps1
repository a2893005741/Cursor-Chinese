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

function TextFromCodePoints($CodePoints) {
    $builder = New-Object System.Text.StringBuilder
    foreach ($codePoint in $CodePoints) {
        [void]$builder.Append([char]$codePoint)
    }
    return $builder.ToString()
}

function ExpectedText($Name) {
    if ($Name -eq 'feedbackMenu') {
        return TextFromCodePoints @(0x63D0, 0x4F9B, 0x53CD, 0x9988, 0x2E, 0x2E, 0x2E)
    }
    if ($Name -eq 'feedbackLabel') {
        return TextFromCodePoints @(0x63D0, 0x4F9B, 0x53CD, 0x9988)
    }
    if ($Name -eq 'processExplorer') {
        return TextFromCodePoints @(0x5DE5, 0x4F5C, 0x533A, 0x8FDB, 0x7A0B, 0x8D44, 0x6E90, 0x7BA1, 0x7406, 0x5668)
    }
    if ($Name -eq 'openProcessExplorer') {
        return TextFromCodePoints @(0x6253, 0x5F00, 0x8FDB, 0x7A0B, 0x8D44, 0x6E90, 0x7BA1, 0x7406, 0x5668)
    }
    if ($Name -eq 'developerTools') {
        return TextFromCodePoints @(0x6253, 0x5F00, 0x5F00, 0x53D1, 0x8005, 0x5DE5, 0x5177)
    }
    if ($Name -eq 'openBrowser') {
        return TextFromCodePoints @(0x6253, 0x5F00, 0x6D4F, 0x89C8, 0x5668)
    }
    if ($Name -eq 'configureIconVisibility') {
        return TextFromCodePoints @(0x914D, 0x7F6E, 0x56FE, 0x6807, 0x53EF, 0x89C1, 0x6027)
    }
    if ($Name -eq 'openPullRequestDiffView') {
        return TextFromCodePoints @(0x6253, 0x5F00, 0x62C9, 0x53D6, 0x8BF7, 0x6C42, 0x5DEE, 0x5F02, 0x89C6, 0x56FE)
    }
    if ($Name -eq 'markFileAsViewed') {
        return TextFromCodePoints @(0x6807, 0x8BB0, 0x6587, 0x4EF6, 0x4E3A, 0x5DF2, 0x67E5, 0x770B)
    }
    if ($Name -eq 'addFileComment') {
        return TextFromCodePoints @(0x6DFB, 0x52A0, 0x6587, 0x4EF6, 0x8BC4, 0x8BBA)
    }
    Fail ("Unknown expected text: " + $Name)
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

function IsCursorResourceRoot($Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    try {
        $root = FullPath $Path
    } catch {
        return $false
    }

    $outDir = Join-Path $root 'resources\app\out'
    $workbenchDir = Join-Path $outDir 'vs\workbench'
    $nlsFile = Join-Path $outDir 'nls.messages.json'

    if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
        return $false
    }
    if ((Test-Path -LiteralPath $workbenchDir -PathType Container) -or (Test-Path -LiteralPath $nlsFile -PathType Leaf)) {
        return $true
    }

    return $false
}

function ResolveManualCursorRoot($ManualRoot, $DryRun) {
    if ([string]::IsNullOrWhiteSpace($ManualRoot)) {
        return $null
    }

    $manual = FullPath $ManualRoot
    if (IsCursorRoot $manual) {
        return $manual
    }
    if ($DryRun -and (IsCursorResourceRoot $manual)) {
        return $manual
    }

    Fail ("Invalid manual Cursor root: " + $manual)
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

function GetSha256Base64NoPadding($Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.Convert]::ToBase64String($sha256.ComputeHash($bytes)).TrimEnd('=')
    } finally {
        $sha256.Dispose()
    }
}

function AssertProductChecksums($Root, $ScopeName) {
    $productPath = Join-Path $Root 'resources\app\product.json'
    if (-not (Test-Path -LiteralPath $productPath -PathType Leaf)) {
        Fail ($ScopeName + ' verification failed: missing resources\app\product.json.')
    }

    $product = Get-Content -LiteralPath $productPath -Raw | ConvertFrom-Json
    if ($null -eq $product.checksums) {
        Fail ($ScopeName + ' verification failed: product.json missing checksums.')
    }

    $checksumProps = @($product.checksums.PSObject.Properties)
    foreach ($prop in $checksumProps) {
        $relative = ($prop.Name -replace '/', '\')
        $filePath = Join-Path $Root (Join-Path 'resources\app\out' $relative)
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            continue
        }

        $actual = GetSha256Base64NoPadding $filePath
        if ($actual -ne [string]$prop.Value) {
            Fail ($ScopeName + ' verification failed: product checksum mismatch: ' + $prop.Name)
        }
    }
}

function AssertPackageRoot($PackageRoot) {
    $requiredFiles = @(
        'resources\app\product.json',
        'resources\app\out\main.js',
        'resources\app\out\nls.keys.json',
        'resources\app\out\nls.messages.json',
        'resources\app\out\vs\workbench\workbench.desktop.main.js',
        'resources\app\out\vs\workbench\contrib\composer\browser\preload-webview-browser.js',
        'resources\app\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106\package.json',
        'resources\app\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106\translations\main.i18n.json',
        'resources\app\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106\translations\extensions\github.vscode-pull-request-github.i18n.json'
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

    $nlsPath = Join-Path $PackageRoot 'resources\app\out\nls.messages.json'
    $bundlePath = Join-Path $PackageRoot 'resources\app\out\vs\workbench\workbench.desktop.main.js'
    $languagePackPath = Join-Path $PackageRoot 'resources\app\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106\translations\main.i18n.json'
    $githubPrPath = Join-Path $PackageRoot 'resources\app\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106\translations\extensions\github.vscode-pull-request-github.i18n.json'
    $nlsText = [System.IO.File]::ReadAllText($nlsPath, [System.Text.Encoding]::UTF8)
    $bundleText = [System.IO.File]::ReadAllText($bundlePath, [System.Text.Encoding]::UTF8)
    $languagePackText = [System.IO.File]::ReadAllText($languagePackPath, [System.Text.Encoding]::UTF8)
    $githubPrText = [System.IO.File]::ReadAllText($githubPrPath, [System.Text.Encoding]::UTF8)

    $expectedFeedbackMenu = ExpectedText 'feedbackMenu'
    $expectedFeedbackLabel = ExpectedText 'feedbackLabel'
    $expectedProcessExplorer = ExpectedText 'processExplorer'
    $expectedOpenProcessExplorer = ExpectedText 'openProcessExplorer'
    $expectedDeveloperTools = ExpectedText 'developerTools'
    $expectedOpenBrowser = ExpectedText 'openBrowser'
    $expectedConfigureIconVisibility = ExpectedText 'configureIconVisibility'
    $expectedOpenPullRequestDiffView = ExpectedText 'openPullRequestDiffView'
    $expectedMarkFileAsViewed = ExpectedText 'markFileAsViewed'
    $expectedAddFileComment = ExpectedText 'addFileComment'

    if ($nlsText.IndexOf($expectedFeedbackMenu, [System.StringComparison]::Ordinal) -lt 0 -and $languagePackText.IndexOf($expectedFeedbackMenu, [System.StringComparison]::Ordinal) -lt 0) {
        Fail 'Package verification failed: missing localized feedback menu text.'
    }
    if ($languagePackText.IndexOf($expectedProcessExplorer, [System.StringComparison]::Ordinal) -lt 0) {
        Fail 'Package verification failed: missing localized process explorer text in fused language pack.'
    }
    if ($languagePackText.IndexOf($expectedOpenProcessExplorer, [System.StringComparison]::Ordinal) -lt 0) {
        Fail 'Package verification failed: missing localized open process explorer text in fused language pack.'
    }
    if ($languagePackText.IndexOf($expectedDeveloperTools, [System.StringComparison]::Ordinal) -lt 0) {
        Fail 'Package verification failed: missing localized developer tools text in fused language pack.'
    }
    if ($languagePackText.IndexOf($expectedOpenBrowser, [System.StringComparison]::Ordinal) -lt 0) {
        Fail 'Package verification failed: missing localized open browser text in fused language pack.'
    }
    if ($languagePackText.IndexOf($expectedConfigureIconVisibility, [System.StringComparison]::Ordinal) -lt 0) {
        Fail 'Package verification failed: missing localized configure icon visibility text in fused language pack.'
    }
    if ($githubPrText.IndexOf($expectedOpenPullRequestDiffView, [System.StringComparison]::Ordinal) -lt 0) {
        Fail 'Package verification failed: missing localized GitHub PR diff view text in fused language pack.'
    }
    if ($githubPrText.IndexOf($expectedMarkFileAsViewed, [System.StringComparison]::Ordinal) -lt 0) {
        Fail 'Package verification failed: missing localized GitHub PR viewed text in fused language pack.'
    }
    if ($githubPrText.IndexOf($expectedAddFileComment, [System.StringComparison]::Ordinal) -lt 0) {
        Fail 'Package verification failed: missing localized GitHub PR file comment text in fused language pack.'
    }
    if ($bundleText.IndexOf(('this.LABEL="' + $expectedFeedbackLabel + '"'), [System.StringComparison]::Ordinal) -lt 0) {
        Fail 'Package verification failed: missing localized feedback label in workbench bundle.'
    }

    AssertProductChecksums $PackageRoot 'Package'
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
            [void]$files.Add([pscustomobject]@{
                Source = $_.FullName
                Relative = $relative
            })
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

function AssertFileMatchesPackage($TargetRoot, $Relative) {
    $sourcePath = Join-Path $packageRoot $Relative
    $targetPath = Join-Path $TargetRoot $Relative

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        Fail ("Package is missing key file: " + $Relative)
    }
    if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
        Fail ("Target is missing installed key file: " + $Relative)
    }

    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash
    if ($sourceHash -ne $targetHash) {
        Fail ("Installed verification failed: target file does not match package file: " + $Relative)
    }
}

function AssertInstalledFiles($TargetRoot) {
    $requiredFiles = @(
        'resources\app\product.json',
        'resources\app\out\main.js',
        'resources\app\out\nls.keys.json',
        'resources\app\out\nls.messages.json',
        'resources\app\out\vs\workbench\workbench.desktop.main.js',
        'resources\app\out\vs\workbench\contrib\composer\browser\preload-webview-browser.js',
        'resources\app\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106\package.json',
        'resources\app\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106\translations\main.i18n.json',
        'resources\app\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106\translations\extensions\github.vscode-pull-request-github.i18n.json'
    )

    foreach ($relative in $requiredFiles) {
        $path = Join-Path $TargetRoot $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Fail ("Target is missing installed key file: " + $relative)
        }
    }

    $nlsPath = Join-Path $TargetRoot 'resources\app\out\nls.messages.json'
    $mainPath = Join-Path $TargetRoot 'resources\app\out\main.js'
    $bundlePath = Join-Path $TargetRoot 'resources\app\out\vs\workbench\workbench.desktop.main.js'
    $languagePackPath = Join-Path $TargetRoot 'resources\app\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106\translations\main.i18n.json'
    $githubPrPath = Join-Path $TargetRoot 'resources\app\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106\translations\extensions\github.vscode-pull-request-github.i18n.json'

    $nlsText = [System.IO.File]::ReadAllText($nlsPath, [System.Text.Encoding]::UTF8)
    $mainText = [System.IO.File]::ReadAllText($mainPath, [System.Text.Encoding]::UTF8)
    $bundleText = [System.IO.File]::ReadAllText($bundlePath, [System.Text.Encoding]::UTF8)
    $languagePackText = [System.IO.File]::ReadAllText($languagePackPath, [System.Text.Encoding]::UTF8)
    $githubPrText = [System.IO.File]::ReadAllText($githubPrPath, [System.Text.Encoding]::UTF8)

    $expectedFeedbackMenu = ExpectedText 'feedbackMenu'
    $expectedFeedbackLabel = ExpectedText 'feedbackLabel'
    $expectedProcessExplorer = ExpectedText 'processExplorer'
    $expectedOpenProcessExplorer = ExpectedText 'openProcessExplorer'
    $expectedDeveloperTools = ExpectedText 'developerTools'
    $expectedOpenBrowser = ExpectedText 'openBrowser'
    $expectedConfigureIconVisibility = ExpectedText 'configureIconVisibility'
    $expectedOpenPullRequestDiffView = ExpectedText 'openPullRequestDiffView'
    $expectedMarkFileAsViewed = ExpectedText 'markFileAsViewed'
    $expectedAddFileComment = ExpectedText 'addFileComment'

    $checks = @(
        @{ Name = 'Help menu Give Feedback'; Text = ($nlsText + $languagePackText); Expected = $expectedFeedbackMenu },
        @{ Name = 'Help menu Open Process Explorer'; Text = $languagePackText; Expected = $expectedOpenProcessExplorer },
        @{ Name = 'Help menu Process Explorer title'; Text = $languagePackText; Expected = $expectedProcessExplorer },
        @{ Name = 'Help menu Developer Tools'; Text = $languagePackText; Expected = $expectedDeveloperTools },
        @{ Name = 'Editor menu Open Browser'; Text = $languagePackText; Expected = $expectedOpenBrowser },
        @{ Name = 'Editor menu Configure Icon Visibility'; Text = $languagePackText; Expected = $expectedConfigureIconVisibility },
        @{ Name = 'GitHub PR Open Pull Request Diff View'; Text = $githubPrText; Expected = $expectedOpenPullRequestDiffView },
        @{ Name = 'GitHub PR Mark File As Viewed'; Text = $githubPrText; Expected = $expectedMarkFileAsViewed },
        @{ Name = 'GitHub PR Add File Comment'; Text = $githubPrText; Expected = $expectedAddFileComment },
        @{ Name = 'Main process nls bootstrap'; Text = $mainText; Expected = 'nls.messages.json' },
        @{ Name = 'Main process process explorer title'; Text = $mainText; Expected = 'S(2183,null)' },
        @{ Name = 'Workbench Give Feedback action'; Text = $bundleText; Expected = ('this.LABEL="' + $expectedFeedbackLabel + '"') }
    )

    foreach ($check in $checks) {
        if ($check.Text.IndexOf($check.Expected, [System.StringComparison]::Ordinal) -lt 0) {
            Fail ("Installed verification failed: " + $check.Name + " is not patched in target Cursor.")
        }
    }

    AssertFileMatchesPackage $TargetRoot 'resources\app\product.json'
    AssertFileMatchesPackage $TargetRoot 'resources\app\out\main.js'
    AssertFileMatchesPackage $TargetRoot 'resources\app\out\nls.messages.json'
    AssertFileMatchesPackage $TargetRoot 'resources\app\out\vs\workbench\workbench.desktop.main.js'
    AssertFileMatchesPackage $TargetRoot 'resources\app\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106\translations\main.i18n.json'
    AssertFileMatchesPackage $TargetRoot 'resources\app\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106\translations\extensions\github.vscode-pull-request-github.i18n.json'
    AssertProductChecksums $TargetRoot 'Installed'
}

$packageRoot = FullPath $PSScriptRoot
Info ("Package root: " + $packageRoot)

AssertPackageRoot $packageRoot
Ok 'Package structure verified'

$resolvedCursorRoot = ResolveManualCursorRoot $CursorRoot $WhatIf
if ([string]::IsNullOrWhiteSpace($resolvedCursorRoot)) {
    $resolvedCursorRoot = FindCursorRoot $CursorRoot
}
if ([string]::IsNullOrWhiteSpace($resolvedCursorRoot)) {
    Fail 'Cursor root was not found. Use -CursorRoot to specify it manually.'
}

if ((-not $WhatIf) -and (-not (IsCursorRoot $resolvedCursorRoot)) ) {
    Fail ("Invalid Cursor root: " + $resolvedCursorRoot)
}
if ($WhatIf -and (-not (IsCursorRoot $resolvedCursorRoot)) -and (-not (IsCursorResourceRoot $resolvedCursorRoot))) {
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