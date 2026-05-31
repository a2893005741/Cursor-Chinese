@echo off
setlocal EnableExtensions
title Cursor Chinese Patch Verification

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%" >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Cannot enter package directory:
    echo %SCRIPT_DIR%
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $n=(-join ([char[]](23433,35013,27721,21270,21253)))+'.ps1'; $p=Join-Path (Get-Location).ProviderPath $n; if(!(Test-Path -LiteralPath $p -PathType Leaf)){ Write-Host ('[ERROR] Missing installer ps1: '+$p); exit 1 }; & $p -VerifyOnly; exit $LASTEXITCODE"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
popd >nul 2>nul
pause
exit /b %EXIT_CODE%
