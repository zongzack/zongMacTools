# zongMacTools

`zongMacTools` 当前主要包含一个 macOS Dock 悬停窗口预览工具原型：`DockHoverPreviewProbe`。它是一个菜单栏常驻应用，用 Swift、AppKit、SwiftUI 和 ScreenCaptureKit 实现类似 Windows 任务栏窗口预览的最小可用能力：鼠标悬停在 Dock 应用图标上时，显示该应用当前可见窗口的横向预览面板，点击卡片即可切换到对应窗口。

项目目前处于 MVP 验证完成阶段：核心功能已经可用，最终记录为 `pass with concerns`。主要功能路径已通过自动测试、打包验证和人工 UI 验收；剩余风险集中在多显示器、Stage Manager、Dock 自动隐藏、左右 Dock、全屏 Space 等环境变体尚未完整跑完。

## 功能概览

- Dock 图标悬停触发窗口预览。
- 使用非激活的浮动 `NSPanel` 展示预览，不抢占当前应用焦点。
- SwiftUI 横向卡片列表，最多显示 8 个窗口。
- 每张卡片包含应用图标、窗口标题、静态缩略图或占位图。
- 点击预览卡片后尝试激活对应窗口，并隐藏预览面板。
- 鼠标快速离开 Dock 图标时取消过期预览，避免 stale panel 残留。
- 鼠标从 Dock 图标移动到预览面板时保持面板显示。
- 鼠标离开 Dock 图标和预览面板后自动隐藏。
- 按 `Esc` 可隐藏预览面板。
- Screen Recording 权限缺失时静默抑制预览 UI，不弹出重复干扰提示。
- Dock 重启后可重新订阅 Dock Accessibility 事件。
- 菜单栏提供权限状态、权限入口和 frontmost app 调试预览入口。

## 当前状态

MVP UI 状态：`pass with concerns`。

已验证内容：

- `swift test` 通过，最终记录为 32 个 XCTest、0 失败。
- `swift build` 通过。
- `Scripts/build_probe_app.sh` 可产出 `build/DockHoverPreviewProbe.app`。
- Accessibility 和 Screen Recording 授权后，日志确认 Dock 监听订阅成功。
- VS Code、Chrome、Typora、IINA、WPS 的主流程由人工反馈为功能正常。
- 点击激活、快速离开取消 stale preview、进入 panel 保持显示、离开隐藏、移动到相邻未启动 Dock app 时隐藏旧 panel、`Esc` 隐藏、`killall Dock` 恢复均由人工反馈为功能正常。

仍需继续验证的内容：

- 最终 UI pass 中没有重新手动切换 Screen Recording denied 路径，但已有自动测试和早期 probe 证据覆盖。
- 全屏 Space、Stage Manager、Dock 自动隐藏、左/右 Dock、多显示器仍未完成最终 UI 环境变体验证。
- Typora 等窄窗口的缩略图内容会按真实窗口比例显示，看起来比容器窄；当前接受为 polish candidate，不作为 MVP 阻塞问题。

详细记录见：

- `docs/verification/dock-hover-preview-probe-summary.md`
- `docs/verification/dock-hover-preview-mvp-ui-manual-checklist.md`
- `docs/architecture/dock-hover-preview-technical-design.md`
- `docs/roadmap.md`

## 运行环境

- macOS 14 或更新版本。
- Swift 6 / SwiftPM。
- Xcode Command Line Tools 或完整 Xcode。
- 需要系统授予：
  - Accessibility，用于监听 Dock Accessibility 事件和窗口激活。
  - Screen Recording，用于 ScreenCaptureKit 窗口枚举和缩略图截图。

当前 `Package.swift` 链接框架：

- AppKit
- ApplicationServices
- CoreGraphics
- ScreenCaptureKit

## 快速开始

### 1. 构建并打包 app

```bash
Scripts/build_probe_app.sh
```

成功后会输出：

```text
/Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app
```

脚本会执行以下动作：

- 运行 `swift build`。
- 创建 `build/DockHoverPreviewProbe.app` 目录结构。
- 复制可执行文件和 `Info.plist`。
- 校验 `Info.plist`。
- 使用 ad-hoc 签名重新签名 app。

### 2. 构建并打开 app

```bash
Scripts/run_probe_app.sh
```

这个脚本会先调用 `Scripts/build_probe_app.sh`，然后用 `open` 启动打包后的 app。

### 3. 手动授权权限

首次运行后，需要在系统设置中授权：

1. 打开 系统设置 > 隐私与安全性 > 辅助功能。
2. 添加并启用 `build/DockHoverPreviewProbe.app`。
3. 打开 系统设置 > 隐私与安全性 > 屏幕录制。
4. 添加并启用 `build/DockHoverPreviewProbe.app`。
5. 退出并重新打开 `DockHoverPreviewProbe.app`。

权限生效后，日志中应能看到类似内容：

```text
permissions.refresh accessibility=true screenRecording=true
orchestrator.start accessibility=true screenRecording=true
dock.subscribed pid=...
```

## 使用方式

1. 启动 `DockHoverPreviewProbe.app`。
2. 菜单栏会显示 `DHP`。
3. 确认 Accessibility 和 Screen Recording 都已授权。
4. 将鼠标移动到 Dock 中某个正在运行的应用图标上。
5. 停留约 250 ms 后，屏幕上会出现预览面板。
6. 点击某个窗口卡片，应用会尝试切换到对应窗口，随后隐藏预览面板。
7. 按 `Esc` 或移出 Dock 图标和预览面板区域，面板会隐藏。

菜单栏中的 `Debug: Show Preview For Frontmost App` 可以对当前前台应用触发同一套预览 UI 路径，适合调试窗口枚举和缩略图生成。

## 架构说明

代码集中在 `Sources/DockHoverPreviewProbe` 下，按职责拆分为几组模块。

### 应用启动与菜单栏

- `ProbeApp.swift`：SwiftPM executable 入口。
- `AppDelegate.swift`：初始化日志、权限服务、Dock 监听、窗口查询、缩略图、激活服务、预览面板和菜单栏。
- `MenuBarController.swift`：创建 `DHP` 菜单栏项，展示权限状态和调试入口。

### 权限与日志

- `PermissionService.swift`：检查 Accessibility 和 Screen Recording 状态，打开系统设置页面。
- `ProbeLogger.swift`：封装 OSLog，同时保留内存日志快照，便于测试和排障。

### Dock 悬停监听

- `DockHoverMonitor.swift`：通过 Dock Accessibility 订阅 `kAXSelectedChildrenChangedNotification`，解析当前悬停的 Dock 应用项，并检测鼠标离开和 Dock 重启。
- `ProbeOrchestrator.swift`：协调 Dock hover 事件、250 ms 延迟验证、stale hover 清理和预览会话启动。
- `AXHelpers.swift`：Accessibility 属性读取和几何读取辅助函数。
- `GeometryHelpers.swift`：坐标转换、命中检测、窗口 frame 匹配分数等纯函数。

### 窗口查询、缩略图和激活

- `WindowQueryService.swift`：使用 ScreenCaptureKit 枚举当前可见窗口，并结合 AX 窗口做匹配。
- `ThumbnailService.swift`：优先用 ScreenCaptureKit 生成静态缩略图，必要时使用 CoreGraphics fallback。
- `ActivationService.swift`：通过 AX raise 和 `NSRunningApplication.activate` 尝试激活选中的窗口。
- `ProbeModels.swift`：窗口 ID、窗口模型、权限状态、缩略图 cache key、激活结果等共享模型。

### 预览面板 UI

- `PreviewPanelModels.swift`：预览面板 anchor、卡片 view model、面板 view model。
- `PreviewPanelLayoutEngine.swift`：根据 Dock item frame、鼠标位置和可见屏幕区域计算面板位置，支持 bottom/left/right/mouse fallback。
- `PreviewPanelView.swift`：SwiftUI 横向预览卡片 UI。
- `PreviewPanelController.swift`：拥有非激活 `NSPanel` 和 `NSHostingController`，负责 show/update/hide、Escape 监听和 panel 命中检测。
- `PreviewSessionController.swift`：预览会话状态机，处理权限抑制、窗口查询、占位卡片展示、缩略图渐进更新、点击激活、stale async 取消和鼠标离开轮询。

## 测试

运行全部测试：

```bash
swift test
```

运行构建：

```bash
swift build
```

如果菜单栏 app 正在运行，建议先退出或执行：

```bash
pkill -x DockHoverPreviewProbe
```

再运行测试。最终验收时曾观察到正在运行的 probe app 会让一次 `swift test` 在 build 后未及时退出；退出 app 后测试正常完成。

当前测试覆盖重点包括：

- 几何与坐标转换。
- 预览面板布局引擎。
- 预览 view model 的卡片数量限制、缩略图更新和可访问性标签。
- 预览 session 的 Screen Recording 缺失抑制、无窗口隐藏、缩略图更新、stale cancellation、点击激活、Dock 到 panel 的桥接保留和相邻 Dock item hover-lost 隐藏。
- 静态缩略图 cache、ScreenCaptureKit/CoreGraphics fallback 日志。
- 窗口 AX 匹配诊断日志。
- orchestrator frontmost preview 权限抑制。

## 常用命令

```bash
# 运行测试
swift test

# 构建 SwiftPM executable
swift build

# 打包 .app
Scripts/build_probe_app.sh

# 打包并打开 .app
Scripts/run_probe_app.sh

# 查看 probe 日志
/usr/bin/log show --last 5m --info --style compact --predicate 'subsystem == "com.zong.DockHoverPreviewProbe"'

# 退出正在运行的 probe app
pkill -x DockHoverPreviewProbe
```

## 日志与排障

### 看不到预览面板

先确认权限日志：

```bash
/usr/bin/log show --last 5m --info --style compact --predicate 'subsystem == "com.zong.DockHoverPreviewProbe"'
```

重点查找：

- `permissions.refresh accessibility=true screenRecording=true`
- `orchestrator.start accessibility=true screenRecording=true`
- `dock.subscribed pid=...`

如果 Accessibility 为 false，Dock 监听不会启动。需要在系统设置中重新授权辅助功能，并重启 app。

如果 Screen Recording 为 false，预览 UI 会被静默抑制，这是预期行为。需要在系统设置中重新授权屏幕录制，并重启 app。

### 悬停后没有出现预览

检查日志中是否有：

- `dock.hover ...`
- `dock.hoverDelayed ... matches=true mouseInside=true`
- `windows.query ... count=...`
- `preview.panel.show ...`

如果出现 `dock.selectedStale`、`mouseInside=false` 或 `hoverValidationFailed`，说明鼠标已经离开或 Dock 当前选中项过期，预览被取消，这是 stale hover 防护的一部分。

### 缩略图显示为占位图

可能原因：

- ScreenCaptureKit 截图失败。
- CoreGraphics fallback 也失败。
- 目标窗口不在当前可交互 Space 或不满足当前窗口过滤条件。

对应日志通常包含：

- `thumbnail.sckFailed ...`
- `thumbnail.cgFailed ...`
- `thumbnail.failed ...`

## 已知限制

- 只展示当前可见、可枚举、非最小化的普通应用窗口。
- 不支持最小化窗口、其他 Space 中的窗口或全屏 Space 自动切换。
- 不提供实时视频缩略图，当前是静态截图。
- 不提供关闭、最小化、全屏按钮。
- 不提供设置页、应用过滤、搜索或键盘切换器。
- 不使用私有 API。
- 对 Full-screen Space、Stage Manager、Dock 自动隐藏、左右 Dock、多显示器等场景仍需额外手动验证。
- 窄窗口缩略图会保留真实窗口比例，可能看起来没有铺满缩略图区域；这属于后续 UI polish 议题。

## 设计边界

本项目参考了 DockDoor 的产品形态和交互方向，但只作为视觉和行为参考。实现不复制、翻译或机械改写 DockDoor 的 GPLv3 源码、文件结构、helper、注释或私有 API wrapper。

MVP 阶段坚持以下边界：

- 使用公开 API。
- 保持菜单栏工具形态，不出现在 Dock 中。
- 权限缺失时通过菜单栏/日志表达，不在 Dock hover 路径弹窗打扰。
- 保持子系统拆分：Dock 监听、窗口查询、缩略图、激活、UI 会话、面板展示彼此独立。
- stale hover cancellation 是一等状态，不能让过期 hover 弹出或残留面板。

## 项目目录

```text
.
├── Package.swift
├── Scripts
│   ├── build_probe_app.sh
│   └── run_probe_app.sh
├── Sources
│   └── DockHoverPreviewProbe
├── Tests
│   └── DockHoverPreviewProbeTests
└── docs
    ├── architecture
    ├── verification
    ├── roadmap.md
    └── archive
```

## 后续建议

优先级从高到低：

1. 补跑环境变体验证：全屏 Space、Stage Manager、Dock 自动隐藏、左/右 Dock、多显示器。
2. 做 UI polish：缩略图真实比例与铺满裁切策略、轻微显示/隐藏动画。
3. 评估是否需要持久设置页、应用过滤或更完整的窗口状态处理。

完整后续清单见 `docs/roadmap.md`。
