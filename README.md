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

## 重要说明

- 当前交付以“核心复制包 + VSIX 语言包”为准。
- 一键安装脚本只复制核心补丁文件，不再递归复制已展开语言包目录。
- 基础菜单、命令、设置、扩展翻译由根目录 VSIX 负责：`ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106-cursor105-fused.vsix`。
- 菜单类英文优先检查融合中文语言包源码：`H:\clourer\__zh_pack_fused\extension\translations\main.i18n.json`。
- 用户扩展贡献的菜单英文优先检查融合语言包的扩展翻译文件，例如 GitHub Pull Requests：`H:\clourer\__zh_pack_fused\extension\translations\extensions\github.vscode-pull-request-github.i18n.json`。
- 如果语言包缺少对应模块/key，先补语言包源码并重新打包 VSIX；只有确认不是语言包可接管的文案，才改 `workbench.desktop.main.js`。
- 复制包根目录保留一个标准 VSIX，供 Cursor “从 VSIX 安装”时选择。
- 安装脚本会校验目标核心文件与复制包文件一致，避免使用旧版本内部标记误判安装失败。
- 复制包包含同步后的 `resources/app/product.json`，用于匹配已汉化的 `workbench.desktop.main.js` 完整性校验，避免 Cursor 报安装损坏。
- Automations 页面属于主程序硬编码前端文案，当前已通过 `workbench.desktop.main.js` 窄范围补丁汉化首页、统计卡片、运行历史、表格表头、空状态和新建按钮。
- 如果需要安装或重装基础语言包，请选择本目录下的 `ms-ceintl.vscode-language-pack-zh-hans-1.121.2026052106-cursor105-fused.vsix`。
- VSIX 已按标准 ZIP 路径格式打包，包内路径使用 `/`，避免 Cursor 选择文件安装时识别不到。

## 如果安装后仍有英文

把英文界面截图发回来，继续只改这个复制包，不直接改真实 Cursor 安装目录。