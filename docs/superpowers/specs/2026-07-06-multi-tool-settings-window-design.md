# zongMacTools 多工具设置窗口开发设计

日期：2026-07-06

## 背景

`zongMacTools` 当前是一个 macOS 菜单栏常驻工具，主要功能是 Dock hover 时显示窗口预览。现有设置全部放在菜单栏 `NSMenu` 中，包括启停、悬停延迟、面板保留手感、最大卡片数、语言、排除 App、Launch at Login、权限入口、关于与状态和诊断导出。

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
- 极简菜单提供打开设置窗口、启停 Dock 窗口速览、关于与状态、导出诊断和退出。
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
  右键扩展（未开发 / 禁用态，不可选中）

支持
  权限与状态
  关于与状态
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
- 排除当前可排除 App。
- 手动添加 `.app` 到排除列表。
- 已排除 App 列表、移除单项和清空全部入口。

### 右键扩展

当前只作为未来工具占位。第一版建议只在左侧显示禁用项和“未开发”标签，不可选中，不提供右侧页面，也不加入 `SettingsPage`。这样能展示多工具方向，又避免提前引入未确定的信息架构和测试成本。

后续如果改为可选中空状态页，可使用以下文案：

```text
右键扩展尚未启用
此工具将在后续版本中提供右键菜单相关能力。
```

### 权限与状态

承载支持和排障相关能力：

- Accessibility 状态和打开系统设置入口。
- Screen Recording 状态和打开系统设置入口。
- 刷新权限状态。
- 导出诊断。

### 关于与状态

承载 app 状态摘要：

- 版本、build、bundle id、bundle path、可执行文件。
- Accessibility、Screen Recording、Launch at Login 和签名状态。
- Dock 窗口速览设置摘要。
- Copy Status。

第一版使用设置窗口内的独立页面，而不是额外弹出一个 About / Status 窗口。菜单栏的 `关于与状态` 入口直接打开设置窗口并选中此页。

## 菜单栏极简菜单

点击菜单栏 icon 后显示极简菜单。建议结构：

```text
zongMacTools
Dock 窗口速览：已启用

打开设置...
停用 Dock 窗口速览

关于与状态
导出诊断...

退出
```

当 Dock 窗口速览已停用时：

```text
Dock 窗口速览：已停用
启用 Dock 窗口速览
```

菜单中不再直接承载悬停延迟、面板保留手感、最大卡片数、语言、排除 App 列表、权限设置等长配置。它们迁移到设置窗口。

保留 `关于与状态` 和 `导出诊断...` 的原因是：故障时用户可能首先打开菜单栏入口，需要快速获得状态和导出排障资料。导出诊断仍使用用户主动选择保存位置的 `NSSavePanel`。

## 设置窗口视觉设计

窗口使用 AppKit `NSWindow` 承载 SwiftUI 内容，窗口尺寸建议默认约 `980 x 640`，可按内容适度调整。窗口应可关闭、可最小化，并在重复点击“打开设置...”时复用同一个窗口实例而不是不断创建新窗口。

视觉原则：

- 左侧 sidebar 使用浅色、半透明或材质感背景，强调现代 macOS 设置风格。
- 右侧内容区使用系统语义背景；浅色外观下接近白底，深色外观下使用对应深色 surface，避免过度玻璃化影响阅读。
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

统一映射规则：

- SwiftUI `Slider` 绑定离散 index，而不是直接绑定真实设置值。
- 每个滑杆维护有序 preset 数组，例如 `[150, 250, 400]`。
- 从 settings snapshot 进入 UI 时，用当前值查找 preset index；如果 snapshot 值非法或缺失，显示 Store 回退后的默认 preset。
- 拖动过程中按 index 四舍五入吸附到最近 preset，value badge 同步显示对应 preset。
- 只有吸附后的 preset value 可以写入 `DockHoverPreviewSettingsStore`，不能把中间浮点值或非 preset 整数写入 `UserDefaults`。
- 可以在拖动结束时写入，也可以在吸附 index 改变时即时写入；无论选择哪种方式，都必须保证每次写入都是合法 preset。

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

- 拖动时通过 index 吸附到最近合法值。
- 写入设置后由 orchestrator observer 取消 pending hover，reason 保持 `settingsChanged`。
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

- 拖动时通过 index 吸附到三档。
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

- 拖动时通过 index 吸附到四档。
- 不开放任意数量。
- 现有查询和 view model 最大数量逻辑保持由 settings snapshot 驱动。

### 排除规则

包含快捷排除、手动添加和已排除列表。

#### 排除当前可排除 App

显示当前可排除目标，而不是简单等同于当前前台 App。目标来源沿用 `AppTargetTracker` 的既有优先级：

1. 当前正在预览的 App。
2. 最近悬停过的 Dock App。
3. 最近非 zongMacTools 自身的前台 App。

如果没有有效目标，展示禁用态：

```text
没有可排除的 App
```

如果当前 target 已被排除，按钮文案变为：

```text
恢复当前可排除 App
```

交互规则：

- 排除 app 后，写入 `excludedAppBundleIdentifiers`。
- 排除当前 preview app 后由 orchestrator observer 取消 pending hover 并隐藏当前 panel，reason 保持 `appExcluded`。
- 不能排除 zongMacTools 自己。

#### 手动添加 App

在 `排除的 App` 标题行提供 `添加...` 按钮。点击后打开 `NSOpenPanel`，只允许用户选择 `.app` 应用包，不提供内置搜索窗口、不扫描 `/Applications` 生成应用列表，也不显示运行中 App 列表。

选中 `.app` 后读取该 bundle 的 bundle identifier 和显示名称：

- 如果 bundle identifier 有效、不是 zongMacTools 自己且当前不在排除列表中，则只写入 `excludedAppBundleIdentifiers`。
- 如果用户取消选择，不做任何变更。
- 如果选中的 `.app` 没有 bundle identifier、bundle identifier 为空、是 zongMacTools 自己或已经被排除，不写入重复或非法值，可记录日志。
- 手动添加不改变 `AppTargetTracker` 的“当前可排除 App”来源语义；它只是用户显式选择 bundle 的补充入口。
- 手动添加命中 pending hover app 或当前 preview app 时，取消 pending hover 和隐藏 preview 仍由 orchestrator observer 统一处理，不在设置页重复调用 hide/cancel。

#### 已排除 App 列表

列表显示已排除 app。优先显示 app 名称，旁边显示 bundle id。每行提供移除按钮。列表标题行提供 `添加...` 和 `清空全部` 操作；当列表为空时禁用 `清空全部`，但 `添加...` 保持可用。

空状态：

```text
当前没有排除项
```

超长列表：

- Store 仍保持最多 128 个有效 bundle id 的既有上限。
- UI 可先完整展示或用滚动容器展示，避免窗口被撑高。
- 清空全部只清空 `excludedAppBundleIdentifiers`，不改变其他设置。

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
- 导出诊断。

导出诊断沿用现有 `DiagnosticExportPresenter` 和 `DiagnosticExportService`。第一版可以继续调用现有 presenter，但建议把 protocol 方法从菜单语义的 `exportDiagnosticsFromMenu()` 泛化为 `exportDiagnostics()`，方便菜单和设置页共用。文案可说明该文件用于本地排障，可能包含 app 名称、bundle id 和环境信息，但不包含截图、屏幕录制或文件内容。

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
- 适配当前 `LSUIElement` / `.accessory` 菜单栏 app：重复打开应把已有窗口置前，关闭窗口后再次打开仍能复用或重建，不影响菜单栏常驻。

窗口控制器不直接实现设置业务逻辑，只负责窗口生命周期和注入依赖。

### 新增 SwiftUI 设置视图

建议新增或拆分：

```text
SettingsRootView.swift
SettingsSidebarView.swift
GeneralSettingsView.swift
DockWindowQuickLookSettingsView.swift
SupportSettingsView.swift
AboutStatusSettingsView.swift
```

也可以先放在一个文件中，等实现稳定后再拆。若单文件超过约 400 行，应拆分。

核心状态：

```swift
enum SettingsPage: Hashable {
    case general
    case dockWindowQuickLook
    case support
    case aboutStatus
}
```

`右键扩展` 第一版只是 sidebar 禁用占位，不进入 `SettingsPage`，避免为不可访问页面增加无效状态。

SwiftUI 视图通过轻量 view model 或 observable adapter 读取和写入现有服务：

- `DockHoverPreviewSettingsStore`
- `LaunchAtLoginService`
- `PermissionService`
- `AppTargetTracker`
- `AppNameResolving`
- `AppStatusProviding`
- `DiagnosticExportPresenting`
- `ExcludedAppSelectionPresenting`

### 设置 Store 适配

现有 `DockHoverPreviewSettingsStore` 是 `@MainActor` protocol，已经支持 snapshot、observer 和 update。设置窗口可以直接使用它，但 SwiftUI 更适合有一个 observable adapter：

```text
SettingsViewModel
```

职责：

- 持有当前 settings snapshot。
- 注册 settings observer，并在变化时更新 published state。
- 暴露 intent 方法，例如 `setHoverDelayPreset(_:)`、`setPanelRetentionMode(_:)`、`setMaxCardCount(_:)`、`toggleDockWindowQuickLook()`。
- 暴露手动添加排除 App 的 intent，接收由选择器解析出的 bundle identifier，并只写入合法、非重复、非本 app 的 bundle id。
- 集中写入 `DockHoverPreviewSettingsStore`，并通过少量 intent 暴露给 SwiftUI view。
- 不直接隐藏 preview panel，也不直接操作 hover monitor；这些副作用由统一的 orchestrator 路径处理。

不要让 SwiftUI view 到处直接写 `settingsStore.update`，否则测试和副作用会分散。ViewModel 也不应绕过统一副作用路径直接调用 preview session 或 hover monitor。

### Orchestrator 副作用

设置窗口修改设置时需要保留现有菜单行为中的副作用，但副作用只能有一个权威来源，避免重复 cancel / hide 和重复日志。

- 关闭 Dock 窗口速览：取消 pending hover，并隐藏当前 preview，reason `settingsDisabled`。
- 修改悬停延迟：取消 pending hover，reason `settingsChanged`。
- 排除当前可排除 App：取消 pending hover，并隐藏当前 preview，reason `appExcluded`。
- 手动添加 `.app` 到排除列表：如果新增 bundle id 命中 pending hover app 或当前 preview app，同样由 observer 取消 pending hover / 隐藏 preview，reason `appExcluded`。

第一版建议把 `ProbeOrchestrator` 的 settings observer 扩展为设置派生副作用的权威来源：

- `isDockHoverPreviewEnabled` 从 true 变为 false 时，observer 取消 pending hover 并隐藏当前 preview。
- `hoverDelayMilliseconds` 改变时，observer 取消 pending hover，reason `settingsChanged`。
- `excludedAppBundleIdentifiers` 新增 bundle id 时，observer 判断 pending hover app 和当前 preview app 是否被排除；命中时取消 pending hover 并隐藏当前 preview。

这样菜单和设置窗口都只负责写同一份 store，不各自复制 hide/cancel 逻辑。普通极简菜单不注入 preview 副作用出口，也不保留旧设置 selector，避免后续误用。

第一版不需要把 orchestrator protocol 直接注入 `SettingsViewModel`。若后续为了非菜单入口继续抽象 orchestrator protocol，建议使用更贴近职责的命名，例如 `PreviewOrchestrating`，避免把设置窗口误写成 preview 副作用的直接操作者。

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

- `openSettings`：调用 `showSettings(selectedPage: .dockWindowQuickLook)`，从菜单进入时默认展示 Dock 窗口速览详情页。
- `toggleDockWindowQuickLook`
- `showAboutStatus`：调用 `showSettings(selectedPage: .aboutStatus)`。
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
- 停用 Dock 窗口速览。
- 启用 Dock 窗口速览。
- 通用。
- 工具。
- 支持。
- 权限与状态。
- 关于与状态。
- 性能与手感。
- 排除规则。
- 排除当前可排除 App。
- 恢复当前可排除 App。
- 添加...
- 选择要排除的 App
- 没有可排除的 App。
- 当前没有排除项。
- 清空全部。
- 右键扩展。
- 未开发。
- zongMacTools 设置。
- 移除排除项。

英文文案可使用：

- `Dock Window Quick Look`
- `Open Settings...`
- `Disable Dock Window Quick Look`
- `Enable Dock Window Quick Look`
- `General`
- `Tools`
- `Support`
- `Permissions & Status`
- `About & Status`
- `Exclude Current App`
- `Include Current App`
- `Add...`
- `Choose App to Exclude`
- `Clear All`
- `zongMacTools Settings`
- `Remove excluded app`

注意：即使内部仍叫 `DockHoverPreview`，用户可见文案应统一使用新名称。

## 错误处理

- 设置窗口打开失败时记录日志，不影响菜单栏 app 运行。
- Launch at Login 写入失败时记录日志并保留当前显示状态。
- 权限入口打开失败时静默降级或记录日志，不弹出重复干扰提示。
- 导出诊断失败时沿用现有错误文案。
- 手动添加 `.app` 时，用户取消选择不记录错误；无法读取 bundle identifier、选择本应用或选择重复项时不写入 store，可记录诊断日志。
- 设置读取到非法值时沿用现有 Store 回退策略。

## 测试策略

建议新增或调整测试。

### MenuBarControllerTests

覆盖：

- 菜单安装后仍显示 template icon。
- 极简菜单包含打开设置、启停 Dock 窗口速览、关于与状态、导出诊断、退出。
- 极简菜单不再包含悬停延迟、面板保留手感、最大卡片数、语言和排除 App 子菜单。
- 点击打开设置会调用 `SettingsWindowPresenting.showSettings(selectedPage: .dockWindowQuickLook)`。
- 启停 Dock 窗口速览只写 settings store；具体 cancel/hide 副作用由 orchestrator observer 测试覆盖。

### SettingsWindowControllerTests

覆盖：

- 重复打开设置窗口复用同一窗口。
- 打开时激活 app 并显示窗口，适配当前 `LSUIElement` / `.accessory` 菜单栏 app。
- 可以指定初始 selected page。
- 可以从菜单直接打开 `aboutStatus` 页面。
- 关闭窗口后再次打开不会创建多个残留窗口，也不会影响菜单栏 status item。

如果 AppKit window 测试过重，可抽 `WindowFactory` 或只测试 presenter/model 层。

### SettingsViewModelTests

覆盖：

- 初始 snapshot 映射到 UI state。
- hover delay slider index 映射到 `150 / 250 / 400`。
- panel retention slider index 映射到 `tight / standard / forgiving`。
- max card slider index 映射到 `3 / 5 / 8 / 12`。
- 非 preset snapshot 值显示 Store 回退后的默认 preset，不向 UI 暴露非法值。
- 修改 hover delay 时只写 store；具体取消 pending hover 由 orchestrator observer 测试覆盖。
- 关闭 Dock 窗口速览时只写 store，不重复调用已经由 orchestrator observer 处理的 hide/cancel。
- 排除当前可排除 App 时只写 store，不重复调用已经由 orchestrator observer 处理的 hide/cancel。
- 手动添加 `.app` 时只接受有效、非本 app、非重复 bundle id，并只写 store。
- 清空全部排除项时只清空 `excludedAppBundleIdentifiers`，不改变其他 settings。
- 语言和 Launch at Login 属于 general page state。

### ProbeOrchestrator / Preview 主流程回归

覆盖：

- `settingsStore` 更新为停用时仍取消 pending hover 并隐藏 preview，reason `settingsDisabled`。
- pending hover app 被加入排除列表时仍取消 pending hover 并隐藏 preview，reason `appExcluded`。
- 当前 preview app 被加入排除列表时仍隐藏 preview，reason `appExcluded`。
- 与当前 pending hover / preview 无关的排除列表变化不会隐藏 preview。
- 修改 hover delay 后新的 Dock hover 使用最新 delay。
- 修改 hover delay 时取消当前 pending hover，reason `settingsChanged`。
- 打开、关闭或重复打开设置窗口不会启动 preview、隐藏现有 preview 或改变 hover monitor 状态。

### AppDelegateWiringTests

覆盖：

- `SettingsWindowController` / `SettingsWindowPresenting` 使用现有 `settingsStore`、`targetTracker`、`launchAtLoginService`、`permissionService`、`appStatusProvider` 和 `diagnosticExportPresenter` 注入。
- `MenuBarController` 接入 `SettingsWindowPresenting`，菜单打开设置不会绕过 presenter。
- `DiagnosticExportPresenting` 的中性方法名可同时被菜单和设置页调用。

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
- 关于与状态页能显示并复制本工具状态摘要。
- 导出诊断仍能保存文件。
- 打开设置窗口、调整设置、关闭设置窗口后，Dock hover preview 主流程仍可正常触发、展示和隐藏。

## 实施顺序建议

1. 新增设置页文案和页面枚举。
2. 新增 settings view model，先用测试覆盖离散 preset 映射、store 写入和副作用去重边界。
3. 新增设置窗口 controller 和根 SwiftUI view。
4. 实现 Dock 窗口速览详情页。
5. 实现通用页、权限与状态页和关于与状态页。
6. 调整 `MenuBarController` 为极简菜单并接入 settings presenter。
7. 补菜单、窗口、view model、orchestrator 回归、AppDelegate wiring 和文案测试。
8. 更新 README 和相关验证文档。
9. 运行 `swift test`、`swift build`、`Scripts/build_probe_app.sh`、`git diff --check`。

## 验收标准

- 菜单栏 icon 点击后显示极简菜单，不再显示旧的大型设置菜单。
- 从极简菜单可以打开设置窗口。
- 设置窗口左侧显示应用、工具、支持分组。
- 支持分组包含权限与状态、关于与状态，菜单关于入口默认选中关于与状态。
- 右键扩展第一版只作为禁用占位，不可选中。
- Dock 窗口速览详情页可以完成现有 P1 设置能力。
- 离散滑杆只写入合法预设值。
- 设置变更的副作用与旧菜单一致，且不会重复触发 hide/cancel。
- 现有 Dock hover preview 主流程不回退。
- 自动测试覆盖核心映射、菜单迁移、设置窗口接线和 preview 主流程回归。
- 构建、打包和 diff check 通过。

## 设计自检

- 本文档没有要求改变现有 UserDefaults key，兼容性明确。
- 本文档没有要求升级最低 macOS 版本，视觉风格与 API 依赖分离。
- 全局设置、工具设置、支持入口职责分离。
- “Dock 窗口速览”只作为用户可见名称，内部命名迁移不在本轮范围。
- 右键扩展只作为未来工具禁用占位，不引入未确定功能或不可达页面状态。
- 离散滑杆通过 index/preset 映射写入合法值，不依赖任意数值输入。
- 设置副作用有单一权威来源，避免设置窗口和 orchestrator observer 重复处理。
