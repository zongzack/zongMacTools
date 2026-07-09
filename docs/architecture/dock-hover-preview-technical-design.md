# Dock 悬停窗口预览技术设计

日期：2026-06-25

最近更新：2026-07-09

## 目标

`zongMacTools` 当前打包为用户可见的菜单栏 app，SwiftPM executable / target 仍为 `DockHoverPreviewProbe`。它用公开 API 实现类似 Windows 任务栏窗口预览的最小可用体验：

- 鼠标悬停 Dock 应用图标。
- 默认等待约 250 ms 后展示该应用在当前可交互环境中可枚举的窗口。
- 预览面板默认最多展示 8 张窗口卡片。
- 每张卡片包含应用图标、窗口标题、静态缩略图或占位图。
- 点击卡片后尝试激活对应窗口，并隐藏面板。

当前状态是 MVP/P0 UI `pass with note`，P1 基础设置实现、自动验证和人工验证均已完成；P2 界面打磨实现、自动验证和人工视觉验证均已完成，人工验证由用户在 2026-07-03 反馈正常；P3 窗口操作增强已完成实现和自动测试，人工验收待执行。普通底部 Dock、全屏 Space、Dock auto-hide、左右 Dock 和 Stage Manager 已完成 P0 验证；多显示器因当前硬件不可用仍为 `blocked / not available`。

## 范围

MVP 范围内：

- SwiftPM executable / target `DockHoverPreviewProbe` 打包成菜单栏 `.app`；本次多工具源码结构拆分没有引入 plugin system、多 target runtime、额外 product 或新 executable。
- AppKit + SwiftUI + ScreenCaptureKit + Accessibility。
- Dock hover 是主触发方式。
- 菜单栏提供极简入口：打开设置、启用/停用 Dock 窗口速览、关于与状态、导出诊断和退出；Launch at Login、权限状态和细分设置位于独立设置窗口。
- 使用非激活 `NSPanel` 显示预览，不抢焦点。
- 使用 ScreenCaptureKit 枚举当前可见/可捕获窗口，并用 AX 做窗口匹配。
- 使用静态缩略图，不做实时视频预览。
- 无窗口、权限缺失、缩略图失败或设置错误时安静降级，不弹重复提示。
- stale hover cancellation 是一等行为：过期 hover、快速离开、候选变化都不能留下旧面板。
- P1 设置持久化到 `UserDefaults`，默认值保持 MVP 行为：enabled、250 ms、standard retention、max 8 cards、excluded apps 为空、English。
- Launch at Login 只通过公开 `ServiceManagement` / `SMAppService.mainApp` 读取和修改。
- P2 UI polish 仅扩展 preview panel 的 ViewModel、SwiftUI 渲染、视觉 token 和 panel 动画；不新增 settings key，不修改 P1 默认值。
- P2 缩略图默认使用 fill；窄窗口按窗口比例自动使用 fit，缩略图容器尺寸保持稳定。
- P2 区分 loading 与 unavailable placeholder；thumbnail unavailable 文案由当前 display language 提供，English 为 `No thumbnail`，简体中文为 `无缩略图`。
- P2 显示/隐藏动画由 panel controller 处理，并读取系统减少动态效果设置；减少动态效果打开时走无 scale/offset 的降级路径。
- P2 浅色/深色外观使用集中视觉规则表达 panel/card 边框、阴影、hover state 和 placeholder surface。
- P3 增加预览卡片右键窗口操作菜单，支持激活窗口、隐藏应用、关闭窗口、最小化窗口和保守屏幕提示。
- P3 窗口操作只使用公开接口；关闭/最小化依赖公开辅助功能按钮或 `kAXMinimizedAttribute`，失败时安静降级并记录日志。

MVP 范围外：

- 实时缩略图。
- 恢复最小化窗口、其他 Space 窗口、全屏 Space 自动切换。
- 精确遮挡检测。
- 卡片上的关闭/最小化/全屏按钮。
- 搜索、键盘切换器、Cmd+Tab 替代、Dock 锁定等扩展功能。
- App Store 分发。

## 外部参考和许可边界

参考项目：[DockDoor](https://github.com/ejbills/DockDoor)。

只参考产品形态和 macOS API 策略，不复制、翻译或机械改写 DockDoor 的 GPLv3 源码、文件结构、helper、注释或私有 API wrapper。

可借鉴的经验：

- Dock Accessibility notification 适合作为 hover wake-up 信号。
- Dock selected child 不能被当成最终事实，必须重新验证鼠标是否仍在目标 Dock item frame 内。
- Dock 监听、窗口查询、缩略图、激活、面板 UI 要保持模块分离。
- Dock 会重启，监听器必须能自动恢复。
- 公开 API 无法保证所有 app 的精确窗口激活，因此激活逻辑必须隔离并记录成功率。

明确不做：

- 不用私有 API 作为默认实现路径。
- 不枚举其他 Space 的窗口。
- 不依赖 CoreDock 私有方向 API。
- 不把 DockDoor 的 GPLv3 实现搬进本项目。

## 模块结构

源码根目录仍是 `Sources/DockHoverPreviewProbe`，`Info.plist` 也保留在该 target 下。目录拆分只是源码组织方式：app 仍只有一个 SwiftPM executable / target，名称仍为 `DockHoverPreviewProbe`，运行时没有插件加载器、多 target host、额外 product 或新增 executable。

当前唯一实现的真实工具是 Dock Window Quick Look，domain folder 为 `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/`。`Settings/ToolDescriptor.swift` 及其 registry 只描述设置窗口里的工具导航 metadata，用于 sidebar/detail 页面，不是 runtime plugin、menu/status item 或工具生命周期抽象。

### 源码布局

- `App/`：app launch、`NSApplication` wiring、`AppDelegate`、菜单栏/status-bar app shell、Launch at Login 和菜单栏入口。`ProbeApp.swift` 仍是 SwiftPM executable 入口。
- `Settings/`：设置模型、`SettingsStore`、settings view models、独立设置窗口、sidebar/detail 页面和 settings-only tool descriptor registry。`DockHoverPreviewSettings` 仍写入既有 `UserDefaults` key，非法值回退规则不变。
- `Support/`：权限、状态、关于与状态、诊断导出和相关支持界面/服务，包括 `PermissionService`、`AppMetadata`、`AppStatusSnapshot` 和 `DiagnosticExportService`。
- `Shared/`：共享校验、日志和 text provider base，包括 `BundleIdentifierValidator`、`ProbeLogger`、`AppTextProvider`。English / 简体中文静态文案拆分在 `Shared/Text/` 下；app 名称、窗口标题、bundle id 和系统权限名称不翻译。
- `Tools/DockWindowQuickLook/`：Dock Window Quick Look 的完整实现，包含 Dock hover monitor、target tracking、orchestrator、窗口查询、缩略图、激活/窗口操作、预览 panel/session，以及该工具的设置页和 view model。

权限策略：

- Accessibility 缺失时不启动 Dock observer，也不尝试 AX 激活。
- Screen Recording 缺失时静默抑制正常 Dock hover preview，因为窗口枚举和缩略图依赖 ScreenCaptureKit。
- 权限问题只通过设置窗口支持页、关于与状态和日志体现，不在 Dock hover 路径弹窗打扰。

### Dock Window Quick Look 关键组件

- `DockHoverMonitor.swift`：连接 Dock 进程的 Accessibility 树，订阅 `kAXSelectedChildrenChangedNotification`。
- `ProbeOrchestrator.swift`：负责 settings-aware hover 延迟、二次验证、enabled/excluded app gating、pending work 取消和预览会话启动。
- `HoverDelayScheduler.swift`：封装 hover 延迟调度，便于 orchestrator 测试。
- `AppTargetTracker.swift`：按当前 preview、最新 Dock hover、最新非本 app 前台应用的优先级提供 excluded-app target。
- `GeometryHelpers.swift` / `AXHelpers.swift`：提供坐标转换、命中测试和 AX 属性读取。
- `WindowQueryService.swift`：用 ScreenCaptureKit 查询当前可见窗口，并用 AX 做 best-effort 匹配；调用方传入当前 max cards limit。
- `ProbeModels.swift`：定义 `PreviewWindowID`、`PreviewWindow`、`ThumbnailSource` 等模型。
- `ThumbnailService.swift`：优先 ScreenCaptureKit 截图，失败时 CoreGraphics fallback。
- 缩略图按窗口 ID、frame size、title 等短期缓存。
- 缩略图失败只显示应用图标和标题，不阻塞面板展示。
- `ActivationService.swift`：优先 AX raise，再调用 `NSRunningApplication.activate(options: [])`。
- 如果 AX element 缺失或 raise 失败，仍激活 app 并隐藏面板。
- 不依赖 `.activateIgnoringOtherApps`，它在现代 macOS 上已不可靠且废弃。
- 激活路径只使用 AX raise 和 `NSRunningApplication.activate(options: [])`。
- `WindowOperationService.swift`：P3 窗口操作服务，隔离激活、隐藏应用、关闭窗口和最小化窗口的能力判断与执行。
- 激活窗口：委托 `ActivationService`，不复制激活逻辑。
- 隐藏应用：调用公开 `NSRunningApplication.hide()`。
- 关闭窗口：读取公开 `kAXCloseButtonAttribute` 并对按钮执行 `kAXPressAction`；按钮缺失或动作失败时记录失败阶段和 AX code。
- 最小化窗口：优先读取公开 `kAXMinimizeButtonAttribute` 并执行 `kAXPressAction`；按钮不可用但 `kAXMinimizedAttribute` 可设置时设置为 `true`。
- `availability` 只做只读探测，不 press、不 set；菜单项根据窗口级可用性启用或禁用。
- `WindowEnvironmentDescriptor.swift`：按窗口 frame 与屏幕 frame 最大交集生成“屏幕：...”提示；无法匹配时显示“屏幕：未知”，不承诺真实空间归属。
- `PreviewPanelModels.swift`：anchor、卡片 view model、panel view model。P2 增加 `ThumbnailDisplayMode`，默认 `.fill`，当窗口 frame aspect ratio `< 1.2` 时使用 `.fit`；`updateThumbnail(nil, for:)` 会让对应卡片停止 loading 并进入 unavailable 语义。
- `PreviewPanelLayoutEngine.swift`：根据 Dock item frame、鼠标位置和可见屏幕区域计算面板 frame。
- `PreviewPanelView.swift`：SwiftUI 卡片 UI。P2 通过 `PreviewThumbnailRenderPlan` 映射 `.fill` / `.fit` 渲染分支；loading 显示 app icon + spinner，unavailable 显示 app icon + 本地化 `No thumbnail` / `无缩略图`；Light / Dark 视觉常量集中在 `PreviewPanelVisualStyle`。
- `PreviewPanelController.swift`：拥有非激活 `NSPanel`，负责 show/update/hide、Reduce Motion aware animation、Esc 监听和 panel frame 查询。update 只更新内容和 frame，不重复触发 show animation。
- `PreviewSessionController.swift`：会话状态机，负责权限抑制、max cards、retention 参数、窗口查询、thumbnail unavailable 文案注入、缩略图更新、点击激活和鼠标离开轮询。

关键规则：

- Dock selected-child 只是候选项。
- 显示 preview 前必须确认 bundle 仍匹配，且鼠标仍在当前 Dock item frame 内。
- 如果 Dock item 变 stale、候选为空、鼠标离开、preview 被禁用或 app 被排除，都必须取消 pending preview 或隐藏当前面板。
- 鼠标从 Dock 图标移动到 panel 时允许保留面板，但横向移动到相邻 Dock item，尤其是未启动 app，不应保留旧面板。
- 当前窗口范围是“当前可交互环境近似值”，不是严格 Mission Control Space API；不承诺精确 Space membership，不恢复最小化窗口，Stage Manager、多显示器和全屏 Space 必须以实测记录为准。

面板行为：

- `NSPanel` 使用 `.nonactivatingPanel`、`.borderless`、透明背景和 floating level。
- 面板可加入所有 Space，并支持 full-screen auxiliary。
- Dock-to-panel 移动使用窄桥接区保留。
- 常规 leave timer 使用 Dock frame、panel frame 和桥接区组成的 preview region。
- Dock hover lost 使用更严格的 panel transition region，避免相邻 Dock item 保留旧 panel。
- P2 show 动画只处理 opacity/transform，不改变 layout size；hide 动画开始后，旧 panel 不再作为可交互区域参与命中判断。
- Reduce Motion 打开时，show/hide 走降级路径，不使用 scale/offset 动画。
- P2 visual token 保持系统 material 方向；Light / Dark 下分别约束 panel border、shadow、card hover 和 placeholder surface。

## 主要流程

Dock hover：

1. Dock AX notification 到达。
2. `DockHoverMonitor` 解析候选 Dock app，并验证鼠标命中 Dock item。
3. `ProbeOrchestrator` 取消旧 pending work，读取 settings snapshot；若 disabled 或 app 被排除则安静隐藏/跳过，否则启动当前 hover delay。
4. 延迟结束后重新解析当前 Dock hover 候选。
5. 如果 bundle 或鼠标命中不匹配，隐藏/取消。
6. 如果权限允许，按当前 max cards 设置查询窗口。
7. 无窗口则隐藏。
8. 有窗口则显示 loading 卡片。
9. 缩略图异步返回后更新卡片；缩略图返回 `nil` 时，对应卡片进入 unavailable placeholder。
10. 点击卡片激活窗口并隐藏。

鼠标离开：

1. 面板显示后以 30 Hz 左右轮询鼠标位置。
2. 鼠标在 panel、Dock item 容差区、panel edge 或 Dock-panel 桥接区时保留。
3. 离开 preview region 后隐藏。
4. Dock hover lost 时只允许 panel/bridge 转场保留，不允许相邻 Dock item 保留旧面板。

Dock 恢复：

1. 定时检查 Dock PID 和 AX list element。
2. Dock 重启或 AX element invalid 时重新订阅。
3. 不留下 stuck panel。

## 已知限制

- 当前只承诺普通可枚举窗口，不承诺最小化窗口或其他 Space 窗口。
- ScreenCaptureKit 对 Stage Manager、多显示器、全屏 Space 的行为需要继续验证。
- 不做精确遮挡检测。
- 某些 app 的 AX raise 可能只能退化为 app-level activation。
- 每次 ad-hoc 重新签名 app 后，macOS TCC 可能需要重新授权，系统权限列表显示名称应为 `zongMacTools`。
- Launch at Login 自动测试覆盖服务构造和 fake-driven menu tests；真实状态已通过签名后的 `build/zongMacTools.app` 和系统 Login Items 人工验证。

## 验收标准

MVP/P1/P2 当前验收标准：

- 菜单栏 app 能启动，且不显示自己的 Dock 图标。
- Accessibility 与 Screen Recording 权限状态可见。
- Screen Recording 缺失时正常 hover preview 被静默抑制。
- VS Code、Chrome、Typora、IINA、WPS 等样本 app 在普通 Space 可展示预览并可点击激活。
- 快速离开不会出现 stale panel。
- 从 Dock 图标移动到 panel 可保持面板。
- 离开 panel 后能及时隐藏。
- 移到相邻未启动 Dock app 时旧 panel 会隐藏。
- `Esc` 能隐藏 panel。
- `killall Dock` 后能重新订阅 Dock。
- 默认 P1 设置保持 MVP 行为：enabled、250 ms、standard retention、max 8 cards、excluded apps 为空、English。
- 菜单设置能即时写入并通知相关模块；设置错误不会导致 hover preview 崩溃、卡住或打扰用户。
- Screen Recording 缺失时继续静默抑制 preview UI。
- Launch at Login 使用公开 `ServiceManagement`。
- P1 manual validation 已完成：Finder/TCC/Login Items 中的 `zongMacTools` 名称和 Z icon、真实菜单 checkmark/交互、Launch at Login 状态。
- P2 自动验证已完成：`swift test` 在 2026-07-03 13:31:05 Asia/Shanghai 记录 130 XCTest、0 failures、exit 0；`swift build` exit 0；`Scripts/build_probe_app.sh` exit 0，输出 `/Users/zong/Desktop/Project/zongMacTools/build/zongMacTools.app`，Info.plist OK，替换 existing signature。
- P2 不改变 P1 defaults，也不新增 settings key。
- P2 ViewModel 和 UI 层覆盖 thumbnail `.fill` / `.fit`、窄窗口 fit、loading/unavailable placeholder、本地化 `No thumbnail` / `无缩略图`、show/hide animation、Reduce Motion 降级以及 Light / Dark visual token。
- P2 人工视觉验证已完成：底部程序坞、左右程序坞、程序坞自动隐藏、台前调度、浅色/深色外观、减少动态效果、Typora 窄窗口、多窗口应用、屏幕录制权限缺失和快速悬停失效取消均由用户反馈正常。
- P3 自动测试覆盖：窗口操作服务公开接口路径、失败降级和日志结果；右键菜单模型、禁用项、动作回调；菜单跟踪期间会话保留；旧会话动作保护；屏幕提示匹配。
- P3 自动验证已完成：`swift test` 在 2026-07-06 CST 记录 164 XCTest、0 failures、exit 0；`swift build` exit 0；`Scripts/build_probe_app.sh` exit 0，输出 `/Users/zong/Desktop/Project/zongMacTools/build/zongMacTools.app`，Info.plist OK，替换 existing signature；`git diff --check` exit 0。
- 多工具源码结构文档自动验证：2026-07-09 Asia/Shanghai，`git diff --check` exit 0；`swift test` 记录 212 XCTest、0 failures、exit 0；`swift build` exit 0；`Scripts/build_probe_app.sh` exit 0，输出 `build/zongMacTools.app`，executable `DockHoverPreviewProbe`，bundle id `com.zong.zongMacTools`。

待补验收：

- Multiple displays。
- P3 人工验收。
- 多工具源码结构重组后的人工 smoke test 尚未执行，需覆盖：
  - 从 `build/zongMacTools.app` 启动 app。
  - 打开设置，切换 General language，确认 sidebar 和 detail 刷新，并确认窗口重新显示时 title 使用当前语言。
  - 验证 Dock Window Quick Look 设置控件仍写入设置，预览行为仍响应。
  - 验证 Context Menu Extension 仍只是设置里的禁用占位。
  - 覆盖 Dock hover preview、右键窗口操作菜单、诊断导出/关于状态、Launch at Login 状态和打开设置路径等主流程。
  - ad-hoc 重新签名后，macOS TCC 可能需要重新添加 `build/zongMacTools.app`。
