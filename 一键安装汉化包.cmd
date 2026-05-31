@echo off
setlocal EnableExtensions
title Cursor Chinese Patch Installer

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%" >nul 2>nul
if errorlevel 1 (
    echo.
    echo [ERROR] Cannot enter package directory:
    echo %SCRIPT_DIR%
    echo.
    goto :END_FAIL
)

echo.
echo ========================================
echo Cursor Chinese Patch Installer
echo ========================================
echo.
echo Please close Cursor completely before installing.
echo.

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] powershell.exe was not found.
    echo.
    goto :END_FAIL
)

echo Starting installer...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $n=(-join ([char[]](23433,35013,27721,21270,21253)))+'.ps1'; $p=Join-Path (Get-Location).ProviderPath $n; if(!(Test-Path -LiteralPath $p -PathType Leaf)){ Write-Host ('[ERROR] Missing installer ps1: '+$p); exit 1 }; & $p -Yes; exit $LASTEXITCODE"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo [OK] Installation completed.
    echo Restart Cursor and check the UI.
    goto :END_OK
)

if "%EXIT_CODE%"=="2" (
    echo [NOT INSTALLED] Cursor is still running.
    echo Close Cursor completely and run this file again.
    goto :END_FAIL_WITH_CODE
)

echo [FAILED] Installer exit code: %EXIT_CODE%
echo Check the PowerShell output above and send it back if it still fails.
goto :END_FAIL_WITH_CODE

:END_FAIL
set "EXIT_CODE=1"

:END_FAIL_WITH_CODE
echo.
popd >nul 2>nul
pause
exit /b %EXIT_CODE%

:END_OK
echo.
popd >nul 2>nul
pause
exit /b 0
