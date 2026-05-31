@echo off
setlocal EnableExtensions
title Cursor Fused Language Pack Installer

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%install-fused-language-pack.ps1"

echo.
echo ========================================
echo Cursor Fused Language Pack Installer
echo ========================================
echo.
echo This script only installs the fused language pack VSIX.
echo It does not copy core patch files.
echo Restart Cursor after installation.
echo.

if not exist "%PS_SCRIPT%" (
    echo [ERROR] Missing PowerShell script:
    echo %PS_SCRIPT%
    echo.
    goto :END_FAIL
)

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] powershell.exe was not found.
    echo.
    goto :END_FAIL
)

echo Installing fused language pack extension...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo [OK] Extension install command completed.
    echo Open Cursor to apply it.
    goto :END_OK
)

if "%EXIT_CODE%"=="2" (
    echo [SKIPPED] Cursor is running.
    echo Close Cursor completely, then run this installer again.
    goto :END_FAIL
)

echo [ERROR] Installer exited with code: %EXIT_CODE%
echo If it still fails, install the VSIX manually from Cursor.

:END_FAIL
echo.
pause
exit /b %EXIT_CODE%

:END_OK
echo.
pause
exit /b 0
