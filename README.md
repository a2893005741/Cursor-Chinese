# Cursor 汉化复制包说明

这个目录是给 Cursor 使用的精简汉化复制包：复制包只覆盖少量核心补丁文件，基础界面中文由 VSIX 语言包负责。

## 一键安装

1. 先完全关闭 Cursor。
2. 双击 `一键安装汉化包.cmd`，复制核心汉化文件。
3. 手动安装本目录下的 `ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106-cursor105-fused.vsix`，用于基础菜单、命令、设置、扩展翻译。
4. 等提示完成后，重新打开 Cursor。

## 只检查是否真正生效

如果你已经手动覆盖或运行过安装，但界面仍有英文，先双击 `只检查是否已正确汉化.cmd`。

这个检查不会复制或修改任何真实安装文件，只会确认真实 Cursor 目录里的核心补丁文件是否与本复制包一致。基础界面中文由 VSIX 语言包负责。

如果这里检查失败，说明真实目录当前实际加载的关键文件还不是本复制包里的文件；如果这里检查通过但界面仍英文，再继续排查缓存或其他运行态来源。

## 当前复制内容

安装脚本只复制这些核心补丁文件和 Cursor 完整性校验关联文件：

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

基础界面中文由这个 VSIX 负责：

- `ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106-cursor105-fused.vsix`

