# zongMacTools 多工具设置窗口开发设计

日期：2026-07-06

## 背景

`zongMacTools` 当前是一个 macOS 菜单栏常驻工具，主要功能是 Dock hover 时显示窗口预览。现有设置全部放在菜单栏 `NSMenu` 中，包括启停、悬停延迟、面板保留手感、最大卡片数、语言、排除 App、Launch at Login、权限入口、About / Status 和诊断导出。

这个菜单结构适合早期 MVP，但不适合继续扩展多个 tools。后续会有右键扩展等工具，继续把每个工具的配置堆进菜单会让入口变长、层级混乱，也无法承载滑杆、说明文案、列表管理等更适合设置窗口的控件。

本设计把菜单栏入口调整为“极简菜单 + 独立设置窗口”：菜单只保留状态和快捷操作；设置窗口左侧列出工具和系统页面，右侧展示当前工具的详细配置。

## 命名

当前 Dock hover preview 功能的用户可见名称改为：

```text
Dock 窗口速览
```

推荐使用方式：

- 左侧工具名：`Dock 窗口速览`
- 详情页标题：`Dock 窗口速览`
- 状态文案：`Dock 窗口速览：已启用` / `Dock 窗口速览：已停用`
- 说明文案：`悬停在 Dock 应用图标上时，快速查看该应用的窗口卡片。`

实现阶段不要求同步重命名 Swift target、源码目录、已有类型和测试文件。`DockHoverPreviewSettings`、`PreviewSessionController` 等内部名称可以先保留，避免把 UI 改版和机械重命名混在一起。后续如需正式产品化命名迁移，应单独规划。

## 目标

- 点击菜单栏 icon 先弹出极简菜单。
- 极简菜单提供打开设置窗口、启停 Dock 窗口速览、About / Status、导出诊断和退出。
- 新增独立设置窗口，采用左侧导航 + 右侧详情的 macOS 设置风格。
- 左侧导航支持当前和未来的多个 tools。
- 右侧 Dock 窗口速览详情页承载现有 P1 设置能力，并使用更适合配置页的控件。
- 数值类配置使用离散预设滑杆，不开放任意数值范围。
- 全局设置和支持能力从 Dock 工具页中分离出来，避免工具页职责膨胀。
- 视觉方向接近现代 macOS 设置窗口：通透 sidebar、清晰内容区、原生控件、克制的 Liquid Glass 感。

## 非目标

- 不实现右键扩展本身。
- 不新增 Dock 窗口速览的行为能力，例如实时视频缩略图、跨 Space 主动拉起窗口、搜索窗口。
- 不改变现有 `UserDefaults` key 的含义。
- 不要求最低系统版本升级到 macOS 26/27。
- 不依赖 macOS 26/27 专属 API；当前项目仍以 macOS 14+ 可构建为约束。
- 不做完整工程命名迁移。
- 不复制第三方 app 的功能集合或源码结构。参考图只作为 UI 密度、控件风格和布局方向参考。

## 信息架构

设置窗口左侧按页面类型分组。

```text
应用
  通用

工具
  Dock 窗口速览
  右键扩展（未开发 / 禁用态）

支持
  权限与状态
```

### 通用

承载 app 级设置：

- 显示语言：English / 简体中文。
- 开机启动：读取和写入 Launch at Login。

这些设置不属于某一个工具，不能放进 Dock 窗口速览页。

### Dock 窗口速览

承载当前 Dock hover preview 的工具级设置：

- 总开关。
- 悬停延迟。
- 面板保留手感。
- 最大卡片数。
- 排除当前前台 App。
- 已排除 App 列表和移除入口。

### 右键扩展

当前只作为未来工具占位。建议在第一版中显示禁用态或“未开发”标签，点击后可展示轻量空状态：

```text
右键扩展尚未启用
此工具将在后续版本中提供右键菜单相关能力。
```

如果实现成本希望进一步收敛，也可以只在左侧显示禁用项，不提供右侧页面。

### 权限与状态

承载支持和排障相关能力：

- Accessibility 状态和打开系统设置入口。
- Screen Recording 状态和打开系统设置入口。
- 刷新权限状态。
- About / Status。
- 导出诊断。

## 菜单栏极简菜单

点击菜单栏 icon 后显示极简菜单。建议结构：

```text
zongMacTools
Dock 窗口速览：已启用

打开设置...
暂停 Dock 窗口速览

关于 / 状态
导出诊断...

退出
```

当 Dock 窗口速览已停用时：

```text
Dock 窗口速览：已停用
启用 Dock 窗口速览
```

菜单中不再直接承载悬停延迟、面板保留手感、最大卡片数、语言、排除 App 列表、权限设置等长配置。它们迁移到设置窗口。

保留 `About / Status` 和 `导出诊断...` 的原因是：故障时用户可能首先打开菜单栏入口，需要快速获得状态和导出排障资料。导出诊断仍使用用户主动选择保存位置的 `NSSavePanel`。

## 设置窗口视觉设计

窗口使用 AppKit `NSWindow` 承载 SwiftUI 内容，窗口尺寸建议默认约 `980 x 640`，可按内容适度调整。窗口应可关闭、可最小化，并在重复点击“打开设置...”时复用同一个窗口实例而不是不断创建新窗口。

视觉原则：

- 左侧 sidebar 使用浅色、半透明或材质感背景，强调现代 macOS 设置风格。
- 右侧内容区保持清晰白底或接近白底，避免过度玻璃化影响阅读。
- 使用原生 `Toggle`、`Slider`、`Picker`、`Button`、`List` 或等价 SwiftUI/AppKit 控件。
- 交互目标不小于 macOS 常见控件尺寸，行高保持舒适。
- 文案不要写成教程式大段说明；每个复杂设置只保留一句短说明。
- 支持浅色和深色外观；不能只调浅色。
- 中文界面下避免过宽标题导致截断，长文案允许换行。

macOS 26/27 风格应作为视觉方向，不作为 API 依赖。当前最低 macOS 14 时，可以通过 `NavigationSplitView` 或自定义 sidebar + detail layout 达到接近效果。

## Dock 窗口速览详情页

页面顶部：

- 标题：`Dock 窗口速览`
- 副标题：`悬停在 Dock 应用图标上时，快速查看该应用的窗口卡片。`
- 总开关：绑定 `settings.isDockHoverPreviewEnabled`

### 性能与手感

使用离散预设滑杆。滑杆显示连续视觉，但只允许停在合法 preset 上。

#### 悬停延迟

绑定字段：

```text
DockHoverPreviewSettings.hoverDelayMilliseconds
```

合法值：

```text
150 ms / 250 ms / 400 ms
```

UI 显示：

- 左侧 label：`悬停延迟`
- 右侧 value badge：`250 ms`
- 滑杆刻度：`150`、`250`、`400`

交互规则：

- 拖动时吸附到最近合法值。
- 写入设置后取消 pending hover，reason 保持 `settingsChanged`。
- 不接受任意数值输入。

#### 面板保留手感

绑定字段：

```text
DockHoverPreviewSettings.panelRetentionMode
```

合法值：

```text
tight / standard / forgiving
```

中文显示：

```text
紧凑 / 标准 / 宽松
```

UI 显示：

- 左侧 label：`面板保留手感`
- 右侧 value badge：当前中文名
- 滑杆刻度：`紧凑`、`标准`、`宽松`

交互规则：

- 拖动时吸附到三档。
- 设置变化应即时影响 preview region 参数。

#### 最大卡片数

绑定字段：

```text
DockHoverPreviewSettings.maxCardCount
```

合法值：

```text
3 / 5 / 8 / 12
```

UI 显示：

- 左侧 label：`最大卡片数`
- 右侧 value badge：当前数字
- 滑杆刻度：`3`、`5`、`8`、`12`

交互规则：

- 拖动时吸附到四档。
- 不开放任意数量。
- 现有查询和 view model 最大数量逻辑保持由 settings snapshot 驱动。

### 排除规则

包含两个区域。

#### 排除当前前台 App

显示当前可排除目标。如果没有有效目标，展示禁用态：

```text
没有可排除的前台 App
```

如果当前 target 已被排除，按钮文案变为：

```text
恢复当前前台 App
```

交互规则：

- 排除 app 后，写入 `excludedAppBundleIdentifiers`。
- 排除当前 preview app 时取消 pending hover 并隐藏当前 panel，reason 保持 `appExcluded`。
- 不能排除 zongMacTools 自己。

#### 已排除 App 列表

列表显示已排除 app。优先显示 app 名称，旁边显示 bundle id。每行提供移除按钮。

空状态：

```text
当前没有排除项
```

超长列表：

- Store 仍保持最多 128 个有效 bundle id 的既有上限。
- UI 可先完整展示或用滚动容器展示，避免窗口被撑高。

## 通用页

第一版建议只放现有全局设置。

### 显示语言

绑定字段：

```text
DockHoverPreviewSettings.displayLanguage
```

选项：

```text
English / 简体中文
```

交互规则：

- 改变后设置窗口和菜单下次刷新应使用新语言。
- 第三方 app 名称、窗口标题、bundle id、系统权限名称不翻译。

### 开机启动

绑定服务：

```text
LaunchAtLoginService
```

状态映射沿用现有逻辑：

- enabled：显示已启用，可关闭。
- notRegistered：显示未启用，可开启。
- requiresApproval：显示需要系统批准，提供打开登录项设置。
- notFound：禁用启停动作，提供打开登录项设置。

## 权限与状态页

显示当前权限状态：

- 辅助功能。
- 屏幕录制。

操作：

- 请求辅助功能授权提示。
- 打开辅助功能设置。
- 打开屏幕录制设置。
- 刷新权限状态。
- 打开 About / Status。
- 导出诊断。

导出诊断沿用现有 `DiagnosticExportPresenter` 和 `DiagnosticExportService`。文案可说明该文件用于本地排障，可能包含 app 名称、bundle id 和环境信息，但不包含截图、屏幕录制或文件内容。

## 架构设计

### 新增设置窗口控制器

建议新增：

```text
SettingsWindowController.swift
```

职责：

- 拥有和复用 `NSWindow`。
- 创建 SwiftUI 根视图。
- 提供 `showSettings(selectedPage:)`。
- 打开窗口时 `makeKeyAndOrderFront(nil)` 并 `NSApp.activate(ignoringOtherApps: true)`。

窗口控制器不直接实现设置业务逻辑，只负责窗口生命周期和注入依赖。

### 新增 SwiftUI 设置视图

建议新增或拆分：

```text
SettingsRootView.swift
SettingsSidebarView.swift
GeneralSettingsView.swift
DockWindowQuickLookSettingsView.swift
SupportSettingsView.swift
```

也可以先放在一个文件中，等实现稳定后再拆。若单文件超过约 400 行，应拆分。

核心状态：

```swift
enum SettingsPage: Hashable {
    case general
    case dockWindowQuickLook
    case contextMenuExtension
    case support
}
```

SwiftUI 视图通过轻量 view model 或 observable adapter 读取和写入现有服务：

- `DockHoverPreviewSettingsStore`
- `LaunchAtLoginService`
- `PermissionService`
- `AppTargetTracker`
- `AppNameResolving`
- `AboutStatusPresenting`
- `DiagnosticExportPresenting`

### 设置 Store 适配

现有 `DockHoverPreviewSettingsStore` 是 `@MainActor` protocol，已经支持 snapshot、observer 和 update。设置窗口可以直接使用它，但 SwiftUI 更适合有一个 observable adapter：

```text
SettingsViewModel / SettingsWindowModel
```

职责：

- 持有当前 settings snapshot。
- 注册 settings observer，并在变化时更新 published state。
- 暴露 intent 方法，例如 `setHoverDelayPreset(_:)`、`setPanelRetentionMode(_:)`、`setMaxCardCount(_:)`、`toggleDockWindowQuickLook()`。
- 在需要时调用 orchestrator 取消 pending hover 或隐藏 preview。

不要让 SwiftUI view 到处直接写 `settingsStore.update`，否则测试和副作用会分散。

### Orchestrator 副作用

设置窗口修改设置时需要保留现有菜单行为中的副作用：

- 关闭 Dock 窗口速览：取消 pending hover，并隐藏当前 preview，reason `settingsDisabled`。
- 修改悬停延迟：取消 pending hover，reason `settingsChanged`。
- 排除当前 app：取消 pending hover，并隐藏当前 preview，reason `appExcluded`。

建议把 `MenuOrchestrating` 重命名或泛化为更中性的 protocol，例如：

```text
SettingsOrchestrating
```

但第一版也可以复用现有 protocol，只要命名不影响可读性。

### 菜单栏控制器调整

`MenuBarController` 从“所有设置的承载者”调整为“极简菜单和设置窗口入口”。

需要注入：

```text
SettingsWindowPresenting
```

建议 protocol：

```swift
@MainActor
protocol SettingsWindowPresenting: AnyObject {
    func showSettings(selectedPage: SettingsPage)
}
```

菜单动作：

- `openSettings`
- `toggleDockWindowQuickLook`
- `showAboutStatus`
- `exportDiagnostics`
- `quit`

可以保留 debug preview 入口，但建议不要默认放在普通极简菜单中。如果仍需要开发调试入口，可以后续放进隐藏 debug 菜单或编译条件中。

## 数据兼容性

第一版不改变现有 UserDefaults keys：

```text
DockHoverPreview.isEnabled
DockHoverPreview.hoverDelayMilliseconds
DockHoverPreview.panelRetentionMode
DockHoverPreview.maxCardCount
DockHoverPreview.excludedAppBundleIdentifiers
DockHoverPreview.displayLanguage
```

所有新增 UI 只读写这些既有字段。非法值回退策略沿用 `UserDefaultsSettingsStore`。

## 本地化

`AppTextProvider` 需要新增用户可见文案：

- Dock 窗口速览。
- 打开设置。
- 暂停 Dock 窗口速览。
- 启用 Dock 窗口速览。
- 通用。
- 工具。
- 支持。
- 权限与状态。
- 性能与手感。
- 排除规则。
- 排除当前前台 App。
- 恢复当前前台 App。
- 当前没有排除项。
- 右键扩展。
- 未开发。

英文文案可使用：

- `Dock Window Quick Look`
- `Open Settings...`
- `Pause Dock Window Quick Look`
- `Enable Dock Window Quick Look`
- `General`
- `Tools`
- `Support`
- `Permissions & Status`

注意：即使内部仍叫 `DockHoverPreview`，用户可见文案应统一使用新名称。

## 错误处理

- 设置窗口打开失败时记录日志，不影响菜单栏 app 运行。
- Launch at Login 写入失败时记录日志并保留当前显示状态。
- 权限入口打开失败时静默降级或记录日志，不弹出重复干扰提示。
- 导出诊断失败时沿用现有错误文案。
- 设置读取到非法值时沿用现有 Store 回退策略。

## 测试策略

建议新增或调整测试。

### MenuBarControllerTests

覆盖：

- 菜单安装后仍显示 template icon。
- 极简菜单包含打开设置、启停 Dock 窗口速览、About / Status、导出诊断、退出。
- 极简菜单不再包含悬停延迟、面板保留手感、最大卡片数、语言和排除 App 子菜单。
- 点击打开设置会调用 `SettingsWindowPresenting.showSettings(selectedPage: .dockWindowQuickLook)` 或默认页。
- 启停 Dock 窗口速览保留现有副作用。

### SettingsWindowControllerTests

覆盖：

- 重复打开设置窗口复用同一窗口。
- 打开时激活 app 并显示窗口。
- 可以指定初始 selected page。

如果 AppKit window 测试过重，可抽 `WindowFactory` 或只测试 presenter/model 层。

### SettingsViewModelTests

覆盖：

- 初始 snapshot 映射到 UI state。
- hover delay slider index 映射到 `150 / 250 / 400`。
- panel retention slider index 映射到 `tight / standard / forgiving`。
- max card slider index 映射到 `3 / 5 / 8 / 12`。
- 修改 hover delay 时写 store 并取消 pending hover。
- 关闭 Dock 窗口速览时写 store、取消 pending hover、隐藏 preview。
- 排除当前 app 时写 store、取消 pending hover、隐藏 preview。
- 语言和 Launch at Login 属于 general page state。

### AppTextProviderTests

覆盖新增中英文文案，尤其用户可见名称 `Dock 窗口速览`。

### Manual Verification

新增人工验证清单：

- 菜单栏极简菜单内容正确。
- 打开设置窗口后默认选中 Dock 窗口速览。
- 三个离散滑杆只能停在合法预设值。
- 设置变更即时生效。
- 中文界面无截断，浅色和深色外观可读。
- 权限与状态页入口能打开系统设置。
- 导出诊断仍能保存文件。

## 实施顺序建议

1. 新增设置页文案和页面枚举。
2. 新增 settings view model，先用测试覆盖离散 preset 映射和副作用。
3. 新增设置窗口 controller 和根 SwiftUI view。
4. 实现 Dock 窗口速览详情页。
5. 实现通用页和权限与状态页。
6. 调整 `MenuBarController` 为极简菜单并接入 settings presenter。
7. 补菜单、窗口、view model 和文案测试。
8. 更新 README 和相关验证文档。
9. 运行 `swift test`、`swift build`、`Scripts/build_probe_app.sh`、`git diff --check`。

## 验收标准

- 菜单栏 icon 点击后显示极简菜单，不再显示旧的大型设置菜单。
- 从极简菜单可以打开设置窗口。
- 设置窗口左侧显示应用、工具、支持分组。
- Dock 窗口速览详情页可以完成现有 P1 设置能力。
- 离散滑杆只写入合法预设值。
- 设置变更的副作用与旧菜单一致。
- 现有 Dock hover preview 主流程不回退。
- 自动测试覆盖核心映射和菜单迁移。
- 构建、打包和 diff check 通过。

## 设计自检

- 本文档没有要求改变现有 UserDefaults key，兼容性明确。
- 本文档没有要求升级最低 macOS 版本，视觉风格与 API 依赖分离。
- 全局设置、工具设置、支持入口职责分离。
- “Dock 窗口速览”只作为用户可见名称，内部命名迁移不在本轮范围。
- 右键扩展只作为未来工具占位，不引入未确定功能。
