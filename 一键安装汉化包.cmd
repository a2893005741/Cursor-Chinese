@echo off
setlocal
cd /d "%~dp0"
echo Cursor localization installer
echo.
echo Please close Cursor completely before continuing.
echo This script will install the localization package from this folder.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-localization.ps1"
set "exitCode=%ERRORLEVEL%"
echo.
if "%exitCode%"=="0" (
  echo Done. Please restart Cursor.
) else (
  echo Failed or cancelled. Exit code: %exitCode%
)
echo.
pause
exit /b %exitCode%