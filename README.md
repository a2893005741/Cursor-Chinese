# Cursor 中文化复制安装包

这是一个用于 Cursor 的简体中文化复制安装包。普通用户只需要使用 `一键复制到Cursor安装目录` 文件夹里的内容即可。

> 适用系统：Windows
>
> 适用目标：Cursor 桌面版

## 这个包能做什么

- 把 Cursor 界面中的大量英文文案替换为简体中文。
- 包含 Cursor / VS Code 简体中文语言包融合版本，作为 `.vsix` 文件随包提供，需要你在 Cursor 里手动安装。
- 包含 Cursor 主界面、Agent、Composer、设置页等界面的中文化补丁。
- 提供一键安装脚本，安装前会自动备份被覆盖的文件；脚本不会把扩展复制进 Cursor 安装目录。

## 快速安装

1. 下载本项目。
2. 打开 `一键复制到Cursor安装目录` 文件夹。
3. 完全关闭 Cursor。
4. 双击运行 `一键安装汉化包.cmd`。
5. 等待脚本提示完成。
6. 重新打开 Cursor。
7. 如果还需要安装中文语言包扩展，请在 Cursor 中手动安装 `一键复制到Cursor安装目录\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106-cursor105-fused.vsix`。

如果双击脚本无法运行，也可以在 `一键复制到Cursor安装目录` 文件夹中打开 PowerShell，然后执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-localization.ps1
```

## 安装包内容

```text
一键复制到Cursor安装目录/
├─ 一键安装汉化包.cmd
├─ install-localization.ps1
├─ 安装汉化包.ps1
├─ extensions/
│  └─ ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106-cursor105-fused.vsix
├─ locales/
│  ├─ en-GB.pak
│  └─ en-US.pak
└─ resources/
   └─ app/
      └─ out/
         ├─ nls.messages.json
         └─ vs/
            └─ workbench/
               ├─ workbench.desktop.main.js
               └─ contrib/
                  └─ composer/
                     └─ browser/
                        └─ preload-webview-browser.js
```

## 文件说明

| 文件或目录 | 作用 |
| --- | --- |
| `一键安装汉化包.cmd` | 给普通用户使用的双击安装入口。 |
| `install-localization.ps1` | PowerShell 安装入口，会自动调用正式安装脚本。 |
| `安装汉化包.ps1` | 正式安装脚本，负责查找 Cursor、备份旧文件、复制主程序汉化文件；不会复制扩展目录。 |
| `resources/app/out/nls.messages.json` | Cursor / VS Code 标准界面文案的中文化文件。 |
| `resources/app/out/vs/workbench/workbench.desktop.main.js` | Cursor 主界面、按钮、菜单、Agent 等硬编码文案补丁。 |
| `resources/app/out/vs/workbench/contrib/composer/browser/preload-webview-browser.js` | Composer / Webview 相关界面的中文化补丁。 |
| `locales/` | Electron / Chromium 相关本地化资源。 |
| `extensions/ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106-cursor105-fused.vsix` | 融合后的简体中文语言包扩展安装包，由你在 Cursor 中手动安装。 |
| `install-backups/` | 安装时自动生成的备份目录。首次下载时可能不存在。 |

## 安全说明

- 安装前请先完全关闭 Cursor。
- 安装脚本会先备份将要覆盖的文件，再复制主程序汉化文件。
- 安装脚本不会复制 `resources/app/extensions` 扩展目录；语言包 `.vsix` 请手动安装。
- 备份会保存在 `一键复制到Cursor安装目录/install-backups/时间戳/` 下。
- 本项目不会在你下载后自动修改 Cursor，只有你主动运行安装脚本时才会执行安装。
- 如果不确定安装位置，可以先执行试运行命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-localization.ps1 -WhatIf
```

## 常见问题

### 运行脚本后提示 Cursor 正在运行怎么办？

请完全退出 Cursor 后再运行安装脚本。只关闭窗口可能不够，建议在任务栏托盘或任务管理器中确认 Cursor 已退出。

### 安装后没有变成中文怎么办？

请重启 Cursor。如果仍未生效，通常是 Cursor 版本结构发生变化，需要重新适配对应版本的复制安装包。

### 可以直接手动复制文件吗？

可以，但不推荐。推荐使用 `一键安装汉化包.cmd`，因为脚本会自动备份旧文件，手动复制更容易漏文件。

## 近期维护记录

- 已确认安装脚本不复制 `resources/app/extensions` 扩展目录，复制包压缩文件也不再包含扩展目录；语言包扩展改为由用户手动安装 `.vsix`。
- 已按当前复制包资源重新补齐文件菜单截图中的残留英文，包括 `新建文本文件`、`新建窗口`、`打开文件...`、`打开文件夹...`、`另存为...`、`全部保存`、`自动保存`、`关闭编辑器` 等可见菜单项。
- 已刷新 `一键复制到Cursor安装目录 (2).zip`，压缩包内容与当前复制包目录保持一致。
- 已补齐文件菜单截图中的残留英文，包括 `Switch to Agents Window`、`Close Window`、`Exit` 等可见菜单项。
- 已补齐侧边栏和分组菜单截图中的残留英文，包括 `Marketplace`、`Repositories`、`Show`、`Collapse All`、`More`、`Automations`。
- 保留 `Slack`、`Linear`、`Git`、`SDK`、`API` 等产品名或技术名，避免误伤程序值。
- 所有补丁均只写入 `一键复制到Cursor安装目录` 复制包目录。

## 版本信息

- 语言包版本：`1.121.2026052106`
- 融合包文件：`H:\clourer\一键复制到Cursor安装目录\extensions\ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106-cursor105-fused.vsix`
- 主要面向 Cursor `1.105.x` 相关资源结构

Cursor 更新后，旧补丁可能失效。如果升级 Cursor 后出现界面异常或部分英文恢复，需要重新制作对应版本的复制安装包。

## 声明

本项目是面向 Cursor 的中文化复制安装包整理。Cursor 及相关资源版权归原权利方所有，VS Code 官方中文语言包部分遵循其原始许可。请仅在你自己可控的环境中使用。