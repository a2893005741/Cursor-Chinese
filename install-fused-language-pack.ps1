param(
    [string]$CursorRoot = '',
    [switch]$WhatIf
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

function FindCursorCli($CursorRoot) {
    $cli = Join-Path $CursorRoot 'resources\app\bin\cursor.cmd'
    if (Test-Path -Path $cli -PathType Leaf) { return (FullPath $cli) }
    return $null
}

function AssertVsixShape($VsixPath) {
    if (-not (Test-Path -Path $VsixPath -PathType Leaf)) { Fail ("Missing VSIX: " + $VsixPath) }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($VsixPath)
    try {
        $entries = @($zip.Entries | ForEach-Object { $_.FullName })
    } finally {
        $zip.Dispose()
    }

    $required = @(
        'extension/package.json',
        'extension/translations/main.i18n.json',
        'extension/translations/extensions/vscode.git.i18n.json',
        'extension.vsixmanifest'
    )
    foreach ($entry in $required) {
        if (-not ($entries -contains $entry)) { Fail ("VSIX is missing entry: " + $entry) }
    }
    $backslashEntries = @($entries | Where-Object { $_ -like '*\*' })
    if ($backslashEntries.Count -gt 0) { Fail 'VSIX contains invalid backslash entries.' }
}

function SplitOutputLines($Text) {
    if ([string]::IsNullOrEmpty($Text)) { return @() }
    return @($Text -split '\r?\n' | Where-Object { $_ -ne '' })
}

function QuoteCmdArgument($Argument) {
    if ($null -eq $Argument) { return '""' }
    $text = [string]$Argument
    if ($text.Contains('"')) { Fail ("Unsupported quote character in CLI argument: " + $text) }
    return '"' + $text + '"'
}

function InvokeCursorCli($CursorCli, [string[]]$Arguments) {
    $comSpec = $env:ComSpec
    if ([string]::IsNullOrWhiteSpace($comSpec)) {
        $comSpec = Join-Path $env:WINDIR 'System32\cmd.exe'
    }

    $commandParts = New-Object System.Collections.ArrayList
    [void]$commandParts.Add((QuoteCmdArgument $CursorCli))
    foreach ($argument in $Arguments) {
        [void]$commandParts.Add((QuoteCmdArgument $argument))
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $comSpec
    $startInfo.Arguments = '/d /s /c "' + ($commandParts -join ' ') + '"'
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        $lines = @()
        $lines += @(SplitOutputLines $stdout)
        $lines += @(SplitOutputLines $stderr)
        return [PSCustomObject]@{
            ExitCode = [int]$process.ExitCode
            StdOut = $stdout
            StdErr = $stderr
            Lines = $lines
        }
    } finally {
        $process.Dispose()
    }
}

$packageRoot = FullPath $PSScriptRoot
$vsixName = 'ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052214.vsix'
$vsixPath = Join-Path $packageRoot $vsixName

Info ("Package root: " + $packageRoot)
AssertVsixShape $vsixPath
Ok ("VSIX verified: " + $vsixPath)

$resolvedCursorRoot = FindCursorRoot $CursorRoot
if ([string]::IsNullOrWhiteSpace($resolvedCursorRoot)) { Fail 'Cursor root was not found. Use -CursorRoot to specify it manually.' }
$cursorExe = Join-Path $resolvedCursorRoot 'Cursor.exe'
Ok ("Cursor executable: " + $cursorExe)
$cursorCli = FindCursorCli $resolvedCursorRoot
if ([string]::IsNullOrWhiteSpace($cursorCli)) { Fail 'Cursor CLI wrapper was not found: resources\app\bin\cursor.cmd' }
Ok ("Cursor CLI wrapper: " + $cursorCli)

$arguments = @('--install-extension', $vsixPath, '--force')
if ($WhatIf) {
    Write-Host ("WhatIf: " + $cursorCli + " " + ($arguments -join ' '))
    Warn 'No extension was installed because -WhatIf was used.'
    exit 0
}

try {
    $runningCursor = @(Get-Process -Name 'Cursor' -ErrorAction SilentlyContinue)
    if ($runningCursor.Count -gt 0) {
        Warn 'Cursor is running. Please close Cursor completely before installing the language pack.'
        Warn 'No extension was installed. This avoids stale windows using the old language-pack state.'
        exit 2
    }
} catch {}

Warn 'This installs only the fused language pack VSIX. It does not copy core patch files.'
Warn 'Open Cursor after installation so the language pack is loaded from a fresh process.'

$cliResult = InvokeCursorCli -CursorCli $cursorCli -Arguments $arguments
$cliOutput = @($cliResult.Lines)
$exitCode = [int]$cliResult.ExitCode
if ($exitCode -ne 0) {
    $installLog = Join-Path ([System.IO.Path]::GetTempPath()) ('cursor-fused-language-pack-install-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
    [System.IO.File]::WriteAllLines($installLog, [string[]]($cliOutput | ForEach-Object { [string]$_ }), [System.Text.Encoding]::UTF8)
    Warn ("Cursor CLI output was saved to: " + $installLog)
    Fail ("Cursor extension install failed with exit code: " + $exitCode)
}

$stderrLines = @(SplitOutputLines $cliResult.StdErr)
if ($stderrLines.Count -gt 0) {
    Warn 'Cursor CLI wrote warning output to stderr but exited successfully.'
    foreach ($line in @($stderrLines | Select-Object -First 6)) {
        Warn ("CLI stderr: " + $line)
    }
}

Write-Host ''
Ok 'Fused language pack VSIX installation command completed.'
Warn 'Open Cursor now to apply the language pack.'
