# Cursor 中文汉化包

这是一个面向 Windows 版 Cursor 的中文汉化包。推荐普通用户使用图形更新器安装和更新；仓库内脚本保留为手动备用方式。

## 推荐方式：使用图形更新器

1. 安装 [Git for Windows](https://git-scm.com/download/win)，并确保 `git.exe` 可以在系统 `PATH` 中运行。
2. 从本仓库 Releases 下载并运行版本号最高的图形更新器：
   `CursorZhLauncher-v*.exe`

   例如当前应优先使用 `CursorZhLauncher-v1.0.3.exe`。不要下载旧版本，除非新版无法启动且你正在排查兼容问题。
3. 在更新器中点击“检查本机 Cursor”，确认检测到本机 Cursor 版本。
4. 点击“同步汉化仓库”。更新器会使用系统 `git.exe` 拉取：
   `https://github.com/a2893005741/Cursor-Chinese.git`
5. 点击“更新本地汉化文件”。更新器只会复制安装所需白名单文件到本地可安装包。
6. 当“汉化包版本”和“本机 Cursor”显示匹配后，先完全关闭 Cursor。
7. 点击“安装核心汉化”。更新器会先执行 `安装汉化包.ps1 -WhatIf`，检查通过后才执行真实安装。
8. 点击“安装融合语言包”，安装基础菜单、命令、设置和扩展翻译所需的 VSIX。
9. 重新打开 Cursor。

更新器使用的运行时目录：

- 仓库缓存：`%LOCALAPPDATA%\CursorZhUpdater\repo`
- 本地可安装包：`%LOCALAPPDATA%\CursorZhUpdater\package`
- 日志目录：`%LOCALAPPDATA%\CursorZhUpdater\logs`

更新器不会直接把仓库源码目录当作安装包使用。它会先同步到本机缓存，再复制安装所需文件到本地可安装包目录。

## 版本号优先

- 总是优先下载 Releases 中版本号最高的 `CursorZhLauncher-v*.exe`。
- 新版本会保留旧版本文件名，不会覆盖已经运行中的旧 EXE。
- 如果你已经打开了旧版本，关闭旧窗口后再运行新版本。
- README、Release 文案或截图中的旧版本号只作为历史示例；实际下载以 Releases 里最高版本为准。

## 手动备用方式

如果不使用图形更新器，可以克隆或下载本仓库后，在仓库目录手动执行：

1. 先完全关闭 Cursor。
2. 双击 `一键安装汉化包.cmd`，复制核心汉化文件。
3. 双击 `安装融合语言包扩展.cmd`，或手动安装：
   `ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052214.vsix`
4. 重新打开 Cursor。

手动方式不会自动同步远端仓库，也不会帮你判断当前仓库内容是否匹配本机 Cursor。版本不匹配时不要强行覆盖。

## 检查是否生效

如果安装后界面仍有英文，先双击：

`只检查是否已正确汉化.cmd`

这个检查不会复制或修改真实 Cursor 安装目录，只会确认真实 Cursor 目录里的核心补丁文件是否与本目录一致。

- 检查失败：真实 Cursor 目录当前加载的关键文件不是本汉化包里的文件。
- 检查通过但仍有英文：继续排查 VSIX 是否安装、Cursor 缓存、运行态动态文案或尚未补齐的界面英文。

## 当前复制内容

核心安装脚本只复制这些文件：

- `resources/app/product.json`
- `resources/app/out/main.js`
- `resources/app/out/nls.keys.json`
- `resources/app/out/nls.messages.json`
- `resources/app/out/vs/base/parts/sandbox/electron-sandbox/preload.js`
- `resources/app/out/vs/workbench/workbench.desktop.main.css`
- `resources/app/out/vs/workbench/api/node/extensionHostProcess.js`
- `resources/app/out/vs/workbench/workbench.desktop.main.js`
- `resources/app/out/vs/workbench/contrib/composer/browser/preload-webview-browser.js`
- `resources/app/out/vs/code/electron-sandbox/workbench/workbench.js`
- `locales/en-GB.pak`
- `locales/en-US.pak`

基础界面中文由融合语言包负责：

- `ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052214.vsix`
