@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0安装汉化包.ps1" -VerifyOnly
echo.
pause