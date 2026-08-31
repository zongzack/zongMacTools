# zongMacTools

`zongMacTools` 是一组 macOS 桌面效率工具，目前包含 Dock 窗口速览和 Finder 右键助手。

- **Dock 窗口速览**：将鼠标悬停在 Dock 中正在运行的应用上，查看该应用的窗口缩略图并快速切换。
- **Finder 右键助手**：在 Finder 文件夹或桌面空白处右键新建常用文件，也可以使用自己的模板。

## 功能

### Dock 窗口速览

- 悬停 Dock 图标显示窗口预览面板。
- 点击卡片切换到对应窗口。
- 支持最多 3、5、8 或 12 张预览卡片。
- 右键卡片可激活窗口、隐藏应用、关闭窗口或最小化窗口。
- 支持排除指定 App、调整悬停延迟和面板保留时间。
- 支持浅色/深色外观、减少动态效果和中英文界面。

### Finder 右键助手

启用 Finder Sync 扩展后，在 Finder 普通目录或桌面空白处右键即可使用“新建文件 / New File”菜单。默认格式包括：

| 格式 | 创建内容 |
| --- | --- |
| TXT | 零字节 `.txt` 文件 |
| Markdown | 零字节 `.md` 文件 |
| JSON | UTF-8 编码的 `{}` |
| Word | 空白 `.docx` 文档 |
| Excel | 带 `Sheet1` 的空白 `.xlsx` 工作簿 |
| PowerPoint | 包含一张空白幻灯片的 `.pptx` 演示文稿 |

右键助手还支持：

- 单独启用或停用格式。
- 拖拽调整菜单顺序。
- 修改显示名称。
- 导入普通文件作为自定义模板。
- 修改自定义模板后缀、删除模板或恢复默认配置。
- 文件重名时自动尝试 ` 2`、` 3` 等后缀，不覆盖已有文件。
- 创建成功后自动选中新文件。

## 系统要求

- macOS 14 或更新版本。
- Apple Silicon 或 Intel Mac。
- Swift 6 / Xcode Command Line Tools（仅从源码构建时需要）。

首次运行需要在“系统设置 > 隐私与安全性”中授予：

1. **辅助功能**：用于监听 Dock 事件和执行窗口操作。
2. **屏幕录制**：用于枚举窗口并生成静态缩略图。
3. **Finder 扩展**：在“扩展 > Finder”中启用 `zongMacTools` Finder Sync 扩展。

如果只使用 Finder 右键助手，不需要安装 WPS 或 Microsoft Office；Office 应用仅用于打开和编辑创建出的 Office 文件。

## 安装与运行

### 从 GitHub Releases 安装

普通用户可以直接从 [GitHub Releases](https://github.com/zongzack/zongMacTools/releases) 下载最新公开测试版：

1. 下载对应版本的 `zongMacTools-<version>-<build>.zip`。
2. 可选：按照同一发布页提供的 `SHA256SUMS.txt` 校验文件完整性。
3. 解压后将 `zongMacTools.app` 移动到 `/Applications`，然后打开应用。
4. 首次打开未公证的 ad-hoc 应用时，如果 macOS 阻止启动，请在 Finder 中按住 Control 点击应用，选择“打开”，再确认启动。
5. 按照下面的权限和 Finder 扩展步骤完成配置。

发行版当前是未公证的公开测试包，需要用户手动授予辅助功能、屏幕录制权限，并手动启用 Finder Sync 扩展。替换应用版本后，macOS 可能要求重新授予权限或重新启用扩展。

### 从源码构建

```bash
Scripts/build_probe_app.sh
```

构建产物为：

```text
build/zongMacTools.app
```

脚本会同时打包主程序、`FinderSyncExtension.appex` 和内置 Office 模板资源。

启动应用：

```bash
Scripts/run_probe_app.sh
```

### 启用 Finder 右键助手

1. 将 `zongMacTools.app` 放在固定位置，推荐 `/Applications/zongMacTools.app`。
2. 启动应用并打开菜单栏中的 `Open Settings...` / `打开设置`。
3. 进入 `Right-click Extension` / `右键扩展`。
4. 点击 `Manage Finder Extension` / `管理 Finder 扩展`。
5. 在“系统设置 > 隐私与安全性 > 扩展 > Finder”中启用 `zongMacTools`。
6. 返回设置窗口，确认扩展状态为“已启用”。

右键助手的配置和自定义模板保存在用户目录，不会写入 app bundle：

```text
~/Library/Application Support/com.zong.zongMacTools/FinderNewFile/catalog.json
~/Library/Application Support/com.zong.zongMacTools/FinderNewFile/Templates/
```

## 使用方式

### Dock 窗口速览

1. 启动 `zongMacTools.app`。
2. 确认辅助功能和屏幕录制权限已授权。
3. 将鼠标悬停在 Dock 中正在运行的应用图标上。
4. 预览面板出现后，点击窗口卡片即可切换。
5. 按 `Esc`，或将鼠标移出 Dock 图标和预览面板，隐藏面板。

菜单栏中的设置窗口还可以配置语言、开机启动、卡片数量、悬停延迟、排除 App 和 Finder 新建文件格式。

### Finder 新建文件

1. 确认 Finder Sync 扩展已启用。
2. 在 Finder 普通目录或桌面空白处右键。
3. 选择 `New File` / `新建文件`，再选择文件格式。
4. 新文件会在当前目录创建并由 Finder 自动选中。

右键助手只响应容器背景菜单。选中文件或文件夹、多选项目、侧边栏、工具栏、最近使用、搜索结果等位置不会显示该菜单。

## 发布包

仓库当前提供未公证的 ad-hoc 公开测试包。发布前请使用：

```bash
Scripts/package_release_app.sh
```

生成的 ZIP、校验和与安装说明位于 `dist/`。首次打开未公证应用时，macOS 可能需要在 Finder 中按住 Control 点击应用并选择“打开”。替换 ad-hoc 签名的应用后，系统可能要求重新授予权限并重新启用 Finder 扩展。

正式发行仍需要 Developer ID 签名、Apple 公证和干净环境验证。

## 已知限制

- Dock 速览当前显示静态缩略图，不提供实时视频预览。
- 只展示当前可见、可枚举且未最小化的普通窗口，不自动切换其他 Space。
- Finder 右键助手依赖用户手动启用 Finder Sync 扩展。
- Finder 虚拟位置、云盘/文件提供程序和其他非普通目录的兼容性不作保证。
- Word、Excel、PowerPoint 文件使用内置静态空白模板；在 WPS/Office 中的实际兼容性需要在目标机器上确认。
- 多显示器场景尚未完成完整验证。

## 开发命令

```bash
# 运行测试
swift test

# 构建 SwiftPM targets
swift build

# 校验 app bundle
Scripts/verify_app_bundle.sh build/zongMacTools.app
```

详细的 Finder 人工验收步骤见 [`docs/verification/finder-new-file-manual-acceptance.md`](docs/verification/finder-new-file-manual-acceptance.md)，发布策略见 [`docs/architecture/release-update-strategy.md`](docs/architecture/release-update-strategy.md)。
