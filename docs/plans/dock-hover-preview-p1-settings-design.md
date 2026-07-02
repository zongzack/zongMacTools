# Dock 悬停窗口预览 P1 基础设置能力设计

日期：2026-07-01

## 背景

`DockHoverPreviewProbe` 的 MVP / P0 已完成核心 hover preview、stale cancellation、权限静默降级、Dock 重启恢复和常见环境变体验证。P1 的目标不是扩展窗口管理能力，而是把当前已经可用的行为变成长期自用时可调、可控、不打扰。

本设计基于：

- `README.md`
- `docs/roadmap.md`
- `docs/architecture/dock-hover-preview-technical-design.md`
- `docs/verification/dock-hover-preview-probe-summary.md`
- `docs/verification/dock-hover-preview-mvp-ui-manual-checklist.md`
- `docs/verification/dock-hover-preview-environment-variant-verification-plan.md`

## P1 目标

- 菜单栏提供 `Enable / Disable Dock hover preview`，默认启用，关闭后不响应 Dock hover preview。
- 支持 hover delay 预设：`150 ms`、`250 ms`、`400 ms`，默认 `250 ms`，保持当前 MVP 行为。
- 支持 panel hide / retention 手感预设，默认等价于当前 MVP 的 Dock item 容差、panel edge 容差和 Dock-to-panel bridge 逻辑。
- 支持最大卡片数设置，默认 `8`，保持当前 MVP 行为。
- 支持 excluded apps，不对指定 app 显示 preview。
- 支持 Launch at Login。
- 支持应用自身显示语言切换：`English` / `简体中文`。
- 设置持久化到 `UserDefaults`。
- 设置变更尽量即时生效；无法即时生效的状态必须在菜单中明确表达。
- 设置读取、写入或迁移错误不能导致 hover preview 崩溃、卡住或打扰用户。

范围说明：显示语言切换作为 P1 基础设置的一项处理，已同步纳入 `docs/roadmap.md` 的 P1 清单。它只覆盖本工具静态 UI 文案，不引入系统级本地化工程，也不改变 hover preview 核心行为。

## 应用名称和图标

应用集合的用户可见名称暂定为 `zongMacTools`，后续如果确定更好的正式名称再统一迁移。当前 SwiftPM target、源码目录和已有验证文档仍可暂时保留 `DockHoverPreviewProbe`，避免在 P1 设置设计阶段把命名迁移和功能设置混在一起。

图标源文件放在：

```text
Assets/AppIcon/zong-mac-tools-logo.png
```

使用规则：

- 该 PNG 是项目内的 app icon 源图，后续生成 `.icns`、asset catalog 或不同尺寸图标时都从它派生。
- P1 若接入 Launch at Login 和正式打包图标，应让 Finder、System Settings 权限列表、Login Items 中显示 `zongMacTools` 名称和这个 Z 字型图标。
- 菜单栏状态项使用适合 18 px 菜单栏尺寸的 template/monochrome Z 标记，不直接把全彩源 PNG 缩到菜单栏里。
- 图标不用于窗口卡片、第三方 app 名称、窗口标题或 bundle id 展示，避免混淆目标 app 和本工具自身。

## 非目标

- 不实现独立设置窗口，不做复杂偏好页。
- 不新增窗口操作，例如关闭、最小化、隐藏 app、全屏切换。
- 不改变窗口查询范围，不支持最小化窗口、其他 Space 窗口或实时缩略图。
- 不改变 Screen Recording 缺失时的策略：正常 Dock hover preview 继续静默抑制 UI。
- 不改变 stale hover cancellation 的优先级：过期 hover、快速离开、候选变化仍必须取消 pending preview 或隐藏旧 panel。
- 不翻译第三方 app 名称、窗口标题、bundle id、系统权限名称或系统设置页面名称。
- 不使用私有 API。
- 不复制、翻译或机械改写 DockDoor GPLv3 源码、文件结构、helper、注释或私有 API wrapper。
- 不把 P2 UI polish 提前塞进 P1，例如缩略图显示模式、动画、Light / Dark 视觉重做。

## 当前架构接入点

P1 应该以一个小型设置服务接入现有模块，不改动现有子系统边界。

- `AppDelegate.swift`
  - 新增设置服务初始化。
  - 把同一个设置读写接口注入 `MenuBarController`、`ProbeOrchestrator`、`PreviewSessionController`。
  - 初始化 Launch at Login 服务，并注入菜单栏。

- `MenuBarController.swift`
  - 当前负责菜单栏 template logo 状态项、权限状态和 debug preview。
  - P1 菜单设置项放在权限项和 debug 项之间。
  - 菜单打开或设置变化后重建菜单，保证 checkmark 和状态文本准确。
  - 菜单标题、状态文案和设置项显示应通过本地化文案表读取，不在菜单构建逻辑中散落硬编码英文/中文。
  - 需要维护或注入一个“最近的非本工具前台 app”来源，用于 excluded apps 菜单动作；不能只依赖菜单打开瞬间的 `NSWorkspace.shared.frontmostApplication`。

- `ProbeOrchestrator.swift`
  - 当前硬编码 `0.25` 秒 hover delay。
  - P1 改为读取 settings snapshot 的 `hoverDelay`。
  - Enable 关闭或 app 被 excluded 时，应取消 pending hover，并调用 `previewSessionController.hide(reason:)`。
  - delayed validation 仍保留：延迟结束后必须重新解析当前 hovered Dock app，确认 bundle match 和 mouseInside。

- `PreviewSessionController.swift`
  - 当前硬编码最大窗口数 `prefix(8)`、`previewRegionTolerance = 24`、`panelEdgeTolerance = 6` 和 30 Hz leave polling。
  - P1 将最大卡片数和 retention 参数从 settings snapshot 注入或按 showPreview 时读取。
  - 保留 generation-based stale async cancellation。
  - Screen Recording 缺失仍在这里静默抑制 preview UI。

- `PreviewPanelViewModel` / `PreviewPanelView.swift`
  - 当前 `PreviewPanelViewModel` 再次 `prefix(8)`。
  - P1 应避免两处硬编码分叉，设计上由统一配置决定最大卡片数。
  - 纵向 side Dock 仍最多显示 3 张完整可见卡片后滚动；这是 panel 可见区域策略，不等于最大卡片数。
  - preview panel 里属于本工具的静态 UI 文案应通过显示语言设置读取；窗口标题和 app 名称保持原始系统值。

- `WindowQueryService.swift`
  - 当前内部也返回 `sorted.prefix(8)`。
  - P1 实现时需要统一最大卡片数入口，避免 query 层、session 层、view model 层各自截断出不同结果。
  - 设计建议优先让 query service 支持 limit 参数，session 传入设置值；view model 只做防御性截断。

- `PermissionService.swift`
  - 不承担 P1 设置职责。
  - Launch at Login 走独立公开 API 服务，不混入权限服务。

- `Package.swift`
  - P1 实现 Launch at Login 时需要链接 `ServiceManagement` framework。
  - 本设计文档不修改 `Package.swift`。

## 设置模型设计

新增一个轻量设置模块，建议文件名为 `DockHoverPreviewSettings.swift` 和 `SettingsStore.swift`。核心概念分为三层：

- `DockHoverPreviewSettings`
  - 纯值类型，表示当前可用设置。
  - 所有字段都有安全默认值。
  - 只包含 P1 范围内的设置。

- `SettingsStore`
  - 负责从 `UserDefaults` 读取、校验、写入、发布变化。
  - 提供 `snapshot` 给 hover 路径同步读取。
  - 发生非法值时回退默认值，并记录日志。

- `LaunchAtLoginService`
  - 独立封装 `SMAppService.mainApp`。
  - 读写系统登录项状态，不把系统状态伪装成普通 UserDefaults 设置。

建议模型：

```swift
struct DockHoverPreviewSettings: Equatable, Sendable {
    var isDockHoverPreviewEnabled: Bool
    var hoverDelayMilliseconds: Int
    var panelRetentionMode: PanelRetentionMode
    var maxCardCount: Int
    var excludedAppBundleIdentifiers: Set<String>
    var displayLanguage: DisplayLanguage
}

enum PanelRetentionMode: String, CaseIterable, Sendable {
    case tight
    case standard
    case forgiving
}

enum DisplayLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
}
```

默认值：

```swift
DockHoverPreviewSettings(
    isDockHoverPreviewEnabled: true,
    hoverDelayMilliseconds: 250,
    panelRetentionMode: .standard,
    maxCardCount: 8,
    excludedAppBundleIdentifiers: [],
    displayLanguage: .english
)
```

合法值约束：

- `hoverDelayMilliseconds` 只接受 `150`、`250`、`400`。
- `panelRetentionMode` 只接受 `tight`、`standard`、`forgiving`。
- `maxCardCount` P1 只接受菜单预设 `3`、`5`、`8`、`12`；默认 `8`。读取到非预设值时回退 `8` 并记录 `settings.invalid`，不要把 `11` 之类手工写入值变成一个无 checkmark 的隐藏状态。
- `excludedAppBundleIdentifiers` 只保存 bundle id 字符串，过滤空字符串、whitespace-only、超长或明显不像 bundle id 的值。建议单项最长 `256` 字符，最多保留 `128` 个有效条目；超出部分按排序后截断并记录丢弃数量，避免损坏的 defaults 让菜单重建卡住。
- `displayLanguage` 只接受 `en`、`zh-Hans`，默认 `en`，保持当前 MVP 的英文菜单显示。

panel retention 参数建议：

| Mode | 预期手感 | Dock item tolerance | Panel edge tolerance | Bridge inset | 说明 |
| --- | --- | ---: | ---: | ---: | --- |
| `tight` | 更快隐藏 | 12 | 4 | 12 | 适合不想面板停留太久。 |
| `standard` | 当前 MVP | 24 | 6 | 24 | 默认值，必须保持现有行为。 |
| `forgiving` | 更容易移入 panel | 36 | 8 | 36 | 适合 Dock 到 panel 距离较难操作时。 |

注意：`DockHoverMonitor` 自身的 Dock item hover 判断仍保持严格，用于 stale candidate 抑制。retention mode 只影响 panel 已显示后的 preview region 和 panel transition region，不放宽 delayed validation 的 stale 防线。

### 显示语言和本地化文案

P1 的语言能力采用显式 app 内设置，不跟随系统语言。这样用户可以在系统语言不变的情况下切换本工具显示语言，也避免运行时切换 `Bundle` localization 的不可控行为。

建议新增轻量文案表：

```swift
enum LocalizedTextKey: String {
    case dockHoverPreviewStatus
    case enableDockHoverPreview
    case disableDockHoverPreview
    case hoverDelay
    case panelRetention
    case maxCards
    case language
    case excludedApps
    case launchAtLogin
    case requestAccessibilityPrompt
    case openAccessibilitySettings
    case openScreenRecordingSettings
    case refreshPermissions
    case debugShowPreviewForFrontmostApp
    case quit
}
```

`AppTextProvider` 根据 `DisplayLanguage` 返回英文或简体中文字符串。菜单层和 preview panel 只通过 text provider 取本 app 静态文案，不直接散落字符串。P1 不要求完整系统级 `.lproj` 本地化，也不要求 app 名称、窗口标题、权限名称跟着翻译。

日志不参与显示语言切换。日志事件名、reason、枚举 raw value、bundle id、数量和权限布尔值应保持稳定，便于现有人工验证和后续自动化检查。

## UserDefaults key 设计和默认值

使用 app bundle id 的标准 `UserDefaults.standard`。key 加统一前缀，避免未来与其他工具设置混淆。

| Key | Type | 默认值 | 说明 |
| --- | --- | --- | --- |
| `DockHoverPreview.isEnabled` | Bool | `true` | 是否响应正常 Dock hover preview。 |
| `DockHoverPreview.hoverDelayMilliseconds` | Int | `250` | 仅接受 `150`、`250`、`400`。 |
| `DockHoverPreview.panelRetentionMode` | String | `standard` | `tight` / `standard` / `forgiving`。 |
| `DockHoverPreview.maxCardCount` | Int | `8` | 只接受菜单预设 `3` / `5` / `8` / `12`，非法值回退 `8`。 |
| `DockHoverPreview.excludedAppBundleIdentifiers` | [String] | `[]` | 排除 app 的 bundle id 集合，保存时排序以便 diff 和排障；读取时过滤非法/超长值并限制有效条目数量。 |
| `DockHoverPreview.displayLanguage` | String | `en` | 应用自身显示语言，`en` / `zh-Hans`。 |

Launch at Login 不使用 UserDefaults 作为真实状态来源。菜单显示读取 `SMAppService.mainApp.status`。如果需要记住“用户最近一次点击打开登录项”的意图，只能作为诊断辅助 key，P1 默认不需要。

读取策略：

- 首次启动没有 key 时使用默认值，不主动写入全部默认值。
- 读取到非法值时只在内存 snapshot 中回退安全默认值或丢弃非法集合项，不弹窗。
- 用户下一次通过菜单选择合法值时再写入。
- 每次设置写入后发布 `settings.changed` 日志，日志只记录数量和枚举值，不记录过长数据。

## 菜单栏 UI 设计

菜单保持轻量，不引入独立 window。

建议结构：

```text
zongMacTools template logo
Accessibility: granted / missing
Screen Recording: granted / missing
-
Dock Hover Preview: Enabled / Disabled
Enable Dock Hover Preview / Disable Dock Hover Preview
Hover Delay
  150 ms
  250 ms
  400 ms
Panel Retention
  Tight
  Standard
  Forgiving
Max Cards
  3
  5
  8
  12
Language
  English
  简体中文
Excluded Apps
  Exclude <Target App>
  Include <Target App>
  Clear Excluded Apps
  <已排除 app 列表，只读或点击移除>
Launch at Login: Enabled / Disabled / Requires Approval / Not Registered / Not Found
Enable Launch at Login / Disable Launch at Login
Open Login Items Settings
-
Request Accessibility Prompt
Open Accessibility Settings
Open Screen Recording Settings
Refresh Permissions
-
Debug: Show Preview For Frontmost App
-
Quit
```

交互规则：

- 当前选中的 delay、retention 和 max cards 用 `NSMenuItem.state = .on` 表示。
- 当前选中的 Language 用 `NSMenuItem.state = .on` 表示。
- Enable 关闭时，delay/retention/max cards/excluded apps 菜单仍可用，方便先配置再启用。
- `Dock Hover Preview: Disabled` 是只读状态行；真正动作行是 `Enable...` 或 `Disable...`。
- Exclude / Include 动作应绑定到一个明确的 target app，而不是菜单打开瞬间盲读 frontmost app。
- target app 优先级：当前 preview 对应 app；其次最近一次 hovered Dock app；最后是通过 `NSWorkspace.didActivateApplicationNotification` 维护的最近非本工具前台 app。
- Exclude / Include 菜单标题应带上 target 名称，例如 `Exclude Google Chrome`；没有可用 bundle id、target 是本工具、或 target 无法确定时禁用。
- 已排除 app 列表用 `App Name (bundle.id)` 展示；找不到 app name 时显示 bundle id。点击单项即可从排除列表移除，P1 不做搜索和多选管理。
- 已排除列表最多直接展示前 `20` 项；超过时增加只读摘要行，例如 `108 more excluded apps`，仍保留 `Clear Excluded Apps`。这只是防御损坏 defaults 或手工写入大量条目，不是 P1 的完整管理 UI。
- `Clear Excluded Apps` 在列表为空时禁用。
- Launch at Login 若为 `requiresApproval`，菜单显示 `Requires Approval`，提供 `Open Login Items Settings`，不反复弹系统提示。

语言显示规则：

- Language 只控制本 app 自己的菜单项、状态行、debug item 和 preview panel 静态占位/加载文案。
- app 名称、窗口标题、bundle id、系统权限名称、系统设置页面名称保持系统/原始值，不做翻译。
- 日志保持稳定的英文事件名和 raw value，不跟随显示语言切换。
- 默认 `English`，保证首次启动和当前 MVP 的可见菜单文字一致。
- 语言切换后立即重建菜单；当前已经显示的 preview panel 不强制刷新，下一次 preview 使用新语言。

## 设置变更如何即时生效

设置服务应提供主线程安全的 snapshot 和变化回调。P1 不需要复杂响应式框架，菜单动作写入后直接通知依赖方即可。

变更规则：

- Enable -> Disable
  - 立即取消 `ProbeOrchestrator` 的 pending hover work item。
  - 立即隐藏当前 panel，reason 建议为 `settingsDisabled`。
  - Dock monitor 可以继续运行，以便再次 Enable 时无需重启 observer；但 orchestrator 收到 hover 后应直接忽略。

- Disable -> Enable
  - 不主动显示 panel。
  - 下一个 Dock hover 事件按新设置正常触发。

- hover delay 改变
  - 新 hover 使用新 delay。
  - 已经排队的 pending hover 建议取消；如果鼠标仍在 Dock item 上，等待下一次 Dock notification 或用户重新 hover 触发。不要为了配置变化主动显示 preview。

- panel retention 改变
  - 当前已显示 panel 的 leave polling 下一次 tick 使用新 retention 参数，或在 session 内更新参数 snapshot。
  - 如果新模式更 tight，可能会在下一次 tick 隐藏；这是可接受的即时生效。

- max card count 改变
  - 下一次 preview 使用新数量。
  - 当前已显示 panel 不主动重新查询窗口，避免异步刷新和 stale state 复杂化。
  - 如果当前 preview 正在加载缩略图，继续当前 generation，不因 max cards 变化重排。

- display language 改变
  - 立即重建菜单，菜单项、状态行和设置项使用新语言。
  - 不取消 pending hover，不隐藏当前 panel，不影响 stale cancellation。
  - 当前已经显示的 panel 不强制刷新，避免为了文案切换引入额外 view model generation；下一次 preview 使用新语言。
  - 语言设置读取失败时回退英文。

- excluded apps 改变
  - 如果当前 panel 对应 app 被加入排除列表，立即隐藏，reason 建议为 `appExcluded`。
  - 如果 app 从排除列表移除，不主动显示 panel。

- Launch at Login 改变
  - 调用系统 API 后重建菜单并显示最新 status。
  - 失败时记录日志，菜单状态以 `SMAppService.mainApp.status` 为准。

## excluded apps 数据结构和交互方案

数据结构：

- 内存中使用 `Set<String>`，用于 O(1) 判断。
- `UserDefaults` 中保存排序后的 `[String]`，便于稳定排障。
- bundle id 匹配使用 exact match，不做 wildcard、正则或路径匹配。
- 读取时只接受长度 `1...256`、trim 后非空、且由常见 bundle id 字符组成的字符串。建议允许 ASCII 字母、数字、`.`、`-`、`_`；其他值视为非法并丢弃。
- 有效条目最多 `128` 个。超过上限时保留排序后的前 `128` 个，记录 `settings.invalid excludedAppsDropped=<count>`，但不弹窗、不阻塞 hover。

判断位置：

- `ProbeOrchestrator.dockHoverMonitor(_:didHover:)` 收到 `HoveredDockApp` 后，先读取 settings snapshot。
- 如果 `isDockHoverPreviewEnabled == false`，取消 pending 并隐藏。
- 如果 `excludedAppBundleIdentifiers.contains(app.bundleIdentifier)`，取消 pending 并隐藏，reason 建议为 `appExcluded`。
- delayed validation 后仍要再次检查 excluded apps，避免用户在 delay 期间刚好把 app 加入排除列表。
- `showFrontmostAppProbe()` 是 debug 入口，不受 `isDockHoverPreviewEnabled` 影响，因为该开关只控制正常 Dock hover preview；但它必须继续尊重 Screen Recording 权限，并在 P1 中尊重 excluded apps。如果需要绕过，后续可以单独加 `Debug: Show Preview Ignoring Exclusions`，但不属于 P1。

菜单交互：

- `Exclude <App Name>`
  - target app 按“当前 preview app > 最近 hovered Dock app > 最近非本工具前台 app”解析。
  - 若 target app 是本 app、无 bundle id 或无法确定，禁用。
  - 写入 bundle id 到 set，保存并立即通知。

- `Include <App Name>`
  - 如果 target app bundle id 在 set 中，点击后移除。

- 已排除列表
  - 每个 item 标题建议为 `App Name (bundle.id)`，找不到 app name 时显示 bundle id。
  - 点击 item 从 set 中移除。

- `Clear Excluded Apps`
  - 清空 set。
  - 如果当前 panel 对应 app 原本被排除，清空不会主动显示 preview。

暂不处理：

- 不提供按路径排除。
- 不提供导入/导出。
- 不提供 Dock item 右键直接排除。
- 不监听 app 重命名或 bundle id 变化；bundle id 是稳定身份。

## Launch at Login 公开 API 方案

使用 Apple 公开 `ServiceManagement` API：

- `SMAppService.mainApp.status`
- `SMAppService.mainApp.register()`
- `SMAppService.mainApp.unregister()`
- `SMAppService.openSystemSettingsLoginItems()`

项目最低 macOS 14，`SMAppService.mainApp` 的可用性满足要求。实现时需要：

- 在 `Package.swift` linker settings 增加 `.linkedFramework("ServiceManagement")`。
- 新增 `LaunchAtLoginService` 协议和系统实现，便于单元测试。
- 菜单中的状态来自 `SMAppService.mainApp.status`。
- `register()` 或 `unregister()` 抛错时只记录日志并重建菜单，不弹出干扰 hover 路径的提示。

状态映射：

| `SMAppService.Status` | 菜单展示 | 行为 |
| --- | --- | --- |
| `.enabled` | `Launch at Login: Enabled` | 显示 Disable 动作。 |
| `.notRegistered` | `Launch at Login: Not Registered` | 显示 Enable 动作。 |
| `.requiresApproval` | `Launch at Login: Requires Approval` | 显示 Open Login Items Settings。 |
| `.notFound` | `Launch at Login: Not Found` | 记录日志；禁用 Enable / Disable 动作，只显示 Open Login Items Settings。 |

注意事项：

- `SMAppService` 要求 app 被签名；当前打包脚本已有 ad-hoc 签名。P1 验证要覆盖打包 app，而不只是在 SwiftPM debug executable 中运行。
- Launch at Login 是系统级状态，不与 `DockHoverPreview.isEnabled` 互相覆盖。用户可以设置开机启动但禁用 hover preview。

## 权限缺失、Dock 重启、App 重启行为

Accessibility 缺失：

- 保持现有策略：`ProbeOrchestrator.start()` 不启动 Dock observer。
- 菜单仍可读取和修改 P1 设置。
- 用户点击 Refresh Permissions 后只要求菜单状态刷新；P1 不新增 Accessibility 热恢复能力。Accessibility 恢复后的 Dock observer 启动仍按现有重启 app 路径处理。

Screen Recording 缺失：

- 保持现有策略：正常 Dock hover preview 静默抑制 UI。
- Enable 状态仍可为 true；这表示功能意图启用，但权限不满足时不显示 preview。
- 菜单显示 Screen Recording missing；不在 hover 路径弹窗。
- Debug preview 入口继续按现有策略跳过并记录日志。

Dock 重启：

- `DockHoverMonitor` 继续通过 health check 重新订阅 Dock。
- 设置服务不依赖 Dock PID，Dock 重启不影响 settings snapshot。
- Dock 重启过程中如有 pending hover 或当前 panel，按现有 stop/start 路径隐藏，不能留下 stuck panel。

App 重启：

- 启动时从 `UserDefaults` 读取设置。
- 缺失或非法值回退默认值。
- 默认配置必须等价当前 MVP：启用、250 ms、standard retention、最大 8 张卡片、无 excluded apps、英文显示。
- Launch at Login 状态从系统读取，不从 UserDefaults 恢复。

设置错误：

- 非法 delay、retention、max cards、excluded apps、display language 均不能 crash。
- 读取失败或类型不匹配时回退默认值，并记录 `settings.invalid` 或类似日志。
- 写入失败没有常规可恢复 API；若检测到保存后读回不一致，只记录日志，不阻塞 hover。

## 测试计划

### 单元测试

新增设置 store 测试：

- 默认值：空 `UserDefaults` 返回启用、250 ms、standard、8、空 excluded set。
- delay 校验：非法值回退 250；合法值 150/250/400 保留。
- retention 校验：非法 raw value 回退 standard。
- max cards 校验：非法值回退 8；菜单写入的 3/5/8/12 可读回；非预设值例如 11 不应产生隐藏有效状态。
- excluded apps：去重、过滤空字符串、whitespace-only、超长值和非法字符值，保存排序数组，并覆盖超过 128 项时的截断和日志。
- display language：默认英文，合法值 `en` / `zh-Hans` 可读回，非法值回退英文。
- 写入后 snapshot 即时更新。

新增 orchestrator 测试：

- disabled 时收到 hover 不 schedule preview，并隐藏当前 panel。
- excluded app hover 不 schedule preview，并隐藏当前 panel。
- hover delay 使用 settings 中的毫秒值。建议将 scheduler 抽象出来，避免测试真实等待 150/250/400 ms。
- delay 期间设置变为 disabled 或 app 被 excluded 时，delayed validation 不显示 preview。
- debug preview 不受 `isDockHoverPreviewEnabled=false` 影响，但在 Screen Recording missing 或 app 被 excluded 时仍静默跳过。
- Screen Recording missing 仍由 session 静默抑制，P1 设置不改变该行为。

新增 preview session / view model 测试：

- maxCardCount 默认 8 时保持当前测试通过。
- maxCardCount 为 3/5/12 时，窗口查询或 session 只展示对应数量。
- retention mode standard 保持当前 bridge / transition region 测试结果。
- tight / forgiving 的 tolerance 差异用纯函数测试覆盖，不依赖真实鼠标。
- max cards 改变不破坏 stale thumbnail generation cancellation。

新增 menu controller 测试：

- 当前设置项 checkmark 正确。
- disabled/enabled 菜单动作写入 store 并触发 hide。
- language 菜单动作写入 store，菜单立即以目标语言重建，当前语言项 checkmark 正确。
- exclude/include target app 对无 bundle id、本 app、已排除 app、菜单打开时本工具成为 frontmost app 的启用状态正确；菜单标题包含 target app name。
- excluded app 列表超过直接展示上限时显示摘要行，菜单重建不遍历渲染无限条目。
- Launch at Login status 映射正确，尤其 `.notFound` 禁用 Enable / Disable 且保留 Open Login Items Settings。使用 fake service，不调用真实 `SMAppService`。

新增 Launch at Login service 测试：

- 使用协议 fake 覆盖 enabled/notRegistered/requiresApproval/notFound。
- register/unregister 失败时不 crash，并返回错误状态给菜单层记录日志。

### 人工验证

基础验证：

1. `swift test`
2. `swift build`
3. `Scripts/build_probe_app.sh`
4. `git diff --check`
5. 打开 `build/zongMacTools.app`

菜单设置验证：

- 默认启动后 hover 行为与 MVP 一致：250 ms 左右显示，最多 8 张卡片，Dock-to-panel 保留、离开隐藏、Esc 隐藏正常。
- Disable 后 hover 有窗口 app 不显示 panel；Enable 后下一次 hover 恢复。
- 150 ms 明显更快，400 ms 明显更慢；快速离开仍无 stale panel。
- retention `tight` 更容易隐藏，`forgiving` 更容易从 Dock 移到 panel；移动到相邻未启动 Dock app 仍隐藏旧 panel。
- max cards 设为 3/5/8/12 时，多窗口 app 展示数量符合设置，side Dock 仍只显示最多 3 张完整可见卡片后滚动。
- Language 切换为简体中文后，菜单和本 app 静态 UI 文案显示中文；切回 English 后恢复英文。窗口标题、app 名称和 bundle id 不被翻译。
- Exclude target app 后，对该 app hover 不显示 preview；Include 或 Clear 后恢复。菜单标题必须清楚显示当前要排除/恢复的是哪个 app。
- App 重启后设置保持。

权限验证：

- Screen Recording disabled 时，即使 Enable=true，hover preview 仍静默抑制，不弹窗。
- Accessibility disabled 时菜单设置可用，Dock observer 不启动；恢复权限后按现有路径恢复或重启恢复。

Dock / app 生命周期验证：

- `killall Dock` 后不留下 stuck panel，重新订阅后设置仍生效。
- app 退出重启后 UserDefaults 设置仍生效。
- Launch at Login Enable/Disable 后菜单状态与系统 Login Items 状态一致；requiresApproval 时能打开 Login Items 设置。
- 打包后的 app 在 Finder、System Settings 权限列表和 Login Items 中使用 `zongMacTools` 名称和 `Assets/AppIcon/zong-mac-tools-logo.png` 派生出的 app icon。

环境抽样：

- 至少在普通底部 Dock、Dock auto-hide、左/右 Dock、Stage Manager 中抽样确认 disabled、delay、retention、excluded apps 不破坏 P0 结论。
- Multiple displays 仍受硬件限制；有外接显示器后按现有环境变体验证计划补测。

## 分阶段实现计划

阶段 1：设置模型和持久化

- 新增 `DockHoverPreviewSettings`、`PanelRetentionMode`、`SettingsStore`。
- 完成 UserDefaults key、默认值、非法值回退和单元测试。
- 不接入 UI 和 hover 路径。

阶段 2：菜单栏设置 UI

- 扩展 `MenuBarController` 菜单结构。
- 增加 excluded apps target app 解析：当前 preview app、最近 hovered Dock app、最近非本工具前台 app。
- 接入 enable、delay、retention、max cards、display language、excluded apps 的读写。
- 新增轻量本地化文案表，至少覆盖菜单栏、状态行、设置项和 preview panel 静态文案。
- 增加菜单状态测试。

阶段 3：hover 路径即时生效

- `ProbeOrchestrator` 读取 enable、delay、excluded apps。
- 取消 pending hover 和隐藏当前 panel 的 reason 明确化。
- delayed validation 后再次检查设置。

阶段 4：preview session 参数化

- `PreviewSessionController` 和 `PreviewPanelViewModel` 使用统一 max card count。
- retention mode 参数化 preview region / transition region。
- preview panel 静态文案读取 display language；窗口标题和 app 名称保持原始值。
- 保持 standard 模式与现有测试一致。

阶段 5：Launch at Login

- 增加 `ServiceManagement` 链接。
- 新增 `LaunchAtLoginService`。
- 菜单接入 status/register/unregister/open settings。
- 使用 fake service 做单元测试，打包 app 做人工验证。

阶段 6：回归验证和文档更新

- 跑自动测试、构建和打包。
- 按人工验证清单抽样验证 P1。
- 更新 `README.md` 和相关 verification 文档，只记录已实际验证内容。

## 风险和暂不处理事项

风险：

- 最大卡片数目前在 query、session、view model 多处硬编码为 8，P1 实现时若只改一处会出现设置不生效或测试误导。
- retention mode 若误用于 delayed validation，会削弱 stale hover cancellation，造成过期 preview 或旧 panel 残留。
- Launch at Login 在 SwiftPM executable 和打包 `.app` 下行为不同，必须以签名后的 `.app` 为人工验收对象。
- `SMAppService` 的 `.requiresApproval` 需要用户在系统设置中操作，测试不能假设 register 后一定 enabled。
- `SMAppService` 的 `.notFound` 不能留给实现时即兴处理；P1 固定为禁用 Enable / Disable，只保留打开系统 Login Items 设置和日志。
- excluded apps 如果只在初次 hover 检查，不在 delayed validation 后复查，会在 250 ms 窗口内出现竞态。
- excluded apps 如果直接读取菜单打开瞬间的 frontmost app，可能因为状态栏菜单激活而指向本工具或错误 app；必须使用明确 target app，并在菜单标题中展示。
- 损坏的 `UserDefaults` 可能包含大量或超长 excluded app 字符串；读取和菜单渲染都必须设上限，避免设置错误造成卡顿。
- 语言切换如果依赖系统 `Bundle` localization 而不是显式设置，运行时切换可能不会即时生效；P1 应使用自己的轻量文案表。
- 若把 app 名称或窗口标题也纳入翻译，会改变用户识别窗口的方式，P1 明确不做。
- 若把日志也本地化，会破坏现有以英文 event/reason 为依据的验证和排障；日志必须保持稳定。
- 设置变化若主动重查当前 preview，容易引入 generation / thumbnail stale 更新复杂度；P1 应避免。

暂不处理：

- 独立 Settings 窗口。
- 配置导入导出。
- 快捷键切换设置。
- Dock item 右键排除 app。
- excluded apps 的搜索、图标列表和路径级规则。
- per-app hover delay、per-app max cards 或 per-app retention。
- per-app language 和跟随系统语言模式。
- 复杂迁移版本号；P1 只有首版 key，非法值回退即可。
- 把 Launch at Login 状态写入 UserDefaults 并当作事实来源。
