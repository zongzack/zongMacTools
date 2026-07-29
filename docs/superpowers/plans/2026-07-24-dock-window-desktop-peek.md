# Dock Window Desktop Peek Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Dock 窗口速览卡片 hover 时，以目标窗口原始位置和大小显示两阶段静态桌面镜像，并在不激活应用、不改变真实窗口层级的前提下压暗目标屏幕。

**Architecture:** `PreviewSessionController` 为每个 Dock panel session 产生永不复用的 epoch，并将同步卡片事件交给新的 `WindowPeekCoordinator`。Coordinator 将 session-local hover sequence（输入排序）与 `(sessionEpoch, peekGeneration, windowID)` capture token（截图结果有效性）严格分开；它只维护逻辑 active/pending latest，而 app composition 强持有的 `ScreenCaptureKitCaptureBroker` 串行化缩略图和 desktop-peek 的所有物理 `SCScreenshotManager.captureImage` 调用。`WindowPeekGeometry` 使用按 display ID 配对的 `SCDisplay.frame` capture-point space 与 `NSScreen.frame` AppKit space，并基于实际图像尺寸裁切。查询、AX、`SCWindow`、panel 和 broker 均隔离在 MainActor；测试以不含系统对象的领域 fake 替代它们。

**Tech Stack:** Swift 6、SwiftPM、AppKit、SwiftUI、ScreenCaptureKit、CoreGraphics、ApplicationServices、XCTest、shell build scripts。

---

日期：2026-07-24

设计依据：`docs/superpowers/specs/2026-07-24-dock-window-desktop-peek-design.md`

> **实现决议（不修改当前未提交设计规格）：** 规格的屏幕几何段落若仍将 `CGDisplayBounds(displayID)` 作为 ScreenCaptureKit capture frame，执行时不得照用。SDK 中 `SCDisplay.frame` 才是与 `SCWindow.frame` 相同的 capture-point 坐标来源；本计划以同一次 `SCShareableContent` 的 `SCDisplay.frame` 与按 display ID 配对的 `NSScreen.frame` 为准。`CGDisplayBounds` 仅用于原型诊断日志。本计划的该项绑定优先于规格中的冲突表述，且本任务明确不触碰该用户未提交文件。

## 实施原则

- 不使用私有 API，不调用 AX raise，不激活应用，也不修改真实窗口层级。
- 卡片已有缩略图时，粗略镜像的 `show` 必须发生在同一个 MainActor 事件处理内，并先于高清截图请求。
- hover、主选择和右键菜单开始不能通过新的非结构化 `Task` 延后；只有窗口查询和截图保留异步边界。
- session epoch 永不复用；hover sequence 只在同一 epoch 中排序 enter/exit，capture completion 只验证 request 的 session epoch、peek generation 和 window ID。重复进入同一 target 不会使在飞 request 因新的输入 sequence 失效。
- `desktopPeekEligible` 是查询阶段产生的明确事实，不能从 `CGImage?`、`SCWindow?` 或 AX fallback 的存在与否临时推断。
- 任何时刻全 app 只有一个未返回的 `SCScreenshotManager.captureImage` 调用，包含现有缩略图和 desktop peek；已进入该公开 API 的 worker 一律不取消，隐藏和切换只能使逻辑 token 失效或取消尚未开始的 broker queue entry。
- 原始 `SCWindow.frame`/AX frame 不得直接与 `NSScreen.frame` 求交；`SCDisplay.frame` 是唯一用于 ScreenCaptureKit 窗口交集的 capture-point 屏幕 frame，`CGDisplayBounds` 只允许出现在诊断日志中。所有 overlay 几何先经显式 capture-point 到 AppKit-space 转换，所有像素裁切基于实际 `CGImage` 尺寸。
- `AXUIElement`、`AXObserver`、`SCWindow`、`SCContentFilter` 和 `NSPanel` 不得藏在跨 actor 的 `@unchecked Sendable` model 中；它们的构造、持有和使用均在 MainActor，`@preconcurrency import` 仅用于 C API 导入边界。
- overlay 不加入 Dock-to-panel 保留区域，不接收鼠标，不显示 loading 或错误占位，也不写入磁盘。
- 先完成公开 API 技术原型并记录结论，再进入生产实现。原型失败时停止后续任务并回到设计评审，不能用定时延迟掩盖 hover tracking 问题。

## 文件结构

### 新增文件

- `Scripts/Probes/window_peek_capability_probe.swift`：开发期最小 AppKit/SwiftUI/ScreenCaptureKit/AX 原型，验证 hover 顺序、窗口层级、全屏 Space、截图取消和目标窗口 destroyed 通知。
- `Scripts/Probes/run_window_peek_capability_probe.sh`：编译并启动原型，不接入 SwiftPM product。
- `docs/verification/dock-window-desktop-peek-capability-probe.md`：记录原型环境、步骤、日志和结论。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekModels.swift`：所有 Task 共享的质量、capture 配置、双坐标屏幕、layout 和 stop reason 契约。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekGeometry.swift`：纯函数屏幕选择、截图尺寸、点/像素裁切与 overlay frame。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ScreenCaptureKitCaptureBroker.swift`：唯一发起物理 SCK 截图的 MainActor broker，串行化缩略图与最新 desktop-peek 请求。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekCaptureService.swift`：不暴露 SCK 对象给测试的 backend/service 边界和可判别结果。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekPanel.swift`：preview、mirror 和 dimming 共用的不可 key/main `NSPanel` 子类与集中层级策略。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekOverlayController.swift`：压暗 panel、镜像 panel、集中窗口层级策略和图片清理。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekCoordinator.swift`：桌面速览状态机、session epoch、输入 sequence、capture request token、图像质量、逻辑 latest 门控和活跃目标期间的权限刷新。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekLifecycleObserver.swift`：Space、屏幕参数、应用终止和当前 AX 窗口 destroyed 通知适配器。
- `Tests/DockHoverPreviewProbeTests/WindowPeekGeometryTests.swift`：单/多显示器、跨屏、混合 scale、无交集和 800 万像素上限测试。
- `Tests/DockHoverPreviewProbeTests/WindowPeekCaptureServiceTests.swift`：领域截图配置、backend seam 和结果分类测试。
- `Tests/DockHoverPreviewProbeTests/ScreenCaptureKitCaptureBrokerTests.swift`：缩略图/desktop-peek 跨 service 的单物理截图、最新请求替换和 active 请求不可取消测试。
- `Tests/DockHoverPreviewProbeTests/WindowPeekOverlayControllerTests.swift`：panel 属性、层级、update 和资源清理测试。
- `Tests/DockHoverPreviewProbeTests/WindowPeekCoordinatorTests.swift`：两阶段显示、乱序事件、stale 结果、单飞截图和取消矩阵测试。
- `Tests/DockHoverPreviewProbeTests/WindowPeekLifecycleObserverTests.swift`：系统通知到领域事件的映射测试。
- `docs/verification/dock-window-desktop-peek-manual-checklist.md`：单显示器核心场景与多显示器硬件验收记录。

### 修改文件

- `Sources/DockHoverPreviewProbe/Settings/DockHoverPreviewSettings.swift`：增加独立开关和持久化 key。
- `Sources/DockHoverPreviewProbe/Settings/SettingsStore.swift`：snapshot 字段复制、读取、写入、非法类型回退和 observer 数据。
- `Sources/DockHoverPreviewProbe/Support/PermissionService.swift`：将 PermissionService/SystemPermissionService 隔离到 MainActor，供 coordinator 的显式刷新调度器安全调用。
- `Sources/DockHoverPreviewProbe/Shared/AppTextProvider.swift`：增加两条设置文案 key。
- `Sources/DockHoverPreviewProbe/Shared/Text/AppTextProvider+DockWindowQuickLook.swift`：增加 English/简体中文标题和说明。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsViewModel.swift`：映射和更新独立开关。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsView.swift`：显示带说明的独立 Toggle。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ProbeModels.swift`：将含义不明的 `frame` 改名为 capture-point `captureFrame`，并把不可 Sendable 的 AX/SCK/AppKit 引用限制在 MainActor model。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowQueryService.swift`：从同一次 `SCShareableContent` 查询按 display ID 配对 `SCDisplay.frame` 与 `NSScreen.frame`，返回窗口及 session 屏幕快照；仅为 SCK/AX 成功匹配候选创建生产 capture source 并标记 eligible。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ThumbnailService.swift`：使用重命名后的 capture-point frame 生成 cache key，并经全局 broker 发起 SCK 缩略图。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowEnvironmentDescriptor.swift`：提取并复用最大交集屏幕选择函数。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelModels.swift`：增加 sequence 化 hover action 和同步右键菜单开始 action。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelView.swift`：发送卡片 hover 意图，并在弹出 `NSMenu` 前同步发送隐藏意图。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelController.swift`：生成 panel session 内单调 sequence，并保持事件同步路由。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewSessionController.swift`：会话校验、同步 action 路由、缩略图升级和所有 hide 路径。
- `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ProbeOrchestrator.swift`：主功能关闭时保证旧 session 与 desktop peek 同步停止。
- `Sources/DockHoverPreviewProbe/App/AppDelegate.swift`：构造新服务、启动/停止 observer，并移除动作路径中的多余 `Task` 跳转。
- `Tests/DockHoverPreviewProbeTests/SettingsStoreTests.swift`：默认值、持久化、非法类型和字段保持测试。
- `Tests/DockHoverPreviewProbeTests/SettingsViewModelTests.swift`：UI state、独立 toggle 和 observer 测试。
- `Tests/DockHoverPreviewProbeTests/AppTextProviderTests.swift`：双语文案测试。
- `Tests/DockHoverPreviewProbeTests/WindowQueryServiceTests.swift`：eligibility 只来自 SCK/AX 匹配测试。
- `Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift`：新 action contract 测试。
- `Tests/DockHoverPreviewProbeTests/PreviewPanelViewRenderingTests.swift`：hover intent 和菜单调用顺序测试。
- `Tests/DockHoverPreviewProbeTests/PreviewPanelControllerTests.swift`：sequence 生成和同步路由测试。
- `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`：session、操作顺序、缩略图升级和生命周期取消测试。
- `Tests/DockHoverPreviewProbeTests/ThumbnailServiceTests.swift`：补充 `PreviewWindow` 的 capture source/eligibility 构造参数，保持现有缩略图测试可编译。
- `Tests/DockHoverPreviewProbeTests/WindowOperationServiceTests.swift`：补充 `PreviewWindow` 的 capture source/eligibility 构造参数，保持现有窗口操作测试可编译。
- `Tests/DockHoverPreviewProbeTests/ProbeOrchestratorPreviewTests.swift`：主功能禁用联动测试。
- `Tests/DockHoverPreviewProbeTests/MenuBarControllerTests.swift`：随 PermissionService MainActor 化调整本文件 fake。
- `Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift`：随 PermissionService MainActor 化调整本文件 fake。
- `docs/architecture/dock-hover-preview-technical-design.md`：实现后补充最终组件边界和已验证限制。
- `docs/roadmap.md`：实现完成后记录状态，人工场景未通过前不得写成全部完成。
- `docs/releases/CHANGELOG.md`：在 Unreleased 中记录新增能力。

## 核心类型契约

所有任务统一使用以下命名，后续不得再创造同义类型：

```swift
enum WindowPeekImageQuality: Int, Sendable {
    case coarse
    case highResolution
}

enum WindowPeekCaptureResult {
    case image(CGImage)
    case unavailable
    case permissionDenied
    case failed
}

struct WindowPeekPixelSize: Equatable, Sendable {
    let width: Int
    let height: Int
}

struct WindowPeekCaptureConfiguration: Equatable, Sendable {
    let pixelSize: WindowPeekPixelSize
    let showsCursor: Bool
    let ignoresSingleWindowShadow: Bool
}

struct WindowPeekScreen: Equatable, Sendable {
    let identifier: UInt32
    let localizedName: String?
    /// 同一次 SCShareableContent 查询中对应 SCDisplay.frame 的全局 point frame，Y 向下。
    let captureFrame: CGRect
    /// 同一 display ID 对应的 NSScreen.frame，AppKit point frame，Y 向上。
    let appKitFrame: CGRect
    let backingScaleFactor: CGFloat
}

struct WindowPeekLayout: Equatable, Sendable {
    let screen: WindowPeekScreen
    let dimmingFrame: CGRect
    let mirrorFrame: CGRect
    let windowCaptureFrame: CGRect
    let windowAppKitFrame: CGRect
    /// 以完整窗口左上角为原点的点坐标裁切区。
    let pointCropRect: CGRect
}

enum WindowPeekStopReason: String, Sendable {
    case hoverExited
    case sessionReplaced
    case sessionHidden
    case primarySelection
    case contextMenu
    case settingsDisabled
    case targetUnavailable
    case targetWindowDestroyed
    case permissionDenied
    case activeSpaceChanged
    case screenParametersChanged
    case applicationTerminated
    case appTermination
}

struct WindowPeekCaptureRequestToken: Equatable, Sendable {
    let sessionEpoch: UInt64
    let peekGeneration: UInt64
    let windowID: PreviewWindowID
}
```

上述类型全部定义在 `WindowPeekModels.swift`，包括 `WindowPeekCaptureRequestToken`。`pointCropRect` 使用完整窗口左上角为原点、Y 向下的 capture-point 坐标；它不是可直接传给 `CGImage.cropping(to:)` 的像素 rect。`WindowPeekCaptureRequestToken` 只代表异步截图结果的有效性，不能用来给 input hover event 排序；后者直接使用 `(sessionEpoch, sequence)`。`WindowPeekStopReason` 只用于状态机、日志和测试断言；传给现有 panel 的 hide reason 保持现有字符串，避免无关日志回归。

### Task 1: 完成公开 API 最小技术原型和决策门

**Files:**
- Create: `Scripts/Probes/window_peek_capability_probe.swift`
- Create: `Scripts/Probes/run_window_peek_capability_probe.sh`
- Create: `docs/verification/dock-window-desktop-peek-capability-probe.md`

- [ ] **Step 1: 创建原型目录**

Run: `mkdir -p Scripts/Probes`

Expected: `Scripts/Probes` 存在，且 `git status --short` 未出现其他路径变化。

- [ ] **Step 2: 创建可独立编译的原型入口**

原型必须只使用公开 `AppKit`、`SwiftUI`、`ScreenCaptureKit`、`CoreGraphics` 和 `ApplicationServices`。界面显示三张内容会刷新的 SwiftUI 卡片，每张卡片记录 `.onHover` 的 enter/exit、固定 session epoch 内单调 sequence 和当前 run-loop tick；重新打开 panel 时 epoch 必须递增且 sequence 从 1 重启。右键路径在 `NSMenu.popUpContextMenu` 前记录 `contextMenuWillOpen`。原型创建三个固定层级 panel：dimming 为 `.floating - 2`、mirror 为 `.floating - 1`、card panel 为 `.floating`；三个 panel 都必须通过同一个 non-key/non-main subclass 创建。dimming/mirror 必须使用与生产计划相同的 `orderFront(nil)`，card panel 保持现有 `orderFrontRegardless()`；三者使用生产 style mask/collection behavior，并持续记录 app activation、key/main 和 `CGWindowListCopyWindowInfo` 可见层级。

原型还要同时记录样本窗口的 `SCWindow.frame`、AX frame、同一次 `SCShareableContent` 中每个 display ID 对应的 `SCDisplay.frame`、`NSScreen.frame`、backing scale，以及仅作诊断的 `CGDisplayBounds`。overlay 必须只使用 `SCDisplay.frame -> NSScreen.frame` 的成对 point-space 公式做视觉对齐；禁止以 `CGDisplayBounds` 作为交集输入，禁止先假定两个全局坐标空间共享原点或 scale。截图使用下列配置：

```swift
let filter = SCContentFilter(desktopIndependentWindow: window)
let configuration = SCStreamConfiguration()
configuration.showsCursor = false
configuration.ignoreShadowsSingleWindow = true
configuration.width = max(1, Int(window.frame.width.rounded(.up)))
configuration.height = max(1, Int(window.frame.height.rounded(.up)))
let image = try await SCScreenshotManager.captureImage(
    contentFilter: filter,
    configuration: configuration
)
```

取消实验必须记录四个时间点：请求开始、`Task.cancel()`、async 调用返回、下一请求开始。该实验只记录 API 行为，不会将生产策略改为取消 worker；生产始终等待未返回的调用。原型不读取或修改真实窗口层级，不写入截图文件。

- [ ] **Step 3: 创建编译运行脚本**

脚本内容固定为：

```bash
#!/bin/zsh
set -euo pipefail

probe_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="$(mktemp -d "${TMPDIR:-/tmp}/window-peek-probe.XXXXXX")"
trap 'rm -rf "$output_dir"' EXIT

xcrun swiftc \
  -parse-as-library \
  -framework AppKit \
  -framework SwiftUI \
  -framework ScreenCaptureKit \
  -framework CoreGraphics \
  -framework ApplicationServices \
  "$probe_dir/window_peek_capability_probe.swift" \
  -o "$output_dir/window-peek-capability-probe"

"$output_dir/window-peek-capability-probe"
```

Run: `chmod +x Scripts/Probes/run_window_peek_capability_probe.sh && Scripts/Probes/run_window_peek_capability_probe.sh`

Expected: 原型编译成功，打开非激活卡片 panel；终端持续输出 session epoch、hover sequence、panel level 和 capture 时序。

- [ ] **Step 4: 执行六组能力验证**

逐项执行并保留原始日志：

1. 普通 Space 中反复扫过三张卡片，同时触发 root view 内容更新；enter/exit 必须成对且不能因刷新产生持续抖动。
2. 普通 Space 和全屏 Space 中显示三个 panel；卡片 panel 始终位于 mirror 和 dimming 上方，Dock、菜单栏和通知中心仍可交互，任何 panel 都不能成为 key/main。
3. 以两个生产等价来源连续提交 thumbnail A、desktop-peek B、desktop-peek C 三个静态截图；A 在飞时只允许记录 C 为最新 pending，B 不得启动。记录 A 开始/返回、B 被逻辑替换、C 开始的时间点，确认任何时刻最多一个公开 capture 调用。
4. 对比 `SCWindow.frame`/AX frame 与同一 `SCDisplay.frame`；在单屏、副屏位于主屏上/下/左/右、负坐标和混合 scale 时确认转换后 overlay 与真实窗口四边对齐。当前硬件无法提供副屏时，单屏实测和多屏数学样例分开记录，不把数学样例写为硬件 pass。
5. 在全屏 Space 切换、屏幕参数变化和 Esc 后同步 `orderOut`；确认无残留 panel，并确认 preview、mirror、dimming 均未成为 key/main、前台应用不变。
6. 对测试应用的当前 AX window 订阅公开 `kAXUIElementDestroyedNotification`，关闭该窗口但保持应用进程运行；确认 callback 到达 main run loop，并记录 `AXObserverCreate`、`AXObserverAddNotification` 和移除订阅的返回码。

- [ ] **Step 5: 写入原型结论并执行决策门**

`docs/verification/dock-window-desktop-peek-capability-probe.md` 必须记录：macOS build、显示器数量、是否独立 Space、Stage Manager、Dock 位置、每组步骤、关键日志、`pass / pass with note / fail / blocked` 和以下明确结论：

- `.onHover` 在 root view 更新后稳定：生产实现继续使用 `.onHover`。
- `.onHover` 出现重复离开/进入或空窗：生产实现改用轻量 `NSTrackingArea` bridge；不得增加延迟。
- 无论取消后 async 调用何时返回，生产 coordinator 都不取消 capture worker，只使 generation 失效并在 worker 返回后启动当时仍有效的最新目标。
- `SCDisplay.frame` capture-point 到 AppKit-space 的 X/Y/尺寸映射无法使单屏样本窗口与 overlay 四边对齐，或只有依赖 `CGDisplayBounds` 才能对齐：停止 Task 2-8，先更新坐标契约与数学样例。
- 公开层级无法在全屏 Space 保持正确关系：停止 Task 2-8，回到设计评审，不提交私有 API 或对 overlay 使用 `orderFrontRegardless()` 的 workaround。
- 任一 preview/dimming/mirror panel 成为 key/main 或改变前台应用：停止 Task 2-8，先修订 panel subclass 与交互验证，不接受 `.nonactivatingPanel` 的名称作为证据。
- broker 不能证明 thumbnail 与 desktop-peek 请求共享一个物理 in-flight 上限：停止 Task 2-8，先修订 broker API；不得把“最多一个”缩小解释为仅 coordinator 内部。
- 当前目标 AX window 不支持 destroyed 订阅或关闭后 callback 不到达 main run loop：停止 Task 2-8，回到设计评审，在规格中明确选择可测试的窗口存在性复查周期后再继续；不得保留一条无法兑现的关闭清理验收路径。

- [ ] **Step 6: 提交原型和验证记录**

```bash
git add Scripts/Probes/window_peek_capability_probe.swift \
  Scripts/Probes/run_window_peek_capability_probe.sh \
  docs/verification/dock-window-desktop-peek-capability-probe.md
git diff --cached --check
git commit -m "test: probe desktop window peek capabilities"
```

Expected: 只提交原型和能力验证记录，不包含设计规格的用户未提交改动。

### Task 2: 增加设置和共享领域契约

**Files:**
- Modify: `Sources/DockHoverPreviewProbe/Settings/DockHoverPreviewSettings.swift`
- Modify: `Sources/DockHoverPreviewProbe/Settings/SettingsStore.swift`
- Modify: `Sources/DockHoverPreviewProbe/Shared/AppTextProvider.swift`
- Modify: `Sources/DockHoverPreviewProbe/Shared/Text/AppTextProvider+DockWindowQuickLook.swift`
- Modify: `Sources/DockHoverPreviewProbe/Support/PermissionService.swift`
- Modify: `Sources/DockHoverPreviewProbe/Support/SupportSettingsView.swift`
- Modify: `Sources/DockHoverPreviewProbe/Settings/SettingsRootView.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsViewModel.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsView.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekModels.swift`
- Test: `Tests/DockHoverPreviewProbeTests/SettingsStoreTests.swift`
- Test: `Tests/DockHoverPreviewProbeTests/SettingsViewModelTests.swift`
- Test: `Tests/DockHoverPreviewProbeTests/AppTextProviderTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/MenuBarControllerTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/ProbeOrchestratorPreviewTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift`

- [ ] **Step 1: 写设置默认值、字段保持和同步 read-back 失败测试**

在 `SettingsStoreTests` 中覆盖 dedicated key、非法类型、其他字段更新和 observer 最终值：

```swift
func testDesktopWindowPeekDefaultsToEnabledAndUsesDedicatedKey() {
    let (defaults, suiteName) = makeTemporaryDefaults()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: ProbeLogger())

    XCTAssertTrue(store.snapshot.isDesktopWindowPeekEnabled)
    XCTAssertEqual(
        SettingsKey.desktopWindowPeekEnabled.rawValue,
        "DockHoverPreview.desktopWindowPeekEnabled"
    )
}

func testDesktopWindowPeekInvalidTypeFallsBackToEnabled() {
    let (defaults, suiteName) = makeTemporaryDefaults()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("false", forKey: SettingsKey.desktopWindowPeekEnabled.rawValue)

    let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: ProbeLogger())

    XCTAssertTrue(store.snapshot.isDesktopWindowPeekEnabled)
}

func testUpdatingOtherDockSettingsPreservesDesktopWindowPeek() {
    let (defaults, suiteName) = makeTemporaryDefaults()
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: ProbeLogger())
    store.update { $0.isDesktopWindowPeekEnabled = false }

    store.updateDockWindowQuickLookSettings { $0.maxCardCount = 12 }

    XCTAssertFalse(store.snapshot.isDesktopWindowPeekEnabled)
    XCTAssertEqual(store.snapshot.maxCardCount, 12)
}

func testDesktopWindowPeekImmediateReadbackFailurePublishesEnabledFallback() {
    let logger = ProbeLogger()
    let persistence = RejectingDesktopPeekPersistence()
    let store = UserDefaultsSettingsStore(persistence: persistence, logger: logger)
    var observed: [DockHoverPreviewSettings] = []
    _ = store.addObserver { observed.append($0) }

    store.update { $0.isDesktopWindowPeekEnabled = false }

    XCTAssertTrue(store.snapshot.isDesktopWindowPeekEnabled)
    XCTAssertEqual(observed, [store.snapshot])
    XCTAssertTrue(logger.snapshot().contains {
        $0.contains("settings.persistFailed key=DockHoverPreview.desktopWindowPeekEnabled")
    })
}

func testDesktopWindowPeekWrongTypeReadbackPublishesEnabledFallback() {
    let logger = ProbeLogger()
    let persistence = WrongTypeDesktopPeekPersistence()
    let store = UserDefaultsSettingsStore(persistence: persistence, logger: logger)

    store.update { $0.isDesktopWindowPeekEnabled = false }

    XCTAssertTrue(store.snapshot.isDesktopWindowPeekEnabled)
    XCTAssertTrue(logger.snapshot().contains {
        $0.contains("settings.persistFailed key=DockHoverPreview.desktopWindowPeekEnabled")
    })
}

func testDesktopWindowPeekMismatchedReadbackPublishesEnabledFallback() {
    let logger = ProbeLogger()
    let persistence = InvertingDesktopPeekPersistence()
    let store = UserDefaultsSettingsStore(persistence: persistence, logger: logger)

    store.update { $0.isDesktopWindowPeekEnabled = false }

    XCTAssertTrue(store.snapshot.isDesktopWindowPeekEnabled)
    XCTAssertTrue(logger.snapshot().contains {
        $0.contains("settings.persistFailed key=DockHoverPreview.desktopWindowPeekEnabled")
    })
}

private final class RejectingDesktopPeekPersistence: SettingsKeyValueStoring {
    private var values: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? { values[defaultName] }

    func set(_ value: Any?, forKey defaultName: String) {
        guard defaultName != SettingsKey.desktopWindowPeekEnabled.rawValue else { return }
        values[defaultName] = value
    }
}

private final class WrongTypeDesktopPeekPersistence: SettingsKeyValueStoring {
    private var values: [String: Any] = [:]
    func object(forKey defaultName: String) -> Any? { values[defaultName] }
    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = defaultName == SettingsKey.desktopWindowPeekEnabled.rawValue
            ? NSNumber(value: 0)
            : value
    }
}

private final class InvertingDesktopPeekPersistence: SettingsKeyValueStoring {
    private var values: [String: Any] = [:]
    func object(forKey defaultName: String) -> Any? { values[defaultName] }
    func set(_ value: Any?, forKey defaultName: String) {
        if defaultName == SettingsKey.desktopWindowPeekEnabled.rawValue,
           let requested = value as? Bool {
            values[defaultName] = !requested
        } else {
            values[defaultName] = value
        }
    }
}
```

Run: `swift test --filter SettingsStoreTests`

Expected: FAIL because the model, key, persistence seam and snapshot field do not exist.

- [ ] **Step 2: 实现完整设置字段复制链和可测试 persistence seam**

`DockHoverPreviewSettings`、`DockHoverPreviewSettings.defaults`、`DockWindowQuickLookSettingsSnapshot` 的 stored property/initializer/`init(settings:)`、`updateDockWindowQuickLookSettings` copy-back、`SettingsKey`、`readSnapshot` 和 `persist` 全部加入 `isDesktopWindowPeekEnabled`；key 固定为 `DockHoverPreview.desktopWindowPeekEnabled`，默认值固定为 `true`。

在 `SettingsStore.swift` 增加最小接口和两个 initializer；生产仍默认 `.standard`，测试才能注入拒写 fake：

```swift
protocol SettingsKeyValueStoring: AnyObject {
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: SettingsKeyValueStoring {}

init(userDefaults: UserDefaults = .standard, logger: ProbeLogger) {
    self.init(persistence: userDefaults, logger: logger)
}

init(persistence: any SettingsKeyValueStoring, logger: ProbeLogger) {
    self.persistence = persistence
    self.logger = logger
    self.snapshot = Self.readSnapshot(from: persistence, logger: logger)
}
```

`readSnapshot`、`readBool`、`readInt`、`readEnum` 和 `readExcludedApps` 的输入统一改为 `any SettingsKeyValueStoring`；现有实现本来只需 `object(forKey:)`，不扩张接口。布尔读取必须用 `CFGetTypeID(number) == CFBooleanGetTypeID()` 排除字符串和普通数字。`persist(_:) -> DockHoverPreviewSettings` 先写全部字段，再从同一 persistence 读取 dedicated key；类型或值不匹配时记录 `settings.persistFailed key=DockHoverPreview.desktopWindowPeekEnabled` 并把返回 snapshot 的字段改为 `true`。`update` 固定执行 sanitize → persist/read-back → snapshot 赋值 → observer，observer 只收到最终 snapshot。该 seam 不声称验证进程退出后的磁盘耐久化。

- [ ] **Step 3: 写并实现设置 UI、observer 和双语文案**

`LocalizedTextKey` 增加 `.desktopWindowPeek` 与 `.desktopWindowPeekDescription`，在 `AppTextProviderTests` 精确断言 English/简体中文标题和说明。`DockWindowQuickLookSettingsViewState` 增加 `isDesktopWindowPeekEnabled` 和 `isDesktopWindowPeekControlEnabled`，后者始终等于主功能开关。

```swift
func testDesktopWindowPeekMapsWritesObservesAndFollowsMasterDisabledState() {
    let store = RecordingSettingsStore(snapshot: .defaults)
    let viewModel = DockWindowQuickLookSettingsViewModel(
        settingsStore: store,
        targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
        logger: ProbeLogger()
    )

    XCTAssertTrue(viewModel.state.isDesktopWindowPeekEnabled)
    XCTAssertTrue(viewModel.state.isDesktopWindowPeekControlEnabled)
    viewModel.setDesktopWindowPeekEnabled(false)
    XCTAssertFalse(viewModel.state.isDesktopWindowPeekEnabled)
    XCTAssertTrue(store.snapshot.isDockHoverPreviewEnabled)

    var external = store.snapshot
    external.isDesktopWindowPeekEnabled = true
    external.isDockHoverPreviewEnabled = false
    store.replaceSnapshot(external)
    XCTAssertTrue(viewModel.state.isDesktopWindowPeekEnabled)
    XCTAssertFalse(viewModel.state.isDesktopWindowPeekControlEnabled)
}
```

view model 的 `setDesktopWindowPeekEnabled(_:)` 只更新独立字段。View 在主 Toggle 后增加独立 Toggle 和 `.caption` 说明，使用 `.disabled(!viewModel.state.isDesktopWindowPeekControlEnabled)`；禁用主功能不改写独立持久化值。

- [ ] **Step 4: 将权限服务收敛到 MainActor**

将 `PermissionService` protocol 和 `SystemPermissionService` 标记为 `@MainActor`，保留现有 `currentState`、`refresh()` 和设置跳转签名；`PermissionState` 仍是纯 `Equatable, Sendable` value。给 `SupportSettingsView` 与 `SettingsRootView` 加 `@MainActor`，使其 initializer 和按钮 action 对 `PermissionService` 的访问也处于同一隔离域。这样 Task 6 的刷新和现有 AppKit 设置跳转都只能从 MainActor 访问，不需要以 `@unchecked Sendable` 传递服务或其闭包。

同一提交中，给所有现有测试 conformer 添加 `@MainActor`，且不改 fake 行为：`MenuBarControllerTests.swift`、`PreviewSessionControllerTests.swift`、`ProbeOrchestratorPreviewTests.swift`、`SettingsWindowControllerTests.swift` 中的 `FakePermissionService`/`OrchestratorFakePermissionService` 均声明为 `@MainActor private final class`。所有生产使用方已经是 MainActor UI/编排对象；若编译器报告非 MainActor 使用方，必须将该使用方显式迁入 MainActor，而不是给 protocol 或 fake 增加 `nonisolated`。

Run: `swift test --filter MenuBarControllerTests && swift test --filter PreviewSessionControllerTests && swift test --filter ProbeOrchestratorPreviewTests && swift test --filter SettingsWindowControllerTests`

Expected: 所有既有 PermissionService 使用方保持编译，且没有通过 `@unchecked Sendable` 绕过隔离。

- [ ] **Step 5: 创建共享 `WindowPeekModels` 契约**

在 `WindowPeekModels.swift` 原样定义本计划“核心类型契约”中的 `WindowPeekImageQuality`、`WindowPeekCaptureResult`、`WindowPeekPixelSize`、`WindowPeekCaptureConfiguration`、`WindowPeekScreen`、`WindowPeekLayout`、`WindowPeekStopReason` 和 `WindowPeekCaptureRequestToken`。`WindowPeekCaptureResult` 不声明 `Sendable`，因为它携带 `CGImage` 且只在 MainActor 的 capture/coordinator 边界使用。该文件只导入 `CoreGraphics`；后续 Task 不得重复定义同义类型，也不得在这里导入 ScreenCaptureKit。

- [ ] **Step 6: 运行聚焦测试并提交**

Run: `swift test --filter SettingsStoreTests && swift test --filter SettingsViewModelTests && swift test --filter AppTextProviderTests && swift test --filter MenuBarControllerTests && swift test --filter PreviewSessionControllerTests && swift test --filter ProbeOrchestratorPreviewTests && swift test --filter SettingsWindowControllerTests`

Expected: 所有设置、observer 和文案测试 PASS，整个 test target 可编译。

```bash
git add Sources/DockHoverPreviewProbe/Settings/DockHoverPreviewSettings.swift \
  Sources/DockHoverPreviewProbe/Settings/SettingsStore.swift \
  Sources/DockHoverPreviewProbe/Shared/AppTextProvider.swift \
  Sources/DockHoverPreviewProbe/Shared/Text/AppTextProvider+DockWindowQuickLook.swift \
  Sources/DockHoverPreviewProbe/Support/PermissionService.swift \
  Sources/DockHoverPreviewProbe/Support/SupportSettingsView.swift \
  Sources/DockHoverPreviewProbe/Settings/SettingsRootView.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsView.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsViewModel.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekModels.swift \
  Tests/DockHoverPreviewProbeTests/SettingsStoreTests.swift \
  Tests/DockHoverPreviewProbeTests/SettingsViewModelTests.swift \
  Tests/DockHoverPreviewProbeTests/AppTextProviderTests.swift \
  Tests/DockHoverPreviewProbeTests/MenuBarControllerTests.swift \
  Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift \
  Tests/DockHoverPreviewProbeTests/ProbeOrchestratorPreviewTests.swift \
  Tests/DockHoverPreviewProbeTests/SettingsWindowControllerTests.swift
git diff --cached --check
git commit -m "feat: add desktop window peek settings"
```

### Task 3: 实现纯函数截图尺寸与屏幕几何

**Files:**
- Create: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekGeometry.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowEnvironmentDescriptor.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ProbeModels.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowQueryService.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ThumbnailService.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewSessionController.swift`
- Create: `Tests/DockHoverPreviewProbeTests/WindowPeekGeometryTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/WindowEnvironmentDescriptorTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/WindowQueryServiceTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/ThumbnailServiceTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/WindowOperationServiceTests.swift`

- [ ] **Step 1: 写双坐标映射、实际像素裁切和像素上限失败测试**

先写以下核心测试；测试数据必须同时给出由 `SCDisplay.frame` 得到的 capture-point frame 和 `NSScreen.frame` AppKit frame，禁止用 `CGDisplayBounds` 或含义不明的 `frame` 代替：

```swift
func testSelectsLargestCaptureIntersectionAndMapsFragmentToAppKit() throws {
    let screens = [
        WindowPeekScreen(
            identifier: 1,
            localizedName: "Main",
            captureFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
            appKitFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
            backingScaleFactor: 2
        ),
        WindowPeekScreen(
            identifier: 2,
            localizedName: "Right",
            captureFrame: CGRect(x: 1200, y: 0, width: 1200, height: 900),
            appKitFrame: CGRect(x: 1200, y: 0, width: 1200, height: 900),
            backingScaleFactor: 1
        )
    ]

    let layout = try XCTUnwrap(WindowPeekGeometry.layout(
        windowCaptureFrame: CGRect(x: 900, y: 100, width: 900, height: 600),
        screens: screens
    ))

    XCTAssertEqual(layout.screen.identifier, 2)
    XCTAssertEqual(layout.dimmingFrame, screens[1].appKitFrame)
    XCTAssertEqual(layout.windowAppKitFrame, CGRect(x: 900, y: 200, width: 900, height: 600))
    XCTAssertEqual(layout.mirrorFrame, CGRect(x: 1200, y: 200, width: 600, height: 600))
    XCTAssertEqual(layout.pointCropRect, CGRect(x: 300, y: 0, width: 600, height: 600))
}

func testPixelCropUsesReturnedImageSizeAndTopLeftImageRows() throws {
    let pixelRect = try XCTUnwrap(WindowPeekGeometry.pixelCropRect(
        pointCropRect: CGRect(x: 300, y: 150, width: 600, height: 300),
        windowCaptureSize: CGSize(width: 900, height: 600),
        imagePixelSize: WindowPeekPixelSize(width: 1200, height: 800)
    ))

    XCTAssertEqual(pixelRect, CGRect(x: 400, y: 200, width: 800, height: 400))
}

func testCroppedImageKeepsTopLeftPixelRowDirection() throws {
    let image = makeTwoBandImage(top: .red, bottom: .blue, width: 4, height: 4)
    let layout = makeLayout(pointCropRect: CGRect(x: 0, y: 0, width: 4, height: 2))

    let cropped = try XCTUnwrap(WindowPeekGeometry.croppedImage(image, layout: layout))

    XCTAssertEqual(pixelColor(atX: 0, y: 0, in: cropped), .red)
    XCTAssertEqual(pixelColor(atX: 0, y: 1, in: cropped), .red)
}

func testPairsSCDisplayPointFrameWithAppKitScreenByDisplayID() {
    let screens = WindowPeekGeometry.makeScreens(
        captureDisplays: [
            WindowPeekCaptureDisplay(identifier: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982)),
            WindowPeekCaptureDisplay(identifier: 2, frame: CGRect(x: -1080, y: 0, width: 1080, height: 1920))
        ],
        appKitDisplays: [
            WindowPeekAppKitDisplay(identifier: 2, localizedName: "Left", frame: CGRect(x: -1080, y: 0, width: 1080, height: 1920), backingScaleFactor: 1),
            WindowPeekAppKitDisplay(identifier: 1, localizedName: "Built-in", frame: CGRect(x: 0, y: 0, width: 1512, height: 982), backingScaleFactor: 2)
        ]
    )

    XCTAssertEqual(screens.map(\.identifier), [1, 2])
    XCTAssertEqual(screens[0].captureFrame.size, CGSize(width: 1512, height: 982))
    XCTAssertEqual(screens[0].backingScaleFactor, 2)
}

func testCaptureSizeNeverExceedsEightMillionPixelsAfterRounding() {
    let size = WindowPeekGeometry.capturePixelSize(
        logicalSize: CGSize(width: 6016, height: 3384),
        backingScaleFactor: 2
    )

    XCTAssertGreaterThan(size.width, 0)
    XCTAssertGreaterThan(size.height, 0)
    XCTAssertLessThanOrEqual(size.width * size.height, 8_000_000)
    XCTAssertEqual(Double(size.width) / Double(size.height), 6016.0 / 3384.0, accuracy: 0.01)
}
```

将同一测试文件加上 `import Foundation`，并将像素 helper 固定为下列实现，避免以未定义的 `PixelColor` 或平台绘制坐标系代替真正的 data-row 断言：

```swift
private enum TestPixelColor: Equatable {
    case red
    case blue
}

private func makeTwoBandImage(
    top: TestPixelColor,
    bottom: TestPixelColor,
    width: Int,
    height: Int
) -> CGImage {
    precondition(height.isMultiple(of: 2))
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0 ..< height {
        let color = y < height / 2 ? top : bottom
        let rgba: (UInt8, UInt8, UInt8, UInt8) = color == .red ? (255, 0, 0, 255) : (0, 0, 255, 255)
        for x in 0 ..< width {
            let offset = (y * width + x) * 4
            bytes[offset] = rgba.0
            bytes[offset + 1] = rgba.1
            bytes[offset + 2] = rgba.2
            bytes[offset + 3] = rgba.3
        }
    }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )!
}

private func pixelColor(atX x: Int, y: Int, in image: CGImage) -> TestPixelColor {
    let providerData = image.dataProvider!.data!
    let bytes = CFDataGetBytePtr(providerData)!
    let offset = y * image.bytesPerRow + x * 4
    return bytes[offset] > bytes[offset + 2] ? .red : .blue
}
```

将上面测试中的 `.red`/`.blue` 改为 `TestPixelColor.red`/`TestPixelColor.blue`。另外覆盖以下独立样例：单显示器；副屏在主屏上方、下方、左侧和右侧；capture/AppKit 任一空间含负坐标；缺失任一 display ID 时不产生 `WindowPeekScreen`；最大交集；无 capture 交集返回 nil；混合 scale；全屏使用 `appKitFrame`；顶部/底部/左侧/右侧 pixel crop；min/max 非整数时 floor/ceil；越界 clamp；8 百万像素降采样后使用真实 image size 而不是 backing scale。

Run: `swift test --filter WindowPeekGeometryTests`

Expected: FAIL because `WindowPeekGeometry` does not exist.

- [ ] **Step 2: 把窗口模型和既有消费者改为明确的 capture-space 命名**

将 `PreviewWindow.frame` 改名为 `captureFrame`，并在 `WindowQueryService` 的排序、日志、AX 匹配、fallback，`ThumbnailService` cache key，三个现有测试 helper 以及所有断言中同步改名。将 `WindowQueryService`、`ThumbnailService`、`ScreenCaptureWindowQueryService` 和 `StaticThumbnailService` 标记为 `@MainActor`，删除 `PreviewWindow`、`ThumbnailSource` 和 query service 上为跨 actor 使用而添加的 `@unchecked Sendable`/`Sendable` 声明；AX、`SCWindow`、`NSRunningApplication`、`NSImage` 只在 MainActor model 中存取。这个 Step 不添加 eligibility stored property。

卡片的 `sourceFrame` 只使用 `captureFrame.size` 决定缩略图 fit/fill。这个 Step 暂时保留现有 screen description 调用；Step 4 在 geometry API 可用后立即替换该调用，Task 3 不在中间状态提交。

Run: `swift build`

Expected: 生产 target 在 capture-space 重命名后编译成功。Step 1 已创建引用尚不存在 `WindowPeekGeometry` 的失败测试，因此此时不得运行任何 `swift test --filter ...` 并声称其他测试可通过；SwiftPM 会编译整个 test target。测试 target 保持预期红色，直到 Step 4 实现 geometry。

- [ ] **Step 3: 提取共享最大交集选择函数**

在 `WindowEnvironmentDescriptor.swift` 增加：

```swift
enum WindowScreenSelection {
    static func largestIntersectionIndex(windowFrame: CGRect, screenFrames: [CGRect]) -> Int? {
        screenFrames.indices
            .map { index in
                let intersection = windowFrame.intersection(screenFrames[index])
                let area = intersection.isNull || intersection.isEmpty
                    ? CGFloat.zero
                    : intersection.width * intersection.height
                return (index, area)
            }
            .filter { $0.1 > 0 }
            .max { lhs, rhs in lhs.1 < rhs.1 }?
            .0
    }
}
```

先新增 `WindowEnvironmentDescriptor.description(forCaptureFrame:screens:textProvider:)` overload，使用 `screens.map(\.captureFrame)` 调用这个函数，再读取同 index 的 `localizedName`；保持现有 screen name 和 unknown fallback 文案不变。旧 overload 暂时保留到 Step 4 完成消费者迁移。`WindowPeekGeometry.layout` 复用同一选择函数，不能复制另一份交集算法。

- [ ] **Step 4: 实现成对屏幕转换、截图尺寸和像素裁切**

实现固定 public-to-target 契约：

```swift
enum WindowPeekGeometry {
    static let maximumPixelArea = 8_000_000

    static func makeScreens(
        captureDisplays: [WindowPeekCaptureDisplay],
        appKitDisplays: [WindowPeekAppKitDisplay]
    ) -> [WindowPeekScreen]
    static func capturePixelSize(logicalSize: CGSize, backingScaleFactor: CGFloat) -> WindowPeekPixelSize
    static func layout(
        windowCaptureFrame: CGRect,
        screens: [WindowPeekScreen]
    ) -> WindowPeekLayout?
    static func appKitRect(for captureRect: CGRect, on screen: WindowPeekScreen) -> CGRect
    static func pixelCropRect(
        pointCropRect: CGRect,
        windowCaptureSize: CGSize,
        imagePixelSize: WindowPeekPixelSize
    ) -> CGRect?
    static func croppedImage(_ image: CGImage, layout: WindowPeekLayout) -> CGImage?
}
```

`WindowPeekCaptureDisplay` 是仅含 `identifier` 和 `frame` 的 Sendable domain struct；生产代码从同一次 `SCShareableContent.displays` 读取 `SCDisplay.displayID`/`SCDisplay.frame` 创建它。`WindowPeekAppKitDisplay` 是仅含 `identifier`、`localizedName`、`frame` 和 `backingScaleFactor` 的 Sendable domain struct；生产代码在 MainActor 从 `NSScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]` 与 `NSScreen.frame` 创建它。`makeScreens` 只能按相同 display ID 配对，缺少任何一侧、空 frame 或重复 ID 都记录并跳过；禁止使用数组位置或 `CGDisplayBounds` 猜配对关系。

`layout` 在 `captureFrame` 中选最大正面积交集；没有任何交集时直接返回 nil。成对 screen-local 转换将 `screen.captureFrame` 双射到同一 screen 的 `appKitFrame`，所以无 capture 交集时 anchor 也不能产生保持原位置语义的 AppKit 交集。选中后按以下唯一公式映射完整窗口和 fragment：

```swift
let x = screen.appKitFrame.minX + captureRect.minX - screen.captureFrame.minX
let y = screen.appKitFrame.maxY - (captureRect.maxY - screen.captureFrame.minY)
```

`windowAppKitFrame` 是完整窗口转换结果，`mirrorFrame` 是它与选中 `appKitFrame` 的交集；空交集返回 nil。再把 mirror fragment 逆映射回 capture space，减去完整窗口的 capture origin 得到 `pointCropRect`。`dimmingFrame` 固定为选中 screen 的完整 `appKitFrame`。

在 `ProbeModels.swift` 创建 `WindowQueryResult`，它保存 `[PreviewWindow]` 和 `[WindowPeekScreen]`，且不声明 `Sendable`，因为 `PreviewWindow` 含 MainActor-only 的 AX/SCK/AppKit 引用。将 query contract 固定为：

```swift
@MainActor
protocol WindowQueryService: AnyObject {
    func query(for app: NSRunningApplication, limit: Int) async -> WindowQueryResult
}

struct WindowQueryResult {
    let windows: [PreviewWindow]
    let screens: [WindowPeekScreen]
}
```

`ScreenCaptureWindowQueryService` 必须从同一次 `SCShareableContent` 的 `windows` 和 `displays` 产生该 result，不能在 hover 时重新用 `NSScreen` 猜 capture frame。Task 3 在 `PreviewSessionController` 新增 `private var currentWindowPeekScreens: [WindowPeekScreen] = []`；query 返回并通过既有 panel generation 验证后立刻写入 `result.screens`，调用新的 capture-space description overload 时也只传这个 snapshot，hide/session replacement 时清空。此时还没有 coordinator，Task 3 不调用 `updateScreens`；Task 7 仅复用这个 property 并在同一已验证位置把它传给 coordinator。迁移完成后删除旧的 AppKit-only descriptor overload。没有可配对 screens 时仍展示现有窗口卡片，但 Task 7 接线后所有目标均按“无 geometry”停止 desktop peek。此后不得把 `PreviewWindow.captureFrame` 直接与 `NSScreen.frame` 求交。

截图尺寸先计算 `ceil(logical * scale)`；面积超限时乘以 `sqrt(8_000_000 / desiredArea)` 并向上取整。若取整后超限，按原始宽高比每次缩小造成比例误差较小的轴，直到面积不超过上限；宽高最小为 1。

`pixelCropRect` 在图像返回后计算独立的 `scaleX`/`scaleY`，分别等于实际 image pixel size 除以完整 capture-point size。x/y min 使用 floor，max 使用 ceil，再夹到 `[0, image.width] x [0, image.height]`；空结果返回 nil。`CGImageCreateWithImageInRect`/`CGImage.cropping(to:)` 的 `(0, 0)` 是图像数据第一行，所以 point Y 与 pixel Y 均向下，不做第二次翻转。`croppedImage` 只把该实际 pixel rect 交给 `image.cropping(to:)`。

- [ ] **Step 5: 运行测试并提交**

Run: `swift test --filter WindowPeekGeometryTests && swift test --filter WindowEnvironmentDescriptorTests && swift test --filter WindowQueryServiceTests && swift test --filter PreviewSessionControllerTests && swift test --filter ThumbnailServiceTests && swift test --filter WindowOperationServiceTests`

Expected: 所有双坐标、实际像素裁切、环境文案和现有 `PreviewWindow` 消费者测试 PASS；整个 test target 可编译。

```bash
git add Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekGeometry.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowEnvironmentDescriptor.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ProbeModels.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowQueryService.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ThumbnailService.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewSessionController.swift \
  Tests/DockHoverPreviewProbeTests/WindowPeekGeometryTests.swift \
  Tests/DockHoverPreviewProbeTests/WindowEnvironmentDescriptorTests.swift \
  Tests/DockHoverPreviewProbeTests/WindowQueryServiceTests.swift \
  Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift \
  Tests/DockHoverPreviewProbeTests/ThumbnailServiceTests.swift \
  Tests/DockHoverPreviewProbeTests/WindowOperationServiceTests.swift
git diff --cached --check
git commit -m "feat: add desktop peek geometry"
```

### Task 4: 实现可判别失败的一次高清截图服务

**Files:**
- Create: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ScreenCaptureKitCaptureBroker.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekCaptureService.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ProbeModels.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowQueryService.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ThumbnailService.swift`
- Create: `Tests/DockHoverPreviewProbeTests/WindowPeekCaptureServiceTests.swift`
- Create: `Tests/DockHoverPreviewProbeTests/ScreenCaptureKitCaptureBrokerTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/WindowQueryServiceTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/ThumbnailServiceTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/WindowOperationServiceTests.swift`

- [ ] **Step 1: 写领域 source、eligibility 和配置编码失败测试**

单元测试在同一文件 private scope 只定义一次不含 ScreenCaptureKit 对象的 fake source/backend，不构造 `SCWindow`。所有 Task 4 测试类标记为 `@MainActor`，以匹配生产 SCK/AX 所有权：

```swift
@MainActor
private final class TestCaptureSource: WindowPeekCaptureSource {
    let windowID: PreviewWindowID
}

func testMissingSourceReturnsUnavailableWithoutCallingBackend() async {
    let backend = RecordingWindowPeekCaptureBackend()
    let service = DefaultWindowPeekCaptureService(
        logger: ProbeLogger(),
        permissionProvider: { true },
        backend: backend
    )

    let token = WindowPeekCaptureRequestToken(sessionEpoch: 1, peekGeneration: 1, windowID: PreviewWindowID(pid: 100, windowID: 7))
    let result = await service.capture(token: token, source: nil, logicalSize: CGSize(width: 800, height: 600), backingScaleFactor: 2)

    guard case .unavailable = result else { return XCTFail("Expected unavailable") }
    let callCount = backend.callCount
    XCTAssertEqual(callCount, 0)
}

func testCaptureConfigurationUsesScaleCursorAndShadowRules() async {
    let backend = RecordingWindowPeekCaptureBackend(result: .success(makeImage(width: 1600, height: 1200)))
    let service = DefaultWindowPeekCaptureService(
        logger: ProbeLogger(),
        permissionProvider: { true },
        backend: backend
    )
    let source = TestCaptureSource(windowID: PreviewWindowID(pid: 100, windowID: 7))
    let token = WindowPeekCaptureRequestToken(sessionEpoch: 1, peekGeneration: 1, windowID: source.windowID)

    let result = await service.capture(
        token: token,
        source: source,
        logicalSize: CGSize(width: 800, height: 600),
        backingScaleFactor: 2
    )

    guard case let .image(image) = result else { return XCTFail("Expected image") }
    XCTAssertEqual(image.width, 1600)
    let configuration = backend.lastConfiguration
    XCTAssertEqual(configuration?.pixelSize, WindowPeekPixelSize(width: 1600, height: 1200))
    XCTAssertEqual(configuration?.showsCursor, false)
    XCTAssertEqual(configuration?.ignoresSingleWindowShadow, true)
}
```

同一测试文件定义下列完整 test seam；不要再次声明 `TestCaptureSource`，也不要引用另一个 test file 的 private helper：

```swift
@MainActor
private final class RecordingWindowPeekCaptureBackend: WindowPeekCaptureBackend {
    private(set) var callCount = 0
    private(set) var lastConfiguration: WindowPeekCaptureConfiguration?
    private let result: Result<CGImage, Error>

    init(result: Result<CGImage, Error> = .failure(WindowPeekCaptureBackendError.unavailable)) {
        self.result = result
    }

    func capture(
        token: WindowPeekCaptureRequestToken,
        source: any WindowPeekCaptureSource,
        configuration: WindowPeekCaptureConfiguration
    ) async throws -> CGImage {
        callCount += 1
        lastConfiguration = configuration
        return try result.get()
    }

    func invalidateQueuedCapture(token: WindowPeekCaptureRequestToken) {}
}

private func makeImage(width: Int = 2, height: Int = 2) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}
```

在 `ScreenCaptureKitCaptureBrokerTests` 以两个 domain operation fake（一个从 `StaticThumbnailService` 路径提交、一个从 `WindowPeekCaptureService` 路径提交）覆盖两个方向：thumbnail A 正在物理 capture 时，desktop-peek A/B/C 只保留 C，thumbnail A 返回后 C 才开始；desktop-peek A 已 physical active 时，随后 thumbnail B/C 均不得在 A 返回前开始，A 返回后 B/C 以 FIFO 依次开始。两个测试都记录每个 operation 的 start/finish 与全局 `physicalInFlight`，并断言最大值始终为 1。另断言已开始的 thumbnail 或 peek 不因 `invalidateQueuedCapture` 被取消；已排队但尚未开始的 desktop request 立即以内部 `.superseded` 完成且不调用 operation。测试不得构造 `SCWindow`，而要通过 broker 注入的 `@MainActor () async throws -> CGImage` operation 增加 `physicalStartCount`。

在 `WindowQueryServiceTests` 另写纯决策测试：只有 `hasCaptureSource == true && axMatched == true` 才 eligible；AX fallback 和未匹配 SCK 候选都同时得到 `desktopPeekCaptureSource == nil` 与 `desktopPeekEligible == false`。另覆盖捕获前权限 false、backend `.unavailable`、异常后权限 false -> `permissionDenied`、异常后权限仍 true -> `failed`、超大窗口使用 Task 3 尺寸上限。

Run: `swift test --filter ScreenCaptureKitCaptureBrokerTests && swift test --filter WindowPeekCaptureServiceTests && swift test --filter WindowQueryServiceTests`

Expected: FAIL because capture source/backend/service and eligibility fields do not exist.

- [ ] **Step 2: 实现领域 source、backend 和 service 边界**

```swift
@MainActor
protocol WindowPeekCaptureSource: AnyObject {
    var windowID: PreviewWindowID { get }
}

@MainActor
protocol WindowPeekCaptureBackend: AnyObject {
    func capture(
        token: WindowPeekCaptureRequestToken,
        source: any WindowPeekCaptureSource,
        configuration: WindowPeekCaptureConfiguration
    ) async throws -> CGImage
    func invalidateQueuedCapture(token: WindowPeekCaptureRequestToken)
}

@MainActor
protocol WindowPeekCaptureService: AnyObject {
    func capture(
        token: WindowPeekCaptureRequestToken,
        source: (any WindowPeekCaptureSource)?,
        logicalSize: CGSize,
        backingScaleFactor: CGFloat
    ) async -> WindowPeekCaptureResult
    func invalidateQueuedCapture(token: WindowPeekCaptureRequestToken)
}

enum WindowPeekCaptureBackendError: Error {
    case unavailable
}

@MainActor
final class DefaultWindowPeekCaptureService: WindowPeekCaptureService {
    init(
        logger: ProbeLogger,
        permissionProvider: @escaping () -> Bool = CGPreflightScreenCaptureAccess,
        backend: any WindowPeekCaptureBackend
    )

    func capture(
        token: WindowPeekCaptureRequestToken,
        source: (any WindowPeekCaptureSource)?,
        logicalSize: CGSize,
        backingScaleFactor: CGFloat
    ) async -> WindowPeekCaptureResult

    func invalidateQueuedCapture(token: WindowPeekCaptureRequestToken)
}
```

`ScreenCaptureKitCaptureBroker` 的对外 API 固定为下列三个方法。两个 operation 仅在 MainActor 上保存、执行和完成，因此不声明 `Sendable`，也不能捕获跨 actor 的 `SCWindow`/AppKit 对象：

```swift
@MainActor
final class ScreenCaptureKitCaptureBroker {
    func captureThumbnail(
        operation: @MainActor @escaping () async throws -> CGImage
    ) async throws -> CGImage

    func captureDesktopPeek(
        token: WindowPeekCaptureRequestToken,
        operation: @MainActor @escaping () async throws -> CGImage
    ) async throws -> CGImage

    func invalidateQueuedDesktopPeek(token: WindowPeekCaptureRequestToken)
}

enum WindowPeekCaptureBrokerError: Error {
    case superseded
}
```

broker 由 `AppDelegate` 强持有，且只构造一个实例后同时注入 `StaticThumbnailService` 和 `ScreenCaptureKitWindowPeekCaptureBackend`。它维护一个 active entry、FIFO thumbnail queue 与唯一 replaceable desktop-peek queue entry；entry 保存 origin、可选 desktop token、operation 和 continuation。broker 空闲时必须先同步写 active entry，才创建 worker；worker 返回后在同一 MainActor 调用栈清 active、优先启动最新 desktop peek、再启动下一个 thumbnail。`invalidateQueuedDesktopPeek(token:)` 只移除尚未 active 的同 token entry，并以 `WindowPeekCaptureBrokerError.superseded` 恢复其 waiter；它绝不取消 active worker。调用 `captureDesktopPeek` 遇到已有 queued desktop entry 时，先以 `.superseded` 恢复旧 entry，再原子替换为新 entry；遇到 active desktop entry 时只替换 pending entry。broker 不暴露 `SCWindow`，但它是唯一能够启动 operation 内 `SCScreenshotManager.captureImage` 的位置。每一次 physical start/finish 记录 `sck.broker.capture.started/finished origin=thumbnail|desktopPeek`、desktop token（仅 desktop）、像素尺寸、结果分类和时长；不得记录图片内容或标题。

生产 composition 使用以下明确构造路径，测试继续注入 `RecordingWindowPeekCaptureBackend`，不创建 broker 或实际 ScreenCaptureKit 对象：

```swift
let broker = ScreenCaptureKitCaptureBroker(logger: logger)
let thumbnailService = StaticThumbnailService(logger: logger, captureBroker: broker)
let captureBackend = ScreenCaptureKitWindowPeekCaptureBackend(logger: logger, captureBroker: broker)
let windowPeekCaptureService = DefaultWindowPeekCaptureService(
    logger: logger,
    backend: captureBackend
)
```

在新的 desktop-peek capture 抽象内，`ScreenCaptureKitWindowPeekCaptureSource` 是唯一持有 `SCWindow` 的 MainActor production source，不得标记 `@unchecked Sendable`；现有 `ThumbnailSource` 同样只在 MainActor 使用。`ScreenCaptureKitWindowPeekCaptureBackend` 先 downcast source，失败则抛 `.unavailable`，成功后创建 `SCContentFilter(desktopIndependentWindow:)` 和 `SCStreamConfiguration`，把领域 configuration 映射为 width/height、`showsCursor = false`、`ignoreShadowsSingleWindow = true`，并把实际 `captureImage` closure 交给 broker。`StaticThumbnailService.captureWithScreenCaptureKit` 必须把其固定缩略图 filter/configuration 交给同一个 broker；它不能再直接调用 `SCScreenshotManager`。其他类型不得直接调用 screenshot manager。

`StaticThumbnailService` 的生产 initializer 固定为 `init(logger: ProbeLogger, captureBroker: ScreenCaptureKitCaptureBroker)`，所以 `AppDelegate` 无法遗漏 broker 注入。保留现有带 `now`、`captureWithScreenCaptureKit`、`captureWithCoreGraphics` override 的 test-only initializer；只要提供 SCK override，它就不持有或创建 broker，现有 `ThumbnailServiceTests` 继续通过该 override 验证 cache/fallback。该 initializer 在 `thumbnailSource.screenCaptureKit` 且 override 为 nil 时必须 `preconditionFailure`，防止未来生产 composition 悄悄绕过 broker。

service 的顺序固定为：nil source -> `.unavailable`；捕获前权限 false -> `.permissionDenied`；按 Task 3 生成纯领域 configuration；以 token 调用 backend；source downcast 失败产生的 backend unavailable -> `.unavailable`；broker `.superseded` 只写 stale 日志并返回 `.unavailable`，不把它记录为用户可见 capture failure；其他 ScreenCaptureKit 异常后复查权限，权限已撤销 -> `.permissionDenied`，权限仍存在 -> `.failed`。`invalidateQueuedCapture(token:)` 只转发 broker 的 queued invalidation。service 不缓存、不做 CoreGraphics fallback、不写文件。单元测试只停在 backend/broker seam 之前，因此不会查询 `SCShareableContent` 或触发 TCC。

- [ ] **Step 3: 将 source 和明确 eligibility 接入 `PreviewWindow` 查询结果**

`PreviewWindow` 删除未被现有生产代码消费的 `scWindow` stored property，并增加：

```swift
let desktopPeekCaptureSource: (any WindowPeekCaptureSource)?
let desktopPeekEligible: Bool
```

`ScreenCaptureWindowQueryService.desktopPeekEligibility(hasCaptureSource:axMatched:)` 是纯函数。`makePreviewWindow` 只有在 AX match 成功时才创建 `ScreenCaptureKitWindowPeekCaptureSource(windowID:window:)`，并让 source/eligibility 同时有效；未匹配 SCK 候选和 `fallbackPreviewWindows` 均传 `nil/false`。现有 `ThumbnailSource.screenCaptureKit` 保持不变，桌面速览资格不得从 thumbnail 是否存在推断。`PreviewWindow`、`ThumbnailSource` 和 source 的所有读取都发生在 MainActor；不得恢复 Sendable conformances 来绕过编译器。

在本 Step 一次性修改 `PreviewSessionControllerTests.swift`、`ThumbnailServiceTests.swift` 和 `WindowOperationServiceTests.swift` 中所有 `PreviewWindow(...)`：删除 `scWindow:`，默认显式传 `desktopPeekCaptureSource: nil, desktopPeekEligible: false`。Coordinator harness 后续使用 `TestCaptureSource/true`。SwiftPM filter 会编译整个 test target，不能把这些 initializer 修复留到 Task 6 或 Task 7。

- [ ] **Step 4: 运行测试并提交**

Run: `swift test --filter ScreenCaptureKitCaptureBrokerTests && swift test --filter WindowPeekCaptureServiceTests && swift test --filter WindowQueryServiceTests && swift test --filter PreviewSessionControllerTests && swift test --filter ThumbnailServiceTests && swift test --filter WindowOperationServiceTests`

Expected: capture 配置/结果分类、query eligibility 和所有既有 `PreviewWindow` helper 测试 PASS；测试不请求真实权限。

```bash
git add Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ScreenCaptureKitCaptureBroker.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekCaptureService.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ProbeModels.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowQueryService.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ThumbnailService.swift \
  Tests/DockHoverPreviewProbeTests/ScreenCaptureKitCaptureBrokerTests.swift \
  Tests/DockHoverPreviewProbeTests/WindowPeekCaptureServiceTests.swift \
  Tests/DockHoverPreviewProbeTests/WindowQueryServiceTests.swift \
  Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift \
  Tests/DockHoverPreviewProbeTests/ThumbnailServiceTests.swift \
  Tests/DockHoverPreviewProbeTests/WindowOperationServiceTests.swift
git diff --cached --check
git commit -m "feat: add desktop peek capture service"
```

### Task 5: 实现鼠标穿透覆盖层和集中层级策略

**Files:**
- Create: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekPanel.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekOverlayController.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelController.swift`
- Create: `Tests/DockHoverPreviewProbeTests/WindowPeekOverlayControllerTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelControllerTests.swift`

- [ ] **Step 1: 写 panel 属性、层级和清理失败测试**

```swift
@MainActor
func testOverlayPanelsAreNonActivatingMouseTransparentAndOrdered() throws {
    let controller = WindowPeekOverlayController(logger: ProbeLogger())
    controller.show(image: makeImage(), layout: makeLayout(), quality: .coarse)

    let inspection = controller.inspection()
    let dimming = try XCTUnwrap(inspection.dimmingPanel)
    let mirror = try XCTUnwrap(inspection.mirrorPanel)

    XCTAssertTrue(dimming.ignoresMouseEvents)
    XCTAssertTrue(mirror.ignoresMouseEvents)
    XCTAssertFalse(dimming.canBecomeKey)
    XCTAssertFalse(dimming.canBecomeMain)
    XCTAssertFalse(mirror.canBecomeKey)
    XCTAssertFalse(mirror.canBecomeMain)
    XCTAssertLessThan(dimming.level.rawValue, mirror.level.rawValue)
    XCTAssertLessThan(mirror.level.rawValue, NSWindow.Level.floating.rawValue)
    XCTAssertLessThan(mirror.level.rawValue, Int(CGWindowLevelForKey(.dockWindow)))
}

@MainActor
func testExistingPreviewPanelUsesSharedLevelPolicy() throws {
    let controller = PreviewPanelController(logger: ProbeLogger())
    controller.show(model: makeModel(), anchor: makeAnchor()) { _ in }

    let panel = try XCTUnwrap(controller.inspection().panel)
    XCTAssertEqual(panel.level, WindowPeekPanelLevels.preview)
    XCTAssertFalse(panel.canBecomeKey)
    XCTAssertFalse(panel.canBecomeMain)
    XCTAssertFalse(panel.ignoresMouseEvents)
}

@MainActor
func testCoarseImageUsesFullWindowViewOffsetAndMirrorPanelClipping() throws {
    let controller = WindowPeekOverlayController(logger: ProbeLogger())
    let layout = makeLayout(
        windowAppKitFrame: CGRect(x: 900, y: 200, width: 900, height: 600),
        mirrorFrame: CGRect(x: 1200, y: 200, width: 600, height: 600)
    )

    controller.show(image: makeImage(), layout: layout, quality: .coarse)

    XCTAssertEqual(
        controller.inspection().imageViewFrame,
        CGRect(x: -300, y: 0, width: 900, height: 600)
    )
    XCTAssertTrue(controller.inspection().mirrorContentClips)
}

@MainActor
func testHighResolutionImageFillsMirrorBoundsAfterPixelCrop() {
    let controller = WindowPeekOverlayController(logger: ProbeLogger())
    let layout = makeLayout(mirrorFrame: CGRect(x: 1200, y: 200, width: 600, height: 600))

    controller.show(image: makeImage(width: 601, height: 599), layout: layout, quality: .highResolution)

    let inspection = controller.inspection()
    XCTAssertEqual(inspection.imageViewFrame, CGRect(origin: .zero, size: layout.mirrorFrame.size))
    XCTAssertEqual(inspection.imageScaling, .scaleAxesIndependently)
    XCTAssertTrue(inspection.mirrorContentClips)
}

@MainActor
func testUpdateOnlyReplacesImageAndHideClearsReferences() throws {
    let controller = WindowPeekOverlayController(logger: ProbeLogger())
    let layout = makeLayout()
    controller.show(image: makeImage(width: 2), layout: layout, quality: .coarse)
    controller.update(image: makeImage(width: 4), quality: .highResolution)

    XCTAssertEqual(controller.inspection().logicalMirrorFrame, layout.mirrorFrame)
    XCTAssertEqual(controller.inspection().imagePixelSize, WindowPeekPixelSize(width: 4, height: 2))

    controller.hide()

    let inspection = controller.inspection()
    XCTAssertNil(inspection.logicalMirrorFrame)
    XCTAssertNil(inspection.imagePixelSize)
    XCTAssertFalse(inspection.dimmingPanel?.isVisible == true)
    XCTAssertFalse(inspection.mirrorPanel?.isVisible == true)
}
```

同一 `WindowPeekOverlayControllerTests.swift` 文件在测试类内定义 `makeImage(width:height:)` 与 `makeLayout(windowAppKitFrame:mirrorFrame:)`。`makeLayout` 使用固定 `WindowPeekScreen(identifier: 1, localizedName: "Test", captureFrame: CGRect(x: 0, y: 0, width: 1800, height: 900), appKitFrame: CGRect(x: 0, y: 0, width: 1800, height: 900), backingScaleFactor: 2)`，默认完整窗口为 `(900, 200, 900, 600)`、mirror 为 `(1200, 200, 600, 600)`、`pointCropRect` 为 `(300, 0, 600, 600)`；不得依赖未定义的全局 `makeLayout` 或 `makeImage`。

Run: `swift test --filter WindowPeekOverlayControllerTests`

Expected: FAIL because the overlay controller does not exist.

- [ ] **Step 2: 实现集中层级策略和不可激活 panel**

```swift
enum WindowPeekPanelLevels {
    static let preview = NSWindow.Level.floating
    static let mirror = NSWindow.Level(rawValue: preview.rawValue - 1)
    static let dimming = NSWindow.Level(rawValue: preview.rawValue - 2)
}

final class WindowPeekNonKeyPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
protocol WindowPeekOverlayDisplaying: AnyObject {
    func show(image: CGImage, layout: WindowPeekLayout, quality: WindowPeekImageQuality)
    func update(image: CGImage, quality: WindowPeekImageQuality)
    func hide()
}

@MainActor
struct WindowPeekOverlayInspection {
    let dimmingPanel: NSPanel?
    let mirrorPanel: NSPanel?
    let logicalMirrorFrame: CGRect?
    let imageViewFrame: CGRect
    let imageScaling: NSImageScaling
    let mirrorContentClips: Bool
    let imagePixelSize: WindowPeekPixelSize?
}

@MainActor
struct PreviewPanelInspection {
    let panel: NSPanel?
}
```

`WindowPeekPanel.swift` 只定义 internal `WindowPeekPanelLevels` 与 `WindowPeekNonKeyPanel`；overlay 和现有 preview panel 都必须使用该类。两个 overlay panel 都使用 `.borderless`、`.nonactivatingPanel`、`.fullSizeContentView`、`ignoresMouseEvents = true`、`hidesOnDeactivate = false`、`isReleasedWhenClosed = false` 和 `[.canJoinAllSpaces, .transient, .fullScreenAuxiliary]`。preview panel 使用相同 style mask、`ignoresMouseEvents = false`，因此仍可 hover、点击和打开右键菜单，但永远不能成为 key/main。dimming content 是纯黑 `alpha = 0.22`；mirror content 开启 clipping、透明背景、1 px 轻边框和 panel shadow。coarse quality 的 image view 使用 `.scaleProportionallyUpOrDown`；high-resolution quality 的图已是目标 fragment，image view 使用 `.scaleAxesIndependently`，以 mirror bounds 为 frame，保证 pixel crop rounding 后仍完整覆盖目标原始 frame。

coarse quality 时 image view frame 固定为完整 `windowAppKitFrame` 相对 `mirrorFrame` 的 offset，让 panel 裁切跨屏片段；不得预裁来源比例未知的 thumbnail，也不得把完整 thumbnail 缩进 `mirrorFrame`。high-resolution quality 接收 Task 3 已按实际像素裁好的 fragment，image view 使用 mirror panel bounds。`show` 调用 `orderFront(nil)`，不调用 `orderFrontRegardless()`；`update` 只切换 image/quality/image-view frame，不改变 panel frame；`hide` 先清 image，再 `orderOut` 并清 logical frame/quality。

`WindowPeekOverlayController.inspection()` 与 `PreviewPanelController.inspection()` 是 internal、只读、返回上述 snapshot 的明确 test seam；生产逻辑不读取它们，测试也不得访问不存在的 `dimmingPanelForTesting`、`panelForTesting` 或其他临时 property。`PreviewPanelController.ensurePanel()` 同时改为创建 `WindowPeekNonKeyPanel` 并使用 `WindowPeekPanelLevels.preview`，不再独立写 `.floating`；它保留现有 `orderFrontRegardless()`，因为 Task 1 原型必须验证的生产 ordering 组合就是 preview panel 的现有 ordering 加两个 overlay 的 `orderFront(nil)`。

overlay 不接入现有 `PanelAnimationControlling`，不修改 alpha、scale 或 offset；show、switch、update 和 hide 都直接完成。

- [ ] **Step 3: 运行测试并提交**

Run: `swift test --filter WindowPeekOverlayControllerTests && swift test --filter PreviewPanelControllerTests`

Expected: 新覆盖层和既有预览 panel 测试均 PASS。

```bash
git add Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekPanel.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekOverlayController.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelController.swift \
  Tests/DockHoverPreviewProbeTests/WindowPeekOverlayControllerTests.swift \
  Tests/DockHoverPreviewProbeTests/PreviewPanelControllerTests.swift
git diff --cached --check
git commit -m "feat: add desktop peek overlays"
```

### Task 6: 实现 coordinator 状态机、逻辑 latest 门控和权限刷新

**Files:**
- Create: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekCoordinator.swift`
- Create: `Tests/DockHoverPreviewProbeTests/WindowPeekCoordinatorTests.swift`

- [ ] **Step 1: 建立可暂停 capture、可控 exit scheduler 和失败测试 harness**

测试 fake 必须分别记录 `show`、`update`、`hide`、logical capture start、capture finish、queued invalidation 和 permission refresh。物理 `SCScreenshotManager` 并发数只在 Task 4 的 broker tests 断言；coordinator tests 只验证 coordinator 的 logical active/pending-latest 状态，不伪造全局物理 gate。`WindowPeekCoordinatorTests.swift` 在测试类后定义以下名称稳定的 seam；所有 harness 都使用真实 coordinator API，不访问 private state，也不调用真实 ScreenCaptureKit、RunLoop、Timer 或 TCC：

```swift
@MainActor
private final class CoordinatorTestCaptureSource: WindowPeekCaptureSource {
    let windowID: PreviewWindowID
}

@MainActor
private final class ManualWindowPeekExitScheduler: WindowPeekExitScheduling {
    private var operations: [@MainActor @Sendable () -> Void] = []

    func schedule(_ operation: @MainActor @escaping @Sendable () -> Void) {
        operations.append(operation)
    }

    func flush() {
        let scheduled = operations
        operations.removeAll()
        scheduled.forEach { $0() }
    }
}

@MainActor
private final class GatedWindowPeekCaptureService: WindowPeekCaptureService {
    private var startedIDs: [CGWindowID] = []
    private var maximumInFlightCount = 0
    private var inFlight: Set<CGWindowID> = []
    private var startWaiters: [CGWindowID: [CheckedContinuation<Void, Never>]] = [:]
    private var resultWaiters: [CGWindowID: CheckedContinuation<WindowPeekCaptureResult, Never>] = [:]

    func capture(
        token: WindowPeekCaptureRequestToken,
        source: (any WindowPeekCaptureSource)?,
        logicalSize: CGSize,
        backingScaleFactor: CGFloat
    ) async -> WindowPeekCaptureResult {
        guard let source else { return .unavailable }
        let id = source.windowID.windowID
        startedIDs.append(id)
        inFlight.insert(id)
        maximumInFlightCount = max(maximumInFlightCount, inFlight.count)
        let waiters = startWaiters.removeValue(forKey: id) ?? []
        waiters.forEach { $0.resume() }
        return await withCheckedContinuation { continuation in
            resultWaiters[id] = continuation
        }
    }

    func invalidateQueuedCapture(token: WindowPeekCaptureRequestToken) {
        invalidatedTokens.append(token)
    }

    func waitUntilStarted(id: CGWindowID) async {
        guard !startedIDs.contains(id) else { return }
        await withCheckedContinuation { continuation in
            startWaiters[id, default: []].append(continuation)
        }
    }

    func finish(id: CGWindowID, result: WindowPeekCaptureResult) {
        inFlight.remove(id)
        resultWaiters.removeValue(forKey: id)?.resume(returning: result)
    }

    func started() -> [CGWindowID] { startedIDs }
    func maximumLogicalInFlight() -> Int { maximumInFlightCount }
    private(set) var invalidatedTokens: [WindowPeekCaptureRequestToken] = []
    func invalidated() -> [WindowPeekCaptureRequestToken] { invalidatedTokens }
}

@MainActor
private final class RecordingWindowPeekOverlay: WindowPeekOverlayDisplaying {
    enum Event: Equatable { case show(WindowPeekImageQuality), update(WindowPeekImageQuality), hide }
    private(set) var events: [Event] = []
    private var highResolutionWaiters: [CheckedContinuation<Void, Never>] = []

    func show(image: CGImage, layout: WindowPeekLayout, quality: WindowPeekImageQuality) {
        events.append(.show(quality))
        resumeHighResolutionWaitersIfNeeded(quality)
    }
    func update(image: CGImage, quality: WindowPeekImageQuality) {
        events.append(.update(quality))
        resumeHighResolutionWaitersIfNeeded(quality)
    }
    func hide() { events.append(.hide) }

    func waitUntilHighResolutionDisplayed() async {
        guard events.contains(where: {
            if case .show(.highResolution) = $0 { return true }
            if case .update(.highResolution) = $0 { return true }
            return false
        }) else {
            return await withCheckedContinuation { highResolutionWaiters.append($0) }
        }
    }

    private func resumeHighResolutionWaitersIfNeeded(_ quality: WindowPeekImageQuality) {
        guard quality == .highResolution else { return }
        let waiters = highResolutionWaiters
        highResolutionWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

@MainActor
private final class CoordinatorSettingsStore: DockWindowQuickLookSettingsStore {
    private var observers: [UUID: @MainActor (DockWindowQuickLookSettingsSnapshot) -> Void] = [:]
    private(set) var dockWindowQuickLookSettingsSnapshot = DockWindowQuickLookSettingsSnapshot(
        settings: .defaults
    )

    @discardableResult
    func addDockWindowQuickLookSettingsObserver(
        _ observer: @MainActor @escaping (DockWindowQuickLookSettingsSnapshot) -> Void
    ) -> UUID {
        let token = UUID()
        observers[token] = observer
        return token
    }

    func removeObserver(_ token: UUID) {
        observers.removeValue(forKey: token)
    }

    func updateDockWindowQuickLookSettings(
        transform: (inout DockWindowQuickLookSettingsSnapshot) -> Void
    ) {
        transform(&dockWindowQuickLookSettingsSnapshot)
        let current = dockWindowQuickLookSettingsSnapshot
        observers.values.forEach { $0(current) }
    }
}

@MainActor
private final class CoordinatorPermissionService: PermissionService {
    private(set) var currentState: PermissionState

    init(screenRecordingGranted: Bool) {
        currentState = PermissionState(accessibilityGranted: true, screenRecordingGranted: screenRecordingGranted)
    }

    func refresh() -> PermissionState { currentState }
    func setScreenRecordingGranted(_ granted: Bool) {
        currentState = PermissionState(accessibilityGranted: true, screenRecordingGranted: granted)
    }
    func requestAccessibilityPrompt() {}
    func openAccessibilitySettings() {}
    func openScreenRecordingSettings() {}
}

@MainActor
private final class ManualWindowPeekPermissionRefreshScheduler: WindowPeekPermissionRefreshScheduling {
    private var handler: (@MainActor () -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
        XCTAssertEqual(interval, WindowPeekCoordinator.permissionRefreshInterval)
        self.handler = handler
        startCount += 1
    }

    func stop() {
        handler = nil
        stopCount += 1
    }

    func fire() { handler?() }
}

@MainActor
private final class WindowPeekCoordinatorHarness {
    let capture = GatedWindowPeekCaptureService()
    let overlay = RecordingWindowPeekOverlay()
    let exitScheduler = ManualWindowPeekExitScheduler()
    let settingsStore = CoordinatorSettingsStore()
    let permissionService = CoordinatorPermissionService(screenRecordingGranted: true)
    let permissionRefreshScheduler = ManualWindowPeekPermissionRefreshScheduler()
    let screen = WindowPeekScreen(
        identifier: 1,
        localizedName: "Test",
        captureFrame: CGRect(x: 0, y: 0, width: 1600, height: 900),
        appKitFrame: CGRect(x: 0, y: 0, width: 1600, height: 900),
        backingScaleFactor: 2
    )
    let coordinator: WindowPeekCoordinator

    init() {
        coordinator = WindowPeekCoordinator(
            captureService: capture,
            overlay: overlay,
            settingsStore: settingsStore,
            permissionService: permissionService,
            logger: ProbeLogger(),
            exitScheduler: exitScheduler,
            permissionRefreshScheduler: permissionRefreshScheduler,
            onCurrentTargetChanged: { _ in }
        )
        coordinator.beginSession(epoch: 1)
        coordinator.updateScreens([screen], sessionEpoch: 1)
    }

    func makeEligibleWindow(id rawID: CGWindowID) -> PreviewWindow {
        let id = PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: rawID)
        return PreviewWindow(
            id: id,
            cgWindowID: rawID,
            app: .current,
            title: "Window \(rawID)",
            captureFrame: CGRect(x: 0, y: 0, width: 800, height: 600),
            axElement: nil,
            appIcon: NSImage(size: NSSize(width: 32, height: 32)),
            thumbnailSource: nil,
            desktopPeekCaptureSource: CoordinatorTestCaptureSource(windowID: id),
            desktopPeekEligible: true
        )
    }
}

private func makeImage(width: Int = 2, height: Int = 2) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}
```

上述 harness 固定以同文件的 settings、permission、capture、overlay、scheduler 和单屏 geometry 构造真实 coordinator，并在 initializer 中调用 `coordinator.beginSession(epoch: 1)`；不得复用另一个测试文件的 private `FakeSettingsStore` 或 `FakePermissionService`。

核心测试先覆盖：

```swift
@MainActor
func testEnterShowsCoarseBeforeStartingHighResolutionCapture() async {
    let harness = WindowPeekCoordinatorHarness()
    let window = harness.makeEligibleWindow(id: 1)
    let coarse = makeImage(width: 2, height: 2)

    harness.coordinator.hoverEntered(
        windowID: window.id,
        window: window,
        coarseImage: coarse,
        sessionEpoch: 1,
        sequence: 1
    )

    XCTAssertEqual(harness.overlay.events, [.show(.coarse)])
    await harness.capture.waitUntilStarted(id: 1)
    let startedIDs = harness.capture.started()
    XCTAssertEqual(startedIDs, [1])
}

@MainActor
func testSwitchDropsStaleResultAndOnlyCapturesLatestPendingTarget() async {
    let harness = WindowPeekCoordinatorHarness()
    let a = harness.makeEligibleWindow(id: 1)
    let b = harness.makeEligibleWindow(id: 2)
    let c = harness.makeEligibleWindow(id: 3)

    harness.coordinator.hoverEntered(windowID: a.id, window: a, coarseImage: makeImage(), sessionEpoch: 1, sequence: 1)
    await harness.capture.waitUntilStarted(id: 1)
    harness.coordinator.hoverEntered(windowID: b.id, window: b, coarseImage: makeImage(), sessionEpoch: 1, sequence: 2)
    harness.coordinator.hoverEntered(windowID: c.id, window: c, coarseImage: makeImage(), sessionEpoch: 1, sequence: 3)
    harness.capture.finish(id: 1, result: .image(makeImage(width: 10, height: 10)))
    await harness.capture.waitUntilStarted(id: 3)

    let startedIDs = harness.capture.started()
    let maximumLogicalInFlight = harness.capture.maximumLogicalInFlight()
    XCTAssertEqual(startedIDs, [1, 3])
    XCTAssertEqual(maximumLogicalInFlight, 1)
    XCTAssertTrue(harness.capture.invalidated().contains(
        WindowPeekCaptureRequestToken(sessionEpoch: 1, peekGeneration: 1, windowID: a.id)
    ))
    XCTAssertFalse(harness.overlay.events.contains(.update(.highResolution)))
}
```

第一个测试不能在同步 `hoverEntered` 后立即假设 capture worker 已开始；只先断言 coarse show，再通过 `waitUntilStarted` 确定性等待 capture fake。A exit+B enter 测试使用 `ManualWindowPeekExitScheduler.flush()`，不等待真实 RunLoop。

还必须写：初始 `screenRecordingGranted == false` 的 enter 不显示 coarse、不启动 capture 或 permission scheduler；同 target 的 sequence 1 enter 后 sequence 2 repeat enter 仍接受第一次 request 的高清结果且 permission scheduler 不重复 start；旧 sequence enter/exit 忽略；`beginSession(epoch: 2)` 后 sequence 1 enter 可以接受，而 epoch 1 的 sequence 99 enter/exit、capture completion 和延迟 exit flush 均不得影响 epoch 2；A exit+B enter 在 `ManualWindowPeekExitScheduler.flush()` 前无中间 hide；eligible A -> ineligible/missing/no-layout B 先使 A generation 失效、请求 broker 取消尚未物理开始的 A、清 pending 并 hide；新目标无粗略图立即 hide；高清后忽略晚到粗略图；failed 保留粗略图；两阶段无图保持隐藏；capture 返回 `.permissionDenied` 后 refresh 失败即停止；settings 关闭；session/Space/screen/app 终止停止且 scheduler stop 后 `fire()` 无副作用；hide 清理图片引用和 current target callback。

再加入下列权限撤销回归测试，覆盖高清图已经显示后的生产事件路径，而非只测 capture 返回值：

```swift
@MainActor
func testInitialMissingScreenRecordingDoesNotShowOrCapture() {
    let harness = WindowPeekCoordinatorHarness()
    let window = harness.makeEligibleWindow(id: 1)
    harness.permissionService.setScreenRecordingGranted(false)

    harness.coordinator.hoverEntered(windowID: window.id, window: window, coarseImage: makeImage(), sessionEpoch: 1, sequence: 1)

    XCTAssertFalse(harness.overlay.events.contains(.show(.coarse)))
    XCTAssertFalse(harness.overlay.events.contains(.show(.highResolution)))
    XCTAssertFalse(harness.overlay.events.contains(.update(.highResolution)))
    XCTAssertEqual(harness.capture.started(), [])
    XCTAssertEqual(harness.permissionRefreshScheduler.startCount, 0)
}

@MainActor
func testPermissionRefreshRevocationHidesAlreadyDisplayedHighResolutionImage() async {
    let harness = WindowPeekCoordinatorHarness()
    let window = harness.makeEligibleWindow(id: 1)
    harness.coordinator.hoverEntered(windowID: window.id, window: window, coarseImage: makeImage(), sessionEpoch: 1, sequence: 1)
    await harness.capture.waitUntilStarted(id: 1)
    harness.capture.finish(id: 1, result: .image(makeImage(width: 800, height: 600)))
    await harness.overlay.waitUntilHighResolutionDisplayed()
    XCTAssertTrue(harness.overlay.events.contains(.update(.highResolution)))

    harness.permissionService.setScreenRecordingGranted(false)
    harness.permissionRefreshScheduler.fire()

    XCTAssertEqual(harness.overlay.events.last, .hide)
    XCTAssertGreaterThanOrEqual(harness.permissionRefreshScheduler.stopCount, 1)
}
```

Run: `swift test --filter WindowPeekCoordinatorTests`

Expected: FAIL because the coordinator does not exist.

- [ ] **Step 2: 实现 coordinator 接口和同步进入路径**

```swift
@MainActor
protocol WindowPeekCoordinating: AnyObject {
    func beginSession(epoch: UInt64)
    func updateScreens(_ screens: [WindowPeekScreen], sessionEpoch: UInt64)
    func hoverEntered(
        windowID: PreviewWindowID,
        window: PreviewWindow?,
        coarseImage: CGImage?,
        sessionEpoch: UInt64,
        sequence: UInt64
    )
    func hoverExited(windowID: PreviewWindowID, sessionEpoch: UInt64, sequence: UInt64)
    func coarseImageDidBecomeAvailable(
        _ image: CGImage?,
        for windowID: PreviewWindowID,
        sessionEpoch: UInt64
    )
    func targetWindowDestroyed(_ windowID: PreviewWindowID)
    func targetApplicationTerminated(pid: pid_t)
    func stop(reason: WindowPeekStopReason)
}

@MainActor
final class WindowPeekCoordinator: WindowPeekCoordinating {
    init(
        captureService: WindowPeekCaptureService,
        overlay: WindowPeekOverlayDisplaying,
        settingsStore: DockWindowQuickLookSettingsStore,
        permissionService: PermissionService,
        logger: ProbeLogger
    )

    func startObservingSettings()
    func stopObservingSettings()
    func beginSession(epoch: UInt64)
    func updateScreens(_ screens: [WindowPeekScreen], sessionEpoch: UInt64)
    func hoverEntered(
        windowID: PreviewWindowID,
        window: PreviewWindow?,
        coarseImage: CGImage?,
        sessionEpoch: UInt64,
        sequence: UInt64
    )
    func hoverExited(windowID: PreviewWindowID, sessionEpoch: UInt64, sequence: UInt64)
    func coarseImageDidBecomeAvailable(
        _ image: CGImage?,
        for windowID: PreviewWindowID,
        sessionEpoch: UInt64
    )
    func targetWindowDestroyed(_ windowID: PreviewWindowID)
    func targetApplicationTerminated(pid: pid_t)
    func stop(reason: WindowPeekStopReason)
}
```

在 coordinator 文件中同时定义 permission refresh seam：

```swift
@MainActor
protocol WindowPeekPermissionRefreshScheduling: AnyObject {
    func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor
final class MainRunLoopWindowPeekPermissionRefreshScheduler: WindowPeekPermissionRefreshScheduling {
    private var timer: Timer?

    func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            precondition(Thread.isMainThread)
            MainActor.assumeIsolated { handler() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
```

initializer 另外接收 `exitScheduler: any WindowPeekExitScheduling = MainRunLoopWindowPeekExitScheduler()`、`permissionRefreshScheduler: any WindowPeekPermissionRefreshScheduling = MainRunLoopWindowPeekPermissionRefreshScheduler()` 和 `onCurrentTargetChanged: @MainActor (PreviewWindow?) -> Void`。定义 `static let permissionRefreshInterval: TimeInterval = 1`，唯一用来启动 scheduler，避免散落的 magic number；scheduler 只在首次接受 eligible target 后启动，stop、session replacement、ineligible target 和 deinit 均停止。其 handler 在 MainActor 同步调用 `permissionService.refresh()`；若 `screenRecordingGranted == false`，立即 `stop(reason: .permissionDenied)`，因此不会依赖另一张 screenshot 的异常来观察撤权。后者供 Task 7 的 AX destroyed observer 订阅当前目标；coordinator 每次接受新目标或 stop 都同步调用。`beginSession(epoch:)` 只接受比已见最大 epoch 更大的值；它先使旧 target/pending latest 逻辑失效，对旧 logical active token 调用 queued invalidation（broker 保留已 physical active 调用），再写入新 epoch、清 `currentScreens` 并把该 epoch 的 `lastHoverSequence` 归零。重复或倒退 epoch 只记录 stale，不能复活旧状态。

`updateScreens(_:sessionEpoch:)` 只接受 current epoch；旧 epoch 的结果记录 stale 并丢弃。它复制本次 `WindowQueryResult.screens` 到 coordinator 的 MainActor `currentScreens`，绝不重新读取 `NSScreen` 或 `CGDisplayBounds`。`hoverEntered` 只用该数组调用 `WindowPeekGeometry.layout(windowCaptureFrame:screens:)`；数组为空或 layout 为 nil 都是 target 无 geometry，必须按普通无效目标清掉旧 overlay。

`hoverEntered` 同步执行顺序固定为：epoch 不是当前 epoch 直接忽略；当前 epoch 内旧 sequence 直接忽略；新 sequence 先写入 `lastHoverSequence`；同一个仍有效 target 只清 pending exit 并返回；其他 target 先递增 `peekGeneration`、使旧 target/pending latest 失效，再检查两个设置、`permissionService.refresh().screenRecordingGranted`、可选 window、`desktopPeekEligible`、`desktopPeekCaptureSource` 和 layout。任一检查失败都必须停止 permission refresh、清 target、回调 nil 并 `overlay.hide()`，不能在旧目标失效前 `guard return`；权限失败使用 `.permissionDenied` 日志/stop reason。有效 target 先启动或保持唯一 permission refresh scheduler；有 coarse 时同步 `overlay.show` 并记录 `.coarse`，随后才安排高清；没有 coarse 时先隐藏旧 overlay。由此生成的 capture request 固定保存 `WindowPeekCaptureRequestToken(sessionEpoch: currentEpoch, peekGeneration: currentPeekGeneration, windowID: windowID)`；后续 input sequence 绝不修改该 token。

- [ ] **Step 3: 实现可测试的 run-loop exit 合并**

在 coordinator 文件定义：

```swift
@MainActor
protocol WindowPeekExitScheduling: AnyObject {
    func schedule(_ operation: @MainActor @escaping @Sendable () -> Void)
}

@MainActor
final class MainRunLoopWindowPeekExitScheduler: WindowPeekExitScheduling {
    func schedule(_ operation: @MainActor @escaping @Sendable () -> Void) {
        RunLoop.main.perform {
            MainActor.assumeIsolated { operation() }
        }
    }
}
```

coordinator 用 `exitFlushScheduled` 去重 scheduling。`hoverExited` 只接受当前 epoch、该 epoch 最新 sequence 且 id 等于当前 target 的事件，将 `(epoch, id, sequence, peekGeneration)` 存为 `pendingExit` 并 schedule 一次；较新 enter 同步清 pending exit。flush 再次检查四个字段后调用 `stop(.hoverExited)`。测试 scheduler 只排队 closure，测试显式 `flush()`；不得在测试中直接调用 `RunLoop.main.perform`，生产 adapter 也不得用额外 `Task` 恢复 MainActor。

- [ ] **Step 4: 实现逻辑 latest capture slot，并把物理 single-flight 留给 broker**

coordinator 保存：

```swift
private enum CaptureSlot {
    case idle
    case capturing(active: CaptureRequest, pendingLatest: CaptureRequest?)
}

private var activeSessionEpoch: UInt64?
private var greatestSessionEpoch: UInt64 = 0
private var peekGeneration: UInt64 = 0
private var lastHoverSequence: UInt64 = 0
private var currentTarget: Target?
private var currentQuality: WindowPeekImageQuality?
private var pendingExit: (epoch: UInt64, id: PreviewWindowID, sequence: UInt64, peekGeneration: UInt64)?
private var exitFlushScheduled = false
private var currentScreens: [WindowPeekScreen] = []
private var captureSlot: CaptureSlot = .idle
```

`CaptureSlot` 只表示 coordinator 已提交或即将提交给 service 的**逻辑** request；它不代表 request 已进入 `SCScreenshotManager.captureImage`。全 app 的物理 single-flight 只由 Task 4 broker 保证。`CaptureRequest` 至少保存 `token: WindowPeekCaptureRequestToken`、领域 capture source、完整窗口 logical size、选中屏幕 backing scale 和 layout；它不保存 `CGImage`，也不从 actor-isolated `PreviewWindow` 读取可变状态。启动请求的同步方法必须先把 `.idle` 改成 `.capturing(request, nil)`，然后才创建继承 MainActor isolation 的 worker：

```swift
private func launchCaptureWorker(for request: CaptureRequest) {
    guard case .idle = captureSlot else {
        preconditionFailure("Capture slot must be idle before launching a worker")
    }
    captureSlot = .capturing(active: request, pendingLatest: nil)
    Task { @MainActor [weak self, captureService] in
        let result = await captureService.capture(
            token: request.token,
            source: request.source,
            logicalSize: request.logicalSize,
            backingScaleFactor: request.backingScaleFactor
        )
        guard let self else { return }
        self.captureDidFinish(request: request, result: result)
    }
}
```

已有 active 时，新 target 只替换 `.capturing(active, pendingLatest: newest)`；不为中间 target排队。每当 active request 因新 target、无资格/无 geometry、session replacement 或 `stop` 变成 stale，都必须立即调用 `captureService.invalidateQueuedCapture(token: active.token)`。这只会移除 broker 中尚未 physical active 的 entry；broker 对已经实际调用 public SCK API 的 entry 无操作。`stop` 不把 logical active 伪装成 idle，只把 pending 清成 nil，并且从不保存或调用 worker task 的 `cancel()`。

worker 的 async 调用真实返回后进入一个 MainActor completion 方法。该方法验证返回 request 就是 logical active，取出 pending，并在同一个同步调用栈内直接把 slot 设为 `.idle`，或先重验 pending token 仍对应当前 `(sessionEpoch, peekGeneration, windowID)` 后设为 `.capturing(pending, nil)`；只有占好新 logical slot 才创建下一 worker。这个状态转移中不能出现 `await` 或 executor hop。`captureDidFinish` 显示 `.image` 前也只比较 request token 与 current target token，绝不比较 `lastHoverSequence`。coordinator tests 必须断言 logical `startedIDs == [A, C]`、B 未启动、`maximumLogicalInFlightCount == 1`，以及 stop 后 A 返回不会启动已清除的 pending；Task 4 broker tests 单独断言真实 physical capture 最大值为 1。

- [ ] **Step 5: 实现实际像素裁切、图片升级、失败降级和日志断言**

- `.image`: 调用 Task 3 的 `WindowPeekGeometry.croppedImage(_:layout:)`，它基于返回的实际 `CGImage.width/height` 计算 pixel rect；仅在 request token 与当前 `(sessionEpoch, peekGeneration, windowID)` 相等时，未显示则 `show(.highResolution)`，已显示 coarse 则 `update(.highResolution)`。同 target 的更大 input sequence 不是 stale 条件。
- `.unavailable` 或 `.failed`: coarse 已显示则保持，否则保持隐藏。
- `.permissionDenied`: 同步调用 `permissionService.refresh()`；确认 screen recording 仍缺失时 `stop(.permissionDenied)`，否则按普通 failed 处理。该分支和 scheduler refresh 共用同一个 `handlePermissionRefresh()`，避免一条路径忘记 stop timer。
- `coarseImageDidBecomeAvailable`: 仅 event epoch 等于当前 epoch、id 等于当前 target 且 currentQuality 不是 `.highResolution` 时显示/更新；nil 不改变显示状态。
- `stop`: 先停止 permission refresh scheduler；peek generation 加一、清 target/quality/pending exit、对 active token 请求 queued invalidation、清 capture slot 的 pendingLatest 但保留 logical active、回调 nil、overlay hide，并清 coordinator 持有的所有 `CGImage` 引用；在飞调用返回后只记录 stale。stop 不重置 `greatestSessionEpoch`，只有 `beginSession` 为新的 epoch 重置 input sequence。
- `targetWindowDestroyed` 和 `targetApplicationTerminated` 先匹配 current target 的 ID/PID；迟到或无关事件忽略，匹配时分别 stop `.targetWindowDestroyed` / `.applicationTerminated`。

测试 logger 精确断言 `peek.show`、`peek.capture.started`、`peek.capture.success`、`peek.capture.failed`、`peek.capture.stale`、`peek.update` 和每种 `peek.hide reason`；capture 日志必须包含 session epoch、peek generation 和 window ID，日志只含 screen ID、结果分类、像素尺寸和时长，不新增窗口标题或图片内容。

- [ ] **Step 6: 运行 coordinator 测试并提交**

Run: `swift test --filter WindowPeekCoordinatorTests`

Expected: 全部状态机、乱序、logical latest 门控和权限撤销刷新测试 PASS；全局物理 single-flight 的证明只来自 Task 4 broker tests。

```bash
git add Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekCoordinator.swift \
  Tests/DockHoverPreviewProbeTests/WindowPeekCoordinatorTests.swift
git diff --cached --check
git commit -m "feat: coordinate desktop window peek"
```

### Task 7: 接入 hover、会话和系统生命周期

**Files:**
- Create: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekLifecycleObserver.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelModels.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelView.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelController.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewSessionController.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ProbeOrchestrator.swift`
- Modify: `Sources/DockHoverPreviewProbe/App/AppDelegate.swift`
- Create: `Tests/DockHoverPreviewProbeTests/WindowPeekLifecycleObserverTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelViewRenderingTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelControllerTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/ProbeOrchestratorPreviewTests.swift`

- [ ] **Step 1: 写 panel intent 路由和同步顺序失败测试**

测试必须直接调用已渲染 view/bridge 的 intent callback，不依赖鼠标自动化：

```swift
@MainActor
func testPanelControllerAssignsMonotonicHoverSequences() throws {
    let controller = PreviewPanelController(logger: ProbeLogger())
    var actions: [PreviewPanelAction] = []
    let first = PreviewWindowID(pid: 100, windowID: 1)
    let second = PreviewWindowID(pid: 100, windowID: 2)
    controller.show(model: makeModel(windowIDs: [1, 2]), anchor: makeAnchor(), sessionEpoch: 41) {
        actions.append($0)
    }

    controller.routeHoverIntent(windowID: first, isInside: true)
    controller.routeHoverIntent(windowID: first, isInside: false)
    controller.routeHoverIntent(windowID: second, isInside: true)

    XCTAssertEqual(actions, [
        .hoverEntered(first, sessionEpoch: 41, sequence: 1),
        .hoverExited(first, sessionEpoch: 41, sequence: 2),
        .hoverEntered(second, sessionEpoch: 41, sequence: 3)
    ])
}

@MainActor
func testOldHoverIntentRelayCannotRouteIntoReplacementSession() throws {
    let controller = PreviewPanelController(logger: ProbeLogger())
    let id = PreviewWindowID(pid: 100, windowID: 1)
    var actions: [PreviewPanelAction] = []
    controller.show(model: makeModel(windowIDs: [1]), anchor: makeAnchor(), sessionEpoch: 41) {
        actions.append($0)
    }
    let oldRelay = PreviewCardHoverIntentRelay(windowID: id, sessionEpoch: 41, router: controller)

    controller.show(model: makeModel(windowIDs: [1]), anchor: makeAnchor(), sessionEpoch: 42) {
        actions.append($0)
    }
    oldRelay.emit(isInside: true)
    let currentRelay = PreviewCardHoverIntentRelay(windowID: id, sessionEpoch: 42, router: controller)
    currentRelay.emit(isInside: true)
    currentRelay.emit(isInside: false)

    XCTAssertEqual(actions, [
        .hoverEntered(id, sessionEpoch: 42, sequence: 1),
        .hoverExited(id, sessionEpoch: 42, sequence: 2)
    ])
}

func testContextMenuWillOpenIsSentBeforeMenuBegan() {
    let id = PreviewWindowID(pid: 100, windowID: 1)
    var actions: [PreviewPanelAction] = []
    PreviewCardContextMenuEventOrder.emitBeforeMenuTracking(
        for: id,
        onAction: { actions.append($0) }
    )
    XCTAssertEqual(actions, [.contextMenuWillOpen(id), .contextMenuBegan(id)])
}
```

`PreviewCardContextMenuEventOrder` 定义在 `PreviewPanelView.swift`，完整签名固定为：

```swift
enum PreviewCardContextMenuEventOrder {
    static func emitBeforeMenuTracking(
        for windowID: PreviewWindowID,
        onAction: (PreviewPanelAction) -> Void
    ) {
        onAction(.contextMenuWillOpen(windowID))
        onAction(.contextMenuBegan(windowID))
    }
}
```

Run: `swift test --filter PreviewPanelControllerTests && swift test --filter PreviewPanelViewRenderingTests`

Expected: FAIL because hover routing and `contextMenuWillOpen` are not wired.

- [ ] **Step 2: 实现同步 panel 事件路由**

`PreviewPanelModels.swift` 中的 action 契约固定为：

```swift
enum PreviewPanelAction: Equatable, Sendable {
    case primarySelect(PreviewWindowID)
    case windowOperation(PreviewWindowID, PreviewWindowOperation)
    case contextMenuWillOpen(PreviewWindowID)
    case contextMenuBegan(PreviewWindowID)
    case contextMenuEnded(PreviewWindowID)
    case hoverEntered(PreviewWindowID, sessionEpoch: UInt64, sequence: UInt64)
    case hoverExited(PreviewWindowID, sessionEpoch: UInt64, sequence: UInt64)
}
```

将 `PreviewPanelDisplaying.show` 固定改为 `show(model:anchor:sessionEpoch:onAction:)`，并把 `onRequestHide` 的 closure 类型改为 `((String, UInt64) -> Void)?`。所有 fake display 和既有 controller tests 在 Task 7 同一次修改中显式传入 epoch，不能依赖 default argument。hover 的唯一稳定契约定义在 `PreviewPanelView.swift`：

```swift
@MainActor
protocol PreviewCardHoverIntentRouting: AnyObject {
    func routeHoverIntent(
        windowID: PreviewWindowID,
        isInside: Bool,
        sessionEpoch: UInt64
    )
}

@MainActor
final class PreviewCardHoverIntentRelay {
    private let windowID: PreviewWindowID
    private let sessionEpoch: UInt64
    private weak var router: (any PreviewCardHoverIntentRouting)?

    init(
        windowID: PreviewWindowID,
        sessionEpoch: UInt64,
        router: any PreviewCardHoverIntentRouting
    ) {
        self.windowID = windowID
        self.sessionEpoch = sessionEpoch
        self.router = router
    }

    func emit(isInside: Bool) {
        router?.routeHoverIntent(windowID: windowID, isInside: isInside, sessionEpoch: sessionEpoch)
    }
}
```

`PreviewPanelController` conform `PreviewCardHoverIntentRouting`，并只在 `sessionEpoch == currentSessionEpoch` 时产生 action；失配 epoch 直接记录 stale，绝不借旧 relay 更新 sequence。controller 在 current epoch 内维护 sequence，`show` 写入新 epoch 并将 sequence 归零，`update` 不归零。Task 1 的能力结论只选择以下一个生产 emitter，不能同时保留两条会重复发事件的路径：

```swift
// Task 1 结论为 .onHover 稳定时，在 PreviewCardView body 使用：
.onHover { isInside in relay.emit(isInside: isInside) }

// Task 1 结论要求 AppKit tracking 时，改为同文件的 NSViewRepresentable：
PreviewCardTrackingAreaBridge(relay: relay)
```

`PreviewCardTrackingAreaBridge` 的内部 `NSView` 只持有 relay；`updateNSView` 更新 relay，`updateTrackingAreas()` 移除旧 `NSTrackingArea` 后以 `.mouseEnteredAndExited + .activeAlways + .inVisibleRect` 添加一个新 tracking area，`mouseEntered`/`mouseExited` 各只调用一次 `relay.emit(isInside:)`。不能使用 `.activeInKeyWindow`，因为 preview panel 明确不得成为 key window。SwiftUI path 不能同时渲染该 bridge。右键桥接固定顺序：

```swift
PreviewCardContextMenuEventOrder.emitBeforeMenuTracking(for: card.id, onAction: onAction)
NSMenu.popUpContextMenu(makeMenu(), with: event, for: self)
onAction(.contextMenuEnded(card.id))
```

`PreviewPanelController.show` 交给 session 的 action closure必须在当前 MainActor 调用栈直接执行，不包装 `Task`。primary select、window operation、context menu 和 hover 都沿同一路由。`PreviewPanelEventMonitorOwner` 也必须用 `precondition(Thread.isMainThread)` 加 `MainActor.assumeIsolated` 在 local/global Esc callback 同步调用 controller 的 `requestHideForCurrentSession(reason:)`；不得保留当前源码中的 `Task { @MainActor in ... }`。该方法读取 current panel epoch 并调用 `onRequestHide?(reason, epoch)`。

- [ ] **Step 3: 写 session 调用顺序和取消矩阵失败测试**

新增 recording coordinator 后断言：

```swift
func testPrimarySelectionStopsPeekBeforeActivation() async {
    let window = makeWindow(id: 1)
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
    harness.eventLog.removeAll()

    harness.display.actionHandler?(.primarySelect(window.id))

    XCTAssertEqual(Array(harness.eventLog.events.prefix(2)), [.peekStopped(.primarySelection), .activated(window.id)])
}

func testContextMenuWillOpenStopsPeekBeforeMenuTracking() async {
    let window = makeWindow(id: 1)
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
    harness.eventLog.removeAll()

    harness.display.actionHandler?(.contextMenuWillOpen(window.id))

    XCTAssertEqual(harness.eventLog.events, [.peekStopped(.contextMenu)])
}
```

在 `PreviewSessionControllerTests.swift` 的既有 `PreviewSessionHarness` 中增加同文件 private 的 `SessionEventLog` 和 `RecordingWindowPeekCoordinator`，不得引用不存在的 `orderedEvents`、`makeWindowID` 或跨文件 private fake。其契约固定为：

```swift
@MainActor
private enum SessionEvent: Equatable {
    case beganSession(UInt64)
    case screensUpdated(UInt64, Int)
    case peekStopped(WindowPeekStopReason)
    case hoverEntered(PreviewWindowID, UInt64, UInt64)
    case hoverExited(PreviewWindowID, UInt64, UInt64)
    case coarseAvailable(PreviewWindowID, UInt64)
    case activated(PreviewWindowID)
}

@MainActor
private final class SessionEventLog {
    private(set) var events: [SessionEvent] = []
    func append(_ event: SessionEvent) { events.append(event) }
    func removeAll() { events.removeAll() }
}

@MainActor
private final class RecordingWindowPeekCoordinator: WindowPeekCoordinating {
    let eventLog: SessionEventLog
    init(eventLog: SessionEventLog) { self.eventLog = eventLog }
    func beginSession(epoch: UInt64) { eventLog.append(.beganSession(epoch)) }
    func updateScreens(_ screens: [WindowPeekScreen], sessionEpoch: UInt64) {
        eventLog.append(.screensUpdated(sessionEpoch, screens.count))
    }
    func hoverEntered(windowID: PreviewWindowID, window: PreviewWindow?, coarseImage: CGImage?, sessionEpoch: UInt64, sequence: UInt64) { eventLog.append(.hoverEntered(windowID, sessionEpoch, sequence)) }
    func hoverExited(windowID: PreviewWindowID, sessionEpoch: UInt64, sequence: UInt64) { eventLog.append(.hoverExited(windowID, sessionEpoch, sequence)) }
    func coarseImageDidBecomeAvailable(_ image: CGImage?, for windowID: PreviewWindowID, sessionEpoch: UInt64) { eventLog.append(.coarseAvailable(windowID, sessionEpoch)) }
    func targetWindowDestroyed(_ windowID: PreviewWindowID) {}
    func targetApplicationTerminated(pid: pid_t) {}
    func stop(reason: WindowPeekStopReason) { eventLog.append(.peekStopped(reason)) }
}
```

Harness initializer 用该 coordinator 注入 `PreviewSessionController`，并给既有 `FakeActivationService` 新增 `onActivate: ((PreviewWindowID) -> Void)?`；`activate(window:)` 在 append 后同步调用该 closure，harness 将它连接到 `eventLog.append(.activated(id))`。`FakePreviewPanelDisplay.show` 接收并保存 `sessionEpoch`；其 `onRequestHide` 类型和生产 protocol 一致为 `((String, UInt64) -> Void)?`。

分别断言：新 `showPreview` 在 await window query 前产生新的 `.beganSession(epoch)`，且 session replacement 先停止旧 peek；`query(for:limit:)` 返回 `WindowQueryResult` 后、`panelDisplay.show` 前以同一 epoch 调用 `.screensUpdated(epoch, result.screens.count)`；session replacement/hide 清空 session 保存的 screens；`hide` 在 panel hide 前 `.sessionHidden`；thumbnail 返回时以当前 epoch 通知 coordinator；未知/已消失 ID 的新 epoch/sequence enter 仍传给 coordinator 并使旧目标停止；eligible A -> ineligible B 停止 A；epoch 41 的 `onRequestHide?("escape", 41)` 在 epoch 42 已显示时不隐藏新 panel，而 epoch 42 Esc 同步停止；以及普通 Esc hide。两个设置的 observer 行为已由 Task 6 coordinator 测试覆盖；Space、screen、application termination 与 AX destroyed 的领域映射在 Step 5 单独测试，AppDelegate terminate 在 Step 6 接线验证。

- [ ] **Step 4: 实现 session 接线并移除动作路径的非结构化 Task**

`PreviewSessionController` 只注入 `any WindowPeekCoordinating`。它新增 `private var nextSessionEpoch: UInt64 = 0` 和 `private var currentSessionEpoch: UInt64?`，并复用 Task 3 已创建的 `private var currentWindowPeekScreens: [WindowPeekScreen]`。`showPreview` 的第一段同步代码必须先检查 overflow、递增 epoch、写入 `currentSessionEpoch`、清 `currentWindowPeekScreens`、递增既有 panel generation，并调用 `windowPeekCoordinator.beginSession(epoch:)`；这一步在权限 refresh 和所有 window-query `await` 之前完成，因此新 session 替换旧 session 时没有旧 overlay 残留。`showPreview` 在 Task 7 保持 `async`，因为 `WindowQueryService.query` 和逐卡 `ThumbnailService.thumbnail` 仍异步；只有 action handler 改为同步 `handle(_:expectedGeneration:expectedSessionEpoch:)`，并将 `activate` 与 `performWindowOperation` 改为 MainActor 同步 API。处理分支固定为：

```swift
case let .hoverEntered(id, sessionEpoch, sequence):
    let coarse = currentModel?.cards.first { $0.id == id }?.thumbnail
    windowPeekCoordinator.hoverEntered(
        windowID: id,
        window: currentWindowsByID[id],
        coarseImage: coarse,
        sessionEpoch: sessionEpoch,
        sequence: sequence
    )
case let .hoverExited(id, sessionEpoch, sequence):
    windowPeekCoordinator.hoverExited(
        windowID: id,
        sessionEpoch: sessionEpoch,
        sequence: sequence
    )
case .contextMenuWillOpen:
    windowPeekCoordinator.stop(reason: .contextMenu)
case let .primarySelect(id):
    windowPeekCoordinator.stop(reason: .primarySelection)
    activate(windowID: id)
```

window query 收到 `WindowQueryResult` 后，先验证 generation/epoch 仍 current，再写 `currentWindowPeekScreens = result.screens`，并在调用 `panelDisplay.show` 前同步调用 `windowPeekCoordinator.updateScreens(result.screens, sessionEpoch: epoch)`；不得改用 `NSScreen`、当前显示器的现场重读或另一次 `SCShareableContent` 查询。`result.windows` 是建立 card model 与 `currentWindowsByID` 的唯一窗口列表。action handler 先验证 expected panel generation 和 action epoch 都等于 current values；失配只记录 stale。验证通过后，hover 分支不能在 `currentWindowsByID[id]` 查找失败时提前 return；coordinator 才拥有“新 sequence 指向缺失窗口也使旧 target 失效”的逻辑。调用 `panelDisplay.show` 时把同一 epoch 传给 `show(model:anchor:sessionEpoch:onAction:)`。thumbnail 更新当前 model 后调用 `coarseImageDidBecomeAvailable(image, for: id, sessionEpoch: epoch)`。

`hide` 固定为 `hide(reason: String, expectedSessionEpoch: UInt64? = nil)`：expected epoch 非 nil 且不等于 `currentSessionEpoch` 时只记录 `preview.session.staleHide` 并 return；否则第一项副作用是 `.stop(.sessionHidden)`，随后清 `currentWindowPeekScreens`、panel/model state。`PreviewPanelEventMonitorOwner` 的 Esc 路径传入其 current epoch，AppDelegate 不得再用 `Task` 包装该 callback。这样延迟到达的旧 epoch Esc 不能隐藏后续 session，而当前 epoch Esc 保持同步处理。现有右键菜单会话保留逻辑不变。

- [ ] **Step 5: 实现生命周期 observer 和确定性映射测试**

```swift
enum WindowPeekLifecycleEvent: Equatable, Sendable {
    case activeSpaceChanged
    case screenParametersChanged
    case applicationTerminated(pid_t)
    case targetWindowDestroyed(PreviewWindowID)
}

@MainActor
protocol WindowPeekLifecycleObserving: AnyObject {
    func start(_ handler: @escaping @MainActor (WindowPeekLifecycleEvent) -> Void)
    func observeTargetWindow(id: PreviewWindowID?, element: AXUIElement?)
    func stop()
}

@MainActor
protocol WindowPeekTargetDestroyedSubscribing: AnyObject {
    func replaceTarget(
        id: PreviewWindowID,
        element: AXUIElement?,
        onDestroyed: @escaping @MainActor (PreviewWindowID) -> Void
    )
    func clear()
}
```

`WindowPeekLifecycleObserver` initializer 固定为：

```swift
init(
    workspaceNotificationCenter: NotificationCenter,
    applicationNotificationCenter: NotificationCenter,
    targetDestroyedSubscriber: any WindowPeekTargetDestroyedSubscribing,
    logger: ProbeLogger
)
```

它私有拥有 `workspaceTokens: [NSObjectProtocol]`、`applicationTokens: [NSObjectProtocol]`、`handler` 和 subscriber；`start` 在 handler 尚未设置时才分别从 workspace center 注册 `NSWorkspace.activeSpaceDidChangeNotification`、`NSWorkspace.didTerminateApplicationNotification`，以及从 application center 注册 `NSApplication.didChangeScreenParametersNotification`。`stop` 先把 handler 置 nil，再从各自 center remove 所有 token、清空数组并调用 subscriber `clear()`；重复 start/stop 与 deinit 均幂等。生产传 `NSWorkspace.shared.notificationCenter` 和 `NotificationCenter.default`，不能误把 workspace notification 注册到 default center。

`WindowPeekLifecycleObserverTests.swift` 使用两个新的 `NotificationCenter()` 以及同文件 private 的 `RecordingTargetDestroyedSubscriber`。`observeTargetWindow(id: nil, element: nil)` 必须直接调用 subscriber `clear()`；只有同时有非 nil id/element 时才调用 `replaceTarget`。该 fake 保存 current `(id, handler)`，`replaceTarget` 先 append `.clear` 再保存，`emitDestroyed(id:)` 只调用当前 handler；测试主动 post 三种 notification。必须断言 target 替换先 clear 旧订阅、destroyed 只发送当前 ID、nil target 清订阅、stop 后 notification/fake emit 无事件，且所有注册 token 已从对应 center 移除。

生产 `SystemWindowPeekTargetDestroyedSubscriber` 在 `replaceTarget` 时先完整 clear 旧订阅：若存在旧 observer/element 则调用 `AXObserverRemoveNotification(..., kAXUIElementDestroyedNotification as CFString)`，再从 `CFRunLoopGetMain()` 的 `.commonModes` 移除旧 source，最后 nil 出 observer、element、currentID 与 handler。随后才用 `id.pid` 创建 AXObserver、为新 element 添加公开 `kAXUIElementDestroyedNotification`，并将其 source 加入 main run loop common modes。subscriber 自身在 lifecycle observer 中被强持有，C callback refcon 仅使用 `Unmanaged.passUnretained(subscriber).toOpaque()` 指向这个长生命周期对象；clear 不释放 subscriber，所以移除后已经排队的 callback 仍有有效 refcon，并在 handler 内再次比较 currentID 后丢弃。callback 必须 `precondition(Thread.isMainThread)` 后在 `MainActor.assumeIsolated` 中直接调用领域 handler，不能 `Task` hop。`WindowPeekLifecycleObserver.swift` 以 `@preconcurrency import ApplicationServices` 引入 C API，所有 `AXUIElement`/`AXObserver` 存取都保持 MainActor 隔离。nil target、clear、stop 和 deinit 都移除 notification 与 run-loop source。若订阅返回不支持或 element 为 nil，则记录 `peek.lifecycle.destroyObservationUnavailable id=... code=...`；首版不增加 30 Hz 窗口存在性轮询。

测试 fake handler 断言 Space/screen 分别映射为 `.activeSpaceChanged` / `.screenParametersChanged`，workspace termination 携带 PID，AX fake destroyed 携带当前 window ID；切换 target 后旧 fake callback 不得再发事件。observer start/stop 和目标切换必须幂等。

- [ ] **Step 6: 完成 AppDelegate 和 orchestrator wiring**

`AppDelegate` 增加强持有 `screenCaptureKitCaptureBroker`、`windowPeekLifecycleObserver` 和 `windowPeekCoordinator` 的属性。先构造且只构造一个 `ScreenCaptureKitCaptureBroker`，把它注入 `StaticThumbnailService` 与 `ScreenCaptureKitWindowPeekCaptureBackend`，再以该 backend 构造 `DefaultWindowPeekCaptureService`；禁止在 session、thumbnail service 或 backend initializer 内新建第二个 broker。随后先用局部 `let lifecycleObserver = WindowPeekLifecycleObserver(...)`（再赋值给强持有 property）构造 `NSWorkspace.shared.notificationCenter`、`NotificationCenter.default` 和生产 AX subscriber，之后构造 overlay 和 coordinator，并注入 `MainRunLoopWindowPeekPermissionRefreshScheduler`。coordinator 的 `onCurrentTargetChanged` 固定为：

```swift
{ [weak lifecycleObserver] target in
    lifecycleObserver?.observeTargetWindow(
        id: target?.id,
        element: target?.axElement
    )
}
```

target 为 nil 时该方法清理订阅。随后以 weak coordinator capture 调用 `lifecycleObserver.start`：Space/screen 直接 `stop` 对应 reason，application/destroyed 分别调用 `targetApplicationTerminated(pid:)` / `targetWindowDestroyed(_:)`。observer 不捕获 coordinator，coordinator 的 current-target closure 也不捕获 coordinator 本身，因此没有 observer/coordinator retain cycle。再把 coordinator 传入 session 并启动 coordinator settings observer；终止时先 `windowPeekCoordinator.stop(.appTermination)`，再 `windowPeekLifecycleObserver.stop()`、停止 session observers/orchestrator。

`previewPanelController.onRequestHide` 的 closure 固定为 `{ [weak previewSessionController] reason, epoch in previewSessionController?.hide(reason: reason, expectedSessionEpoch: epoch) }`；它已在 MainActor callback 中执行，绝不能创建 `Task { @MainActor in ... }`。AppDelegate wiring 测试只通过这条 closure 的 fake panel/session 边界验证 epoch guard，不新增依赖真实 `NSApplication` 生命周期的单元测试。

`ProbeOrchestratorPreviewTests` 必须断言主 Dock 速览设置关闭或 orchestrator stop 时，session hide 路径先触发 coordinator `.sessionHidden`，并且独立 `isDesktopWindowPeekEnabled` 持久化值不被改写。`AppDelegate` wiring 通过现有编译与 session/orchestrator fake 边界验证，不新增依赖真实 `NSApplication` 生命周期的单元测试。

- [ ] **Step 7: 运行接线测试并提交**

Run: `swift test --filter PreviewPanelViewModelTests && swift test --filter PreviewPanelControllerTests && swift test --filter PreviewPanelViewRenderingTests && swift test --filter PreviewSessionControllerTests && swift test --filter WindowPeekLifecycleObserverTests && swift test --filter ProbeOrchestratorPreviewTests`

Expected: 所有新旧 panel、session、orchestrator 和 lifecycle 测试 PASS。

```bash
git add Sources/DockHoverPreviewProbe/App/AppDelegate.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelModels.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelView.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelController.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewSessionController.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ProbeOrchestrator.swift \
  Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekLifecycleObserver.swift \
  Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift \
  Tests/DockHoverPreviewProbeTests/PreviewPanelViewRenderingTests.swift \
  Tests/DockHoverPreviewProbeTests/PreviewPanelControllerTests.swift \
  Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift \
  Tests/DockHoverPreviewProbeTests/ProbeOrchestratorPreviewTests.swift \
  Tests/DockHoverPreviewProbeTests/WindowPeekLifecycleObserverTests.swift
git diff --cached --check
git commit -m "feat: wire desktop peek into preview sessions"
```

### Task 8: 完成全量回归、打包和人工验收文档

**Files:**
- Create: `docs/verification/dock-window-desktop-peek-manual-checklist.md`
- Modify: `docs/architecture/dock-hover-preview-technical-design.md`
- Modify: `docs/roadmap.md`
- Modify: `docs/releases/CHANGELOG.md`
- Modify: `docs/superpowers/plans/2026-07-24-dock-window-desktop-peek.md`

- [ ] **Step 1: 创建人工验收清单**

清单必须逐项记录环境、预期、实际、日志证据和 `pass / pass with note / fail / blocked`。核心场景固定使用三个内容明显不同的 VS Code 项目窗口，并覆盖：

1. enter 同步显示粗略图，高清图在原 frame 替换；目标屏幕 alpha 0.22，原 panel 可 hover/点击；preview、mirror、dimming 都不能成为 key/main，前台应用不改变。
2. 快速 A-B-C 扫过，没有旧图覆盖、没有中间闪烁、没有残留 dimming。
3. 点击前 overlay 消失，再激活真实窗口；输入焦点和真实层级在 hover 期间不变。
4. 右键菜单前 overlay 消失，菜单和现有窗口操作可用。
5. 独立开关即时停止并可恢复；主开关关闭即时停止且不覆盖独立值。
6. Esc、hover lost、session 替换、普通 Space、全屏 Space、屏幕参数变化、关闭目标窗口和 app 退出均无残留。
7. AX fallback、未匹配 Stage Manager 候选、截图失败和权限撤销不显示错误镜像；先等待高清图已显示，再在系统设置撤销 Screen Recording，最多一个 refresh interval 后 overlay 消失。
8. Dock 底/左/右、自动隐藏、浅/深色、Reduce Motion、菜单栏和通知中心交互不回退。
9. 多显示器在主屏上/下/左/右、跨屏、负坐标、混合 backing scale 和“显示器具有单独 Space”在可用硬件验证；无硬件时明确写 `blocked / not available`。
10. 同时触发缩略图和 A-B-C desktop peek；日志证明每一次 `sck.broker.capture.started` 都在前一次同类 `finished` 之后，A 在飞时只保留 C，已 active 的调用不被取消。
11. 受保护内容若返回空白但不抛错，记录系统实际结果，不增加像素级黑屏检测，也不把该系统限制写成应用失败。

- [ ] **Step 2: 运行聚焦测试和全量测试**

Run:

```bash
swift test list | rg 'ScreenCaptureKitCaptureBrokerTests|WindowPeekGeometryTests|WindowPeekCaptureServiceTests|WindowPeekOverlayControllerTests|WindowPeekCoordinatorTests|WindowPeekLifecycleObserverTests'
swift test --filter ScreenCaptureKitCaptureBrokerTests
swift test --filter WindowPeekGeometryTests
swift test --filter WindowPeekCaptureServiceTests
swift test --filter WindowPeekOverlayControllerTests
swift test --filter WindowPeekCoordinatorTests
swift test --filter WindowPeekLifecycleObserverTests
swift test --filter PreviewSessionControllerTests
swift test --filter PreviewPanelControllerTests
swift test --filter SettingsStoreTests
swift test
```

Expected: 第一条命令必须列出六个命名 test class，证明后续 filter 不会因零匹配而伪通过；其余所有 XCTest 通过，0 failures。任何偶发失败必须先复现和修复，不能直接重跑后忽略。

- [ ] **Step 3: 构建并打包验证**

Run:

```bash
swift build
Scripts/build_probe_app.sh
git diff --check
```

Expected: SwiftPM build 成功；脚本输出 `build/zongMacTools.app` 并通过 Info.plist/签名校验；`git diff --check` 无输出且 exit 0。

- [ ] **Step 4: 执行单显示器人工核心场景**

Run:

```bash
pkill -x DockHoverPreviewProbe || true
open build/zongMacTools.app
/usr/bin/log stream --info --style compact --predicate 'subsystem == "com.zong.zongMacTools"'
```

Expected logs include `peek.show source=coarse`、`peek.capture.started`、`peek.capture.success`、`peek.update source=highResolution`、`sck.broker.capture.started/finished origin=thumbnail|desktopPeek` 和每条退出路径的 `peek.hide reason=...`。日志不得包含图片内容、额外窗口内容或新敏感字段。

- [ ] **Step 5: 更新技术文档、路线和 changelog**

技术设计写入最终采用的 hover tracking 方式、取消实验结论、窗口层级和已验证平台限制。Roadmap 只把实现与自动测试标记完成；人工场景按清单真实状态记录。Changelog 的 Unreleased 增加一条用户可见描述：卡片 hover 时可在桌面原位置显示两阶段静态窗口镜像，并可在设置中独立关闭。

- [ ] **Step 6: 执行计划自检**

逐条对照设计规格的目标、范围、产品决策、架构、状态模型、截图策略、几何、权限、测试和验收标准。确认每项都能指向 Task 1-8 中的具体步骤；搜索并清除未解决占位词；核对下列名称全篇一致：

```text
isDesktopWindowPeekEnabled
DockHoverPreview.desktopWindowPeekEnabled
desktopPeekEligible
desktopPeekCaptureSource
captureFrame
WindowPeekCaptureResult
WindowPeekCaptureRequestToken
WindowPeekImageQuality
WindowPeekStopReason
PreviewPanelAction.hoverEntered(_:sessionEpoch:sequence:)
PreviewPanelAction.hoverExited(_:sessionEpoch:sequence:)
PreviewPanelAction.contextMenuWillOpen(_:)
WindowPeekCoordinating.beginSession(epoch:)
WindowPeekCoordinating.updateScreens(_:sessionEpoch:)
WindowPeekCoordinating.hoverEntered(windowID:window:coarseImage:sessionEpoch:sequence:)
WindowPeekPermissionRefreshScheduling
ScreenCaptureKitCaptureBroker.captureDesktopPeek(token:operation:)
WindowQueryService.query(for:limit:)
```

- [ ] **Step 7: 提交文档与最终验证结果**

```bash
git add docs/verification/dock-window-desktop-peek-manual-checklist.md \
  docs/architecture/dock-hover-preview-technical-design.md \
  docs/roadmap.md \
  docs/releases/CHANGELOG.md \
  docs/superpowers/plans/2026-07-24-dock-window-desktop-peek.md
git diff --cached --check
git diff --cached --stat
git commit -m "docs: record desktop window peek verification"
```

Expected: staged files只包含本功能的计划、架构、路线、changelog 和验收记录；设计规格的既有用户改动除非明确授权，不随提交带入。

## 完成定义

- 原型结论已记录，生产 hover tracking 与截图门控策略与证据一致。
- 独立开关默认开启，缺 key、非法类型和同步 read-back 不一致均回退 `true`；不承诺检测进程结束后的磁盘耐久化失败，其他设置更新不覆盖该值。
- eligible 窗口 enter 时粗略图同步先显示；input hover sequence 只处理当前 session epoch 的 enter/exit，高清图只升级当前 capture request 的 session epoch/peek generation/window ID，同 target 的重复 enter 不会错误作废在飞截图。
- `AppDelegate` 强持有的唯一 `ScreenCaptureKitCaptureBroker` 是缩略图和 desktop peek 唯一的物理 SCK 入口；任意时刻最多一个未返回的公开 `SCScreenshotManager.captureImage` 调用。已 active worker 不取消，经过的 desktop target 不排队，只保留最新 target；不对公开 API 无法观测的 WindowServer 内部状态作更强承诺。
- 任何 hide、session 替换、主选择、右键菜单、设置、capture permissionDenied、活跃 target 的周期权限刷新、Space、屏幕、目标窗口 AX destroyed 和 app 生命周期路径都清理 overlay。
- overlay 不激活、不接收鼠标、不扩展保留区、不改变真实窗口层级，且层级严格为 dimming < mirror < preview panel < Dock。
- 单/多显示器纯函数测试、capture broker/service、overlay/coordinator/session/lifecycle 自动测试和既有回归全部通过；坐标测试验证 `SCDisplay.frame` 与 `NSScreen.frame` 按 display ID 配对、混合 backing scale 和真实 data-row 的 crop Y 方向。
- `swift test`、`swift build`、`Scripts/build_probe_app.sh` 和 `git diff --check` 通过。
- 单显示器三窗口核心人工场景通过；多显示器受硬件限制时明确记录 blocked，不虚报完成。
