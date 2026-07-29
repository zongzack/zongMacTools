# Dock 窗口桌面速览设计

日期：2026-07-24

## 目标

在现有 Dock 窗口速览面板中，当鼠标进入某张窗口卡片时，立即在桌面上以目标窗口原始位置和大小显示该窗口的静态镜像。目标窗口所在屏幕同步轻微压暗，使用户能够辨认多个外观相近的 VS Code 项目窗口，同时不激活应用、不改变真实窗口层级，也不打断当前输入焦点。

首版使用两阶段静态预览：先立即放大卡片已有缩略图，再异步截取高清静态图并原地替换。功能提供独立开关，默认开启。

## 用户场景

用户同时打开三个 VS Code 项目。鼠标悬停 VS Code Dock 图标后，现有面板展示三张窗口卡片。鼠标进入其中一张卡片时：

1. 该窗口的已有缩略图立即按真实窗口 frame 显示在桌面上。
2. 目标屏幕以固定的轻量强度压暗，预览卡片面板继续保持在最上层。
3. 高清静态截图返回后，在相同位置替换粗略图。
4. 鼠标进入另一张卡片时立即切换显示目标；旧物理截图未完成时不显示其结果，完成后只为最新目标启动新的高清截图。
5. 鼠标离开所有卡片、点击卡片、按 Esc 或 Dock 会话失效时，桌面镜像和压暗层立即消失。

## 范围

首版范围内：

- 卡片级 hover 进入和离开事件。
- 原位置、原大小的非激活静态窗口镜像。
- 目标窗口所在屏幕的轻微压暗层。
- 已有缩略图到高清静态图的两阶段替换。
- 默认开启、可独立关闭的持久化设置。
- 快速切换、过期截图、会话隐藏和权限变化的统一取消规则。
- 在实现前验证公开 API 在 hover 时序、全屏 Space、窗口层级、截图取消和目标 AX window destroyed 通知上的实际行为。
- 单显示器自动测试和人工验收，多显示器几何自动测试与可用硬件上的人工验证。

首版范围外：

- ScreenCaptureKit 实时视频流或连续刷新。
- 在 hover 时调用 AX raise、激活应用或修改真实窗口层级。
- 精确复刻 Windows 将其他窗口变透明的系统级效果。
- 枚举其他 Space、恢复最小化窗口或主动切换全屏 Space。
- 用户可调的卡片级 hover 延迟、压暗强度、镜像尺寸或镜像位置。
- 在桌面镜像上提供点击、拖动、关闭、最小化等交互。
- 将截图写入磁盘、导出或发送到网络。

## 产品决策

### 触发

- Dock 图标的现有 hover delay 保持不变。
- 鼠标进入窗口卡片后没有额外的用户可见延迟；有粗略图时必须在同一 MainActor 处理内调用 overlay show，且该调用发生在启动高清捕获之前。
- 切换卡片也不增加延迟。
- 桌面镜像不扩展现有 Dock-to-panel 鼠标保留区域。
- 卡片 hover 的状态转换、右键菜单开始和主选择开始均不能经新的非结构化 `Task` 延后；只有真正异步的窗口查询和截图可以离开当前 MainActor 处理。

### 视觉

- 镜像保持目标窗口查询时的全局 frame，不居中、不放大到屏幕最大尺寸。
- 目标屏幕压暗层使用固定的纯黑 `alpha = 0.22`，不提供首版设置项。
- 粗略图按比例完整显示；短暂出现边缘留白优于拉伸或错误裁切。
- 高清图忽略单窗口系统阴影，覆盖层统一绘制轻量边框和阴影，避免截图阴影改变原始 frame 对齐。
- 压暗层、镜像层均不接收鼠标事件；现有窗口卡片继续处理 hover、点击和右键。
- 首版不为桌面镜像增加独立位移、缩放或淡入淡出动画，保证进入、切换和离开行为直接且可预测。

### 设置

Dock 窗口速览设置页新增一个开关：

- 简体中文标题：`桌面窗口预览`
- 简体中文说明：`悬停窗口卡片时在桌面显示高清镜像`
- English title: `Desktop Window Peek`
- English description: `Show a high-resolution desktop mirror when hovering a window card`

模型属性命名为 `isDesktopWindowPeekEnabled`，持久化 key 为 `DockHoverPreview.desktopWindowPeekEnabled`。缺少 key 或类型非法时使用 `true`。写入后立即从同一 `UserDefaults` 实例 read back；若值不是 CFBoolean 或与请求值不同，将这次同步写入视为失败，记录日志并使当前 snapshot 回退 `true`。首版不承诺检测 `UserDefaults` 在进程结束后才可见的磁盘耐久化失败。该字段必须完整接入 `DockHoverPreviewSettings`、`DockWindowQuickLookSettingsSnapshot`、`DockWindowQuickLookSettingsStore.update...` 的字段复制、`UserDefaults` 读取/写入、设置页状态、双语文案和 observer。关闭主 Dock 窗口速览时，桌面速览也必须停止；重新打开主功能后仍读取独立开关的持久化值。

首版不增加触发延迟和压暗强度设置，避免把仍需真实环境调校的视觉常量变成长期公开配置。

## 架构

### 组件边界

`PreviewCardView`：

- 继续负责卡片渲染和点击。
- 在 `.onHover` 中发送卡片进入或离开意图。
- 不直接创建截图任务或窗口面板。

`PreviewPanelAction`：

- 新增带 session epoch 和单调递增输入序号的 `hoverEntered(PreviewWindowID, sessionEpoch, sequence)` 与 `hoverExited(PreviewWindowID, sessionEpoch, sequence)`；`PreviewSessionController` 在每次开始替换 Dock session 前生成永不复用的 `sessionEpoch`，`PreviewPanelController` 或经原型验证后的 AppKit tracking bridge 在该 epoch 内从 1 开始产生 sequence。session epoch 不因 panel `update`、缩略图更新或 hide animation completion 改变。
- 新增同步的 `contextMenuWillOpen(PreviewWindowID)`，在调用 `NSMenu.popUpContextMenu` 前完成桌面速览隐藏。
- 保留现有 primary select、窗口操作和右键菜单事件。

`PreviewSessionController`：

- 继续拥有当前 `PreviewWindowID -> PreviewWindow` 映射和 panel generation。
- 将有效的卡片 hover 事件转交给 `WindowPeekCoordinator`。
- 在 `showPreview` 进入任何 `await` 前递增 session epoch，并同步调用 coordinator 的 `beginSession(epoch:)`；action closure 既验证现有 panel generation，也验证 action 的 epoch 与当前 epoch 相等。旧 epoch 的 enter、exit 和延迟 Esc hide 一律只记录 stale，不得影响新 panel session。
- 当前卡片缩略图异步加载完成时，将新图通知 coordinator；高清图已经显示时不得被晚到的粗略图降级覆盖。
- 开始替换已有 Dock session 时，必须在等待新的窗口查询前先停止旧桌面速览。
- 所有现有 session hide 路径必须先停止桌面速览；主选择必须先停止桌面速览，再激活真实窗口。
- App composition 将 Space 切换、屏幕重配、应用终止和当前目标 AX destroyed 事件直接转交 coordinator；session 不拥有系统 observer，只负责自己的会话 hide 路径。

`WindowPeekCoordinator`：

- 是桌面速览的唯一状态拥有者。
- 保存当前 session epoch、当前窗口 ID、独立 peek generation、当前图像质量和互斥 capture slot 状态。
- 读取独立设置并协调粗略图、高清截图与覆盖层。
- 只在当前 session epoch 内保存最后一个 hover sequence；epoch 不同的输入直接丢弃，当前 epoch 内忽略序号较小的 enter/exit。输入 sequence 只用于重排 hover enter/exit 与合并 A exit/B enter，绝不作为截图完成结果的有效性 fence。
- 每次有效的新目标转换生成独立的 `peekGeneration`。capture request 固定携带 `(sessionEpoch, peekGeneration, windowID)`；截图完成只在这三个字段仍等于当前 target 时才能显示。重复进入同一有效窗口可以推进 input sequence 并清除 pending exit，但不创建新 peek generation，也不能使已在飞截图错误过期。
- 快速切换时立即使旧 generation 逻辑失效。物理高清截图最多允许一个未返回的 `captureImage` 调用；若旧请求尚未返回，只记录最新目标，旧请求返回后只为该最新目标启动一次新截图，不为经过的卡片排队。
- 在飞 capture worker 一律不调用 `Task.cancel()`；隐藏和切换只使 generation 失效并清除 pending latest。worker 真实返回后，coordinator 才能在同一 MainActor 状态转移中原子地释放 capture slot，重新验证 pending latest，并在离开当前同步调用栈前占用 slot。
- 只对 `desktopPeekEligible` 的窗口显示粗略图或启动高清截图；该资格由窗口查询的 SCK/AX 匹配结果提供，不能从 `CGImage?` 是否存在推断。
- 一个序号更新的 enter 即使指向 ineligible、已消失或无法计算几何的窗口，也必须使旧目标失效、清除 pending latest 并隐藏 overlay，不能仅 `guard return`。
- 不直接实现 ScreenCaptureKit 或 AppKit panel 细节。

`WindowPeekLifecycleObserver`：

- 是唯一拥有系统生命周期通知 token 和当前 AX destroyed 订阅的 adapter。它分别显式接收 `NSWorkspace.shared.notificationCenter`（Space/app terminate）和 `NotificationCenter.default`（screen parameters）；`start` 只注册一次，`stop`、deinit 和 app termination 都必须从各自所属 center 移除全部 token，再清除 AX subscriber。
- AX subscriber 只保留一个当前 target。replace 时必须先对旧 element 执行 `AXObserverRemoveNotification`、从 main run loop common modes 移除旧 source，并清空旧 handler，才允许为新 pid/element 创建 observer、添加 `kAXUIElementDestroyedNotification` 和 source。`clear`、`stop` 与 deinit 必须幂等。
- C callback 的 refcon 只能指向生命周期长于 observer source 的 subscriber；callback 已在 main run loop 执行时，用 `MainActor.assumeIsolated` 同步进入 actor-isolated handler，并再次比较当前 target ID。不得把 `AXUIElement`、`AXObserver` 或 callback closure 跨 actor 传递，也不得用 `Task` 延后 destroyed 清理。
- app composition 以 weak coordinator capture 接收领域 lifecycle event，避免 observer -> closure -> coordinator -> observer retain cycle。

`WindowPeekCaptureService`：

- 为单个经确认可捕获的领域 `WindowPeekCaptureSource` 生成一次高清静态 `CGImage`；source 接口只暴露稳定窗口 ID，不暴露 ScreenCaptureKit 类型。
- `PreviewWindow` 保存可选的 `desktopPeekCaptureSource: (any WindowPeekCaptureSource)?` 和明确的 `desktopPeekEligible`。生产查询为已通过 AX 匹配的 SCK 窗口创建 `ScreenCaptureKitWindowPeekCaptureSource`；测试使用只含领域 ID 的 fake source，不构造系统禁止初始化的 `SCWindow`。
- 接收不含 ScreenCaptureKit 对象的 `WindowPeekCaptureConfiguration`，通过可注入的 `WindowPeekCaptureBackend` 执行截图。配置编码、eligibility 决策和结果分类都能在不查询真实系统窗口或 TCC 权限的单元测试中执行。
- 在新的 desktop-peek capture 抽象内，生产 `ScreenCaptureKitWindowPeekCaptureSource` 是唯一持有 `SCWindow` 的 source，`ScreenCaptureKitWindowPeekCaptureBackend` 是唯一创建 `SCContentFilter(desktopIndependentWindow:)`、`SCStreamConfiguration` 并调用 `SCScreenshotManager` 的 backend；现有缩略图 `ThumbnailSource` 不属于该抽象。nil source 或 backend 收到不匹配的 source 类型时返回 unavailable；真实 ScreenCaptureKit 调用抛错后权限仍存在则统一分类为 failed，不为未公开稳定语义的错误码建立 unavailable 映射。
- 返回可判别结果：`image(CGImage)`、`unavailable`、`permissionDenied`、`failed`；不得以单一 `CGImage?` 丢失权限失败原因。
- 只有 ScreenCaptureKit 窗口与 AX 窗口匹配的候选才标记为 `desktopPeekEligible`，并能显示粗略图或执行高清捕获。AX fallback 或未匹配的台前调度候选没有桌面速览来源，不显示桌面覆盖层。
- 不复用现有 `StaticThumbnailService` 的固定 `440 x 248` 输出和 10 秒缓存；桌面大图要求更高分辨率与更新鲜的画面。
- 不维护跨 hover 的长期图片缓存；任务结束或隐藏后只允许 coordinator 保留当前显示图。

`WindowPeekOverlayController`：

- 拥有鼠标穿透的压暗 panel 和镜像 panel。
- 只负责面板生命周期、窗口层级、已计算的几何和图片替换。
- 不判断 hover 是否过期，不读取设置，也不决定截图结果能否显示。
- 通过集中层级策略保持 `压暗层 < 镜像层 < 现有预览面板`：压暗层为现有 `.floating` 面板低 2 级，镜像层低 1 级，现有面板保持 `.floating`。三个等级都必须低于公开的 Dock window level；overlay 不使用 `orderFrontRegardless()`。
- 两个 panel 均使用 `.borderless`、`.nonactivatingPanel`、`ignoresMouseEvents = true`、`hidesOnDeactivate = false`、`.canJoinAllSpaces`、`.transient`、`.fullScreenAuxiliary`，并通过子类保证 `canBecomeKey == false`、`canBecomeMain == false`。
- 粗略图始终在完整 `windowAppKitFrame` 的 image view 中 aspect-fit，再由 `mirrorFrame` clip。高清图已经按 `pointCropRect` 裁为 mirror fragment 后，image view 固定铺满 mirror panel bounds，并使用独立 X/Y scaling（或等价的 layer `.resize`）填满；不得再 aspect-fit 而留下条带。像素裁切的 floor/ceil 最多带来一像素比例误差，以完整覆盖和 frame 对齐优先。
- 为自动测试提供名称稳定的只读 inspection value（而非散落的 `...ForTesting` property）：它必须暴露实际 dimming/mirror `NSPanel`、逻辑 frame、image-view frame、image scaling、clipping 和当前 image pixel size。`PreviewPanelController` 同样提供只读 panel inspection；hover intent 则使用生产路径的 `routeHoverIntent(windowID:isInside:)`，测试不得调用不存在的专用路由。

`WindowPeekGeometry`：

- 复用或提取现有 `WindowEnvironmentDescriptor` 的最大交集屏幕选择逻辑，而不是复制另一套规则。
- `PreviewWindow.captureFrame` 明确表示 ScreenCaptureKit/AX/CGWindow 使用的左上角原点、Y 向下 capture space；不得再使用含义不明的 `PreviewWindow.frame`。`WindowPeekLayout.windowAppKitFrame` 明确表示 AppKit 全局坐标，进入 overlay 前必须完成转换。
- `WindowPeekScreen` 用同一 display ID 成对保存 `CGDisplayBounds(displayID)` 的 `captureFrame` 和 `NSScreen.frame` 的 `appKitFrame`，以及 backing scale。屏幕选择只比较 capture-space frame，禁止跨坐标空间直接求交。
- 对选中屏幕上的 `captureRect`，AppKit 映射固定为 `x = appKitFrame.minX + captureRect.minX - captureFrame.minX`、`y = appKitFrame.maxY - (captureRect.maxY - captureFrame.minY)`，宽高不变。该公式同时用于完整窗口 frame 和屏幕交集 fragment，覆盖上/下/左/右及负坐标显示器。
- layout 输出选中屏幕、AppKit `windowAppKitFrame`、AppKit `mirrorFrame`，以及以完整窗口左上角为原点、Y 向下的 capture-point `pointCropRect`。
- 高清像素裁切 rect 必须在图像返回后基于实际 `CGImage.width/height` 计算。`scaleX = image.width / windowCaptureFrame.width`、`scaleY = image.height / windowCaptureFrame.height`；min 边向下取整、max 边向上取整后夹到图像边界。`CGImage.cropping(to:)` 的 `(0, 0)` 是图像数据第一行，因此 pixel Y 与 capture-point Y 同为向下，不能再做一次垂直翻转。
- 粗略图不做不可证明的 bitmap 裁切：overlay 在完整 `windowAppKitFrame` 大小的 image view 中 aspect-fit 显示缩略图，再由 `mirrorFrame` panel clipping 到目标屏幕片段。这样不会把完整窗口压缩进跨屏片段，短暂留白仍符合视觉决策。
- 生成压暗 panel frame、镜像 panel frame 和跨屏裁切结果。
- 作为纯函数与 AppKit panel 创建分离，便于多显示器几何测试。

### 数据流

```text
PreviewCardView.hoverEntered(windowID)
  -> PreviewSessionController synchronously validates current session epoch + input sequence and forwards an optional window
  -> WindowPeekCoordinator starts a new peek generation for a desktopPeekEligible window
  -> show existing card thumbnail immediately when available
  -> WindowPeekCaptureService captures one high-resolution image when no physical capture is in flight
  -> validate capture request sessionEpoch + peekGeneration + windowID
  -> WindowPeekOverlayController replaces coarse image in place
```

卡片现有缩略图尚未可用时，coordinator 仍启动高清截图，但不显示空白压暗层。后续任一有效图像到达时可以首次显示；高清图一旦显示，晚到的粗略图不得替换它。

## 状态模型

建议状态：

```text
idle
  -> pendingHighResolution(sessionEpoch, windowID, peekGeneration, coarseShown: Bool, capture: inFlight | waitingLatest)
  -> showingHighResolution(sessionEpoch, windowID, peekGeneration)
  -> idle
```

状态内部记录当前图像质量，而不是通过 panel 是否可见推断。input sequence 只决定是否接受 enter/exit；所有异步 capture 结果必须同时匹配当前 `sessionEpoch`、`peekGeneration` 和 `windowID`，不要求匹配“最新 hover sequence”。capture slot 使用互斥状态 `idle` 或 `capturing(activeRequest, pendingLatest)`；在飞请求可以已经不是当前显示目标，不能用 panel 可见性推断。

“最多一个物理截图”的可验收定义是：任意时刻最多一个尚未返回的公开 `SCScreenshotManager.captureImage` async 调用。公开 API 无法观测 WindowServer 内部工作是否已经停止，因此不对不可观测的内部状态作更强承诺；生产代码固定不取消在飞调用，以保守地避免已知请求重叠。

### 进入卡片

1. 先比较 session epoch；旧/未知 epoch 直接忽略。当前 epoch 内再比较 hover sequence；旧序号直接忽略，新序号先成为最新值。相同有效目标的重复 enter 只清除待处理 exit，不重新截图，也不改变该 target 的 peek generation。
2. 对其他新 enter，先递增 peek generation、使旧结果失效并清除旧 pending latest，再检查设置、窗口映射、eligibility 和几何。如果新目标 ineligible、不存在或无法计算几何，立即清空当前目标、停止目标窗口监听并隐藏 overlay，不能在失效旧目标前 `guard return`。
3. 如果卡片已有缩略图，立即显示压暗层和粗略镜像。
4. 若没有物理截图在飞，启动当前窗口的高清静态截图；否则覆盖 `pendingLatestTarget`，不启动第二个物理截图。
5. 高清图返回后重新验证 request 的 session epoch、peek generation 和窗口 ID，再原地替换；不能因同目标的较新 input sequence 而错误丢弃结果。

重复收到同一窗口的 `hoverEntered` 时不得重新创建覆盖层或重复截图；coordinator 对相同当前目标去重。

### 切换卡片

- 新窗口成为唯一当前目标，旧 generation 立即失效；同一 run loop 中的旧卡片 exit 不得引起中间 hide。
- 新卡片有粗略图时立即替换镜像，并复用正确屏幕上的压暗层。
- 新卡片没有粗略图时隐藏旧镜像和压暗层，避免继续显示错误窗口；新图可用后再显示。
- 旧截图即使无法及时取消，返回结果也只能被记录为 stale 并丢弃。

### 隐藏与取消

以下事件统一使 peek generation 逻辑失效、清除 pending latest 并隐藏两个覆盖层；已进入 `captureImage` 的 worker 不取消，返回后仅按 stale 处理：

- 当前卡片 `hoverExited`，且没有另一张卡片同步成为新目标。
- 新 Dock session 开始替换旧 session。
- 原预览面板因鼠标离开、Dock hover 失效、无候选、设置禁用或权限变化而隐藏。
- 用户按 Esc。
- 用户点击卡片准备激活真实窗口；必须先隐藏覆盖层，再执行激活。
- 用户开始打开卡片右键菜单；只隐藏桌面速览，原预览面板和菜单会话继续保留。
- 应用停止或 `PreviewSessionController` 被重置。
- `NSWorkspace.activeSpaceDidChangeNotification`、屏幕参数变化或当前显示器不可用。
- 当前 eligible 目标的 AX element 发出公开 `kAXUIElementDestroyedNotification`；应用进程继续运行时也必须清理 overlay。

由于 SwiftUI 可能在内容更新时产生重复 hover 回调，离开和进入事件必须按窗口 ID 与 sequence 幂等处理。实现前必须用最小原型确认缩略图更新不会重排事件；若 `.onHover` 在 root view 更新时不稳定，首版改用轻量 AppKit tracking bridge，而不是在 coordinator 中增加隐藏延迟。

`hoverExited(id, sessionEpoch, sequence)` 只有 epoch 是当前 epoch、sequence 是该 epoch 最新序号且 `id` 仍等于当前目标时才能请求 hide。迟到的 enter 和 exit 都必须直接忽略，不能重新显示或清除已经显示的新目标。

Esc 由现有 panel 的 local/global key monitor 在其同步 main-thread callback 内发起；实现用 `MainActor.assumeIsolated` 直接调用当前 hide handler，不创建 `Task`。hide request 必须携带当前 panel session epoch，`PreviewSessionController` 仅在它等于当前 epoch 时处理。因此即使平台在 session 替换后递送旧 monitor callback，也不能隐藏新 session。

## 截图策略

### 两阶段图像

阶段 1 使用当前 `PreviewCardViewModel.thumbnail`，只用于即时反馈。它可以来自现有缩略图缓存，因此允许短暂模糊或不够新。缩略图在完整 `windowAppKitFrame` 的内容视图中 aspect-fit，再由 `mirrorFrame` 裁切显示；不直接对来源比例未知的缩略图执行 `CGImage.cropping(to:)`。

阶段 2 对当前 `PreviewWindow` 的生产 `ScreenCaptureKitWindowPeekCaptureSource` 执行新的单次 ScreenCaptureKit 截图：

- `SCContentFilter(desktopIndependentWindow:)`
- `SCStreamConfiguration.showsCursor = false`
- `SCStreamConfiguration.ignoreShadowsSingleWindow = true`
- 明确设置保持宽高比的配置；请求宽高按查询时的目标窗口逻辑尺寸乘以选中目标屏幕 backing scale 计算。
- 先按 `sqrt(limit / desiredArea)` 等比缩小，再向上取整为至少 1 的整数像素；取整后再次缩小，确保最终 `width * height <= 8,000,000`。
- 跨屏窗口先按完整窗口的查询时 capture-space frame 截图，图像返回后再用实际 `CGImage.width/height` 将选中屏幕的点裁切区映射为像素 rect；首版不拼接不同 backing scale 的片段。
- 高清图按实际输出尺寸执行 capture-point 到 pixel 的映射和裁切；粗略图使用完整窗口 image view 加 panel clipping。两个阶段最终显示的窗口内容区域必须对应同一个 `mirrorFrame`。

8 百万 SDR BGRA 像素的单图原始内存上限约为 32 MB。coordinator 在切换、隐藏和图片替换时同时清除自己的高清图引用与 overlay content image；由于物理截图最多一个在飞，最多保留当前显示图和一个在飞结果，不能随 hover 次数累积。

### 失败降级

- `PreviewWindow.desktopPeekCaptureSource == nil`、候选未通过 AX 匹配或 `WindowPeekCaptureService` 返回 `unavailable` 时不执行高清捕获。
- `failed` 且粗略图已显示时保留粗略图直到 hover 结束；`permissionDenied` 时复查权限，若仍缺失则立即隐藏覆盖层和取消当前 peek。
- 两阶段都没有图像时不显示压暗层、loading 或错误占位。
- 受保护内容返回空白但未抛错时首版不做像素级黑屏检测；行为与系统截图能力一致，并在人工验收中记录。

## 覆盖层与屏幕几何

### 面板属性

压暗层和镜像层使用无标题、非激活、透明背景的 `NSPanel`：

- `.borderless`
- `.nonactivatingPanel`
- `ignoresMouseEvents = true`
- `hidesOnDeactivate = false`
- `collectionBehavior` 包含 `.canJoinAllSpaces`、`.transient` 和 `.fullScreenAuxiliary`
- 通过 panel 子类不成为 key 或 main window

现有预览面板必须保持在两个新面板之上。层级关系通过一个集中策略同时供 `PreviewPanelController` 和 `WindowPeekOverlayController` 使用并由 controller 测试验证，不在多个文件散落 magic numbers；设置等级后还要断言 overlay 均低于公开 Dock window level。

### 屏幕选择

- 选择与目标窗口 capture-space frame 交集面积最大的 `WindowPeekScreen.captureFrame`，复用现有坐标无关的共享选择函数。选定后才将交集转换为 AppKit-space overlay frame。
- 没有任何 capture-space 正面积交集时不显示桌面速览。成对 screen-local 转换是双射；无 capture 交集的窗口转换后也不会与对应 AppKit screen 相交，因此 anchor 不能构成保持原位置语义的有效 fallback。
- 压暗层只覆盖选中的目标屏幕，不压暗所有显示器。
- 镜像保持目标窗口全局位置，但裁切到目标屏幕 frame。
- 跨屏窗口首版只显示最大交集屏幕上的部分，不创建跨多个 backing scale 的拼接镜像。
- 全屏窗口使用 `screen.frame` 而不是 `visibleFrame`，避免菜单栏或 Dock 保留区错误缩小镜像。

多显示器真实行为仍受当前硬件条件限制。自动测试覆盖屏幕选择和裁切纯函数；硬件不可用时人工结果明确记录为 `blocked / not available`，不写成通过。

## 权限、隐私与错误处理

- 不新增系统权限。Dock 监听继续依赖辅助功能，截图继续依赖屏幕录制权限。
- 屏幕录制权限缺失时沿用当前策略：整个正常 Dock 预览静默抑制，不在 hover 路径弹窗。
- 设置在桌面速览可见期间关闭时，observer 必须立即隐藏覆盖层并取消截图。
- macOS 不为当前 `PermissionService` 提供权限变化推送；当现有权限刷新检测到撤销，或 `WindowPeekCaptureService` 返回 `permissionDenied` 且复查仍缺失时，必须隐藏覆盖层并继续静默降级，不承诺系统设置变化发生的同一时刻收到通知。普通 `failed` 不等同于权限撤销。
- 截图只存在内存中，不写入诊断导出、缓存文件、剪贴板或网络。
- 覆盖层创建或截图失败只记录日志并安静降级，不影响原卡片预览和点击激活。

建议日志事件：

- `peek.show id=... source=coarse screen=...`
- `peek.capture.started id=... generation=...`
- `peek.capture.success id=... width=... height=... elapsedMS=...`
- `peek.capture.failed id=... reason=...`
- `peek.capture.stale id=... generation=... current=...`
- `peek.update id=... source=highResolution`
- `peek.hide reason=...`

日志不记录图片内容，也不新增窗口标题之外的敏感数据。

## 测试设计

### 自动测试

`WindowPeekCoordinatorTests`：

- 进入卡片时先同步显示已有粗略图，再启动高清任务。
- 高清图只更新 request 的 session epoch、peek generation 和窗口 ID 均匹配当前 target 的目标。
- 同一 target 的较新 hover input sequence 不会使旧 request 的高清图失效；只有 request 的 session epoch、peek generation 或窗口 ID 不匹配时才丢弃结果。
- 新 session epoch 从 sequence 1 重新开始仍可被接受；旧 epoch 即使 sequence 更大也不能 stop、显示或排队新 session 的 capture。
- 切换卡片使旧任务失效，并立即显示新卡片粗略图。
- 新卡片没有图像时隐藏旧覆盖层。
- 高清失败时保留粗略图；没有粗略图时保持隐藏。
- 高清图已显示后忽略晚到的粗略图。
- 重复进入同一窗口不会重复截图。
- 从 eligible A 切换到 ineligible、已消失或无几何的 B 会使 A 失效并立即隐藏，不保留 A 的 pending capture。
- hover enter/exit 的任意乱序组合均只接受最新 sequence；A exit 与 B enter 同轮发生时没有中间 hide。
- 新 Dock session 开始、session hide、右键菜单打开前、主选择激活前、设置关闭、Space 切换、屏幕重配，以及权限刷新或 `permissionDenied` 复查确认撤销时都使逻辑状态失效并隐藏；在飞物理调用继续等待真实返回。
- 验证主选择和右键菜单的调用顺序为 `peek.hide` 在激活或 `NSMenu.popUpContextMenu` 之前。
- 注入可暂停的 capture gate，验证未返回的 capture 调用数最多为 1；stop 和 hover 切换不取消 worker，旧请求返回后只启动并显示当时仍有效的最新目标。
- 注入可控的 run-loop exit scheduler；测试显式 flush，生产 adapter 在执行回调时显式恢复 MainActor 隔离，不依赖不确定的真实 run loop 时序。

`WindowPeekCaptureServiceTests`：

- 分辨率策略保持宽高比。
- Retina scale 正确换算逻辑尺寸。
- 输出不超过 8,000,000 像素。
- 缺少领域 capture source、backend unavailable、权限拒绝和普通截图异常返回不同的可判别结果。
- 配置关闭 cursor 并忽略单窗口阴影。
- 取整后的输出面积仍不超过 8,000,000 像素。
- 单元测试通过 fake source 和 fake backend 检查领域配置和结果分类，不构造 `SCWindow`、不查询真实 `SCShareableContent`、不要求 TCC 权限。

`WindowPeekGeometryTests`：

- 单显示器 capture-space 到 AppKit-space 原位置映射。
- 副屏在主屏上/下/左/右、负坐标时的双坐标 frame 转换与最大交集选择。
- 跨屏窗口裁切到主交集屏幕。
- 混合 backing scale 和 8,000,000 像素降采样时，像素裁切使用实际图像尺寸而非 backing scale。
- 顶部、底部、左侧和右侧裁切均覆盖 `CGImage` 像素 Y 方向、floor/ceil 和 clamp。
- 粗略图完整窗口 image view 的 clipping offset 与高清像素裁切都对应同一个 mirror frame。
- 无 capture-space 交集时返回 nil 并停止旧目标。
- 全屏使用完整 screen frame。

`WindowPeekOverlayControllerTests`：

- 两个 panel 均非激活且忽略鼠标。
- 两个 panel 都不能成为 key/main，层级顺序为压暗层、镜像层、原预览面板，且低于 Dock window level。
- 粗略图的完整窗口 offset/clipping 与高清图的 bounds-fill/image scaling 均有断言；高清图不得留下 aspect-fit 条带。
- update 只替换图像，不改变逻辑 frame。
- hide 清理逻辑 frame 和图像引用。

现有测试扩展：

- `PreviewPanelAction` 的 session epoch + sequence 化 hover 路由、同步的右键菜单开始回调，以及过期 epoch Esc hide 不影响新 session 的回归测试。
- `WindowQueryService` 纯决策测试覆盖只有 SCK source 与 AX match 同时成立才产生 desktop-peek source/eligibility；AX fallback 与未匹配候选均为 ineligible。
- `PreviewSessionController` 当前窗口校验、session 替换、缩略图升级通知和所有 hide 路径联动。
- 目标 AX element destroyed 事件在应用进程仍运行时也会先停止 peek 再清理监听。
- 设置默认值、同步 read-back 失败、snapshot 字段复制、observer、非法值回退、中英文标题/说明、主开关禁用态；更新其他 Dock 设置时不得改变独立开关。
- 现有点击、右键菜单、面板保留和 stale hover 测试保持通过。

### 人工验收

核心场景使用三个内容明显不同的 VS Code 项目窗口：

1. 进入每张卡片后桌面粗略图立即出现，随后在原位置变清晰。
2. 目标屏幕轻微压暗，原预览面板仍清晰、可 hover、可点击。
3. 快速来回扫过三张卡片，不出现旧窗口覆盖新窗口或残留压暗层。
4. 点击卡片前覆盖层消失，随后激活正确真实窗口。
5. 整个 hover 过程不改变前台应用、输入焦点或真实窗口层级。
6. 右键菜单打开时桌面速览隐藏，现有窗口操作仍可使用。
7. 独立设置关闭后立即停止，重新开启后恢复。
8. 先显示桌面速览，再按 Esc、切换普通 Space、切换全屏 Space、拔除目标显示器或在应用继续运行时关闭目标窗口；每次都不留下 overlay。关闭窗口的验收边界是 AX destroyed 事件被主 run loop 处理后的下一次 UI 更新，不承诺系统回调前的毫秒时限。
9. 台前调度同时准备当前分组和最近使用分组；只有已确认匹配的窗口显示高清镜像，其他候选不显示错误镜像。
10. Dock 自动隐藏、左/右 Dock、右键菜单、菜单栏和通知中心均保持可见且可交互；overlay 不抢焦点。

环境回归覆盖：

- Dock 位于底部、左侧和右侧。
- Dock 自动隐藏。
- 浅色与深色外观。
- 减少动态效果。
- 全屏 Space，以及切入/切出全屏 Space 时的 overlay 清理。
- 台前调度的当前分组与最近使用分组。
- 多显示器位于主屏上/下/左/右、负坐标、跨屏窗口和不同 backing scale；同时开启和关闭“显示器拥有单独 Space”。硬件不可用时记录 blocked。
- 截图失败、缺少可截图来源和快速关闭目标窗口。

## 验收标准

- 卡片 hover 没有额外的用户可见定时延迟；有粗略图时 overlay show 调用在同一 MainActor 处理内发生，且先于高清截图启动。高清图的完成时间不作固定毫秒承诺。
- 高清图只在 request 的 session epoch、peek generation 和窗口 ID 仍为当前值时更新；它不会覆盖另一个当前窗口，也不会在 hover 结束、session 替换、Space 切换或屏幕重配后重新显示。同一 target 的无害 hover 重复不得使在飞 request 永久 stale。
- 切换到 ineligible/已消失目标或收到当前目标的 AX destroyed 事件后，旧镜像和 pending latest 都立即失效。
- 桌面速览不改变真实应用激活状态、输入焦点或窗口层级。
- 所有 session hide 路径、session 替换和 Space/屏幕生命周期路径都不会留下镜像 panel 或压暗 panel。
- 功能关闭或图片不可用时，现有 Dock 预览行为保持不变。
- 截图任务是单次任务，不存在 hover 结束后持续运行的 SCStream；任意时刻最多一个未返回的 `captureImage` 调用。
- `swift test`、`swift build`、`Scripts/build_probe_app.sh` 和 `git diff --check` 通过。
- 核心 VS Code 三窗口人工场景通过；受硬件限制的环境明确记录状态，不虚报完成。

## 实施顺序约束

实现计划应按以下依赖顺序拆分：

1. 最小技术原型：验证 SwiftUI/AppKit hover 时序、公开窗口层级、全屏 Space、`SCScreenshotManager` 取消后的实际在飞行为。
2. 设置模型、文案和共享领域契约。
3. 复用后的纯函数双坐标屏幕几何、截图尺寸与实际图像像素裁切策略。
4. 不要求测试构造 `SCWindow` 的 capture backend/service 边界，以及可判别的失败结果。
5. 覆盖层 controller 和与现有 preview panel 共享的公开层级策略。
6. 不取消在飞 worker、只保留唯一 pending latest 的 coordinator 状态机。
7. session epoch + sequence 化 action、`PreviewSessionController`、workspace/AX destroyed 生命周期与 hover tracking 接线。
8. 自动测试、打包验证和人工验收清单。

若卡片 hover tracking 在 SwiftUI root view 更新时产生闪烁，先验证并隔离 tracking 实现，不通过增加用户不可见延迟掩盖状态问题。
