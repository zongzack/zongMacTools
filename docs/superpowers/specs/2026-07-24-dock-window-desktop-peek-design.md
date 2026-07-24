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
4. 鼠标进入另一张卡片时立即切换目标，不等待旧截图完成。
5. 鼠标离开所有卡片、点击卡片、按 Esc 或 Dock 会话失效时，桌面镜像和压暗层立即消失。

## 范围

首版范围内：

- 卡片级 hover 进入和离开事件。
- 原位置、原大小的非激活静态窗口镜像。
- 目标窗口所在屏幕的轻微压暗层。
- 已有缩略图到高清静态图的两阶段替换。
- 默认开启、可独立关闭的持久化设置。
- 快速切换、过期截图、会话隐藏和权限变化的统一取消规则。
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
- 鼠标进入窗口卡片后没有额外延迟，当前 run loop 内开始桌面预览。
- 切换卡片也不增加延迟。
- 桌面镜像不扩展现有 Dock-to-panel 鼠标保留区域。

### 视觉

- 镜像保持目标窗口查询时的全局 frame，不居中、不放大到屏幕最大尺寸。
- 目标屏幕压暗层使用固定 `0.22` 视觉强度，不提供首版设置项。
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

模型属性建议命名为 `isDesktopWindowPeekEnabled`，持久化 key 为 `DockHoverPreview.desktopWindowPeekEnabled`。缺少 key 时默认 `true`。关闭主 Dock 窗口速览时，桌面速览也必须停止；重新打开主功能后仍读取独立开关的持久化值。

首版不增加触发延迟和压暗强度设置，避免把仍需真实环境调校的视觉常量变成长期公开配置。

## 架构

### 组件边界

`PreviewCardView`：

- 继续负责卡片渲染和点击。
- 在 `.onHover` 中发送卡片进入或离开意图。
- 不直接创建截图任务或窗口面板。

`PreviewPanelAction`：

- 新增 `hoverEntered(PreviewWindowID)`。
- 新增 `hoverExited(PreviewWindowID)`。
- 保留现有 primary select、窗口操作和右键菜单事件。

`PreviewSessionController`：

- 继续拥有当前 `PreviewWindowID -> PreviewWindow` 映射和 panel generation。
- 将有效的卡片 hover 事件转交给 `WindowPeekCoordinator`。
- 当前卡片缩略图异步加载完成时，将新图通知 coordinator；高清图已经显示时不得被晚到的粗略图降级覆盖。
- 所有现有 session hide 路径必须先停止桌面速览。

`WindowPeekCoordinator`：

- 是桌面速览的唯一状态拥有者。
- 保存当前窗口 ID、独立 peek generation、当前图像质量和高清截图任务。
- 读取独立设置并协调粗略图、高清截图与覆盖层。
- 快速切换时使旧 generation 失效，不排队处理经过的每张卡片。
- 不直接实现 ScreenCaptureKit 或 AppKit panel 细节。

`WindowPeekCaptureService`：

- 为单个 `PreviewWindow` 生成一次高清静态 `CGImage`。
- 使用 `SCContentFilter(desktopIndependentWindow:)` 和 `SCScreenshotManager`。
- 不复用现有 `StaticThumbnailService` 的固定 `440 x 248` 输出和 10 秒缓存；桌面大图要求更高分辨率与更新鲜的画面。
- 不维护跨 hover 的长期图片缓存；任务结束或隐藏后只允许 coordinator 保留当前显示图。

`WindowPeekOverlayController`：

- 拥有鼠标穿透的压暗 panel 和镜像 panel。
- 只负责面板生命周期、窗口层级、屏幕几何与图片替换。
- 不判断 hover 是否过期，不读取设置，也不决定截图结果能否显示。
- 通过集中层级策略保持 `压暗层 < 镜像层 < 现有预览面板`。

`WindowPeekGeometry`：

- 从目标窗口 frame 和屏幕列表选择最大交集屏幕。
- 生成压暗 panel frame、镜像 panel frame 和跨屏裁切结果。
- 作为纯函数与 AppKit panel 创建分离，便于多显示器几何测试。

### 数据流

```text
PreviewCardView.hoverEntered(windowID)
  -> PreviewSessionController validates current session/window
  -> WindowPeekCoordinator starts a new peek generation
  -> show existing card thumbnail immediately when available
  -> WindowPeekCaptureService captures one high-resolution image
  -> validate generation + windowID
  -> WindowPeekOverlayController replaces coarse image in place
```

卡片现有缩略图尚未可用时，coordinator 仍启动高清截图，但不显示空白压暗层。后续任一有效图像到达时可以首次显示；高清图一旦显示，晚到的粗略图不得替换它。

## 状态模型

建议状态：

```text
idle
  -> pendingHighResolution(windowID, generation, coarseShown: Bool)
  -> showingHighResolution(windowID, generation)
  -> idle
```

状态内部记录当前图像质量，而不是通过 panel 是否可见推断。所有异步结果必须同时匹配当前 `generation` 和 `windowID`。

### 进入卡片

1. 确认桌面速览设置开启且窗口仍存在于当前会话映射。
2. peek generation 加一并取消旧高清任务。
3. 如果卡片已有缩略图，立即显示压暗层和粗略镜像。
4. 启动当前窗口的高清静态截图。
5. 高清图返回后重新验证 generation 和窗口 ID，再原地替换。

重复收到同一窗口的 `hoverEntered` 时不得重新创建覆盖层或重复截图；coordinator 对相同当前目标去重。

### 切换卡片

- 新窗口成为唯一当前目标，旧 generation 立即失效。
- 新卡片有粗略图时立即替换镜像，并复用正确屏幕上的压暗层。
- 新卡片没有粗略图时隐藏旧镜像和压暗层，避免继续显示错误窗口；新图可用后再显示。
- 旧截图即使无法及时取消，返回结果也只能被记录为 stale 并丢弃。

### 隐藏与取消

以下事件统一使 peek generation 失效、取消当前任务并隐藏两个覆盖层：

- 当前卡片 `hoverExited`，且没有另一张卡片同步成为新目标。
- 原预览面板因鼠标离开、Dock hover 失效、无候选、设置禁用或权限变化而隐藏。
- 用户按 Esc。
- 用户点击卡片准备激活真实窗口；必须先隐藏覆盖层，再执行激活。
- 用户开始打开卡片右键菜单；只隐藏桌面速览，原预览面板和菜单会话继续保留。
- 应用停止或 `PreviewSessionController` 被重置。

由于 SwiftUI 可能在内容更新时产生重复 hover 回调，离开和进入事件必须按窗口 ID 幂等处理。实现计划需要用最小原型或现有 SwiftUI 渲染测试确认缩略图更新不会造成持续闪烁；若 `.onHover` 在 root view 更新时不稳定，应将卡片 tracking 隔离到轻量 AppKit bridge，而不是在 coordinator 中增加隐藏延迟。

`hoverExited(id)` 只有在 `id` 仍等于当前目标时才能隐藏覆盖层。切换卡片过程中迟到的旧卡片 exit 事件必须直接忽略，不能清除已经显示的新目标。

## 截图策略

### 两阶段图像

阶段 1 使用当前 `PreviewCardViewModel.thumbnail`，只用于即时反馈。它可以来自现有缩略图缓存，因此允许短暂模糊或不够新。

阶段 2 对当前 `PreviewWindow.scWindow` 执行新的单次 ScreenCaptureKit 截图：

- `SCContentFilter(desktopIndependentWindow:)`
- `SCStreamConfiguration.showsCursor = false`
- `SCStreamConfiguration.ignoreShadowsSingleWindow = true`
- 输出宽高按目标窗口逻辑尺寸乘以目标屏幕 backing scale 计算。
- 保持窗口宽高比，并将总像素面积限制为最多 8,000,000 像素。
- 超过上限时使用 `sqrt(limit / desiredArea)` 等比缩小宽高。
- 宽高最终至少为 1，并转换成 ScreenCaptureKit 需要的整数像素。

8 百万 BGRA 像素的单图原始内存上限约为 32 MB。coordinator 在切换或隐藏时释放旧高清图引用，避免快速 hover 造成图片长期累积。

### 失败降级

- `PreviewWindow.scWindow == nil` 时不执行高清捕获。
- 高清截图失败且粗略图已显示时，保留粗略图直到 hover 结束。
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
- 不成为 key 或 main window

现有预览面板必须保持在两个新面板之上。层级关系通过一个集中策略设置并由 controller 测试验证，不在多个文件散落 magic numbers。

### 屏幕选择

- 选择与目标窗口 frame 交集面积最大的 `NSScreen.frame`。
- 没有正面积交集时退回原预览 anchor 对应屏幕；仍无法确定时不显示桌面速览。
- 压暗层只覆盖选中的目标屏幕，不压暗所有显示器。
- 镜像保持目标窗口全局位置，但裁切到目标屏幕 frame。
- 跨屏窗口首版只显示最大交集屏幕上的部分，不创建跨多个 backing scale 的拼接镜像。
- 全屏窗口使用 `screen.frame` 而不是 `visibleFrame`，避免菜单栏或 Dock 保留区错误缩小镜像。

多显示器真实行为仍受当前硬件条件限制。自动测试覆盖屏幕选择和裁切纯函数；硬件不可用时人工结果明确记录为 `blocked / not available`，不写成通过。

## 权限、隐私与错误处理

- 不新增系统权限。Dock 监听继续依赖辅助功能，截图继续依赖屏幕录制权限。
- 屏幕录制权限缺失时沿用当前策略：整个正常 Dock 预览静默抑制，不在 hover 路径弹窗。
- 设置在桌面速览可见期间关闭时，observer 必须立即隐藏覆盖层并取消截图。
- macOS 不为当前 `PermissionService` 提供权限变化推送；当现有权限刷新检测到撤销，或当前高清截图因权限失败时，必须隐藏覆盖层并继续静默降级，不承诺系统设置变化发生的同一时刻收到通知。
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
- 高清图只更新匹配当前 generation 和窗口 ID 的目标。
- 切换卡片使旧任务失效，并立即显示新卡片粗略图。
- 新卡片没有图像时隐藏旧覆盖层。
- 高清失败时保留粗略图；没有粗略图时保持隐藏。
- 高清图已显示后忽略晚到的粗略图。
- 重复进入同一窗口不会重复截图。
- hover exit、session hide、右键开始、设置关闭，以及权限刷新或截图失败检测到权限撤销时都取消并隐藏。
- 旧窗口迟到的 hover exit 不会隐藏已经切换的新窗口。

`WindowPeekCaptureServiceTests`：

- 分辨率策略保持宽高比。
- Retina scale 正确换算逻辑尺寸。
- 输出不超过 8,000,000 像素。
- 缺少 `SCWindow` 和截图异常时返回 nil。
- 配置关闭 cursor 并忽略单窗口阴影。

`WindowPeekGeometryTests`：

- 单显示器原位置映射。
- 多显示器最大交集选择。
- 跨屏窗口裁切到主交集屏幕。
- 无交集时使用 anchor fallback。
- 全屏使用完整 screen frame。

`WindowPeekOverlayControllerTests`：

- 两个 panel 均非激活且忽略鼠标。
- 层级顺序为压暗层、镜像层、原预览面板。
- update 只替换图像，不改变逻辑 frame。
- hide 清理逻辑 frame 和图像引用。

现有测试扩展：

- `PreviewPanelAction` hover 事件路由。
- `PreviewSessionController` 当前窗口校验、缩略图升级通知和所有 hide 路径联动。
- 设置默认值、持久化、observer、非法值回退和中英文文案。
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

环境回归覆盖：

- Dock 位于底部、左侧和右侧。
- Dock 自动隐藏。
- 浅色与深色外观。
- 减少动态效果。
- 全屏 Space。
- 台前调度。
- 多显示器和跨屏窗口；硬件不可用时记录 blocked。
- 截图失败、缺少可截图来源和快速关闭目标窗口。

## 验收标准

- 卡片 hover 没有额外定时延迟；有粗略图时 overlay show 调用发生在等待高清截图之前。
- 高清图不会覆盖另一个当前窗口，也不会在 hover 结束后重新显示。
- 桌面速览不改变真实应用激活状态、输入焦点或窗口层级。
- 所有 session hide 路径都不会留下镜像 panel 或压暗 panel。
- 功能关闭或图片不可用时，现有 Dock 预览行为保持不变。
- 截图任务是单次任务，不存在 hover 结束后持续运行的 SCStream。
- `swift test`、`swift build`、`Scripts/build_probe_app.sh` 和 `git diff --check` 通过。
- 核心 VS Code 三窗口人工场景通过；受硬件限制的环境明确记录状态，不虚报完成。

## 实施顺序约束

实现计划应按以下依赖顺序拆分：

1. 设置模型、文案和 action contract。
2. 纯函数截图尺寸与屏幕几何策略。
3. 可测试的高清截图服务。
4. 覆盖层 controller。
5. coordinator 状态机。
6. `PreviewSessionController` 与 SwiftUI hover 接线。
7. 自动测试、打包验证和人工验收清单。

若卡片 hover tracking 在 SwiftUI root view 更新时产生闪烁，先验证并隔离 tracking 实现，不通过增加用户不可见延迟掩盖状态问题。
