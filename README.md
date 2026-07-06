# zongMacTools

`zongMacTools` 当前主要包含一个 macOS Dock 悬停窗口预览工具原型：`DockHoverPreviewProbe`。它是一个菜单栏常驻应用，用 Swift、AppKit、SwiftUI 和 ScreenCaptureKit 实现类似 Windows 任务栏窗口预览的最小可用能力：鼠标悬停在 Dock 应用图标上时，显示该应用当前可见窗口的横向预览面板，点击卡片即可切换到对应窗口。

项目目前处于 MVP/P0 验证完成、P1 基础设置完成、P2 界面打磨实现、自动验证和人工验证完成、P3 窗口操作增强实现完成、P4 正式应用化开发阶段。核心悬停预览路径已经可用；P1 新增菜单设置、持久化、排除 app、语言切换、Launch at Login 和 `zongMacTools.app` 打包名称；P2 改善预览面板的缩略图显示、占位状态、动画和浅色/深色视觉规则；P3 为预览卡片增加右键窗口操作菜单；P4 增加稳定签名配置、About / Status、诊断导出和 release packaging 流程。P2 人工视觉验证已由用户反馈完成，结果正常；P3 和 P4 人工验收尚未执行。

## 功能概览

- Dock 图标悬停触发窗口预览。
- 使用非激活的浮动 `NSPanel` 展示预览，不抢占当前应用焦点。
- SwiftUI 卡片列表，默认最多显示 8 个窗口；P1 菜单可切换为 3、5、8、12。
- 每张卡片包含应用图标、窗口标题、静态缩略图或占位图。
- P2 缩略图默认裁切填满；窄窗口自动完整显示，避免 Typora 等窄窗口被过度裁切。
- P2 区分加载中与不可用占位状态；缩略图不可用时显示本地化 `No thumbnail` / `无缩略图`。
- 点击预览卡片后尝试激活对应窗口，并隐藏预览面板。
- 右键预览卡片可打开窗口操作菜单：激活窗口、隐藏应用、关闭窗口、最小化窗口，并显示保守的屏幕提示。
- P3 窗口操作只使用公开接口；关闭和最小化依赖公开辅助功能按钮或属性，失败时安静降级并记录日志。
- 鼠标快速离开 Dock 图标时取消过期预览，避免 stale panel 残留。
- 鼠标从 Dock 图标移动到预览面板时保持面板显示。
- 鼠标离开 Dock 图标和预览面板后自动隐藏。
- 按 `Esc` 可隐藏预览面板。
- 屏幕录制权限缺失时静默抑制预览 UI，不弹出重复干扰提示。
- Dock 重启后可重新订阅 Dock Accessibility 事件。
- 菜单栏提供权限状态、权限入口、P1 settings menu、Launch at Login 和 frontmost app 调试预览入口。
- 菜单栏提供 About / Status 和 Export Diagnostics，便于查看版本、build、bundle id、权限、登录项、签名和设置摘要，并主动导出本地诊断文件。
- 预览面板显示/隐藏使用轻量动画，并尊重系统减少动态效果设置；浅色/深色外观下的边框、阴影、占位区域使用集中视觉规则。

## 当前状态

MVP/P0 UI 状态：`pass with note`；P1 基础设置状态：`complete`；P2 界面打磨自动验证状态：`complete`。P2 人工视觉验证状态：`complete`，2026-07-03 用户反馈正常。P3 窗口操作增强状态：实现完成，自动验证通过，人工验收待执行。

已验证内容：

- `swift test`：2026-07-03 13:31:05 Asia/Shanghai，130 XCTest，0 failures，exit 0。
- P3 `swift test`：2026-07-06 CST，164 XCTest，0 failures，exit 0。
- `swift build`：通过，exit 0。
- `Scripts/build_probe_app.sh`：通过，exit 0，输出 `/Users/zong/Desktop/Project/zongMacTools/build/zongMacTools.app`，Info.plist OK，替换 existing signature。
- 系统辅助功能与屏幕录制授权后，日志确认 Dock 监听订阅成功。
- VS Code、Chrome、Typora、IINA、WPS 的主流程由人工反馈为功能正常。
- 点击激活、快速离开取消 stale preview、进入 panel 保持显示、离开隐藏、移动到相邻未启动 Dock app 时隐藏旧 panel、`Esc` 隐藏、`killall Dock` 恢复均由人工反馈为功能正常。
- P2 人工视觉验证已由用户反馈完成，覆盖底部程序坞、左右程序坞、程序坞自动隐藏、台前调度、浅色/深色外观、减少动态效果、Typora 窄窗口、多窗口应用、屏幕录制权限缺失和快速悬停失效取消，结果正常。
- P3 自动测试覆盖窗口操作模型与文案、公开辅助功能窗口操作服务、右键菜单模型、菜单期间会话保留、操作成功/失败路由、旧会话动作保护和屏幕提示匹配；`swift build`、`Scripts/build_probe_app.sh` 和 `git diff --check` 均通过。

仍需继续验证的内容：

- Multiple displays 因当前硬件不可用仍是 `blocked / not available`。
- P3 真实 app 人工验收尚未执行，详见 `docs/verification/dock-hover-preview-p3-window-actions-manual-checklist.md`。

详细记录见：

- `docs/verification/dock-hover-preview-probe-summary.md`
- `docs/verification/dock-hover-preview-mvp-ui-manual-checklist.md`
- `docs/verification/dock-hover-preview-p2-ui-polish-manual-checklist.md`
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
- ServiceManagement
- ScreenCaptureKit

## 快速开始

### 1. 构建并打包 app

```bash
Scripts/build_probe_app.sh
```

成功后会输出：

```text
/Users/zong/Desktop/Project/zongMacTools/build/zongMacTools.app
```

脚本会执行以下动作：

- 运行 `swift build`。
- 创建 `build/zongMacTools.app` 目录结构。
- 复制 `DockHoverPreviewProbe` 可执行文件和 `Info.plist`。
- 从 `Assets/AppIcon/zong-mac-tools-logo.png` 生成 `zongMacTools.icns`。
- 校验 `Info.plist`。
- 使用 `CODE_SIGN_IDENTITY` 指定的身份签名；未指定时使用 ad-hoc fallback。
- 运行 `codesign --verify --deep --strict`。

默认 ad-hoc 签名适合无证书本地开发，但每次重新签名都可能让系统辅助功能和屏幕录制权限需要重新添加。若本机有稳定证书，可使用：

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Example" Scripts/build_probe_app.sh
```

不要把个人证书名称、Apple ID、team id、notary password 或 keychain profile 写入仓库。

### 2. 验证 app bundle

```bash
Scripts/verify_app_bundle.sh build/zongMacTools.app
```

验证内容包括 Info.plist、executable、icon、bundle id、用户可见名称和签名摘要。ad-hoc 签名会通过验证，但脚本会提示 TCC caveat。

### 3. 构建并打开 app

```bash
Scripts/run_probe_app.sh
```

这个脚本会先调用 `Scripts/build_probe_app.sh`，然后用 `open` 启动打包后的 app。

### 4. 手动授权权限

首次运行后，需要在系统设置中授权：

1. 打开 系统设置 > 隐私与安全性 > 辅助功能。
2. 添加并启用 `build/zongMacTools.app`。
3. 打开 系统设置 > 隐私与安全性 > 屏幕录制。
4. 添加并启用 `build/zongMacTools.app`。
5. 退出并重新打开 `zongMacTools.app`。

权限生效后，日志中应能看到类似内容：

```text
permissions.refresh accessibility=true screenRecording=true
orchestrator.start accessibility=true screenRecording=true
dock.subscribed pid=...
```

## 正式本地安装

生成本地 release artifact：

```bash
Scripts/package_release_app.sh
```

脚本默认使用 `CONFIGURATION=release`，调用 `Scripts/build_probe_app.sh` 和 `Scripts/verify_app_bundle.sh build/zongMacTools.app`，并把产物写入 ignored 的 `dist/zongMacTools-<version>-<build>/`。目录中包含 `zongMacTools-<version>-<build>.zip`、`SHA256SUMS.txt`、`release-metadata.txt` 和安装说明。

轻量本地更新流程是：校验 checksum，把 `zongMacTools.app` 复制到 `/Applications` 或你的固定安装目录，然后按需重新确认系统辅助功能和屏幕录制权限。P4 不直接启用 Sparkle 自动更新；更新策略见 `docs/architecture/release-update-strategy.md`。

## 使用方式

1. 启动 `zongMacTools.app`。
2. 菜单栏会显示 `zongMacTools` 的菜单栏 template logo。该图标是适合状态栏尺寸的单色标记，不直接使用全彩 app icon。
3. 确认 Accessibility 和 Screen Recording 都已授权。
4. 将鼠标移动到 Dock 中某个正在运行的应用图标上。
5. 默认停留约 250 ms 后，屏幕上会出现预览面板。
6. 点击某个窗口卡片，应用会尝试切换到对应窗口，随后隐藏预览面板。
7. 按 `Esc` 或移出 Dock 图标和预览面板区域，面板会隐藏。

菜单栏中的 P1 设置项包括 Enable / Disable Dock Hover Preview、hover delay、panel retention、max cards、display language、Exclude / Include target app、Clear Excluded Apps 和 Launch at Login。菜单栏中的 `Debug: Show Preview For Frontmost App` 可以对当前前台应用触发同一套预览 UI 路径，适合调试窗口枚举和缩略图生成；该 debug 入口仍尊重 Screen Recording 权限和 excluded apps。

菜单栏中的 `About / Status` 会显示版本、build、bundle id、bundle path、权限状态、Launch at Login 状态、签名状态和设置摘要，并提供 Copy Status。Copy Status 只包含本工具状态摘要，不包含第三方窗口标题或第三方 app 名称。

## 架构说明

代码集中在 `Sources/DockHoverPreviewProbe` 下，按职责拆分为几组模块。

### 应用启动与菜单栏

- `ProbeApp.swift`：SwiftPM executable 入口。
- `AppDelegate.swift`：初始化日志、权限服务、设置存储、target tracker、Launch at Login、Dock 监听、窗口查询、缩略图、激活服务、预览面板和菜单栏。
- `MenuBarController.swift`：创建菜单栏 template logo 状态项，展示权限状态、P1 设置、Launch at Login 和调试入口。
- `DockHoverPreviewSettings.swift` / `SettingsStore.swift`：定义 P1 设置模型并持久化到 `UserDefaults`。非法值会回退到安全默认值，不覆盖用户写入的原始值。
- `AppTextProvider.swift`：提供 English / 简体中文静态菜单文案；app 名称、窗口标题、bundle id、系统权限名称不翻译。
- `LaunchAtLoginService.swift`：用公开 `ServiceManagement` / `SMAppService.mainApp` 读写 Launch at Login 状态。
- `AppMetadata.swift` / `AppStatusSnapshot.swift`：读取版本、build、bundle id、bundle path、签名摘要，并聚合权限、登录项和设置状态。
- `AboutStatusWindowController.swift`：显示 About / Status 窗口并提供 Copy Status。
- `DiagnosticExportService.swift`：在用户主动触发后导出本地诊断文本。
- `AppTargetTracker.swift`：为 excluded apps 菜单选择当前 preview、最近 Dock hover 或最近非本 app 前台应用。

### 权限与日志

- `PermissionService.swift`：检查 Accessibility 和 Screen Recording 状态，打开系统设置页面。
- `ProbeLogger.swift`：封装 OSLog，同时保留内存日志快照，便于测试和排障。

### Dock 悬停监听

- `DockHoverMonitor.swift`：通过 Dock Accessibility 订阅 `kAXSelectedChildrenChangedNotification`，解析当前悬停的 Dock 应用项，并检测鼠标离开和 Dock 重启。
- `ProbeOrchestrator.swift`：协调 Dock hover 事件、settings-aware 延迟验证、enabled/excluded app gating、stale hover 清理和预览会话启动。
- `AXHelpers.swift`：Accessibility 属性读取和几何读取辅助函数。
- `GeometryHelpers.swift`：坐标转换、命中检测、窗口 frame 匹配分数等纯函数。

### 窗口查询、缩略图和激活

- `WindowQueryService.swift`：使用 ScreenCaptureKit 枚举当前可见窗口，并结合 AX 窗口做匹配；按当前 max cards 设置限制查询数量。
- `ThumbnailService.swift`：优先用 ScreenCaptureKit 生成静态缩略图，必要时使用 CoreGraphics fallback。
- `ActivationService.swift`：通过 AX raise 和 `NSRunningApplication.activate` 尝试激活选中的窗口。
- `WindowOperationService.swift`：通过公开接口执行 P3 窗口操作；激活复用 `ActivationService`，隐藏应用使用 `NSRunningApplication.hide()`，关闭/最小化只使用公开辅助功能按钮或可设置属性。
- `WindowEnvironmentDescriptor.swift`：按窗口与屏幕交集面积生成保守屏幕提示，不承诺真实空间归属。
- `ProbeModels.swift`：窗口 ID、窗口模型、权限状态、缩略图 cache key、激活结果等共享模型。

### 预览面板 UI

- `PreviewPanelModels.swift`：预览面板 anchor、卡片 view model、面板 view model，以及 P2 缩略图 fit/fill 显示模式和 unavailable 文案。
- `PreviewPanelLayoutEngine.swift`：根据 Dock item frame、鼠标位置和可见屏幕区域计算面板位置，支持 bottom/left/right/mouse fallback。
- `PreviewPanelView.swift`：SwiftUI 预览卡片 UI，包含 P2 thumbnail render plan、loading/unavailable placeholder、Light / Dark visual tokens。
- `PreviewPanelController.swift`：拥有非激活 `NSPanel` 和 `NSHostingController`，负责 show/update/hide、Reduce Motion aware animation、Escape 监听和 panel 命中检测。
- `PreviewSessionController.swift`：预览会话状态机，处理权限抑制、max cards、retention 参数、窗口查询、占位卡片展示、本地化 unavailable 文案、缩略图渐进更新、点击激活、stale async 取消和鼠标离开轮询。

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
- P1 settings 默认值、非法值回退、`UserDefaults` 持久化和 observer 通知。
- English / 简体中文静态文案。
- 菜单栏设置项、excluded apps、Launch at Login fake service 和菜单刷新。
- 预览面板布局引擎。
- 预览 view model 的卡片数量限制、缩略图更新、fit/fill 模式、unavailable 状态和可访问性标签。
- SwiftUI render plan 的 fill / fit 分支、loading spinner 和 unavailable 文案分支。
- 预览 session 的 Screen Recording 缺失抑制、无窗口隐藏、max cards、retention、缩略图更新、本地化 unavailable 文案、stale cancellation、点击激活、Dock 到 panel 的桥接保留和相邻 Dock item hover-lost 隐藏。
- P3 窗口操作服务的关闭、最小化、隐藏应用、激活委托、失败阶段与 AX code 记录。
- P3 右键菜单模型、禁用项不触发动作、菜单跟踪期间保留会话、旧会话动作不影响新会话、屏幕提示匹配。
- 预览 panel controller 的 show/hide animation、Reduce Motion 降级、隐藏后命中测试和 update 不重复触发 show animation。
- Light / Dark visual token 的边框、阴影、hover state 和 placeholder surface 基础约束。
- 静态缩略图 cache、ScreenCaptureKit/CoreGraphics fallback 日志。
- 窗口 AX 匹配诊断日志。
- orchestrator frontmost preview 权限抑制。
- app 打包名称/icon 脚本和 AppDelegate wiring。

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
/usr/bin/log show --last 5m --info --style compact --predicate 'subsystem == "com.zong.zongMacTools"'

# 退出正在运行的 probe app
pkill -x DockHoverPreviewProbe
```

## 日志与排障

### 看不到预览面板

先确认权限日志：

```bash
/usr/bin/log show --last 5m --info --style compact --predicate 'subsystem == "com.zong.zongMacTools"'
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

## 导出诊断

菜单栏选择 `Export Diagnostics...` 后可保存本地诊断文本。诊断文件只在用户主动触发后本地生成，不自动上传，也不后台定时采集。

诊断内容包括：

- App 状态快照：版本、build、bundle id、bundle path、权限、Launch at Login、签名和设置摘要。
- 最近 15 分钟本工具统一日志。
- `codesign -dv --verbose=4` 签名摘要。
- `Scripts/verify_app_bundle.sh` bundle 验证摘要。

诊断文件不包含截图、缩略图图像、屏幕录制内容或用户文件内容。统一日志可能包含本机 app 名称、窗口标题、bundle id 和环境细节，因此只应在需要排障时由用户主动保存和分享。

## 已知限制

- 只展示当前可见、可枚举、非最小化的普通应用窗口。
- 不展示或恢复已最小化窗口，不展示其他 Space 中的窗口，也不做全屏 Space 自动切换。
- 不提供实时视频缩略图，当前是静态截图。
- 不提供卡片内关闭、最小化或全屏按钮；P3 右键菜单只发出公开接口窗口操作请求。
- P1 只提供菜单栏设置，不提供独立设置窗口、搜索或键盘切换器。
- Launch at Login 依赖公开 `ServiceManagement`，真实状态以 `SMAppService.mainApp.status` 为准。
- 只使用公开 API。
- 多显示器场景仍需额外手动验证。

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

1. 继续补跑多显示器验证；当前硬件不可用时保持 `blocked / not available`。
2. 执行 P3 窗口操作增强人工验收，重点覆盖右键菜单、关闭/最小化失败降级、菜单期间会话保留和屏幕录制权限缺失。
3. 执行 P4 正式应用化人工验收，重点覆盖稳定签名、TCC、About / Status、诊断导出、release artifact、Launch at Login 和屏幕录制权限缺失静默抑制。
4. 继续评估是否需要持久设置页、应用过滤或更完整的窗口状态处理。

完整后续清单见 `docs/roadmap.md`。
