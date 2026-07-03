# Dock Hover Preview P2 UI Polish 设计

日期：2026-07-02

## 背景

`zongMacTools` 当前是 macOS 菜单栏工具，打包输出为 `build/zongMacTools.app`，SwiftPM executable / target 仍为 `DockHoverPreviewProbe`。MVP/P0 和 P1 已完成：Dock hover preview、stale hover cancellation、Screen Recording 缺失静默抑制、P1 settings、Launch at Login、excluded apps、display language 均已经过自动验证和必要人工验证。

P2 只处理 preview panel 的视觉和交互 polish。它不改变窗口查询范围、权限策略、hover 触发链路、激活能力或 P1 默认行为。

## P2 目标

- 为缩略图增加明确显示策略：保持比例 / 裁切填满。
- 改善 Typora 等窄窗口缩略图在固定卡片里的展示效果。
- 增加轻量 show / hide 动画，并在 Reduce Motion 打开时禁用或降级。
- 优化 loading 和 thumbnail 失败时的 placeholder 状态。
- 优化多窗口标题截断、卡片宽度和横向/纵向布局稳定性。
- 复查 Light / Dark 下的 material、border、shadow 和文字可读性。

## 非目标

- 不实现实时视频缩略图。
- 不实现窗口关闭、最小化、隐藏、右键菜单等 P3 功能。
- 不做独立设置窗口或 release 流程。
- 不使用私有 API。
- 不复制、翻译或机械改写 DockDoor GPLv3 源码、结构、helper、注释或 private API wrapper。
- 不改变窗口枚举范围，不支持最小化窗口、其他 Space 窗口或跨 Space 主动切换。
- 不改变 Screen Recording 缺失时静默抑制 preview UI 的策略。
- 不削弱 stale hover cancellation。
- 不改变 P1 默认行为或 settings 数据模型，除非实施文档明确论证且保持向后兼容。

## 当前 UI 状态和痛点

当前 preview panel 由以下文件组成：

- `PreviewPanelModels.swift`：`PreviewCardViewModel` 只有 `thumbnail: CGImage?` 与 `isLoadingThumbnail`，没有缩略图显示模式、placeholder 原因或尺寸语义。
- `PreviewPanelLayoutEngine.swift`：只负责 panel frame 与 bottom/left/right Dock 的布局方向，不负责卡片内部视觉。
- `PreviewPanelView.swift`：固定卡片尺寸 `232 x 172`，缩略图区 `220 x 124`，图片使用 `.scaledToFill()`，标题单行 tail truncation，loading 为 app icon + spinner，panel 使用 `.regularMaterial`、1px primary opacity border 和固定 shadow。
- `PreviewPanelController.swift`：`show` 直接 `setFrame` + `orderFrontRegardless()`，`hide` 直接 `orderOut(nil)`，没有动画，也没有 Reduce Motion 判断。
- `PreviewSessionController.swift`：先显示 placeholder 卡片，再异步逐张更新缩略图；用 generation 抑制 stale async update；Screen Recording 缺失时调用 `hide(reason: "screenRecording=false")` 并静默跳过。

主要痛点：

- 窄窗口在 `scaledToFill` 下可能被过度裁切；如果改成统一 `scaledToFit`，又会出现大面积空白，卡片显得松散。
- loading 和 thumbnail failed 都表现为近似同一个 app icon placeholder，用户无法感知“正在加载”和“没有可用缩略图”的区别。
- 多窗口标题只有固定 `208` 宽度，长标题会截断得过早；多窗口横向滚动时，每张卡片宽度固定，缺少针对常见长标题的策略。
- show/hide 瞬间出现和消失，功能稳定但不够成熟；动画若处理不当又可能制造 stale panel 残影。
- Light / Dark 当前依赖系统 material 与 `Color.primary.opacity(...)`，需要用截图和人工 checklist 复核边框、阴影、hover state 和文字对比。

## 缩略图显示模式设计

P2 推荐引入一个小型、UI 层可测试的显示枚举：

```swift
enum ThumbnailDisplayMode: String, CaseIterable, Sendable {
    case fit
    case fill
}
```

命名对用户文档使用中文：

- 保持比例：对应 `.fit`，完整显示窗口内容，不裁切，允许 letterbox/pillarbox。
- 裁切填满：对应 `.fill`，填满缩略图区，允许裁切边缘。

默认值建议保持当前视觉行为：`.fill`。原因：

- 当前 P1 默认行为和视觉肌肉记忆是填满卡片。
- 改成 `.fit` 会让所有既有宽屏窗口视觉密度下降，属于默认行为变化。
- P2 的窄窗口改善可以通过自动窄窗口策略解决，不需要改变全局默认。

是否接入 P1 settings：

- P2 可以先把 `ThumbnailDisplayMode` 作为 ViewModel / UI 内部策略，不写入 `UserDefaults`，默认 `.fill`。
- 如果要提供用户可选项，必须作为新增可选 setting key，例如 `DockHoverPreview.thumbnailDisplayMode`，默认 `.fill`，非法值回退 `.fill`，不修改现有 key，不迁移 P1 数据。
- 本轮 P2 推荐先实现内部策略和测试；菜单暴露开关可作为后续 P2b，因为用户明确要求不要改变 P1 settings 数据模型，除非文档论证且向后兼容。

### 保持比例

`.fit` 的渲染规则：

- `Image(decorative: ...).resizable().scaledToFit()`。
- 缩略图容器尺寸固定，不因图片比例改变。
- 背景使用低对比 surface，避免空白区域看起来像缺失内容。
- 对超窄窗口使用 centered fit；不拉伸，不单独放大到超过容器。

适用场景：

- 窄窗口、编辑器侧栏、小工具窗口、近似手机比例窗口。
- 需要识别完整窗口边界和文字位置时。

### 裁切填满

`.fill` 的渲染规则：

- `Image(...).resizable().scaledToFill()`。
- 缩略图区固定 clip 到圆角矩形。
- 用于常规宽屏窗口，维持现有视觉密度。

适用场景：

- 大多数桌面窗口。
- 多窗口快速扫视时更像成熟 Dock preview。

### 窄窗口策略

推荐在 ViewModel 中记录窗口 frame 或 thumbnail aspect ratio，并计算每张卡片的有效显示模式：

- 如果用户/全局模式是 `.fit`，所有图片保持比例。
- 如果用户/全局模式是 `.fill`，但窗口内容过窄，则自动降级为 `.fit`。
- 窄窗口判断建议使用窗口 frame aspect ratio：`width / height < 1.2` 视为窄窗口；如果 frame 缺失，再用 thumbnail `CGImage.width / height`。
- 对极窄窗口，缩略图仍占用固定容器，内层图片保持完整显示，周围使用 placeholder surface，不改变卡片宽高。

这样 Typora 等窄窗口能显示完整内容，同时 VS Code / Chrome / WPS 等普通窗口仍保持当前填满观感。

## Loading / Placeholder 状态设计

状态必须区分“正在加载”和“没有可用缩略图”，但不能增加干扰文案。

建议新增 UI 状态：

```swift
enum ThumbnailVisualState {
    case loading
    case image(CGImage)
    case unavailable
}
```

`CGImage` 本身不 conform `Equatable`，所以不要依赖自动合成的 `Equatable`。如果测试需要比较状态，推荐测试不带图片 payload 的派生状态，例如 `thumbnailPlaceholderState`；也可以继续保留 `thumbnail`，但 ViewModel 至少要能区分：

- loading：`thumbnail == nil && isLoadingThumbnail == true`
- unavailable：`thumbnail == nil && isLoadingThumbnail == false`

Loading 设计：

- 保持固定缩略图容器尺寸。
- 背景为 material/surface 上的 subtle skeleton，不改变布局。
- app icon 居中，spinner 小号放在 icon 下方或右下角。
- 如果 thumbnail 很快返回，loading 不需要人为延迟；测试只验证布局不跳。

Unavailable placeholder 设计：

- 无 spinner。
- 显示 app icon + 低对比 “No thumbnail” / “无缩略图” 文案，文案由 `AppTextProvider` 提供。
- 语言选择应在 `PreviewSessionController` 构建 ViewModel 时完成：读取当前 settings snapshot 的 `displayLanguage`，用 `AppTextProvider` 生成 `thumbnailUnavailableText`，再随 `PreviewPanelViewModel` 传给 SwiftUI。`PreviewPanelView` 不直接读取 settings，也不硬编码英文。
- 对 AX fallback 且 `thumbnailSource == nil` 的 Stage Manager 场景，必须继续只显示安静 placeholder，不尝试 CoreGraphics 或桌面区域截图。
- 缩略图失败日志仍保持稳定英文事件名，不跟随语言切换。

## 标题截断、卡片宽度和布局稳定性

卡片尺寸应保持稳定。P2 不做根据标题动态改变 panel 宽度的方案，因为它会导致缩略图加载、多窗口数量变化或语言切换时 panel 跳动。

推荐策略：

- 保持默认卡片宽度 `232`，作为 P1/P0 兼容基线。
- 将标题行宽度从硬编码 `208` 改为由 `PreviewPanelMetrics` 计算：`cardWidth - cardPadding * 2` 减去 icon 与间距，避免 magic number 分散。
- 标题保持一行 tail truncation；不换行，避免卡片高度变化。
- 增加 `help` / tooltip 或 accessibility value 暴露完整标题；视觉 UI 不增加说明性文字。
- 对多窗口 app，横向 panel 继续最多 8 张可见，超过时横向滚动；left/right Dock 继续最多 3 张完整卡片可见后纵向滚动。
- 不因 `maxCardCount=12` 让 panel 超过当前 8-card 最大宽度。

可选的轻量宽度优化：

- 如果 card count 为 1 且标题特别长，可以允许单卡宽度增加到 `min(280, visibleFrame.width - padding)`。
- P2 推荐暂不做动态单卡宽度，先把标题区域、tooltip 和测试补齐；动态宽度会增加 layout engine 与 visible frame 的耦合。

## Show / Hide 动画设计

动画放在 `PreviewPanelController` 层，而不是 `PreviewSessionController`：

- `PreviewSessionController` 继续只表达 show/update/hide 状态机、权限、stale cancellation 和 async generation。
- `PreviewPanelController` 负责 `NSPanel` 的可视呈现。

默认动画：

- show：120-160 ms，opacity `0 -> 1`，轻微 scale `0.98 -> 1.0` 或 y offset `-2/2 -> 0`。只动画 opacity/transform，不动画 layout size。
- hide：80-120 ms，opacity `1 -> 0`，完成后 `orderOut(nil)`。
- update：缩略图更新不触发 panel show 动画；只替换 rootView，避免每张缩略图返回都闪动。
- 如果 show 在 hide 动画期间发生，新 show 必须取消旧 hide completion，立刻使用最新 generation/frame/model。
- `hide(reason:)` 必须仍立即让 `panelFrame()` 和 `isMouseInsidePanel` 的行为不会把旧面板当作可交互区域。实现可在 hide 开始时标记 `isHiding`，并在命中测试中返回 false，或直接 orderOut 后只做淡出替代视图；具体实现需测试。
- 动画测试必须覆盖 hide 未完成时再次 show 的竞态：旧 hide completion 不能 `orderOut` 新 panel，且新 show 必须保留最新 model、frame 和 select handler。

Reduce Motion：

- 读取 `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`。
- 为测试引入 `MotionPreferenceProviding`，生产实现读取系统值，测试 fake 控制开/关。
- Reduce Motion 关闭：使用默认轻量动画。
- Reduce Motion 打开：禁用 scale/offset，优先直接 show/hide；如保留动画，只允许极短 opacity fade，且不得延迟 stale hide。
- 系统 Reduce Motion 变化不需要在 P2 做实时 observer；下一次 show/hide 读取当前值即可。若实现 observer，必须单独测试且不影响 P1。

## Light / Dark 材质、边框、阴影和可读性

目标不是重做视觉风格，而是让当前 material panel 更稳：

- panel 背景继续使用系统 material，避免硬编码整套颜色。
- panel 边框改用语义化 token，例如 `PreviewPanelVisualStyle.panelBorderColor(scheme:)`，分别定义 Light / Dark opacity。
- card hover 背景和 border 要在 Light / Dark 下都能被看见，但不能过重。
- shadow 在 Light 下可以略强，在 Dark 下应降低不透明度并避免黑边糊成一团。
- thumbnail placeholder surface 在 Light / Dark 下都要和真实 thumbnail 区域分离。
- title 使用 `.primary`，secondary placeholder 文案使用 `.secondary` 或 token，保证可读。
- 不引入大面积单色主题，不引入 decorative gradient/orb。

建议把视觉常量集中到 `PreviewPanelMetrics` 或新增 `PreviewPanelVisualStyle`，避免 opacity 散落在 view 里。

## 与 P1 和核心行为的交互边界

P1 settings：

- P2 默认不修改现有 `DockHoverPreviewSettings` 字段。
- 如果新增 thumbnail mode setting，必须新增 key、默认 `.fill`、非法值回退，不覆盖已有用户设置。
- display language 只用于 loading / unavailable placeholder 的本工具静态文案，不翻译 app 名称、窗口标题、bundle id、权限名称或日志。
- max cards、retention、excluded apps、Launch at Login 不受 P2 视觉改动影响。

Screen Recording 权限：

- `screenRecording=false` 时仍由 `PreviewSessionController.showPreview` 静默抑制，不显示 loading、placeholder 或权限提示。
- P2 的 placeholder 只用于“有窗口但缩略图不可用/失败”的场景，不用于权限缺失场景。

Stale cancellation：

- generation-based thumbnail update 抑制必须保留。
- hide 动画不得让过期 panel 残留可见或可命中。
- 快速 hover 离开时，视觉上可以淡出，但逻辑上必须立即进入隐藏/不可交互状态。

Thumbnail async generation：

- 初始 model 仍展示 loading card，异步 thumbnail 返回后逐张 update。
- 缩略图失败时，应把对应卡片从 loading 变为 unavailable，而不是一直 spinner。
- stale generation 返回后不得把旧 thumbnail 写入新 panel。

## 数据模型 / ViewModel 扩展

推荐最小扩展：

- `PreviewCardViewModel.windowAspectRatio: CGFloat?` 或 `sourceFrame: CGRect`，用于窄窗口策略。
- `PreviewCardViewModel.thumbnailDisplayMode: ThumbnailDisplayMode`，表示该卡最终渲染方式。
- `PreviewCardViewModel.isLoadingThumbnail` 继续保留；当 thumbnail update 传入 nil 时必须变为 `false`，从 loading 转为 unavailable。
- `PreviewPanelViewModel.thumbnailUnavailableText: String` 或等价字段，由 `PreviewSessionController` 使用 `AppTextProvider(language: settings.displayLanguage)` 注入；`PreviewPanelView` 只消费该文案。
- `PreviewPanelViewModel` 继续只持有 appName/cards 和 UI 文案，不承担权限、settings store、窗口查询逻辑。

可选扩展：

- `PreviewPanelVisualStyle`：集中 material、border、shadow、placeholder opacity。
- `MotionPreferenceProviding`：注入 `PreviewPanelController`，用于动画测试。

不推荐：

- 把缩略图模式塞进 `ThumbnailService`。截图服务只生成图片，不决定 UI 裁切。
- 让 `PreviewPanelLayoutEngine` 管卡片内部比例。它应继续只做 panel frame。
- 为 P2 引入复杂设置窗口。

## 测试策略

自动测试：

- `PreviewPanelViewModelTests`
  - 默认 thumbnail mode 为 `.fill`。
  - 窄窗口在 fill 默认下自动使用 `.fit`。
  - `updateThumbnail(nil, for:)` 会停止 loading 并进入 unavailable 语义。
  - accessibility label 仍包含 app name 和 window title。

- `PreviewPanelViewRenderingTests` 或同等纯逻辑测试
  - 抽 `PreviewThumbnailRenderPlan` / `ThumbnailImageSizing` 等测试 seam，且由 `PreviewPanelView.thumbnailView` 唯一使用。
  - `.fill` 必须映射到 fill plan / `.scaledToFill()`。
  - `.fit` 必须映射到 fit plan / `.scaledToFit()`。
  - 两种模式都保持固定 thumbnail container size 和 clipping。
  - 不能只依赖 layout size 测试，因为 panel/card 尺寸不变时 UI 仍可能继续统一 `.scaledToFill()`。

- `PreviewPanelLayoutEngineTests`
  - 横向 12 卡仍不超过 8 卡可见宽度。
  - 纵向 side Dock 仍最多 3 张完整可见卡片高度。
  - 若增加单卡宽度策略，必须测试 visible frame clamp。

- `PreviewSessionControllerTests`
  - placeholder -> thumbnail success 更新保持现有行为。
  - 创建 card 时把 `PreviewWindow.frame` 或 aspect ratio 传入 ViewModel，窄窗口在真实 session model 中得到 `.fit`。
  - thumbnail nil 返回后不再 loading。
  - fake settings language 为简体中文时，nil thumbnail 的 panel model 带有 `无缩略图`；English 时带有 `No thumbnail`。
  - stale hide 后 thumbnail 返回不更新 panel。
  - Screen Recording denied 仍不 show panel。

- `PreviewPanelControllerTests`（已有基础文件，P2 必须扩充）
  - Reduce Motion off 时 show/hide 调用动画配置。
  - Reduce Motion on 时 show/hide 走无动画或降级路径。
  - hide 后 `panelFrame()` 不把隐藏中的旧 panel 当作可见 panel。
  - hide 后 `isMouseInsidePanel(_:)` 立即返回 false，即使底层 panel 仍在淡出。
  - hide 动画未完成时再次 show，旧 hide completion 不会隐藏新 panel。
  - update 不触发 show animation 计数。

SwiftUI 视觉层可用 ViewModel/metrics 单测覆盖结构；真正 Light / Dark、Reduce Motion 和 material 可读性需要人工视觉验证。

手动视觉验证：

- 不把 manual-only 项写成 pass，除非实际执行并记录日期、环境和结果。
- 建议保存截图到 verification 文档引用的路径，或至少记录人工 checklist。
- Light / Dark 必须分别看真实 app：VS Code / WPS 多窗口、Typora 窄窗口、Stage Manager 抽样。

## 风险和回滚点

风险：

- 缩略图模式如果默认改为 `.fit`，会改变 P1 用户感知；默认应保持 `.fill`。
- hide 动画如果延迟 `orderOut` 且命中测试仍返回 true，会破坏 stale cancellation。
- loading spinner 如果 thumbnail 失败后不停止，会让用户误以为还在加载。
- Light / Dark 如果只靠一种主题截图判断，另一种可能边框或文字对比不足。
- 动态卡片宽度可能让 panel 在 thumbnail update 或多窗口切换时跳动。

回滚点：

- 缩略图模式可回滚为当前统一 `.scaledToFill()`。
- loading/unavailable 可回滚为当前 app icon placeholder，但应保留 `updateThumbnail(nil)` 停止 loading 的逻辑修复。
- show/hide 动画可通过 `MotionPreferenceProviding` 或 feature flag 统一关闭，保留直接 `orderFrontRegardless()` / `orderOut(nil)`。
- 视觉 token 可回滚到当前 `.regularMaterial`、primary opacity border 和 fixed shadow。
