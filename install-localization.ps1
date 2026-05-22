param(
    [switch]$WhatIf
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$installer = Get-ChildItem -LiteralPath $root -File -Filter '*.ps1' |
    Where-Object {
        $_.Name -ne 'install-localization.ps1' -and
        (Get-Content -LiteralPath $_.FullName -Raw) -match 'FindCursorRoot' -and
        (Get-Content -LiteralPath $_.FullName -Raw) -match 'Package structure verified'
    } |
    Select-Object -First 1

if ($null -eq $installer) {
    Write-Host '[ERROR] installer script was not found.' -ForegroundColor Red
    exit 1
}

if ($WhatIf) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installer.FullName -WhatIf @args
} else {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installer.FullName -Yes @args
}

exit $LASTEXITCODE