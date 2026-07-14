# Dock Hover Preview P2 UI Polish 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 在保持 P1 settings、Screen Recording 静默抑制、stale hover cancellation、异步缩略图安全和 `build/zongMacTools.app` 打包路径不回退的前提下，打磨 Dock hover preview panel 的 UI。

**架构：** 保持当前边界：`PreviewSessionController` 负责 session state、权限、异步缩略图和 stale cancellation；`PreviewPanelController` 负责 `NSPanel` show/update/hide 呈现；`PreviewPanelView` 负责 SwiftUI 渲染；`PreviewPanelLayoutEngine` 只负责 panel frame 定位。只在 ViewModel、style 和 motion 上增加小型测试接缝。

**技术栈：** Swift 6、SwiftPM、AppKit、SwiftUI、ScreenCaptureKit、XCTest、shell build scripts。

---

## 执行原则

- 按 TDD 执行：先补失败测试，再改实现。
- 每个任务结束后都要保持 `swift test` / `swift build` 可运行；如果某一步只改文档，也至少运行 `git diff --check`。
- 不 stage、不 commit、不 push，除非用户在后续任务明确要求。
- 不改 P1 默认行为：enabled、250 ms、standard retention、max 8 cards、excluded apps 为空、English。
- 不改变 `build/zongMacTools.app` 打包名称，也不重命名 SwiftPM executable / target `DockHoverPreviewProbe`。
- 不把 manual-only 项标记为 pass；人工验证需要执行后再记录结果。

## 硬性非目标 / 许可边界

执行 P2 时不得引入以下内容，即使实现过程中看起来“顺手”：

- 不实现实时视频缩略图。
- 不实现窗口关闭、最小化、隐藏、右键菜单等 P3 功能。
- 不做独立设置窗口或 release 流程。
- 不使用私有 API，不增加 private API wrapper。
- 不复制、翻译或机械改写 DockDoor GPLv3 源码、文件结构、helper、注释或 private API wrapper。
- 不改变窗口枚举范围，不支持最小化窗口、其他 Space 窗口或跨 Space 主动切换。
- 不改变 Screen Recording 缺失时静默抑制 preview UI 的策略。
- 不削弱 stale hover cancellation、Dock hover delayed validation 或 hover-lost panel transition 语义。
- 不做非向后兼容的 P1 settings 数据模型变化；如确需新增 setting，只能新增 key、默认保持现状、非法值回退，并补 SettingsStore 测试。

## 文件地图

预计修改：

- `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`
  - 增加 thumbnail display mode、窗口比例或 placeholder 状态。

- `Sources/DockHoverPreviewProbe/PreviewPanelView.swift`
  - 实现 fit/fill 渲染、loading/unavailable placeholder、标题宽度计算、Light/Dark style token。

- `Sources/DockHoverPreviewProbe/PreviewPanelController.swift`
  - 增加 show/hide animation 与 Reduce Motion 降级。

- `Sources/DockHoverPreviewProbe/PreviewSessionController.swift`
  - 传入窗口 frame/aspect ratio，thumbnail nil 返回后停止 loading；保持 generation stale cancellation。

- `Sources/DockHoverPreviewProbe/AppTextProvider.swift`
  - 如 placeholder 需要静态文案，新增 `No thumbnail` / `无缩略图` key；不翻译 app/window/bundle/log。

- `Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift`
  - 覆盖 display mode、窄窗口策略、thumbnail nil 状态。

- `Tests/DockHoverPreviewProbeTests/PreviewPanelViewRenderingTests.swift` 或同等纯逻辑测试文件
  - 覆盖 `.fit` / `.fill` 在 SwiftUI 渲染层映射到不同 image sizing plan，避免只测 ViewModel 而 UI 仍统一 `.scaledToFill()`。

- `Tests/DockHoverPreviewProbeTests/PreviewPanelLayoutEngineTests.swift`
  - 保持横向/纵向 panel 尺寸稳定；必要时补单卡宽度策略测试。

- `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`
  - 覆盖 thumbnail success / nil / stale update / Screen Recording denied。

- `Tests/DockHoverPreviewProbeTests/PreviewPanelControllerTests.swift`
  - 建议新增，覆盖 motion preference 与 panel hide 可见性语义。若 `NSPanel` 直接单测过重，先抽小 protocol 或 animation coordinator 测纯逻辑。

不预计修改：

- `DockHoverMonitor.swift`、`ProbeOrchestrator.swift`：P2 不改变 hover 判定和 delay validation。
- `WindowQueryService.swift`：P2 不改变窗口查询范围和 filtering。
- `ThumbnailService.swift`：P2 不改变截图生成方式，除非只增加测试 helper。
- `DockHoverPreviewSettings.swift` / `SettingsStore.swift`：默认不改。若必须新增 thumbnail mode setting，需新增向后兼容 key，并单独补 store tests。
- `Scripts/build_probe_app.sh`：不改打包路径和 app 名称。

## Task 1: 缩略图显示模式和窄窗口策略

**目标：** 让卡片能表达 `.fit` 和 `.fill`，默认保持当前 fill 视觉，但窄窗口自动降级为 fit，Typora 等窗口不会被过度裁切。

**涉及文件：**

- Modify: `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`
- Modify: `Sources/DockHoverPreviewProbe/PreviewSessionController.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`

**步骤：**

- [ ] 先在 `PreviewPanelViewModelTests` 写失败测试：
  - 默认 card 使用 `.fill`。
  - `sourceFrame` aspect ratio `< 1.2` 时 card 使用 `.fit`。
  - 宽屏窗口仍使用 `.fill`。

- [ ] 同时在 `PreviewSessionControllerTests` 写失败测试，证明真实 session plumbing 存在：
  - fake window 使用窄 `frame`，`showPreview` 后 `display.lastModel?.cards.first?.effectiveThumbnailDisplayMode == .fit`。
  - fake window 使用宽屏 `frame`，`showPreview` 后对应 card 仍是 `.fill`。
  - 断言来自 `PreviewWindow.frame`，而不是测试直接手工构造 card。

**预期失败信号：**

- `swift test --filter PreviewPanelViewModelTests` 失败，原因是 `ThumbnailDisplayMode` 或 source frame 字段不存在。
- `swift test --filter PreviewSessionControllerTests/testShowPreviewUsesWindowFrameForThumbnailDisplayMode` 失败，原因是 `PreviewSessionController.showPreview` 创建 card 时还没有传入 `window.frame`。

- [ ] 在 `PreviewPanelModels.swift` 新增：
  - `ThumbnailDisplayMode`。
  - `PreviewCardViewModel.sourceFrame: CGRect` 或 `windowAspectRatio: CGFloat?`。
  - `PreviewCardViewModel.effectiveThumbnailDisplayMode` 纯计算属性。

- [ ] 在 `PreviewSessionController.showPreview` 创建 card 时传入 `window.frame`。

- [ ] 跑 targeted tests：

```bash
swift test --filter PreviewPanelViewModelTests
swift test --filter PreviewSessionControllerTests/testShowPreviewUsesWindowFrameForThumbnailDisplayMode
swift test --filter PreviewSessionControllerTests/testShowsPlaceholderCardsThenUpdatesThumbnails
```

**预期通过信号：**

- ViewModel 测试显示窄窗口 `.fit`、普通窗口 `.fill`。
- Session 测试显示 `PreviewWindow.frame` 被传入真实 panel model，Typora 类窄窗口不会只在 isolated ViewModel 测试中生效。
- 现有 placeholder -> thumbnail success 测试仍通过。

**阶段门禁：**

```bash
swift test
swift build
git diff --check
```

## Task 2: SwiftUI 缩略图渲染 fit/fill

**目标：** 在 UI 中真正使用 display mode，同时保持缩略图容器尺寸稳定。

**涉及文件：**

- Modify: `Sources/DockHoverPreviewProbe/PreviewPanelView.swift`
- Create/Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelViewRenderingTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelLayoutEngineTests.swift`
- Optional Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift`

**步骤：**

- [ ] 先补一个能失败的 UI 渲染层测试 seam，不只依赖 layout size：
  - 可选方案 A：抽 `PreviewThumbnailRenderPlan` / `ThumbnailImageSizing` 纯类型，由 `PreviewPanelView.thumbnailView` 唯一使用。
  - 可选方案 B：抽 `PreviewThumbnailImageView` 并暴露内部 render plan 给测试。
  - 测试 `.fill` card 映射到 fill plan / `.scaledToFill()`。
  - 测试 `.fit` card 映射到 fit plan / `.scaledToFit()`。
  - 测试两种模式都声明固定 thumbnail container size 和 clipping。

**预期失败信号：**

- 当前 `PreviewPanelView.thumbnailView` 直接写死 `.scaledToFill()`，新增 render-plan 测试应无法编译或断言 `.fit` 仍是 fill。
- 仅修改 `PreviewPanelMetrics.panelSize` 或 ViewModel 不足以让该测试通过。

- [ ] 确认现有 layout tests 仍覆盖：
  - horizontal `maxCardCount=12` 不超过 8-card 可见宽度。
  - side Dock vertical 最多 3 张完整卡片高度。

- [ ] 修改 `PreviewPanelView.thumbnailView`：
  - `.fill` 使用 `.scaledToFill()`。
  - `.fit` 使用 `.scaledToFit()`。
  - 两者都在固定 `thumbnailWidth/thumbnailHeight` 容器内 clip，不改变 card/panel 尺寸。

- [ ] 把 thumbnail 背景 surface 抽到小 helper，保证 fit 留白区域不是透明空洞。

**预期失败/通过信号：**

- render-plan 测试必须能证明 `.fit` 和 `.fill` 进入不同渲染分支。
- 如果改动导致 `PreviewPanelMetrics.panelSize` 变化，`PreviewPanelLayoutEngineTests` 应失败。
- 通过时 layout tests 的 width/height 断言不变。

**阶段门禁：**

```bash
swift test --filter PreviewPanelViewRenderingTests
swift test --filter PreviewPanelLayoutEngineTests
swift test
swift build
git diff --check
```

## Task 3: Loading 和 unavailable placeholder

**目标：** 区分“正在加载”和“缩略图不可用”，并确保 thumbnail nil 后不再无限 spinner。

**涉及文件：**

- Modify: `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`
- Modify: `Sources/DockHoverPreviewProbe/PreviewPanelView.swift`
- Modify: `Sources/DockHoverPreviewProbe/PreviewSessionController.swift`
- Modify: `Sources/DockHoverPreviewProbe/AppTextProvider.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/AppTextProviderTests.swift`

**步骤：**

- [ ] 先写失败测试：
  - `updateThumbnail(nil, for:)` 后 matching card `isLoadingThumbnail == false` 且 `thumbnail == nil`。
  - `PreviewSessionController` 在 fake thumbnail service 返回 nil 时调用 `panelDisplay.update`，last model 的对应 card 不再 loading。
  - `AppTextProvider` 返回 English `No thumbnail` 和中文 `无缩略图`。
  - `PreviewSessionController` 使用 settings snapshot 的 `displayLanguage` 构造 panel model：English model 带 `No thumbnail`，简体中文 model 带 `无缩略图`。
  - `PreviewPanelViewRenderingTests` 或同等 seam 证明 unavailable branch 使用 model/provider 注入的文案，不硬编码英文。
  - Screen Recording denied 测试保持：`showCount == 0`，不显示 placeholder。

**预期失败信号：**

- 当前 `updateThumbnail` 已能停止 loading，但 AppTextProvider key、panel model 的 unavailable 文案字段和 UI unavailable 文案不存在；新增 session nil update 测试可能暴露 updateCount、language plumbing 或状态断言缺口。

- [ ] 更新 ViewModel 或现有 `isLoadingThumbnail` 语义：
  - loading：`thumbnail == nil && isLoadingThumbnail == true`
  - unavailable：`thumbnail == nil && isLoadingThumbnail == false`
  - 在 `PreviewPanelViewModel` 增加 `thumbnailUnavailableText` 或等价字段；该字段只保存已本地化的 UI 文案，不保存 settings store。

- [ ] 更新 `PreviewPanelView`：
  - loading 显示 app icon + small spinner。
  - unavailable 显示 app icon + model 中的 `thumbnailUnavailableText`，不显示 spinner。
  - placeholder 不改变缩略图容器尺寸。

- [ ] `PreviewSessionController` 不改变权限路径；只在 thumbnail service 返回 nil 后更新当前 model。创建初始 model 时读取 settings snapshot 的 `displayLanguage`，通过 `AppTextProvider` 注入 unavailable 文案；不让 SwiftUI view 直接读取 settings。

**阶段门禁：**

```bash
swift test --filter PreviewPanelViewModelTests
swift test --filter PreviewSessionControllerTests
swift test --filter AppTextProviderTests
swift test
swift build
git diff --check
```

## Task 4: 标题截断和卡片宽度稳定性

**目标：** 减少 magic number，保持多窗口布局稳定，并让完整标题可通过辅助信息获得。

**涉及文件：**

- Modify: `Sources/DockHoverPreviewProbe/PreviewPanelView.swift`
- Modify: `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelLayoutEngineTests.swift`

**步骤：**

- [ ] 先写/确认测试：
  - 新增 metrics/render-plan 测试会在标题宽度仍硬编码为 `208` 时失败，例如 `PreviewPanelMetrics.titleRowWidth == cardWidth - cardPadding * 2`，`titleTextWidth == titleRowWidth - iconSize - titleIconSpacing`，且 `PreviewCardView` 的 title row 只使用这些 metrics。
  - accessibility label 仍为 `appName, title`。
  - 12 张卡横向 panel size 仍等于 8 张可见宽度。
  - side Dock 5 张卡仍只显示 3 张完整高度。

- [ ] 将标题 row width 从硬编码 `208` 改为 metrics 计算：
  - `titleRowWidth = cardWidth - cardPadding * 2`
  - `titleTextWidth = titleRowWidth - iconSize - titleIconSpacing`

- [ ] 标题继续 `.lineLimit(1)` + `.truncationMode(.tail)`。

- [ ] 如实现 tooltip/help，确保完整标题来自原始 `card.title`，不翻译、不截断。

**预期失败/通过信号：**

- 失败信号：当前 `PreviewPanelView` 的 title row 仍是硬编码 `208`，新的 metrics/render-plan 测试应无法通过。
- 布局尺寸断言不应变化。
- accessibility label 测试不应变化。

**阶段门禁：**

```bash
swift test --filter PreviewPanelViewModelTests
swift test --filter PreviewPanelLayoutEngineTests
swift test
swift build
git diff --check
```

## Task 5: Light / Dark visual tokens

**目标：** 把 panel/card/thumbnail 的 border、shadow、placeholder surface 常量集中，方便 Light / Dark 复查和后续截图比对。

**涉及文件：**

- Modify: `Sources/DockHoverPreviewProbe/PreviewPanelView.swift`
- Create/Modify: `Sources/DockHoverPreviewProbe/PreviewPanelVisualStyle.swift` 或等价 style token 类型
- Create/Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelVisualStyleTests.swift` 或同等纯逻辑测试

**步骤：**

- [ ] 先补纯逻辑失败测试：
  - Light 与 Dark 的 panel border opacity 都大于 0。
  - Dark shadow opacity 不高于 Light shadow opacity。
  - placeholder surface opacity 在 Light / Dark 都大于 0。
  - card hover border/background opacity 在 Light / Dark 都高于 normal 状态，保证 hover state 可区分。

- [ ] 将散落的 opacity 常量集中：
  - panel border。
  - card border normal/hover。
  - card background normal/hover。
  - thumbnail border。
  - placeholder surface。
  - panel shadow。

- [ ] SwiftUI view 使用 `@Environment(\.colorScheme)` 选择 token。

**预期失败/通过信号：**

- 失败信号：当前 opacity 分散在 `PreviewPanelView` 中，style token 测试应无法编译或无法引用集中 token。
- 通过信号：style token 测试通过，现有功能测试不受影响。
- 视觉是否可读不能靠单元测试判定，留到 manual checklist。

**阶段门禁：**

```bash
swift test
swift build
git diff --check
```

## Task 6: Show / Hide 动画与 Reduce Motion

**目标：** 增加轻量非阻塞动画；Reduce Motion 打开时禁用或降级；hide 不破坏 stale cancellation。

**涉及文件：**

- Modify: `Sources/DockHoverPreviewProbe/PreviewPanelController.swift`
- Create/Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelControllerTests.swift`

**步骤：**

- [ ] 先抽测试 seam：
  - `MotionPreferenceProviding`，生产实现读取 `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`。
  - `PanelAnimationControlling` 或内部 coordinator，测试可记录 show/hide 是否 animated。

- [ ] 先写失败测试：
  - Reduce Motion off：show 使用 animated path。
  - Reduce Motion off：hide 使用 animated path，completion 后 orderOut。
  - Reduce Motion on：show/hide 不使用 scale/offset 动画，可直接 show/hide。
  - hide 调用后 `panelFrame()` 对外不再返回旧可见 frame，避免 leave polling 误判。
  - hide 调用后 `isMouseInsidePanel(_:)` 立即返回 false，即使底层 `NSPanel` 仍在淡出。
  - hide 动画未完成时再次 show：旧 hide completion 被取消或带 token 校验，不能 `orderOut` 新 panel。
  - hide 动画未完成时再次 show：新 show 使用最新 model、anchor/frame 和 onSelect。
  - `update(model:)` 不触发 show animation 计数。

**预期失败信号：**

- 当前 controller 没有 motion provider/animation seam；测试无法编译或断言失败。
- 当前 `update(model:)` 复用 `show(model:anchor:onSelect:)`，如果直接在 `show` 里加动画，`update` 动画计数测试应失败。

- [ ] 实现 animation：
  - show：先设置 frame/rootView，再 order front，再 opacity/transform 进入。
  - hide：立即标记 not interactable / hiding，然后 fade out，completion orderOut。
  - 新 show 取消 pending hide completion，或让 completion 带 generation/token 校验，使用最新 model/frame/onSelect。
  - update 只替换 rootView 和 frame，不重复 show animation；必要时把当前 `update -> show` 路径拆成共享 render/update helper。

- [ ] Reduce Motion：
  - 若 `accessibilityDisplayShouldReduceMotion == true`，直接 order front/out 或只做极短 opacity，不做 scale/offset。

**阶段门禁：**

```bash
swift test --filter PreviewPanelControllerTests
swift test
swift build
git diff --check
```

## Task 7: 回归验证和文档更新

**目标：** 只在实际验证后更新 README / verification 文档；不提前把 manual-only 项写成 pass。

**涉及文件：**

- Optional Modify: `README.md`
- Optional Modify: `docs/architecture/dock-hover-preview-technical-design.md`
- Optional Modify: `docs/verification/dock-hover-preview-probe-summary.md`
- Optional Create/Modify: `docs/verification/dock-hover-preview-p2-ui-polish-manual-checklist.md`

**步骤：**

- [ ] 先运行最终自动验证的代码/打包部分：

```bash
swift test
swift build
Scripts/build_probe_app.sh
```

**预期通过信号：**

- XCTest exit 0。
- Swift build exit 0。
- build script 输出 `build/zongMacTools.app`。

- [ ] 只记录已实际运行的自动验证，不写“应该通过”。

- [ ] 创建或更新 P2 manual checklist，所有未执行项保持 unchecked / not run。

- [ ] 在所有代码和文档更新完成后，最后运行 whitespace 检查：

```bash
git diff --check
```

**最终通过信号：**

- `git diff --check` 无 whitespace error，且该命令发生在 verification 文档和 manual checklist 更新之后。

- [ ] 如果人工验证发现视觉问题，先补测试或调整实现，再重新跑相关自动门禁。

## 必跑验证命令

P2 完整实现完成后，必须运行：

```bash
swift test
swift build
Scripts/build_probe_app.sh
```

记录验证文档和 manual checklist 后，必须再运行：

```bash
git diff --check
```

如果任一命令失败：

- 不开始人工验证。
- 不声称 P2 完成。
- 先修复失败并重新运行完整门禁。

## Manual Validation Checklist

以下清单只能在实际执行后记录 pass / pass with note / fail / blocked。未执行时保持 `not run`。

- [ ] 普通 bottom Dock：hover 显示、点击激活、离开隐藏、标题不重叠。
- [ ] left/right Dock：纵向 panel 不越界，最多 3 张完整卡片可见后滚动。
- [ ] Dock auto-hide：reveal 后 hover 正常，快速离开无 stale panel。
- [ ] Stage Manager 抽样：AX fallback placeholder 不显示斜系统缩略图或桌面假图。
- [ ] Light / Dark：panel material、border、shadow、title、placeholder 都可读。
- [ ] Reduce Motion 开：show/hide 无明显 scale/offset 动画，不延迟 stale hide。
- [ ] Reduce Motion 关：show/hide 有轻量动画，不闪烁。
- [ ] 窄窗口 app，例如 Typora：缩略图完整可识别，不被过度裁切。
- [ ] 多窗口 app，例如 VS Code / WPS：标题截断合理，横向/纵向滚动稳定。
- [ ] Screen Recording denied 仍静默抑制：不显示 loading、placeholder 或弹窗。
- [ ] 快速 hover 离开仍无 stale panel：过期 thumbnail 不更新旧 panel。

## 风险和回滚点

- 若动画造成 stale panel 或 hit-test 残留，回滚 Task 6，保留直接 `orderFrontRegardless()` / `orderOut(nil)`。
- 若 fit/fill 策略导致大多数窗口视觉密度下降，保留默认 `.fill`，仅对窄窗口使用 `.fit`。
- 若 placeholder 文案显得拥挤，回滚为 icon-only unavailable，但保留 loading 停止逻辑。
- 若 Light / Dark token 在某主题下变差，回滚到当前 `.regularMaterial` + primary opacity border/shadow 常量。
- 若新增 setting 被认为超出 P2，移除 settings 接入，保留内部默认策略；不得迁移或覆盖 P1 keys。
