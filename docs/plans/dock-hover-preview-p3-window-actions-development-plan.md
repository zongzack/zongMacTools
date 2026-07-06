# Dock Hover Preview P3 窗口操作增强开发文档

> **给后续执行者：** 实施本计划时按任务逐项执行，优先先写测试再改实现；每个任务结束后运行对应阶段检查。步骤使用 checkbox 语法，方便执行时追踪。

**目标：** 在现有预览卡片基础上增加右键窗口操作菜单，支持激活窗口、隐藏应用、公开接口可行时关闭窗口、公开接口可行时最小化窗口，并显示保守的屏幕/环境提示。

**架构：** 保持现有边界：会话层负责当前窗口状态和动作路由，面板层负责菜单展示和交互保留，新增窗口操作服务负责公开接口能力判断和执行。关闭/最小化通过公开辅助功能按钮或属性完成，失败只记录日志并安静降级。

**技术栈：** Swift 6、SwiftPM、AppKit、SwiftUI、ScreenCaptureKit、ApplicationServices、XCTest、shell build scripts。

---

日期：2026-07-03

## 背景

`zongMacTools` 当前已经完成 MVP/P0、P1 基础设置和 P2 界面打磨。现有预览路径能在程序坞悬停后展示窗口卡片，点击卡片会通过公开的辅助功能抬升窗口，再调用系统应用激活接口。

P3 的目标是在不破坏现有悬停预览稳定性的前提下，为卡片增加少量高价值窗口操作。所有操作必须使用公开接口；操作失败时安静降级并记录日志，不弹出打扰性提示。

## P3 目标

- 卡片右键菜单提供“激活窗口”。
- 卡片右键菜单提供“隐藏应用”。
- 评估并实现“关闭窗口”。
- 评估并实现“最小化窗口”。
- 在右键菜单或卡片辅助信息中显示窗口所在屏幕或当前可交互环境提示。
- 保持 P1 默认行为不变：启用、250 ms、标准保留、最多 8 张卡片、排除应用为空、英文。
- 保持 P2 行为不回退：窄窗口完整显示、加载/不可用占位、显示/隐藏动画、浅色/深色视觉规则和减少动态效果降级。

## 非目标

- 不实现实时视频缩略图。
- 不实现全屏切换、跨空间拉起窗口、恢复最小化窗口或搜索窗口。
- 不新增独立设置窗口。
- 不新增用户设置项；P3 操作默认随预览能力一起可用。
- 不改变 `build/zongMacTools.app` 打包路径。
- 不重命名 SwiftPM executable / target `DockHoverPreviewProbe`。
- 不使用私有接口，不增加私有接口封装。
- 不复制、翻译或机械改写 DockDoor GPLv3 源码、结构、helper、注释或私有接口封装。
- 不改变屏幕录制权限缺失时静默抑制预览 UI 的策略。

## 设计原则

- **公开接口优先。** 激活继续复用现有 `ActivationService`；隐藏应用使用 `NSRunningApplication.hide()`；关闭和最小化只使用公开辅助功能属性和动作。
- **可用性按窗口判断。** 关闭/最小化依赖窗口辅助功能元素，缺失或动作不可用时，菜单项禁用或执行后记录失败。
- **失败安静。** 不在预览面板上展示错误 toast，不弹权限提示。失败只写日志，并保留/隐藏面板按动作语义处理。
- **状态机不后退。** 右键菜单不能绕过过期悬停取消、旧会话代际保护、屏幕录制权限抑制或面板隐藏后不可交互语义。
- **菜单交互可保留会话。** 用户打开右键菜单并移动鼠标选择菜单项时，不应被离开轮询提前隐藏并清空窗口上下文。
- **文案跟随 P1 语言。** 右键菜单里的本工具静态文案由 `AppTextProvider` 提供；不翻译应用名称、窗口标题、bundle id、系统权限名称或日志事件名。

## 当前代码边界

- `ActivationService.swift`：已有公开激活路径，先对窗口执行 `kAXRaiseAction`，再调用 `NSRunningApplication.activate(options: [])`。
- `PreviewSessionController.swift`：拥有当前窗口字典、预览模型、权限抑制、缩略图更新、点击激活、离开轮询和隐藏逻辑。
- `PreviewPanelController.swift`：拥有非激活 `NSPanel`，负责显示、更新、隐藏、动画、命中检测和 SwiftUI 根视图。
- `PreviewPanelView.swift`：渲染卡片列表，目前卡片点击只回传 `PreviewWindowID`。
- `PreviewPanelModels.swift`：卡片模型有窗口 id、标题、图标、缩略图状态和缩略图显示模式，但没有窗口操作、操作可用性或环境提示。
- `AppTextProvider.swift`：集中提供本工具静态文案，P3 菜单文案应继续放在这里。

## 推荐方案

采用“右键菜单 + 独立窗口操作服务 + 会话层统一路由”的方案。

不把窗口操作直接塞进 `ActivationService`，因为激活、隐藏应用、关闭窗口、最小化窗口的成功条件和日志语义不同。新增 `WindowOperationService` 负责操作能力判断和执行，`PreviewSessionController` 只负责根据卡片动作找到当前窗口并调用服务。

不直接使用 SwiftUI `.contextMenu` 作为最终实现入口。它很轻，但不容易可靠知道菜单何时开始/结束；如果用户把鼠标移到菜单上，现有离开轮询可能提前隐藏面板并清空窗口上下文。推荐用一个小型 AppKit 菜单桥接器展示标准 `NSMenu`，在菜单跟踪期间通知会话层暂停离开隐藏。

## 用户体验

卡片主点击保持原行为：激活窗口并隐藏预览面板。

卡片右键菜单包含：

1. 激活窗口
2. 隐藏应用
3. 关闭窗口
4. 最小化窗口
5. 分隔线
6. 屏幕或环境提示，只读，不可点击

菜单项状态：

- 激活窗口：只要窗口仍在当前会话中就可用。
- 隐藏应用：只要 `NSRunningApplication.hide()` 可调用就可用。
- 关闭窗口：需要窗口辅助功能元素存在，且能取得公开 AX 关闭按钮；P3 不尝试未命名或私有关闭动作。
- 最小化窗口：需要窗口辅助功能元素存在，且能取得最小化按钮，或 `kAXMinimizedAttribute` 可设置。
- 屏幕/环境提示：缺少屏幕匹配时显示“屏幕：未知”；不阻塞其他操作。

操作后面板策略：

- 激活窗口请求已发出后，隐藏面板，沿用当前行为。
- 隐藏应用请求成功后，隐藏面板。
- 关闭窗口请求成功后，隐藏面板，避免展示可能已关闭或等待目标 app 确认的旧卡片。
- 最小化窗口请求成功后，隐藏面板，避免展示可能已最小化窗口的旧卡片。
- 操作失败时记录日志；菜单关闭后如果鼠标仍在预览区域则保留面板，否则按离开轮询隐藏。

## 数据模型

新增窗口操作枚举：

```swift
enum PreviewWindowOperation: String, CaseIterable, Sendable {
    case activate
    case hideApplication
    case closeWindow
    case minimizeWindow
}
```

新增卡片动作枚举，替代单一 `onSelect` 语义：

```swift
enum PreviewPanelAction: Equatable, Sendable {
    case primarySelect(PreviewWindowID)
    case windowOperation(PreviewWindowID, PreviewWindowOperation)
    case contextMenuBegan(PreviewWindowID)
    case contextMenuEnded(PreviewWindowID)
}
```

新增操作可用性模型：

```swift
struct WindowOperationAvailability: Equatable, Sendable {
    let operation: PreviewWindowOperation
    let isEnabled: Bool
    let disabledReason: String?
}
```

新增操作结果模型：

```swift
struct WindowOperationResult: Equatable, Sendable {
    let operation: PreviewWindowOperation
    let windowID: PreviewWindowID
    let requestSucceeded: Bool
    let failure: WindowOperationFailure?
}

struct WindowOperationFailure: Equatable, Sendable {
    let reason: WindowOperationFailureReason
    let stage: WindowOperationFailureStage
    let axErrorCode: Int32?
}

enum WindowOperationFailureReason: String, Sendable {
    case missingWindow
    case missingAccessibilityElement
    case missingButton
    case actionFailed
    case attributeNotSettable
    case applicationRejected
}

enum WindowOperationFailureStage: String, Sendable {
    case lookupWindow
    case copyAttribute
    case pressButton
    case checkSettable
    case setAttribute
    case hideApplication
    case activateApplication
}
```

`PreviewCardViewModel` 建议增加：

- `operationAvailabilities: [PreviewWindowOperation: WindowOperationAvailability]`
- `environmentDescription: String`

如果字典让测试或 SwiftUI diff 变复杂，也可以用固定结构：

```swift
struct PreviewWindowOperationMenuModel: Equatable {
    let activate: WindowOperationAvailability
    let hideApplication: WindowOperationAvailability
    let closeWindow: WindowOperationAvailability
    let minimizeWindow: WindowOperationAvailability
    let environmentDescription: String
}
```

## 窗口操作服务

新增协议：

```swift
@MainActor
protocol WindowOperationService: Sendable {
    func availability(for operation: PreviewWindowOperation, window: PreviewWindow) -> WindowOperationAvailability
    func perform(_ operation: PreviewWindowOperation, on window: PreviewWindow) -> WindowOperationResult
}
```

生产实现建议命名为 `AXWindowOperationService`，只使用公开接口：

- 激活窗口：委托现有 `ActivationService.activate(window:)`，把结果转换成 `WindowOperationResult`。
- 隐藏应用：调用 `window.app.hide()`。
- 激活、隐藏、关闭和最小化的 `requestSucceeded` 表示公开 API 请求已成功发出或被系统接受，不承诺目标窗口真实状态已经完成变化。
- 关闭窗口：从 `window.axElement` 读取 `kAXCloseButtonAttribute`，对按钮执行 `kAXPressAction`；按钮缺失时禁用菜单项或执行失败降级，不尝试未命名 close action。
- 最小化窗口：优先读取 `kAXMinimizeButtonAttribute` 并执行 `kAXPressAction`；若按钮不可用但 `kAXMinimizedAttribute` 可设置，则设置为 `true`。

为了测试，不建议在服务测试中直接构造真实 `AXUIElement`。应抽一个很薄的公开接口执行器：

```swift
@MainActor
protocol AccessibilityWindowActionPerforming {
    func buttonExists(attribute: CFString, on windowElement: AXUIElement?) -> Bool
    func pressButton(attribute: CFString, on windowElement: AXUIElement?) -> AXError
    func setBooleanAttribute(_ attribute: CFString, value: Bool, on windowElement: AXUIElement?) -> AXError
    func isAttributeSettable(_ attribute: CFString, on windowElement: AXUIElement?) -> Bool
}
```

生产执行器内部使用：

- `AXUIElementCopyAttributeValue`
- `AXUIElementPerformAction(..., kAXPressAction as CFString)`
- `AXUIElementIsAttributeSettable`
- `AXUIElementSetAttributeValue`

`availability` 只能使用只读探测，例如读取按钮属性和检查属性 settable，不能为了判断菜单可用性而执行 press 或 set。测试使用 fake 执行器精确模拟按钮存在、按钮缺失、动作失败、属性不可设置等场景。

## 菜单展示和会话保留

`PreviewPanelDisplaying.show` 建议从：

```swift
func show(model: PreviewPanelViewModel, anchor: PreviewPanelAnchor, onSelect: @escaping (PreviewWindowID) -> Void)
```

改为：

```swift
func show(model: PreviewPanelViewModel, anchor: PreviewPanelAnchor, onAction: @escaping (PreviewPanelAction) -> Void)
```

`PreviewPanelController` 维护 `currentOnAction`。卡片主点击发送 `.primarySelect(id)`。右键菜单开始发送 `.contextMenuBegan(id)`，菜单结束发送 `.contextMenuEnded(id)`，菜单项选择发送 `.windowOperation(id, operation)`。

`PreviewSessionController` 增加 `contextMenuDepth` 或 `isContextMenuTracking`。离开轮询中，如果正在跟踪菜单，则不隐藏面板。菜单结束后下一次轮询再按真实鼠标位置判断。

推荐实现一个小型 AppKit 菜单桥接器，而不是直接依赖 SwiftUI `.contextMenu`：

- 每张卡片安装右键命中区域。
- 右键按下时根据 `PreviewWindowOperationMenuModel` 构造 `NSMenu`。
- 调用菜单前通知 `.contextMenuBegan(id)`。
- 菜单关闭后通知 `.contextMenuEnded(id)`。
- 菜单项 action 调用 `.windowOperation(id, operation)`。

这样能可靠保护当前会话窗口字典，不会因为用户移动到菜单区域而提前清空。

## 屏幕和环境提示

新增一个纯逻辑 helper，例如 `WindowEnvironmentDescriptor`：

```swift
struct WindowEnvironmentDescriptor {
    static func description(for windowFrame: CGRect, screens: [NSScreen]) -> String
}
```

匹配规则：

- 优先选择与窗口 frame 交集面积最大的屏幕。
- 如果能得到 `NSScreen.localizedName`，显示“屏幕：\(name)”。
- 如果无法匹配屏幕，显示“屏幕：未知”。
- 不承诺精确空间归属；当前公开接口不能稳定判断窗口属于哪个空间。

如果后续要加“当前可交互环境”提示，应使用保守文案，例如：

- “环境：当前可枚举窗口”
- “环境：台前调度下可能使用占位缩略图”

不要写成“当前空间”或“真实所在空间”，避免承诺公开接口无法保证的信息。

## 日志

建议新增稳定日志事件名：

- `windowOperation.request operation=... id=... title=...`
- `windowOperation.availability operation=... enabled=... reason=... stage=... axCode=...`
- `windowOperation.result operation=... id=... requestSucceeded=... reason=... stage=... axCode=...`
- `windowOperation.missingWindow id=...`
- `preview.panel.contextMenuBegan id=...`
- `preview.panel.contextMenuEnded id=...`

日志事件名保持英文，不跟随显示语言切换。用户可见文案才跟随 `AppTextProvider`。关闭/最小化失败日志必须保留失败阶段和原始 `AXError.rawValue`，方便区分属性读取失败、按钮动作失败、属性不可设置和属性设置失败。

## 实施任务

### Task 1：模型和文案

涉及文件：

- `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`
- `Sources/DockHoverPreviewProbe/AppTextProvider.swift`
- `Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift`
- `Tests/DockHoverPreviewProbeTests/AppTextProviderTests.swift`

步骤：

- [ ] 先写失败测试，覆盖 `PreviewWindowOperation` 的四个操作。
- [ ] 给 `AppTextProvider` 增加英文和简体中文菜单文案：激活窗口、隐藏应用、关闭窗口、最小化窗口、屏幕未知、当前可枚举窗口。
- [ ] 给卡片模型增加操作菜单模型和环境提示字段。
- [ ] 确认 P1 默认设置测试仍不包含新的设置键。

阶段检查：

```bash
swift test --filter AppTextProviderTests
swift test --filter PreviewPanelViewModelTests
git diff --check
```

### Task 2：窗口操作服务

涉及文件：

- `Sources/DockHoverPreviewProbe/WindowOperationService.swift`
- `Sources/DockHoverPreviewProbe/ActivationService.swift`
- `Sources/DockHoverPreviewProbe/ProbeModels.swift`
- `Tests/DockHoverPreviewProbeTests/WindowOperationServiceTests.swift`

步骤：

- [ ] 新增 `WindowOperationService`、`WindowOperationResult` 和 `WindowOperationFailureReason`。
- [ ] 新增 `AXWindowOperationService`，注入 `ActivationService`、公开辅助功能执行器和 logger。
- [ ] `availability` 使用只读探测判断按钮存在和属性 settable，不执行 press 或 set。
- [ ] 用 fake 执行器测试关闭请求成功、关闭按钮缺失、关闭动作失败。
- [ ] 用 fake 执行器测试最小化按钮请求成功、按钮缺失但可设置 `kAXMinimizedAttribute`、属性不可设置。
- [ ] 测试 AX 属性读取、按钮动作、属性 settable 检查和属性设置失败时，结果和日志包含失败阶段与 `AXError.rawValue`。
- [ ] 测试隐藏应用成功/失败结果转换。
- [ ] 测试激活窗口委托现有激活服务，不复制激活逻辑。

阶段检查：

```bash
swift test --filter WindowOperationServiceTests
swift test --filter ProbeModelsTests
git diff --check
```

### Task 3：面板动作回调和右键菜单

涉及文件：

- `Sources/DockHoverPreviewProbe/PreviewPanelController.swift`
- `Sources/DockHoverPreviewProbe/PreviewPanelView.swift`
- `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`
- `Tests/DockHoverPreviewProbeTests/PreviewPanelControllerTests.swift`
- `Tests/DockHoverPreviewProbeTests/PreviewPanelViewRenderingTests.swift`

步骤：

- [ ] 把 `PreviewPanelDisplaying.show` 的回调从 `onSelect` 扩展为 `onAction`。
- [ ] 运行 `rg "PreviewPanelDisplaying|func show\\(" Sources Tests`，更新所有生产调用点和测试 fake，避免只改面板控制器导致编译失败。
- [ ] 主点击发送 `.primarySelect(id)`，保持原点击体验不变。
- [ ] 新增右键菜单桥接器，展示标准菜单并发送菜单开始/结束动作。
- [ ] 菜单项根据 `WindowOperationAvailability.isEnabled` 启用或禁用。
- [ ] 菜单底部显示环境提示，只读不可点击。
- [ ] 测试主点击不回退。
- [ ] 测试右键菜单生成四个操作项和环境提示。
- [ ] 测试禁用操作不会发送执行动作。

阶段检查：

```bash
swift test --filter PreviewPanelControllerTests
swift test --filter PreviewPanelViewRenderingTests
git diff --check
```

### Task 4：会话层操作路由和菜单保留

涉及文件：

- `Sources/DockHoverPreviewProbe/PreviewSessionController.swift`
- `Sources/DockHoverPreviewProbe/AppDelegate.swift`
- `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`

步骤：

- [ ] 给 `PreviewSessionController` 注入 `WindowOperationService`。
- [ ] `.primarySelect(id)` 继续走现有激活路径，并隐藏面板。
- [ ] `.windowOperation(id, .activate)` 复用现有激活路径。
- [ ] `.windowOperation(id, .hideApplication)` 调用窗口操作服务，请求成功后隐藏面板。
- [ ] `.windowOperation(id, .closeWindow)` 调用窗口操作服务，请求成功后隐藏面板。
- [ ] `.windowOperation(id, .minimizeWindow)` 调用窗口操作服务，请求成功后隐藏面板。
- [ ] 操作失败时记录日志，不弹窗。
- [ ] 菜单跟踪期间离开轮询不隐藏面板；菜单结束后恢复离开判断。
- [ ] 测试 `.contextMenuBegan(id)` 后即使鼠标离开预览区域并触发离开轮询，`currentWindowsByID` 仍保留，随后 `.windowOperation(id, ...)` 仍能找到原窗口并执行。
- [ ] 测试 `.contextMenuEnded(id)` 后下一次离开轮询会按真实鼠标位置隐藏面板并清空上下文。
- [ ] 会话隐藏后收到旧菜单动作，应记录 missing window 或 stale action，不影响新会话。

阶段检查：

```bash
swift test --filter PreviewSessionControllerTests
swift test
swift build
git diff --check
```

### Task 5：屏幕/环境提示

涉及文件：

- `Sources/DockHoverPreviewProbe/WindowEnvironmentDescriptor.swift`
- `Sources/DockHoverPreviewProbe/PreviewSessionController.swift`
- `Tests/DockHoverPreviewProbeTests/WindowEnvironmentDescriptorTests.swift`
- `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`

步骤：

- [ ] 新增纯逻辑屏幕匹配 helper，按窗口 frame 与屏幕 frame 最大交集选择屏幕。
- [ ] 在创建卡片模型时注入环境提示文案。
- [ ] 测试单屏幕、多屏幕、无法匹配屏幕三类情况。
- [ ] 确认提示只作为信息展示，不参与窗口操作请求成功判断。

阶段检查：

```bash
swift test --filter WindowEnvironmentDescriptorTests
swift test --filter PreviewSessionControllerTests
git diff --check
```

### Task 6：文档和人工验收

涉及文件：

- `README.md`
- `docs/roadmap.md`
- `docs/architecture/dock-hover-preview-technical-design.md`
- `docs/verification/dock-hover-preview-p3-window-actions-manual-checklist.md`
- `docs/verification/dock-hover-preview-probe-summary.md`

步骤：

- [ ] 新增 P3 人工验收清单，未执行项保持未运行，不提前写通过。
- [ ] 更新 README 和架构设计，说明 P3 窗口操作只使用公开接口。
- [ ] 更新路线图 P3 状态和已完成项。
- [ ] 记录自动验证命令和结果。

最终自动验证：

```bash
swift test
swift build
Scripts/build_probe_app.sh
git diff --check
```

人工验收建议：

- 底部程序坞：右键菜单四个操作可见，主点击仍激活窗口。
- 左/右程序坞：右键菜单不越界，打开菜单时面板不会提前消失。
- 程序坞自动隐藏：菜单打开期间不会因为鼠标离开卡片而丢失操作上下文。
- 台前调度：有真实窗口时操作正常；占位卡片没有真实窗口元素时关闭/最小化应禁用或失败安静。
- 浅色/深色外观：菜单和面板可读。
- 减少动态效果：窗口操作后隐藏面板不出现旧面板残留。
- 屏幕录制权限缺失：不显示预览面板，也不会出现右键菜单。
- 系统辅助功能权限缺失：不启动程序坞监听，不弹出重复提示。
- VS Code、Chrome、Typora、IINA、WPS：分别抽样验证激活、隐藏应用、关闭窗口、最小化窗口。

## 风险和回退

- 关闭/最小化依赖目标应用的辅助功能树；某些应用可能没有按钮元素或拒绝动作。回退方式是禁用菜单项或记录失败，不尝试私有接口。
- 右键菜单如果无法可靠获得菜单关闭事件，会影响离开轮询。回退方式是先只实现主点击激活和隐藏应用，把关闭/最小化菜单延后。
- 最小化窗口请求成功后，该窗口可能不再属于当前可见窗口范围。P3 先隐藏面板，不在原面板中动态删除卡片。
- 关闭窗口可能触发目标应用的保存确认弹窗；P3 不代替用户处理确认弹窗，只发出关闭请求并记录结果。
- 屏幕/环境提示只能表达公开接口能推断的信息，不承诺真实空间归属。

## Ready 条件

P3 可合并前必须满足：

- `swift test` 通过。
- `swift build` 通过。
- `Scripts/build_probe_app.sh` 通过，输出仍为 `/Users/zong/Desktop/Project/zongMacTools/build/zongMacTools.app`。
- `git diff --check` 通过。
- P1 默认行为测试保持通过。
- 屏幕录制权限缺失时不显示预览 UI。
- 右键菜单打开期间不会因离开轮询丢失当前窗口上下文。
- 关闭/最小化只使用公开接口；失败安静降级并记录日志。
- 未执行的人工验收项不写成通过。
