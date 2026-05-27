@echo off
setlocal EnableExtensions
chcp 65001 >nul
title Cursor 汉化包安装器

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%安装汉化包.ps1"

echo.
echo ========================================
echo Cursor 汉化包安装器
echo ========================================
echo.
echo 说明：安装前请先完全关闭 Cursor。
echo.

if not exist "%PS_SCRIPT%" (
    echo [错误] 找不到安装脚本：
    echo %PS_SCRIPT%
    echo.
    goto :END_FAIL
)

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo [错误] 系统找不到 powershell.exe，无法运行安装脚本。
    echo.
    goto :END_FAIL
)

echo 正在启动安装脚本...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Yes
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo [完成] 汉化包安装完成。
    echo 请重新打开 Cursor 查看效果。
    goto :END_OK
)

if "%EXIT_CODE%"=="2" (
    echo [未安装] 检测到 Cursor 正在运行。
    echo 请先完全关闭 Cursor，再重新双击本文件。
    goto :END_FAIL
)

echo [失败] 安装脚本退出码：%EXIT_CODE%
echo 可能原因：安装包不完整、混用了新旧文件，或汉化文件修改后没有同步校验信息。
echo 请重新下载/解压最新版完整汉化包后再运行；如果仍失败，请把上面的错误内容截图发给我。

:END_FAIL
echo.
pause
exit /b %EXIT_CODE%

:END_OK
echo.
pause
exit /b 0