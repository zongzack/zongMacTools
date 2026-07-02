# Dock 悬停窗口预览技术设计

日期：2026-06-25

最近更新：2026-07-02

## 目标

`zongMacTools` 当前打包为用户可见的菜单栏 app，SwiftPM executable / target 仍为 `DockHoverPreviewProbe`。它用公开 API 实现类似 Windows 任务栏窗口预览的最小可用体验：

- 鼠标悬停 Dock 应用图标。
- 默认等待约 250 ms 后展示该应用在当前可交互环境中可枚举的窗口。
- 预览面板默认最多展示 8 张窗口卡片。
- 每张卡片包含应用图标、窗口标题、静态缩略图或占位图。
- 点击卡片后尝试激活对应窗口，并隐藏面板。

当前状态是 MVP/P0 UI `pass with note`，P1 基础设置实现、自动验证和人工验证均已完成。普通底部 Dock、全屏 Space、Dock auto-hide、左右 Dock 和 Stage Manager 已完成 P0 验证；多显示器因当前硬件不可用仍为 `blocked / not available`。

## 范围

MVP 范围内：

- SwiftPM executable 打包成菜单栏 `.app`。
- AppKit + SwiftUI + ScreenCaptureKit + Accessibility。
- Dock hover 是主触发方式。
- 菜单栏提供 P1 设置、Launch at Login、权限入口和 frontmost app 调试预览入口。
- 使用非激活 `NSPanel` 显示预览，不抢焦点。
- 使用 ScreenCaptureKit 枚举当前可见/可捕获窗口，并用 AX 做窗口匹配。
- 使用静态缩略图，不做实时视频预览。
- 无窗口、权限缺失、缩略图失败或设置错误时安静降级，不弹重复提示。
- stale hover cancellation 是一等行为：过期 hover、快速离开、候选变化都不能留下旧面板。
- P1 设置持久化到 `UserDefaults`，默认值保持 MVP 行为：enabled、250 ms、standard retention、max 8 cards、excluded apps 为空、English。
- Launch at Login 只通过公开 `ServiceManagement` / `SMAppService.mainApp` 读取和修改。

MVP 范围外：

- 实时缩略图。
- 最小化窗口、其他 Space 窗口、全屏 Space 自动切换。
- 精确遮挡检测。
- 卡片上的关闭/最小化/全屏按钮。
- 搜索、键盘切换器、Cmd+Tab 替代、独立设置窗口、Dock 锁定等扩展功能。
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

### 应用启动和菜单栏

- `ProbeApp.swift`：SwiftPM executable 入口，启动 `NSApplication`。
- `AppDelegate.swift`：初始化服务、设置存储、target tracker、Launch at Login、预览会话、菜单栏和 orchestrator。
- `MenuBarController.swift`：安装 `zongMacTools` 菜单栏 template logo 状态项，展示权限状态、P1 设置、Launch at Login 和调试入口。菜单栏使用适合 18 px 状态栏尺寸的单色 template 标记，不直接把全彩 app icon 缩成菜单栏小图标。
- `DockHoverPreviewSettings.swift` / `SettingsStore.swift`：定义 P1 设置模型、默认值、非法值回退和 `UserDefaults` 持久化。
- `AppTextProvider.swift`：根据 English / 简体中文设置返回本工具静态 UI 文案，不翻译 app 名称、窗口标题、bundle id 或系统权限名称。
- `AppTargetTracker.swift`：按当前 preview、最新 Dock hover、最新非本 app 前台应用的优先级提供 excluded-app target。
- `LaunchAtLoginService.swift`：封装公开 `ServiceManagement` / `SMAppService.mainApp` 状态读取、register/unregister 和 Login Items 设置入口。

### 权限和日志

- `PermissionService.swift`：检查 Accessibility 与 Screen Recording；打开对应系统设置页面。
- `ProbeLogger.swift`：封装 OSLog，并保留内存日志快照，方便测试和排障。

权限策略：

- Accessibility 缺失时不启动 Dock observer，也不尝试 AX 激活。
- Screen Recording 缺失时静默抑制正常 Dock hover preview，因为窗口枚举和缩略图依赖 ScreenCaptureKit。
- 权限问题只通过菜单栏和日志体现，不在 Dock hover 路径弹窗打扰。

### Dock hover 监听

- `DockHoverMonitor.swift`：连接 Dock 进程的 Accessibility 树，订阅 `kAXSelectedChildrenChangedNotification`。
- `ProbeOrchestrator.swift`：负责 settings-aware hover 延迟、二次验证、enabled/excluded app gating、pending work 取消和预览会话启动。
- `GeometryHelpers.swift` / `AXHelpers.swift`：提供坐标转换、命中测试和 AX 属性读取。

关键规则：

- Dock selected-child 只是候选项。
- 显示 preview 前必须确认 bundle 仍匹配，且鼠标仍在当前 Dock item frame 内。
- 如果 Dock item 变 stale、候选为空、鼠标离开、preview 被禁用或 app 被排除，都必须取消 pending preview 或隐藏当前面板。
- 鼠标从 Dock 图标移动到 panel 时允许保留面板，但横向移动到相邻 Dock item，尤其是未启动 app，不应保留旧面板。

### 窗口查询

- `WindowQueryService.swift`：用 ScreenCaptureKit 查询当前可见窗口，并用 AX 做 best-effort 匹配；调用方传入当前 max cards limit。
- `ProbeModels.swift`：定义 `PreviewWindowID`、`PreviewWindow`、`ThumbnailSource` 等模型。

当前窗口范围是“当前可交互环境近似值”，不是严格 Mission Control Space API。实现依赖：

- `SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)`。
- `SCWindow.isOnScreen`。
- 普通窗口 layer 和尺寸过滤。
- AX title/frame/minimized/role/subrole 辅助匹配。

限制：

- 不承诺精确 Space membership。
- 不恢复最小化窗口。
- Stage Manager、多显示器和全屏 Space 必须以实测记录为准。

### 缩略图

- `ThumbnailService.swift`：优先 ScreenCaptureKit 截图，失败时 CoreGraphics fallback。
- 缩略图按窗口 ID、frame size、title 等短期缓存。
- 缩略图失败只显示应用图标和标题，不阻塞面板展示。

### 激活

- `ActivationService.swift`：优先 AX raise，再调用 `NSRunningApplication.activate(options: [])`。
- 如果 AX element 缺失或 raise 失败，仍激活 app 并隐藏面板。
- 不依赖 `.activateIgnoringOtherApps`，它在现代 macOS 上已不可靠且废弃。
- 不使用私有 WindowServer/front-process API。

### 预览面板 UI

- `PreviewPanelModels.swift`：anchor、卡片 view model、panel view model。
- `PreviewPanelLayoutEngine.swift`：根据 Dock item frame、鼠标位置和可见屏幕区域计算面板 frame。
- `PreviewPanelView.swift`：SwiftUI 横向卡片 UI。
- `PreviewPanelController.swift`：拥有非激活 `NSPanel`，负责 show/update/hide、Esc 监听和 panel frame 查询。
- `PreviewSessionController.swift`：会话状态机，负责权限抑制、max cards、retention 参数、窗口查询、缩略图更新、点击激活和鼠标离开轮询。

面板行为：

- `NSPanel` 使用 `.nonactivatingPanel`、`.borderless`、透明背景和 floating level。
- 面板可加入所有 Space，并支持 full-screen auxiliary。
- Dock-to-panel 移动使用窄桥接区保留。
- 常规 leave timer 使用 Dock frame、panel frame 和桥接区组成的 preview region。
- Dock hover lost 使用更严格的 panel transition region，避免相邻 Dock item 保留旧 panel。

## 主要流程

Dock hover：

1. Dock AX notification 到达。
2. `DockHoverMonitor` 解析候选 Dock app，并验证鼠标命中 Dock item。
3. `ProbeOrchestrator` 取消旧 pending work，读取 settings snapshot；若 disabled 或 app 被排除则安静隐藏/跳过，否则启动当前 hover delay。
4. 延迟结束后重新解析当前 Dock hover 候选。
5. 如果 bundle 或鼠标命中不匹配，隐藏/取消。
6. 如果权限允许，按当前 max cards 设置查询窗口。
7. 无窗口则隐藏。
8. 有窗口则显示 placeholder 卡片。
9. 缩略图异步返回后更新卡片。
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
- 窄窗口缩略图保持真实比例时，可能看起来没有铺满缩略图区域。
- Launch at Login 自动测试覆盖服务构造和 fake-driven menu tests；真实状态已通过签名后的 `build/zongMacTools.app` 和系统 Login Items 人工验证。

## 验收标准

MVP/P1 当前验收标准：

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

待补验收：

- Multiple displays。
