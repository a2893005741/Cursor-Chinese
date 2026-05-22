$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$root = $PSScriptRoot
$zipName = '一键复制到Cursor安装目录 (2).zip'
$zip = Join-Path $root $zipName
$tempZip = Join-Path $root '__current_package.zip'
$staging = Join-Path $root '__zip_staging_current'

Get-ChildItem -LiteralPath $root -Force |
    Where-Object { $_.PSIsContainer -and $_.Name.EndsWith('(2)') } |
    Remove-Item -Recurse -Force

Get-ChildItem -LiteralPath $root -Force |
    Where-Object { -not $_.PSIsContainer -and ($_.Name.EndsWith('(2).zip') -or $_.Name -eq '__current_package.zip') } |
    Remove-Item -Force

if (Test-Path -LiteralPath $staging) {
    Remove-Item -LiteralPath $staging -Recurse -Force
}
New-Item -ItemType Directory -Path $staging -Force | Out-Null

Get-ChildItem -LiteralPath $root -Force |
    Where-Object {
        $_.Name -ne 'install-backups' -and
        $_.Name -ne '__zip_staging_current' -and
        -not $_.Name.StartsWith('__') -and
        -not $_.Name.EndsWith('(2)') -and
        -not ($_.Name.EndsWith('(2).zip'))
    } |
    ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $staging $_.Name) -Recurse -Force
    }

Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $tempZip -CompressionLevel Optimal
Move-Item -LiteralPath $tempZip -Destination $zip -Force
Remove-Item -LiteralPath $staging -Recurse -Force

$zipInfo = Get-Item -LiteralPath $zip
Write-Host ('updated: ' + $zipInfo.FullName)
Write-Host ('bytes: ' + $zipInfo.Length)