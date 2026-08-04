# Finder 右键扩展、文件创建与开发工具开发计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不破坏现有 Dock 窗口速览的前提下，为 `zongMacTools` 增加一个经过平台探针验证的 Finder Sync 右键扩展；它可创建内置或导入模板文件，并按冻结 Finder 上下文调用 Terminal、Visual Studio Code 和用户登记的 `.app`。

**Architecture:** Finder Sync extension 只读取原子菜单快照、冻结 Finder 上下文、写入单条命令文件并通过 `zongmactools://command/<UUID>` 唤醒主程序。主程序保持非沙盒，持有 App Group 的 host lock，串行领取 pending 命令，完成文件创建或公开 API 的工具打开调用，并发布无路径 result。共享协议代码位于主程序源码树中，由 SwiftPM 主程序和 Xcode 的 extension target 按源文件共享；extension 不链接 Dock 窗口速览实现。

**Tech Stack:** Swift 6、SwiftPM、Xcode Finder Sync Extension target、AppKit、FinderSync、Foundation、NSWorkspace、NSPasteboard、BSD `flock`/`lstat`/`renameatx_np`、XCTest、shell build scripts。

---

日期：2026-08-04

设计依据：[Finder 右键扩展：文件创建与开发工具设计](../specs/2026-07-30-finder-context-menu-file-creation-developer-tools-design.md)

## 审批边界

本计划分为阶段 0、探针评审、正式业务三个边界。任务 1 至 8 是唯一可以立即开始的实现任务。它们只证明公开 API、签名、probe 专用上下文/命令、最小队列和不覆盖提交路线；不得在其中加入正式 `FinderCommand`/`FinderMenuCatalog`、14 个正式模板、`configuration.json`、设置 UI、VS Code 注册、自定义工具登记或用户文件创建。

任务 9 至 17 只有在任务 8 形成完整验证记录、所有强制项通过且设计规格重新审批后才可执行。外置卷不可用可以在记录中标为 `blocked / not available`，但不能据此发布外置卷兼容性承诺。

下列情形一旦出现，停止正式业务开发并回到架构设计：App Group 往返失败、Finder Sync 无法覆盖普通本地目录、URL Scheme 不能稳定唤醒主程序、pending 不能可靠排空、启动磁盘不支持 `RENAME_EXCL` 不覆盖提交、Terminal Service 无稳定公开调用契约，或带隔离属性的 ad-hoc ZIP 无法在干净环境启用 extension 并完成最小往返。

## 前置检查与文件地图

开始任何任务前运行：

```bash
git status --short --branch
swift test
swift build
```

当前工作树已有 Dock 窗口速览相关未提交改动。所有任务都必须在这些改动之上工作；不得执行 `git reset --hard`、`git checkout --`、整文件覆盖或把无关文件 stage 到本功能提交中。

每个任务开始前先对 `Files` 清单中的每个 `Modify` 路径执行 `git diff -- <exact-path>` 并保存其任务前基线。提交步骤中的普通 `git add <exact-path>` 只适用于任务前干净的已跟踪文件或本任务新建文件；若某个 `Modify` 文件在任务前已有用户 diff，必须用 `git add -p -- <exact-path>` 只接受本任务新增 hunks并拒绝所有基线 hunks。若新旧修改落在同一不可分割 hunk，停止提交并改用新的 isolated worktree 或让用户先处理该文件，不能把整文件加入 index。所有 staging 只能使用任务 `Files` 清单中的精确文件 pathspec，不得对源码、资源、测试或 Xcode project 目录执行目录级 `git add`。每次 staging 后、`git commit` 前必须运行：

```bash
git diff --cached --name-only
git diff --cached --check
git diff --cached
```

预期：名称列表是本任务 `Files` 清单的子集且包含本任务实际改动的全部文件，`--check` 无输出且退出 0，完整 staged diff 不包含任务前基线、既有 Dock 窗口速览改动或其他任务文件；不满足时停止提交并只调整 index，不改写或丢弃工作树中的用户改动。

每个任务开始时在当前 shell 定义以下 staging helper；后续提交块只调用该 helper，不直接调用 raw `git add`：

```bash
stage_task_path() {
  for task_path in "$@"; do
    if git ls-files --error-unmatch -- "$task_path" >/dev/null 2>&1; then
      git add -p -- "$task_path"
    else
      git add -- "$task_path"
    fi
  done
}
```

已跟踪路径无论任务前是否干净都通过 `git add -p` 逐 hunk 确认；任务前已有 diff 时只接受本任务新增 hunks并拒绝基线 hunks。未跟踪的 `Create` 路径只能按提交块中的精确 path 加入。helper 不改变“同一不可分割 hunk 混入基线时停止提交”的规则。每次 helper 调用后仍执行上面的 staged diff 检查；路径集合与 staging 方式是两个必须同时满足的约束。

| 文件 | 责任 |
| --- | --- |
| `zongMacTools.xcodeproj/project.pbxproj` | 只声明 Finder Sync extension target、共享源文件引用、extension resources 和 scheme；不取代 SwiftPM 主程序 target。 |
| `Sources/RightClickFinderExtension/RightClickFinderExtension.swift` | 受沙盒约束的 Finder Sync extension；构造 `NSMenu`、冻结上下文、写命令、发 URL Scheme。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderCommandSubmitter.swift` | Task 14 后生效、由主程序与 extension 按源文件共享的正式命令发布器；复用共享 validator/queue，负责 staging 槽位、pending 原子发布和发布后的 URL 唤醒。 |
| `Sources/RightClickFinderExtension/Info.plist` | Finder Sync extension point、principal class、最低系统版本和 bundle metadata。 |
| `Sources/RightClickFinderExtension/RightClickFinderExtension.entitlements` | App Sandbox 与 `group.com.zong.zongMacTools`。 |
| `Sources/RightClickFinderExtension/FinderDirectoryRegistration.swift` | 只负责 Finder Sync 目录根注册以及卷挂载/卸载后的受限刷新。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderProbeModels.swift` | 阶段 0 专用的 `FIMenuKind` 原始输入、对象 identity、冻结诊断上下文和 256 项规则；不提供文件创建或工具目标。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderProbeCommandProtocol.swift` | 阶段 0 单一 `probeCounter` action、无路径 probe result、JSON 编解码和边界校验；不得被正式业务命令复用。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderProbeMenuPlan.swift` | 阶段 0 固定单一诊断 action 和禁用状态的纯渲染计划；不定义正式菜单 catalog。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderContextModels.swift` | Task 9 后生效的正式 Finder 上下文、对象 identity、目标解析和 256 项规则。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderMenuCatalog.swift` | Task 9 后生效的正式菜单快照 schema、尺寸/字段验证、固定排序和 `FinderMenuPlan`。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/CommandProtocol.swift` | Task 9 后生效的正式命令/result schema、JSON 编解码、UUID、identity 与完整双端校验。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/AtomicFileSupport.swift` | 同目录 staging、`fsync`、close 检查、无符号链接打开和受限枚举工具。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandQueue.swift` | `staging`/`pending`/`processing`/`results`、queue lock、领取和恢复。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift` | host lock、URL/目录观察、串行 drainer、at-most-once result、错误反馈领取，以及正式配置、模板、工具和 catalog 状态事务的唯一串行协调入口。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderConfigurationStore.swift` | 阶段 1 后的 current/previous JSON 配置、初始化 marker 和 schema 迁移。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderMenuCatalogPublisher.swift` | 从有效配置发布有限、原子替换的 `menu-catalog.json` revision。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/TemplateLibrary.swift` | 内置资源验证、自定义模板导入/删除事务和恢复。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/AtomicFileCreator.swift` | 目标目录 identity 验证、逐级 no-follow 打开、候选命名和 `RENAME_EXCL` 提交。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/DeveloperToolLauncher.swift` | VS Code、Terminal 和自定义 `.app` 的公开打开 API 与 result 完成边界。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/CustomDeveloperToolStore.swift` | 自定义 `.app` 的普通书签、绑定校验、重绑和去重约束。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/TerminalServiceDescriptors.swift` | 经阶段 0 回填的只读 Terminal descriptor 表及当前系统匹配。 |
| `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderProbeHost.swift`、`AtomicCommitProbe.swift`、`TerminalServiceProbe.swift` | 只在阶段 0 使用的无用户业务副作用、`RENAME_EXCL` 与 Terminal Services 证据采集。 |
| `Sources/DockHoverPreviewProbe/Settings/FinderContextMenuSettingsView.swift` | 阶段 1 后替换右键扩展占位的设置 detail 页面。 |
| `Sources/DockHoverPreviewProbe/App/AppDelegate.swift` | 创建并生命周期管理 `FinderCommandCoordinator`，转发 URL 打开事件，不改变现有 Dock 预览 wiring。 |
| `Sources/DockHoverPreviewProbe/Settings/SettingsPage.swift`、`SettingsRootView.swift`、`ToolDescriptor.swift` | 添加真实右键扩展设置页并移除“未开发”占位。 |
| `Sources/DockHoverPreviewProbe/Info.plist` | URL Scheme、Finder 功能的 TCC 用途说明、本地化入口。 |
| `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/` | 14 个内置模板；OOXML 为已验证二进制资源。 |
| `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/manifest.json` | 三个 OOXML 二进制资源的稳定 ID、相对路径和 SHA-256 发布记录。 |
| `Sources/DockHoverPreviewProbe/Resources/en.lproj/InfoPlist.strings`、`zh-Hans.lproj/InfoPlist.strings` | 外层用途说明的英语和简体中文本地化。 |
| `Scripts/build_probe_app.sh`、`Scripts/verify_app_bundle.sh`、`Scripts/package_release_app.sh` | 构建 extension、从内到外签名、bundle/entitlement/URL Scheme 检查和发布 ZIP。 |
| `Scripts/Probes/run_finder_context_menu_probe.sh` | 阶段 0 可重复执行的本机 probe orchestration。 |
| `Tests/DockHoverPreviewProbeTests/FinderContextMenu*.swift` | 共享领域、队列、文件创建、模板、工具、配置和设置的 SwiftPM 自动测试。 |
| `docs/verification/finder-context-menu-stage-0-probe-record.md` | 每个阶段 0 强制项的真实 OS、架构、日志、输入/输出和结论。 |
| `docs/verification/finder-context-menu-stage-0-review.md` | 冻结阶段 0 record 与 Terminal descriptor 内容摘要的独立评审结论；任一被引用输入变化都会使批准失效。 |
| `docs/verification/finder-context-menu-manual-checklist.md` | 阶段 1 至 3 和发布候选的人工作业、TCC、外置卷、Office 与下载安装验证。 |
| `docs/verification/finder-context-menu-release-candidate-record.md` | 正式候选的独立验收记录、ZIP SHA-256、干净安装和升级环境结论；不得回写已批准的阶段 0 record。 |

## 阶段 0：最小平台探针

### Task 1：建立 Finder Sync target、签名边界和最小 bundle 验证

**Files:**

- Create: `zongMacTools.xcodeproj/project.pbxproj`
- Create: `Sources/RightClickFinderExtension/RightClickFinderExtension.swift`
- Create: `Sources/RightClickFinderExtension/Info.plist`
- Create: `Sources/RightClickFinderExtension/RightClickFinderExtension.entitlements`
- Create: `Sources/DockHoverPreviewProbe/Entitlements/zongMacTools.entitlements`
- Modify: `Package.swift`
- Modify: `Sources/DockHoverPreviewProbe/Info.plist`
- Modify: `Scripts/build_probe_app.sh`
- Modify: `Scripts/verify_app_bundle.sh`
- Modify: `Tests/DockHoverPreviewProbeTests/PackagingTests.swift`

- [ ] **Step 1: 写入失败的 bundle/entitlement 自动测试。**

在 `PackagingTests.swift` 增加真实临时 Bundle fixture 测试，实际执行 `Scripts/verify_app_bundle.sh` 并断言缺少 `.appex`、principal class 错误、App Group 不一致、错误 sandbox、错误 URL Scheme、错误签名身份或错误架构时均以非零退出；再用完整 fixture 验证成功路径。仅搜索脚本文本不能作为失败测试的通过条件。验证脚本必须检查以下不可省略项：

```swift
func testFinderExtensionBundleValidationRequiresExpectedNestedArtifacts() throws {
    let fixture = try makeSignedFinderBundleFixture(
        principalClass: "WrongPrincipalClass"
    )
    let result = try runBundleVerifier(fixture.appURL)
    XCTAssertNotEqual(result.exitStatus, 0)
    XCTAssertTrue(result.stderr.contains("NSExtensionPrincipalClass"))
}
```

同一 suite 为每个字段生成单独错误 fixture，不能通过一个包含多处错误的 fixture 推断验证器覆盖了全部字段。`makeSignedFinderBundleFixture` 必须实际生成并 ad-hoc 签名最小可解析 Bundle；无法在当前测试环境签名时，该 suite 必须明确失败或仅把签名 fixture 标为需要 macOS runner 的独立测试，不能把源码字符串搜索替代为通过。

- [ ] **Step 2: 运行测试并确认当前包尚未满足 extension 结构。**

```bash
swift test --filter PackagingTests
```

预期：测试失败，因为现有验证脚本未用结构化 fixture 检查嵌入 `.appex`、principal class、App Group、extension sandbox、ad-hoc 实际签名身份和 URL Scheme。

- [ ] **Step 3: 创建 Xcode extension target 和签名输入。**

在 Xcode 创建 macOS Finder Sync Extension target，并统一配置 SwiftPM、外层 bundle 与 Xcode target：

```text
Main bundle identifier: com.zong.zongMacTools
Extension bundle identifier: com.zong.zongMacTools.RightClickFinderExtension
Extension point: com.apple.FinderSync
Principal class: RightClickFinderExtension
Deployment target: 14.0
App Group: group.com.zong.zongMacTools
Main app sandbox entitlement: absent
Extension sandbox entitlement: present
SwiftPM platforms: macOS 14.0
Outer LSMinimumSystemVersion: 14.0
```

`Package.swift` 必须声明 `.macOS(.v14)` 并排除 `Sources/RightClickFinderExtension/`，避免 SwiftPM 把 extension principal class 链接进主 executable。Xcode extension target 在本任务只编译 extension 目录中的最小 principal class；Task 2 再把三个 probe 专用共享文件加入显式 target membership，Task 9 将其替换为正式共享源。任何阶段都不能用整个目录的隐式 membership 把主程序源码带入 extension。

外层 `Info.plist` 在本任务加入 `LSMinimumSystemVersion = 14.0` 和唯一 URL Scheme 注册：稳定 `CFBundleURLName`、合法 `CFBundleTypeRole`、`CFBundleURLSchemes = ["zongmactools"]`。阶段 0 后续任务只实现 URL handler，不再改变该注册。

更新构建脚本：先通过 `xcodebuild` 生成 `.appex`，复制到 `zongMacTools.app/Contents/PlugIns/RightClickFinderExtension.appex`，以 extension entitlements 对 `.appex` ad-hoc 签名，最后才以主程序 entitlements 签外层 `.app`。禁止 `codesign --deep --force` 作为签名步骤。

- [ ] **Step 4: 扩展验证脚本并重新运行打包测试。**

`verify_app_bundle.sh` 必须验证主 executable 是 `DockHoverPreviewProbe`、extension executable/Info.plist 存在、`NSExtensionPointIdentifier = com.apple.FinderSync`、构建产物中展开后的 `NSExtensionPrincipalClass` 解析到配置的 `RightClickFinderExtension` class、主/extension bundle ID、主程序 URL Scheme、主/extension App Group 一致、主程序未 sandbox、extension 已 sandbox、架构集合相同；还要解析并断言 SwiftPM platform、外层 `LSMinimumSystemVersion` 和所有参与构建的 Xcode target deployment target 均为 `14.0`。脚本必须记录签名命令确实以 `-` 作为两层 identity 输入，并用 `codesign --display --verbose=4` 或等价结构化结果证明主程序和 `.appex` 的实际签名均报告为 ad-hoc；把输出摘要写入 probe record，不能把 `-` 参数本身伪装成实际签名结果，也不能只依赖 `codesign --verify` 或检查文案中是否提到“ad-hoc”。

```bash
swift test --filter PackagingTests
Scripts/build_probe_app.sh
Scripts/verify_app_bundle.sh build/zongMacTools.app
```

预期：测试和脚本都通过；命令输出中能看到嵌入 extension 和主/extension 的签名验证。

- [ ] **Step 5: 以仅包含 target 与验证脚本的范围提交。**

```bash
stage_task_path Package.swift zongMacTools.xcodeproj/project.pbxproj
stage_task_path Sources/RightClickFinderExtension/RightClickFinderExtension.swift
stage_task_path Sources/RightClickFinderExtension/Info.plist
stage_task_path Sources/RightClickFinderExtension/RightClickFinderExtension.entitlements
stage_task_path Sources/DockHoverPreviewProbe/Info.plist
stage_task_path Sources/DockHoverPreviewProbe/Entitlements/zongMacTools.entitlements
stage_task_path Scripts/build_probe_app.sh Scripts/verify_app_bundle.sh
stage_task_path Tests/DockHoverPreviewProbeTests/PackagingTests.swift
git commit -m "build: add Finder Sync extension target"
```

### Task 2：实现 probe 专用 Finder 诊断上下文和命令

**Files:**

- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderProbeModels.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderProbeCommandProtocol.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderProbeMenuPlan.swift`
- Modify: `zongMacTools.xcodeproj/project.pbxproj`
- Create: `Tests/DockHoverPreviewProbeTests/FinderProbeContextTests.swift`
- Create: `Tests/DockHoverPreviewProbeTests/FinderProbeCommandProtocolTests.swift`

- [ ] **Step 1: 先写 probe 领域失败测试。**

测试只覆盖阶段 0 需要证明的诊断能力：`contextualMenuForContainer`/`contextualMenuForItems` 原始来源、package/`.app`/alias/symlink/volume root 分类、原始数组 256/257 边界、稳定去重顺序、本机 `file:` URL、规范 identity、1 MiB 命令和 16 KiB 单 URL 上限。`FinderProbeCommand` 的 action 只能是 `probeCounter`，不得出现 `createFile`、`openTool`、`subjectID`、语言、文件创建目标或 Terminal 目标。核心构造样例：

```swift
let context = FrozenFinderProbeContext(
    invocation: .items,
    items: [.init(
        url: URL(fileURLWithPath: "/tmp/README.md"),
        itemKind: .file,
        identity: .init(device: "16777232", inode: "123456789")
    )],
    observedTargetedURL: nil,
    observedSelectedItemCount: 1
)

XCTAssertEqual(context.items.count, 1)
XCTAssertEqual(context.items[0].identity.inode, "123456789")
```

- [ ] **Step 2: 确认测试在 API 尚不存在时失败。**

```bash
swift test --filter FinderProbeContextTests
swift test --filter FinderProbeCommandProtocolTests
```

预期：编译失败，因为 `FrozenFinderProbeContext`、`FinderProbeObjectIdentity`、`FinderProbeCommand` 和 probe 编码器尚不存在。

- [ ] **Step 3: 实现无 AppKit 依赖的 probe-only 类型。**

定义并测试以下稳定类型：

```swift
enum FinderProbeInvocation: String, Codable, Sendable {
    case container, items
}

struct FinderProbeObjectIdentity: Codable, Equatable, Sendable {
    let device: String
    let inode: String
}

enum FinderProbeAction: String, Codable, Sendable {
    case probeCounter
}
```

`FinderProbeObjectIdentity` 的两个字段必须是由 `lstat` 无符号值转成的规范十进制字符串：只允许 ASCII 数字、无正负号、无前导零（值 `0` 例外），并在写入/读取边界检查其可解析为无符号整数。`FinderProbeCommand` 只包含 schema、canonical uppercase UUID、`createdAt`、固定 action、原始 `FIMenuKind` 诊断、URL、`itemKinds`、一一对应的 identities 和可选目标目录 identity。extension 编码端与主程序解码端都必须拒绝非本机 `file:` URL、远程 host、字段数量不一致、未知 enum、非规范 identity、非法 UUID、超过大小限制以及早于当前时间 5 分钟或晚于 1 分钟的命令。

`FinderProbeMenuPlan` 只能产生单一可点击“运行平台探针”action，或单一禁用状态；不得包含正式分组、模板、工具、语言、排序或 512 KiB catalog 规则。完成后将这三个 probe 文件显式加入 extension target membership。

- [ ] **Step 4: 运行领域测试。**

```bash
swift test --filter FinderProbeContextTests
swift test --filter FinderProbeCommandProtocolTests
```

预期：所有测试通过，257 个原始 URL 无论去重后数量如何都产生 `selectionTooLarge`，且任何正式 action/subject/language 字段都会被 probe decoder 拒绝。

- [ ] **Step 5: 提交共享协议。**

```bash
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderProbeModels.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderProbeCommandProtocol.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderProbeMenuPlan.swift
stage_task_path zongMacTools.xcodeproj/project.pbxproj
stage_task_path Tests/DockHoverPreviewProbeTests/FinderProbeContextTests.swift
stage_task_path Tests/DockHoverPreviewProbeTests/FinderProbeCommandProtocolTests.swift
git commit -m "test: specify Finder stage zero probe protocol"
```

### Task 3：实现 App Group 往返和最小命令队列 probe

**Files:**

- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/AtomicFileSupport.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandQueue.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderProbeHost.swift`
- Modify: `Sources/RightClickFinderExtension/RightClickFinderExtension.swift`
- Modify: `zongMacTools.xcodeproj/project.pbxproj`
- Create: `Tests/DockHoverPreviewProbeTests/FinderCommandQueueTests.swift`
- Create: `docs/verification/finder-context-menu-stage-0-probe-record.md`

- [ ] **Step 1: 写入队列原子性和恢复失败测试。**

覆盖固定目录 `right-click/commands/{staging,pending,processing,results}`、`right-click/state`、`right-click/probe`、空的 `right-click/templates/.staging` 的逐级 directory-FD 相对创建/打开；任一祖先分量为 symlink、非目录、在打开期间被替换或 `fstat` identity 不一致时必须失败且不在替代位置读写。阶段 0 只允许建立空的 templates 固定目录，不创建模板记录、内容、manifest 或 catalog。随后覆盖 `staging -> pending -> processing -> result`、`staging + pending + processing` 合计 255/256 容量、`queueBusy`、`queueFull`、`flock` 同 inode 互斥、锁内计数加 `O_CREAT | O_EXCL | O_NOFOLLOW` 槽位预留、staging 半写不可读、重复 drain 只领取一次、pending 过期、result 写入失败时保留 processing、启动恢复无 result 时先写 `unknown` 再删除 processing、已有 result 优先、`feedbackClaimedAt` 原子领取、24 小时/4,096 条 result 回收顺序和 `resultStoreFull` 时不领取 pending。过期 pending 测试必须断言先写 action 可判定时沿用原 action、内容无法判定时为 `unknown` 的无路径 `failed` result，错误分类明确表示命令过期；写入成功后才在 queue lock 内删除，result 无空间或写入失败时保留原 pending 且不执行 counter。测试还必须证明 24 小时内未领取的 `failed`/`unknown` 不会为腾出空间被删除。测试临时 Group Container 时必须传入显式测试目录，不能使用真实用户 Group Container。

- [ ] **Step 2: 运行并确认测试失败。**

```bash
swift test --filter FinderCommandQueueTests
```

预期：失败，因为队列、锁和原子发布 API 尚不存在。

- [ ] **Step 3: 实现最小队列与 probe counter。**

`FinderProbeHost` 只能执行以下副作用：读取/写入 `probe/request.json` 和 `probe/response.json`、递增 `probe-counter.json`、写入/领取 `FinderProbeCommand`、生成 action 仅为 `probeCounter` 或协议损坏时 `unknown` 的无路径 result。result 只保存命令 ID、action、完成时间、`succeeded`/`failed`/`unknown`、错误分类和可选 `feedbackClaimedAt`。它不得引用正式 `FinderCommand`、`TemplateLibrary`、`DeveloperToolLauncher`、正式设置模型或任何用户目录。

`AtomicFileSupport.swift` 先提供唯一的 managed-root opener：从 App Group container directory FD 开始，使用 directory-FD 相对 `mkdirat`/`openat`，每个固定分量均禁止 `..`、空名称和路径分隔符，以 `O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC` 打开并立即 `fstat`；创建竞争只在重新打开并验证为预期目录时接受。它返回持有的 `right-click`、`commands`、各队列状态、`state`、`probe`、`templates` 和 `templates/.staging` directory FD，不在验证后退回绝对路径。Task 5、10、11、14 的生产状态访问必须复用该入口，不能各自用 `FileManager.createDirectory` 或字符串拼接重建一份安全边界。阶段 0 对 templates FD 只做空目录安全验证，不能读写正式模板状态。

队列锁固定为 `right-click/commands/queue.lock`，相对已验证的 commands directory FD 以 `O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW`、模式 `0600` 创建，立即 `fstat` 确认为普通文件，再调用 `flock(fd, LOCK_EX | LOCK_NB)`；extension 锁忙立即失败，主程序锁忙延后 drain。extension 必须在持锁期间完成三种状态计数和 staging 槽位预留，随后释放锁再写内容；写入完成前 drainer 不得读取 staging。所有 JSON 以同目录临时文件完成 write loop、权限、`fsync`、close、重新打开校验后才原子 rename。

所有改变 staging/pending/processing 计数的删除、领取和回收都必须重新取得同一 queue lock，并在删除前用 no-follow 打开和 `fstat` 二次确认规范名称、普通文件及目标 inode。staging 未满 10 分钟不回收；超过 10 分钟也只有在名称为规范 UUID、没有同 UUID pending/processing 且不是未来时间时才回收。result 写入前先按“超过 24 小时、最早 succeeded、最早且已领取反馈的 failed/unknown”顺序清理；仍满时写一次 `resultStoreFull` 诊断并暂停领取，不执行 probe counter。

- [ ] **Step 4: 将主/extension Group Container API 接到 probe。**

两端只能通过：

```swift
FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.zong.zongMacTools"
)
```

取得容器。禁止拼接 `~/Library/Group Containers`。本任务把 `FinderCommandQueue.swift` 和 `AtomicFileSupport.swift` 显式加入 extension target membership，并在最小 extension 菜单回调中加入两个仅供 probe harness 触发的入口：读取 request/写 response，以及与主程序争用同一 queue lock 并预留 probe staging 槽位。它们不显示正式菜单项、不解析业务 subject，也不创建用户文件。extension 打开真实 Finder 菜单后读取 request，写入包含 request UUID、标准化容器 URL 和 extension bundle ID 的 response。

- [ ] **Step 5: 运行自动测试与本机双向 probe。**

```bash
swift test --filter FinderCommandQueueTests
Scripts/build_probe_app.sh
Scripts/Probes/run_finder_context_menu_probe.sh app-group-round-trip
Scripts/Probes/run_finder_context_menu_probe.sh queue-contention
```

预期：自动测试通过；probe record 记录主程序和 extension 的相同容器 URL、双向原子读写、实际 entitlements 和 Console 结果。`queue-contention` 必须使用真实沙盒 extension 与非沙盒主程序争用同一个 `queue.lock` inode，并记录预留成功、`queueBusy`、`queueFull`、256 条总容量上限、发布者在 5 分钟内中止后不回收以及超过 10 分钟后按规则回收；另记录未领取错误保护、`resultStoreFull` 暂停和 probe counter 对同一命令不得递增两次。

- [ ] **Step 6: 提交最小队列和 probe 记录模板。**

```bash
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/AtomicFileSupport.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandQueue.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderProbeHost.swift
stage_task_path Sources/RightClickFinderExtension/RightClickFinderExtension.swift zongMacTools.xcodeproj/project.pbxproj
stage_task_path Tests/DockHoverPreviewProbeTests/FinderCommandQueueTests.swift
stage_task_path docs/verification/finder-context-menu-stage-0-probe-record.md
git commit -m "feat: add Finder command queue probe"
```

### Task 4：实现最小 Finder Sync 菜单与上下文探针

**Files:**

- Modify: `Sources/RightClickFinderExtension/RightClickFinderExtension.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderProbeMenuPlan.swift`
- Create: `Tests/DockHoverPreviewProbeTests/FinderProbeMenuPlanTests.swift`
- Modify: `Scripts/Probes/run_finder_context_menu_probe.sh`
- Modify: `docs/verification/finder-context-menu-stage-0-probe-record.md`

- [ ] **Step 1: 写 probe 菜单 action factory 和状态选择失败测试。**

Task 2 已实现 `FinderProbeMenuPlan` 的 action/禁用状态，本任务测试尚不存在的 `FinderProbeMenuActionFactory`：它只能把可点击 plan 与同一次菜单构造产生的 `FrozenFinderProbeContext` 组合成一个 `probeCounter` 命令；禁用 plan 不生成命令；Finder 选择后续变化不得修改已经生成的命令 bytes。测试同时固定 container/items API 空值、两个 API 同时有值、非本机 `file:` URL、远程 file host、256/257 原始项、冻结后 identity，以及无效输入只产生一个禁用状态。不得测试正式菜单 schema、语言、模板、工具、分组、排序或 catalog 回退。extension-specific `NSMenu` 不放入 SwiftPM 单元测试；SwiftPM 测试的是 extension 调用的纯 action factory 和 `FinderProbeMenuPlan`。

- [ ] **Step 2: 运行失败测试。**

```bash
swift test --filter FinderProbeMenuPlanTests
```

预期：编译失败，因为 `FinderProbeMenuActionFactory` 尚不存在。

- [ ] **Step 3: 实现 extension 的最小菜单。**

在 `FinderProbeMenuPlan.swift` 实现纯 `FinderProbeMenuActionFactory`，只接受 frozen context 和 plan，拒绝 disabled plan，产出固定 `probeCounter` 命令；extension 不得自行重新读取 Finder selection 或重建 context。`menu(for:)` 只响应 `contextualMenuForContainer` 和 `contextualMenuForItems`。container 只取 `targetedURL()`；items 只取 `selectedItemURLs()`。在菜单构建线程同步执行的工作限制为：原始数组上限、resource values、`lstat` identity、probe-only 上下文解析、固定 `FinderProbeMenuPlan` 渲染和 action factory。阶段 0 菜单只显示一个 probe action；动作把 action factory 在构造菜单时生成并冻结的 `FinderProbeCommand` 写入 staging/pending，并打开已经由 Task 1 注册的 URL Scheme。

extension 启动先登记 `/` 作为监控目录，阶段 0 在普通本地目录验证；它还必须以节流方式写入 `state/extension-heartbeat.json`，内容仅含 extension bundle ID、时间戳和固定 probe schema revision，不含 Finder URL。阶段 0 通过 `FIFinderSyncController.isExtensionEnabled` 与该 heartbeat 分别记录系统启用状态和实际活动，不能增加正式 settings UI。不能在该回调中启动主程序、扫描应用、读取模板正文、等待 IPC、访问网络或递归扫描目录。

- [ ] **Step 4: 完成上下文与性能 probe。**

```bash
swift test --filter FinderProbeMenuPlanTests
Scripts/build_probe_app.sh
Scripts/Probes/run_finder_context_menu_probe.sh finder-context
Scripts/Probes/run_finder_context_menu_probe.sh finder-coverage
Scripts/Probes/run_finder_context_menu_probe.sh menu-performance
Scripts/Probes/run_finder_context_menu_probe.sh extension-status
```

预期：probe record 覆盖 Finder 空白、单选文件夹、单选文件、多选、package、`.app`、symlink、alias、卷根、无效 URL 和非 `file:` URL，记录两种 `FIMenuKind` 下两个 API 的真实组合；菜单构造后改变 Finder 选择、替换同路径对象或改变 resource identity 时，已经序列化的 probe 命令字节不得改变。本任务不声称主程序已经完成 identity/type 复验；该端到端拒绝在 Task 5 完成 coordinator 后执行。`finder-coverage` 必须覆盖用户主目录、Desktop、Documents 和普通项目目录，并记录 `/` 注册是否覆盖真实外置卷根。`extension-status` 必须在系统管理界面手动启用/停用前后验证 `isExtensionEnabled` 的读取时状态，并证明它可以与缺失、过期或最新 heartbeat 独立组合。在启动磁盘上 1/64/256 项冷/热 20 次测量的 `menu(for:)` p95 不超过 150 ms。

- [ ] **Step 5: 提交菜单 probe。**

```bash
stage_task_path Sources/RightClickFinderExtension/RightClickFinderExtension.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderProbeMenuPlan.swift
stage_task_path Tests/DockHoverPreviewProbeTests/FinderProbeMenuPlanTests.swift
stage_task_path Scripts/Probes/run_finder_context_menu_probe.sh docs/verification/finder-context-menu-stage-0-probe-record.md
git commit -m "feat: probe Finder Sync context menus"
```

### Task 5：实现 URL Scheme 唤醒、drainer 和 at-most-once probe

**Files:**

- Modify: `Sources/DockHoverPreviewProbe/App/AppDelegate.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift`
- Create: `Tests/DockHoverPreviewProbeTests/FinderCommandCoordinatorTests.swift`
- Modify: `Scripts/Probes/run_finder_context_menu_probe.sh`
- Modify: `docs/verification/finder-context-menu-stage-0-probe-record.md`

- [ ] **Step 1: 写 URL 和恢复失败测试。**

覆盖合法 `zongmactools://command/<UPPERCASE-UUID>`、非法 scheme/host/path 不触发 scan、启动独立 scan、URL 丢失/合并/重复/乱序、observer 先 arm 再 scan、事件合并/丢失/source 重建后 full rescan、每轮处理后再次扫描到 quiescent、多个 pending 按 `(createdAt, UUID)` 稳定排序。host lock 测试必须覆盖 `O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW`、模式 `0600`、`fstat` 普通文件和 inode 身份确认、`LOCK_EX | LOCK_NB`、descriptor 生命周期持有，以及第二实例取锁失败后不读取、不写入、不清理任何共享状态。在领取前、领取后/counter 前、counter 后/result 前、result 后/processing 删除前注入终止，验证恢复只写 `unknown` 或沿用已有 result、绝不自动重放 counter；同时覆盖 `feedbackClaimedAt` 最多领取一次。另以可控 clock 覆盖五分钟边界：未过期命令正常领取，过期命令不进入 processing、不执行 counter，必须先写错误分类明确表示过期的无路径 `failed` result，再持 queue lock 删除 pending；result 写入失败或 `resultStoreFull` 时 pending 保留。使用可控的 `lstat`/resource-value adapter 覆盖菜单后选择变化不影响命令、同路径对象替换、类型变化、目标目录 identity 变化和目标卷弹出时拒绝执行；拒绝路径不得递增 counter。

- [ ] **Step 2: 运行失败测试。**

```bash
swift test --filter FinderCommandCoordinatorTests
```

预期：失败，因为 URL handler、host lock、目录观察与串行 drainer 尚不存在。

- [ ] **Step 3: 加入 URL handler、协调器和主程序复验。**

URL Scheme 已由 Task 1 注册；本任务不得新增第二个注册项。`AppDelegate` 在 launch 立即初始化 coordinator；已运行 app 收到 URL 时只接受 canonical command URL 并调度全量 pending drain。无论 URL 是否到达，正常 launch 都必须 scan pending。

coordinator 只通过 Task 3 的 managed-root opener 取得已验证的 state/pending/processing/results directory FD，并相对 state FD 以 `O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW`、模式 `0600` 打开 `host.lock`，立即 `fstat` 确认为预期普通文件并记录 inode，再以 `flock(fd, LOCK_EX | LOCK_NB)` 取得锁，在进程生命周期持续持有同一 descriptor；已有持锁实例时新实例不得读取或修改 App Group 其他状态并退出 probe host。取得 host lock 后观察 pending 目录时先 arm、后 scan；观察器安装、重建、事件合并或报告丢失后都做 full rescan，每轮按 `(createdAt, UUID)` 排序处理并再次扫描，直到没有可领取 pending 且观察器没有新变化才达到 quiescent。扫描时先做有界文件名/头部读取以判定 ID、action 和 createdAt；超过五分钟的规范 pending 不得作为普通 decoder 拒绝后直接清理，必须遵循 Task 3 的过期 result 顺序。未过期命令领取完成后再用 Task 2 的 probe decoder 做完整字段校验，并对冻结 URL 执行不跟随最终 symlink 的 identity/type 复验，全部通过后才运行 `FinderProbeHost` 的 counter 副作用。只有规范 UUID 文件名且 `action` 字段本身无法解码时，failed result 的 action 才为 `unknown`；若 action 已解码但 schema、URL、identity 或其他字段损坏，failed result 保留已解码 action。无法取得规范 UUID 的未知目录项只记录结构化错误，不打开、不跟随、不删除。

错误反馈领取沿用 Task 3 的 result store：只有即将显示阶段 0 诊断错误时才原子写入 `feedbackClaimedAt`，后台恢复不提前领取；领取后崩溃允许漏报但不得重复。`resultStoreFull` 时 coordinator 不领取 pending，也不执行 counter。

- [ ] **Step 4: 执行冷/热 URL 和重复恢复 probe。**

```bash
swift test --filter FinderCommandCoordinatorTests
Scripts/build_probe_app.sh
Scripts/Probes/run_finder_context_menu_probe.sh url-cold-hot
Scripts/Probes/run_finder_context_menu_probe.sh queue-recovery
Scripts/Probes/run_finder_context_menu_probe.sh frozen-context-revalidation
Scripts/Probes/run_finder_context_menu_probe.sh lifecycle-restart
```

预期：同一 pending 最多被领取一次；连续命令在任一合法 URL 或独立冷启动后被排空；同路径替换、类型变化、identity 变化和卷弹出均产生无路径 failed result 且 counter 不增加；第二主程序实例不改共享状态。`lifecycle-restart` 分别执行“仅重启主程序”“仅重启 Finder 使 extension 重载”“同时重启两者”，每种情况都重新验证 container URL、request/response、既有 pending 排空、processing 恢复为 `unknown`、已有 result 优先和同一 counter 不重复。probe record 还记录 `/Applications` 发布候选、开发副本、旧副本和替换安装时 Launch Services 的实际 URL 路由。

- [ ] **Step 5: 提交 URL/drainer probe。**

```bash
stage_task_path Sources/DockHoverPreviewProbe/App/AppDelegate.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift
stage_task_path Tests/DockHoverPreviewProbeTests/FinderCommandCoordinatorTests.swift
stage_task_path Scripts/Probes/run_finder_context_menu_probe.sh docs/verification/finder-context-menu-stage-0-probe-record.md
git commit -m "feat: drain Finder commands from URL wakeups"
```

### Task 6：验证启动磁盘的 `RENAME_EXCL` 不覆盖原子发布

**Files:**

- Modify: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/AtomicFileSupport.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/AtomicCommitProbe.swift`
- Create: `Tests/DockHoverPreviewProbeTests/AtomicCommitProbeTests.swift`
- Modify: `Scripts/Probes/run_finder_context_menu_probe.sh`
- Modify: `docs/verification/finder-context-menu-stage-0-probe-record.md`

- [ ] **Step 1: 写公开提交原语失败测试。**

测试同目录 temporary file、`EEXIST` 继续编号、`ENOTSUP`/`EINVAL` 映射 `atomicCommitUnsupported`、其他 errno 映射 `atomicCommitFailed`、`_PC_NAME_MAX` 未知映射 `nameLimitUnknown`，以及写入/`fsync`/close/rename 任一边界终止时非空临时内容不以最终文件名出现。启动卷验证器使用注入的 `lstat`、URL resource values 和 `diskutil info -plist` fixture 覆盖：`/` 与测试 root 的 `st_dev` 相同/不同，标准化 `volumeURL` 相同/不同，diskutil `MountPoint`/设备归属相符/矛盾/字段缺失、非本地、非内置、不可写和检查期间路径 identity 变化。`APFSVolumeGroupUUID` 只作为字段存在时记录的额外证据，缺失或非 APFS 不能单独判定失败；只要必需证据互相矛盾或无法证明测试 root 属于当前启动磁盘，才返回 `startupVolumeUnproven`。

- [ ] **Step 2: 运行失败测试。**

```bash
swift test --filter AtomicCommitProbeTests
```

预期：失败，因为 `AtomicFileSupport` 中唯一的 `renameatx_np(..., RENAME_EXCL)` 包装器、可注入 errno mapper 和启动卷身份校验尚不存在。

- [ ] **Step 3: 在共享支持层实现唯一提交原语，并限制 probe 目录。**

`AtomicFileSupport.swift` 定义唯一的 directory-FD 相对 `renameatx_np(..., RENAME_EXCL)` wrapper、`EEXIST`/`ENOTSUP`/`EINVAL`/其他 errno 映射和 `_PC_NAME_MAX` 查询。`AtomicCommitProbe` 只能调用该 wrapper，不得包含第二份 syscall 或 errno switch。

`atomic-commit` 子命令必须接收显式 `--startup-volume-test-root <absolute-directory>`，不得使用 `NSTemporaryDirectory()` 推断卷归属。脚本在创建任何 probe 文件前分别对 `/` 和该目录执行不跟随最终 symlink 的 `lstat`、读取公开 `volumeURL`/`volumeUUIDString`/`volumeIsLocal`/`volumeIsInternal`，并执行 `/usr/sbin/diskutil info -plist`。只有两者 `st_dev` 相同、标准化 `volumeURL` 相同、diskutil 可用字段没有给出相反设备/挂载点结论、目录为本地内置卷且可写时，才把测试 root 视为已证明位于启动磁盘。`APFSVolumeGroupUUID` 存在时记录并比较，缺失时记录 `not present`，不得将该 APFS 专属字段作为唯一通过或失败条件。任何必需证据缺失、矛盾或检查期间 root identity 改变时，probe 以 `startupVolumeUnproven` 失败而不是继续。所有原始字段、判定步骤和 OS build 一起写入验证记录，不把字段候选写成跨系统既定保证。

验证完成后只在该 root 下创建一个独占、随机命名的专用子目录，并在其中使用相对 directory FD、隐藏临时名和共享 wrapper。它只创建/清理带固定 `zongmactools-probe-` 前缀的普通文件；每次删除前核对名称、文件类型、测试子目录 identity，以及父目录仍满足刚才冻结的启动磁盘 `st_dev`/`volumeURL` 证据。任一归属检查失败时保留现场并停止自动清理。

- [ ] **Step 4: 运行自动与真实文件系统 probe。**

```bash
swift test --filter AtomicCommitProbeTests
finder_probe_startup_root="${FINDER_PROBE_STARTUP_ROOT:?set an existing absolute candidate directory}"
case "$finder_probe_startup_root" in /*) ;; *) exit 2 ;; esac
Scripts/Probes/run_finder_context_menu_probe.sh atomic-commit --startup-volume-test-root "$finder_probe_startup_root"
```

执行者必须先在 probe record 中记录 `FINDER_PROBE_STARTUP_ROOT` 的绝对值及选择理由，不能把 `/Users/Shared`、`NSTemporaryDirectory()` 或任何默认路径当作未经证明的启动卷事实。预期记录明确包含 `st_dev`、标准化 `volumeURL`、公开 volume 属性、diskutil 可用字段、可选 APFS 字段、逐步归属结论以及成功、冲突、竞争和崩溃边界；只要启动卷归属不能证明或不覆盖原子语义不能稳定复现，就停止后续文件创建开发。

- [ ] **Step 5: 提交原子提交 probe。**

```bash
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/AtomicFileSupport.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/AtomicCommitProbe.swift
stage_task_path Tests/DockHoverPreviewProbeTests/AtomicCommitProbeTests.swift
stage_task_path Scripts/Probes/run_finder_context_menu_probe.sh docs/verification/finder-context-menu-stage-0-probe-record.md
git commit -m "test: probe non-overwriting atomic file commit"
```

### Task 7：验证 Terminal Services 并生成 descriptor 证据

**Files:**

- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/TerminalServiceProbe.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/TerminalServiceDescriptors.swift`
- Create: `Tests/DockHoverPreviewProbeTests/TerminalServiceDescriptorTests.swift`
- Modify: `Scripts/Probes/run_finder_context_menu_probe.sh`
- Modify: `docs/verification/finder-context-menu-stage-0-probe-record.md`

- [ ] **Step 1: 写 descriptor 选择失败测试。**

测试 descriptor key 为 macOS build 范围和系统语言；只有完全匹配的 descriptor 才返回调用信息，缺失 descriptor 返回 `terminalDescriptorUnavailable`；`newWindow` 与 `newTab` 必须映射到 descriptor 的语义值而不是硬编码本地化菜单文案。通过可注入 Service performer 和 pasteboard factory 断言 probe 只调用 `NSPerformService(_:_:)` 契约、每次使用独立 pasteboard，并分别记录 `fileURL` 与 `NSFilenamesPboardType` 两种候选编码的接受/拒绝结果；单元测试不得把任何候选预设为可发布 descriptor。

- [ ] **Step 2: 运行失败测试。**

```bash
swift test --filter TerminalServiceDescriptorTests
```

预期：失败，因为 descriptor 模型和 selector 尚不存在。

- [ ] **Step 3: 用公开 API 实现 probe，不预置发布 descriptor。**

probe 的唯一公开调用候选是 AppKit 的 `NSPerformService(_:_:)`；pasteboard 必须用公开 `NSPasteboard.withUniqueName()` 创建专用实例，并只通过公开 pasteboard 写入接口写入候选目录 URL。probe 分别用 `NSPasteboard.PasteboardType.fileURL` 的 URL 对象写入，以及 SDK 仍公开但已废弃的 `NSFilenamesPboardType` 文件路径 property-list 表示，测试候选 `New Terminal at Folder` 与 `New Terminal Tab at Folder`；每个候选必须分别记录是否被 Service 接受，不能把候选字符串或单元测试映射当作通过。废弃表示只允许作为阶段 0 待验证候选，只有真实矩阵稳定通过并经 Task 8 评审批准后才能进入 descriptor。

它必须记录实际调用 API、pasteboard type/编码、Service 名称、系统语言、Terminal 未运行/已运行、有窗口/无窗口、Service 禁用和返回状态。probe 不使用 Apple Events、AppleScript、`osascript`、辅助功能、私有 API 或 `code` CLI；“专用 pasteboard”不得写成“私有 `NSPasteboard`”。

`TerminalServiceDescriptors.swift` 在真实矩阵完成前只能包含 schema 和匹配逻辑，不能伪造支持结果。真实 probe 的稳定结果先写入 verification record；只有记录已经包含两套系统、两种语言、两种模式及全部状态输入，才能把完全相同的 build range、language、API、Service 名称、pasteboard type/编码和语义写成候选 descriptor。候选 descriptor 在 Task 8 独立评审批准前不得被正式 launcher 使用。

- [ ] **Step 4: 在指定环境运行 probe。**

```bash
swift test --filter TerminalServiceDescriptorTests
Scripts/Probes/run_finder_context_menu_probe.sh terminal-services
```

预期：在 macOS 14 最新可用小版本和发布时当前支持的最新 macOS 上，English、简体中文各得到记录。每个稳定 descriptor 必须包含 macOS build 范围、系统语言、`NSPerformService` 调用契约、精确 Service 名称、pasteboard type/编码和 `newWindow`/`newTab` 语义；任一模式无稳定公开输入契约时，Task 8 必须将该强制项标为 `fail` 并停止所有正式业务，而不是只关闭 Terminal 菜单。

- [ ] **Step 5: 从完整事实记录回填候选 descriptor。**

逐行对照 probe record，将稳定通过的精确 tuple 写入 `TerminalServiceDescriptors.swift`。每个表项必须能回指 record 中的 OS build、语言、模式、Service 名称、pasteboard type/编码和返回状态；不得扩大 build range、合并未实测语言或用候选字符串补空项。以从 record 固定样例构造的测试断言 selector 只对精确范围和语言返回表项，范围边界外、语言不匹配或任一字段缺失均返回 `terminalDescriptorUnavailable`。

- [ ] **Step 6: 运行 descriptor 回填测试并生成输入摘要。**

```bash
swift test --filter TerminalServiceDescriptorTests
shasum -a 256 Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/TerminalServiceDescriptors.swift
shasum -a 256 docs/verification/finder-context-menu-stage-0-probe-record.md
```

预期：测试通过；两个 SHA-256 进入 Task 8 评审输入。descriptor 无稳定表项或与 record 不一致时不得进入 Task 8 的通过结论。

- [ ] **Step 7: 提交 Terminal probe、候选表与事实记录。**

```bash
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/TerminalServiceProbe.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/TerminalServiceDescriptors.swift
stage_task_path Tests/DockHoverPreviewProbeTests/TerminalServiceDescriptorTests.swift
stage_task_path Scripts/Probes/run_finder_context_menu_probe.sh docs/verification/finder-context-menu-stage-0-probe-record.md
git commit -m "test: record Terminal Service descriptors"
```

### Task 8：完成隔离安装验证并执行探针评审

**Files:**

- Modify: `Scripts/package_release_app.sh`
- Modify: `Tests/DockHoverPreviewProbeTests/PackagingTests.swift`
- Modify: `docs/verification/finder-context-menu-stage-0-probe-record.md`
- Create: `docs/verification/finder-context-menu-stage-0-review.md`

- [ ] **Step 1: 写阶段 0 ZIP 边界失败测试。**

在 `PackagingTests.swift` 增加 stage-zero package policy 测试，读取 `package_release_app.sh` 并用临时 bundle fixture 断言：必须包含已签名 `.appex`、URL Scheme 和 probe host；若出现 `BuiltInTemplates`、正式 `menu-catalog.json`、`configuration.json`、VS Code/自定义工具登记或设置页面资源则失败。安装说明 fixture 还必须包含首次打开、移动到 `/Applications`、手动启用 extension 和同用户可信边界，并拒绝 Developer ID、公证、Gatekeeper 验证、自动更新或外置卷支持声明。

- [ ] **Step 2: 运行并确认现有 packaging 不满足阶段 0 边界。**

```bash
swift test --filter PackagingTests
```

预期：新增 stage-zero package policy 测试失败，因为脚本尚未执行 probe-only allowlist/denylist 检查。

- [ ] **Step 3: 扩展 release packaging。**

`package_release_app.sh` 必须确保 ZIP 含已签名的 `.appex`、probe 专用共享代码、extension 资源和主程序 URL Scheme，同时执行上述 allowlist/denylist。安装说明不得宣称 Developer ID、公证、Gatekeeper 验证、自动更新或外置卷支持；必须说明首次启动、Control-点击“打开”、手动启用 Finder extension，以及同一登录用户的其他非沙盒进程属于可信环境。

- [ ] **Step 4: 生成并验证最小 probe ZIP。**

```bash
swift test
swift build
Scripts/build_probe_app.sh
Scripts/verify_app_bundle.sh build/zongMacTools.app
Scripts/package_release_app.sh
```

预期：所有自动命令成功，release ZIP 包含完整 bundle 和 nested `.appex`，stage-zero package policy 测试通过。随后把 ZIP 解压到新的 `mktemp -d` 目录，确认只有一个预期 `.app`，并对该解压产物重新运行 `Scripts/verify_app_bundle.sh`；验证脚本必须再次确认 principal class、extension point、主 executable、bundle ID、URL Scheme、实际 ad-hoc 签名身份、entitlements、sandbox 差异、架构和 deployment target。压缩前 bundle 通过、但解压产物失败时，本步骤失败。

- [ ] **Step 5: 在干净用户账户或干净 VM 执行人工隔离安装。**

分别在 macOS 14 的最新可用小版本和发布时当前支持的最新 macOS（两者必须不同）上，通过浏览器下载 ZIP，保留下载隔离属性；在移动到 `/Applications` 前，对浏览器下载后解压出的实际 `.app` 再运行 `Scripts/verify_app_bundle.sh` 并记录输出，任何 principal class、签名身份、entitlement 或 Bundle 结构差异都使该环境失败。随后移动到 `/Applications`，使用系统提供的 Control-点击“打开”或“仍要打开”流程，手动启用 Finder extension。首次安装前确认没有旧应用副本、旧 URL Scheme 注册和旧 App Group 数据；不能让开发副本接管 URL。每个系统都完整执行 `app-group-round-trip`、`queue-contention`、`finder-context`、`finder-coverage`、`menu-performance`、`extension-status`、`url-cold-hot`、`queue-recovery`、`frozen-context-revalidation`、`lifecycle-restart`、带显式启动卷测试 root 的 `atomic-commit` 和 `terminal-services`；不能用一个系统的结果补另一个系统缺项。

随后保留首次探针产生的 App Group 状态，以新的 ad-hoc build 替换 `/Applications` 中的 app，确认没有第二应用副本或竞争 URL 注册，再重新打开并按系统实际要求重新启用 extension。分别执行“仅重启主程序”“仅重启 Finder/extension”“同时重启两者”，每种情况重跑 App Group、Finder 菜单/上下文、URL 冷热唤醒、processing/result 恢复和 counter 不重复；记录替换前后容器 URL、实际签名、extension 注册和既有 probe 状态是否连续。替换验证不得混入首次安装前遗留的开发数据，也不得把应保留的本次 probe 数据描述为不存在。

- [ ] **Step 6: 写探针评审结论。**

`finder-context-menu-stage-0-review.md` 必须逐项引用 probe record，明确每项为 `pass`、`fail` 或仅外置硬件允许的 `blocked / not available`。它还必须记录 `finder-context-menu-stage-0-probe-record.md` 与 `TerminalServiceDescriptors.swift` 的 SHA-256，并逐表项证明候选 descriptor 没有超出真实记录。启动卷归属无法证明、Terminal 任一模式/语言/系统无稳定 descriptor、host lock/生命周期重启矩阵不完整、隔离安装失败或任何其他强制项未通过都只能写 `fail`。只有所有强制项为 `pass` 时，才写“批准进入任务 9 至 17”；任何 `fail` 都必须列出停止条件和后续独立架构设计入口。

Task 8 提交后，stage-0 probe record、review 和候选 descriptor 构成冻结评审输入。Tasks 9-17 中每个任务开始前都必须重新计算 `finder-context-menu-stage-0-probe-record.md` 与 `TerminalServiceDescriptors.swift` 的 SHA-256，并与 review 中记录的两个值逐字比较；任一不一致都使批准失效，必须重新执行受影响探针并产生新的独立评审结论，不能直接修改旧 record 后继续。

- [ ] **Step 7: 提交阶段 0 证据。**

```bash
stage_task_path Scripts/package_release_app.sh
stage_task_path Tests/DockHoverPreviewProbeTests/PackagingTests.swift
stage_task_path docs/verification/finder-context-menu-stage-0-probe-record.md
stage_task_path docs/verification/finder-context-menu-stage-0-review.md
git commit -m "docs: record Finder extension stage zero review"
```

## 探针评审门

在 `docs/verification/finder-context-menu-stage-0-review.md` 获得明确批准，且其中记录的 probe record 与 Terminal descriptor SHA-256 仍匹配前，Tasks 9-17 全部禁止执行。禁止以模拟成功、关闭 extension sandbox、手工访问 Group Container 路径、私有 API、Apple Events 或允许覆盖的文件移动操作绕过此门。

Tasks 9-17 的每个任务在修改文件前运行：

```bash
shasum -a 256 docs/verification/finder-context-menu-stage-0-probe-record.md
shasum -a 256 Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/TerminalServiceDescriptors.swift
```

预期：两个输出分别与 `finder-context-menu-stage-0-review.md` 记录的精确摘要一致，且 review 结论为“批准进入任务 9 至 17”。执行者把本次比对结果附在任务日志或提交说明中；不一致时停止该任务，不得通过更新旧 review 中的摘要解除门禁。

## 正式业务实现：仅在阶段 0 通过后执行

### Task 9：实现正式共享上下文、命令/result 和菜单 catalog

**Files:**

- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderContextModels.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/CommandProtocol.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderMenuCatalog.swift`
- Modify: `zongMacTools.xcodeproj/project.pbxproj`
- Create: `Tests/DockHoverPreviewProbeTests/FinderContextResolverTests.swift`
- Create: `Tests/DockHoverPreviewProbeTests/FinderCommandProtocolTests.swift`
- Create: `Tests/DockHoverPreviewProbeTests/FinderMenuCatalogTests.swift`

- [ ] **Step 1: 写正式领域协议失败测试。**

`FinderContextResolverTests` 覆盖 container/singleFolder/singleFile/multipleItems、container 只接受 `targetedURL()`、items 只接受 `selectedItemURLs()`、空值/两个 API 同时有值/未记录组合、package/`.app`/alias/symlink/volume root、原始数组 256/257、稳定去重、Terminal 同目录规则、非本机 `file:` URL、远程 host、缺少父目录和语言冻结。

`FinderCommandProtocolTests` 必须分别从 extension encoder 和主程序 decoder 验证：schema、canonical uppercase UUID、文件名与内部 ID 一致、`createdAt` 早于当前时间 5 分钟或晚于 1 分钟拒绝、action 只允许 `createFile`/`openTool`、subject ID 非空、语言只允许 `en`/`zh-Hans`、context 枚举、URL 1...256、单 URL 16 KiB、JSON 1 MiB、`itemKinds`/`itemIdentities`/URLs 数量一致、identity 是规范无符号十进制字符串、`targetDirectoryIdentity` 的 action/目标条件，以及 create/Terminal/VS Code/自定义工具各自允许的上下文矩阵。subject ID 是否对应当前已登记且启用的模板/工具由 Task 14 coordinator 测试，不在纯 decoder 中猜测。规范 UUID 文件名但无法解码 action 的输入必须产生 action `unknown` 的 failed result；非规范文件名不得自动删除。

`FinderMenuCatalogTests` 覆盖 schema、512 KiB、`en`/`zh-Hans` 与英文回退、固定 14 个内置模板、32 个自定义模板、16 个自定义工具、显示名称 1...80 扩展字素、固定分组、组内排序、稳定 ID tie-break、Terminal availability 只允许 `available`/`terminalDescriptorUnavailable`、停用过滤、空分组分隔线和损坏快照回退。

- [ ] **Step 2: 运行并确认正式类型尚不存在。**

```bash
swift test --filter FinderContextResolverTests
swift test --filter FinderCommandProtocolTests
swift test --filter FinderMenuCatalogTests
```

预期：编译失败，因为正式 `FrozenFinderContext`、`FinderCommand`、`FinderCommandResult` 和 `FinderMenuCatalog` 尚不存在；阶段 0 的 `FinderProbe*` 类型不能使这些测试通过。

- [ ] **Step 3: 实现正式共享协议并保持 probe extension 可构建。**

`FinderObjectIdentity` 的 `device`/`inode` 使用 `lstat` 无符号值的规范 ASCII 十进制字符串，不得使用默认 JSON number。`FrozenFinderContext` 保存 invocation context、冻结原始 URL、分类、identity、目标目录 identity 和菜单 catalog language；正式目标解析不得引用 `FinderProbeModels`。

`FinderCommand` 包含设计规格第 9.3 节的全部字段。extension 写入前调用共享 validator；主程序解码后再次调用同一组纯字段规则，并在 coordinator 中补充当前配置/登记 ID 和实时 filesystem identity 验证。`FinderCommandResult` 只保存 ID、`createFile`/`openTool`/`unknown` action、完成时间、状态、错误分类和可选 `feedbackClaimedAt`，不允许 URL、模板内容、工具路径或任意附加 payload。

`FinderMenuCatalog` 只保存菜单所需稳定字段，不包含书签、路径或模板正文。完成后把三个正式共享文件显式加入 extension target membership，但 Tasks 9-13 期间保留三个 `FinderProbe*` 文件的 membership 和现有 probe extension 入口，使每个中间提交仍能编译完整 `.appex`。正式类型和 probe 类型必须使用不同名称且不得互相引用；只有 Task 14 在同一提交中切换 extension 实现后才能移除 probe membership。

- [ ] **Step 4: 运行正式领域测试。**

```bash
swift test --filter FinderContextResolverTests
swift test --filter FinderCommandProtocolTests
swift test --filter FinderMenuCatalogTests
Scripts/build_probe_app.sh
Scripts/verify_app_bundle.sh build/zongMacTools.app
```

预期：所有测试通过，面向 extension 写入端和主程序读取端的共享 validator 对同一损坏样例得到相同拒绝分类，result 编码中搜索不到任何测试 URL 或工具路径；阶段 0 probe extension 仍能构建、签名并通过 bundle 验证。

- [ ] **Step 5: 提交正式共享协议。**

```bash
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderContextModels.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/CommandProtocol.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderMenuCatalog.swift
stage_task_path zongMacTools.xcodeproj/project.pbxproj
stage_task_path Tests/DockHoverPreviewProbeTests/FinderContextResolverTests.swift
stage_task_path Tests/DockHoverPreviewProbeTests/FinderCommandProtocolTests.swift
stage_task_path Tests/DockHoverPreviewProbeTests/FinderMenuCatalogTests.swift
git commit -m "test: specify Finder production protocols"
```

### Task 10：实现正式配置、菜单快照和设置变更发布

**Files:**

- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderConfigurationStore.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderMenuCatalogPublisher.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift`
- Create: `Tests/DockHoverPreviewProbeTests/FinderConfigurationStoreTests.swift`
- Create: `Tests/DockHoverPreviewProbeTests/FinderMenuCatalogPublisherTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/FinderCommandCoordinatorTests.swift`

- [ ] **Step 1: 写配置初始化、previous 回退和迁移失败测试。**

覆盖 2 MiB 限制、首次 `initialization.json` starting/complete、current/previous 原子顺序、两份配置损坏不写默认值、旧 schema 幂等迁移、未知未来 schema 拒绝、模板/命令既有状态阻止初始化、`sortOrder` 后按稳定 ID 解决并列。publisher 还必须覆盖“14 个内置资源尚未由 Task 11 验证时不发布业务 catalog”，以及注入完整 validated built-in registry 后才发布 revision。coordinator 测试增加可控串行 executor，证明配置保存与 catalog revision 发布作为一个不可穿插事务执行；drainer 验证命令期间到达的配置变更排队等待，不在两次校验之间改变有效状态。

- [ ] **Step 2: 运行失败测试。**

```bash
swift test --filter FinderConfigurationStoreTests
swift test --filter FinderMenuCatalogPublisherTests
```

预期：失败，因为正式 configuration store 和 catalog publisher 尚不存在。

- [ ] **Step 3: 实现配置事务和 catalog。**

配置路径固定为 App Group 的 `right-click/state/configuration.json`、`configuration.previous.json`、`initialization.json`；只有三个文件都不存在且其他受管内容为空时才发布默认配置。默认配置记录 14 个稳定内置模板 ID、Terminal、VS Code，Terminal 默认 `newWindow`，无自定义模板或工具。store 和 publisher 是不创建自身并发队列的存储原语；生产代码中的初始化、迁移、设置写入和 catalog 发布只能由 `FinderCommandCoordinator` 的同一串行执行域调用。

catalog 只含 menu 所需的 ID、显示名称、分组、启用状态、排序和 Terminal availability；最大 512 KiB，语言只允许 `en`/`zh-Hans`，内置模板 14、用户模板最多 32、工具最多 16。publisher 必须接收由模板库提供的 validated built-in registry；registry 缺失、数量不是 14、ID/资源状态不匹配时只保留配置而不发布可点击业务 catalog。extension 永远不读取正式配置文件。Task 11 完成资源验证后才允许首次发布包含模板 action 的 catalog。

- [ ] **Step 4: 运行配置和 catalog 测试。**

```bash
swift test --filter FinderConfigurationStoreTests
swift test --filter FinderMenuCatalogPublisherTests
```

预期：所有配置恢复和 catalog schema 测试通过。

- [ ] **Step 5: 提交配置层。**

```bash
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderConfigurationStore.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderMenuCatalogPublisher.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift
stage_task_path Tests/DockHoverPreviewProbeTests/FinderConfigurationStoreTests.swift
stage_task_path Tests/DockHoverPreviewProbeTests/FinderMenuCatalogPublisherTests.swift
stage_task_path Tests/DockHoverPreviewProbeTests/FinderCommandCoordinatorTests.swift
git commit -m "feat: publish Finder menu configuration"
```

### Task 11：实现内置模板与自定义模板事务

**Files:**

- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/TemplateLibrary.swift`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.txt`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.md`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.json`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.xml`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.docx`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.xlsx`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.pptx`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.yaml`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.py`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.html`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.css`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.js`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.ts`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.rtf`
- Create: `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/manifest.json`
- Modify: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift`
- Create: `Tests/DockHoverPreviewProbeTests/TemplateLibraryTests.swift`
- Create: `Tests/DockHoverPreviewProbeTests/BuiltInTemplateValidationTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/FinderCommandCoordinatorTests.swift`

- [ ] **Step 1: 写内置资源和导入失败测试。**

覆盖 14 个类型的扩展名/基础内容，OOXML ZIP entry 安全、content types、root relationship、主部件、worksheet/slide relationship 闭包和 SHA-256。导入必须逐项覆盖：拒绝目录/symlink/special file/超过 64 MiB；第一次读取前后及第二次读取后 device、inode、类型、大小、mtime、ctime 任一变化；按初始声明大小读取时提前 EOF 或随后仍有额外字节；双读大小/SHA-256 不一致；执行位、ACL、xattr/resource fork 未排除；无扩展名/dotfile；扩展名 32/33 字素以及 `/`、`:`、控制字符；默认显示名称空白、超过 80 字素或包含控制字符；`importing`/摘要持久化/staging/final/active 每个崩溃边界和 deleting tombstone。coordinator 测试必须覆盖：已领取并完整验证的 create 命令取得该 template ID 的执行租约后，停用/删除事务等待 result 持久化与 processing 收尾才提交；执行使用验证时冻结的模板内容引用；尚未领取的同 subject 命令在停用/删除提交后按最新配置失败；导入完成、active 配置和 catalog revision 作为同一串行事务，不向 drainer 暴露中间状态。

- [ ] **Step 2: 运行失败测试。**

```bash
swift test --filter TemplateLibraryTests
swift test --filter BuiltInTemplateValidationTests
```

预期：失败，因为模板库、资源和验证器尚不存在。

- [ ] **Step 3: 实现资源验证和导入事务。**

`TemplateLibrary` 构造时必须接收显式 `builtInResourceRoot`：单元测试传入仓库内 `Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates` 的解析后绝对路径，正式主程序由 Task 14 注入 `Bundle.main.resourceURL/BuiltInTemplates`；生产代码不得回退到当前工作目录或源码路径。内置模板资源只读且 ID 稳定。资源字节必须精确满足以下首版基线：`empty.txt`、`empty.md`、`empty.py`、`empty.css`、`empty.js` 和 `empty.ts` 为零字节 UTF-8 文本；`empty.json` 为 `{}\n`；`empty.xml` 为 `<?xml version="1.0" encoding="UTF-8"?>\n<root/>\n`；`empty.yaml` 为 `---\n`；`empty.html` 为包含 `<!doctype html>`、`<html>`、`<head>`、`<body>` 的完整最小 HTML5 骨架；`empty.rtf` 为可被 TextEdit 解析的 RTF 语法；三个 OOXML 文件只能由已验证 ZIP 二进制资源提供。`manifest.json` 必须以 `builtin.word`、`builtin.excel`、`builtin.powerpoint` 三个稳定 ID 分别记录资源相对路径和小写 64 位十六进制 SHA-256；测试用 `CryptoKit` 对资源 bytes 重算摘要并与 manifest 精确比较。验证器必须将这些稳定 ID 映射到上述精确路径、扩展名、内容规则和 manifest 摘要。

自定义导入以 `O_NOFOLLOW` 打开源路径并立即 `fstat` 确认为不超过 64 MiB 的普通文件，记录 device、inode、类型、大小、mtime、ctime。第一次严格按记录大小做有界 read loop，必须恰好读满、随后立即 EOF，同时复制到 staging 并计算 SHA-256；将同一 FD seek 到 0，第二次只计算摘要，也必须恰好读满并随后 EOF。第二次后再次 `fstat`，任一记录字段、两次大小或 SHA-256 不一致都拒绝。

扩展名验证器保存最后一个 path extension 的原始大小写，不含前导点，允许 1...32 个扩展字素，拒绝 `/`、`:`、控制字符和路径分隔符；无扩展名与 `.env` dotfile 按设计规格分别处理。托管内容使用 `0666 & ~umask` 且不含执行位，不复制 ACL、xattr 或 resource fork。staging 写完后必须从路径以 no-follow 方式重新打开，复验普通文件、大小、SHA-256、权限、ACL/xattr/resource fork 排除结果，再把预期摘要和属性原子写回 `importing` 记录。

只有持久化后的 `importing` 记录与 staging 完全匹配时，才调用 Task 6 已验证的 `AtomicFileSupport` 不覆盖 rename wrapper 发布 `templates/<UUID>`；最终 UUID 已存在即失败。最后更新 active 记录、向 Task 10 提供完整 validated registry并发布 catalog。`TemplateLibrary` 不创建独立并发队列；生产中的导入完成、停用和删除只能经 coordinator 的串行状态事务执行。coordinator 在命令领取且完成协议、identity、最新配置和 subject 验证后，为该 subject 建立执行租约；租约直到副作用 completion 已转成 result 且 processing 已按队列规则收尾后释放。删除/停用同一 subject 必须等待租约释放，再按“deleting 记录 -> 不含模板的 catalog -> 托管目录 -> 记录”顺序提交；尚未领取的命令按事务提交后的最新配置验证。使用 previous 配置回退时未知 staging/final 目录只报告不删除。

- [ ] **Step 4: 运行模板测试。**

```bash
swift test --filter TemplateLibraryTests
swift test --filter BuiltInTemplateValidationTests
```

预期：所有安全、恢复和资源验证测试通过。

- [ ] **Step 5: 提交模板库。**

```bash
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/TemplateLibrary.swift
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.txt
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.md
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.json
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.xml
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.docx
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.xlsx
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.pptx
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.yaml
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.py
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.html
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.css
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.js
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.ts
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/empty.rtf
stage_task_path Sources/DockHoverPreviewProbe/Resources/BuiltInTemplates/manifest.json
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift
stage_task_path Tests/DockHoverPreviewProbeTests/TemplateLibraryTests.swift
stage_task_path Tests/DockHoverPreviewProbeTests/BuiltInTemplateValidationTests.swift
stage_task_path Tests/DockHoverPreviewProbeTests/FinderCommandCoordinatorTests.swift
git commit -m "feat: add Finder file templates"
```

### Task 12：实现真实文件创建与 Finder 选中

**Files:**

- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/AtomicFileCreator.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/AtomicFileSupport.swift`
- Create: `Tests/DockHoverPreviewProbeTests/AtomicFileCreatorTests.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift`

- [ ] **Step 1: 写命名、identity 和失败回滚测试。**

覆盖 `未命名.ext`/`Untitled.ext`、连续编号、10,000 上限、中文/英语冻结、无扩展名、dotfile、32/33 扩展字素、UTF-8 候选名刚好等于/超过 `_PC_NAME_MAX`、`_PC_NAME_MAX` 未知、大小写敏感/不敏感 fake、同路径同类型替换、目标目录替换、中间 symlink、只读、磁盘满、卷弹出、write/属性/`fsync`/close/rename 失败、`0666 & ~umask` 且无执行位、临时文件清理失败提示和 processing 恢复时只清理匹配固定前缀+命令 UUID+合法语法的临时文件。通过可注入 Finder-selection adapter 验证提交后即使选择动作不可观察或未发生，也不回滚或重复创建文件。

- [ ] **Step 2: 运行失败测试。**

```bash
swift test --filter AtomicFileCreatorTests
```

预期：失败，因为真实创建服务尚不存在。

- [ ] **Step 3: 实现 directory-FD 相对创建。**

直接注入并复用 Task 6 已由真实启动磁盘 probe 调用的 `AtomicFileSupport` wrapper、errno mapper 和 name-limit query；禁止在 `AtomicFileCreator.swift` 中再次调用 `renameatx_np` 或复制 errno switch。根据冻结 `targetDirectoryIdentity` 重新 `lstat`，逐级以 no-follow 方式打开路径分量，用 `fstat` 确认最终 directory FD identity。之后的临时创建、属性、`fpathconf(directoryFD, _PC_NAME_MAX)` 和提交都只相对该 FD 执行。

以包含固定应用前缀、命令 UUID 和随机后缀的隐藏名称独占创建普通文件，只写模板内容一次，设置 `0666 & ~umask` 且清除执行位，完成 write loop、属性、`fsync`、close 并检查每一步错误后才生成候选名。未知 name limit 返回 `nameLimitUnknown`；每个候选按 UTF-8 bytes 检查。只有 `EEXIST` 保留同一临时文件并继续下一个候选；`ENOTSUP`/`EINVAL` 产生 `atomicCommitUnsupported`，其他错误产生 `atomicCommitFailed`，不得退回覆盖语义。

提交成功或明确失败后按设计规则处理临时文件。删除失败的错误必须告诉用户目标目录可能存在隐藏临时文件，但日志不记录完整路径。processing 恢复只能在命令冻结目录仍可安全复验时，清理同时匹配固定前缀、该命令 UUID、合法临时名语法和普通文件类型的项目；无法安全推导目录时只报告，不跨目录搜索。

成功后调用：

```swift
NSWorkspace.shared.activateFileViewerSelecting([createdURL])
```

该调用无可靠完成状态；adapter 只记录请求已发出，不把“文件是否实际被选中”伪造成同步成功或失败。不得因 Finder 未被观察到选中而删除或重建文件。

- [ ] **Step 4: 运行文件创建测试。**

```bash
swift test --filter AtomicFileCreatorTests
```

预期：非空模板从不以零字节或截断的最终名称出现，冲突不覆盖用户文件。

- [ ] **Step 5: 提交文件创建服务。**

```bash
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/AtomicFileCreator.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/AtomicFileSupport.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift
stage_task_path Tests/DockHoverPreviewProbeTests/AtomicFileCreatorTests.swift
git commit -m "feat: create Finder files atomically"
```

### Task 13：实现 VS Code、Terminal 和自定义工具打开

**Files:**

- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/DeveloperToolLauncher.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/CustomDeveloperToolStore.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift`
- Create: `Tests/DockHoverPreviewProbeTests/DeveloperToolLauncherTests.swift`
- Create: `Tests/DockHoverPreviewProbeTests/CustomDeveloperToolStoreTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/FinderCommandCoordinatorTests.swift`

- [ ] **Step 1: 写工具路由和 completion 状态失败测试。**

覆盖 VS Code bundle ID `com.microsoft.VSCode`、单文件/文件夹/多选冻结原始 URL、Terminal 单一目录、`newWindow`/`newTab` descriptor、descriptor 缺失、Service 禁用、`NSWorkspace` 同步失败/异步成功/异步失败/超时/调用期间进程终止、普通 bookmark stale 刷新、bundle ID 改变、同 bundle ID 多副本、无 bundle ID、alias/symlink/non-APPL/executable 缺失或非普通可执行文件拒绝、`NSWorkspace` 不可打开拒绝、确认重新绑定、重复标准化路径复用已有记录以及不同路径但相同 bundle ID 不静默合并。coordinator 测试覆盖：已领取并验证的 openTool 命令持有工具 subject 执行租约期间，停用、删除或重绑事务等待一次性 completion 转成 result 并完成 processing 收尾；外部调用使用验证时冻结的应用 URL/bookmark 或 Terminal descriptor；尚未领取命令在变更提交后按最新配置失败。

- [ ] **Step 2: 运行失败测试。**

```bash
swift test --filter DeveloperToolLauncherTests
swift test --filter CustomDeveloperToolStoreTests
```

预期：失败，因为 launcher、bookmark store 和 completion adapter 尚不存在。

- [ ] **Step 3: 实现公开工具打开边界。**

VS Code 只使用 `NSWorkspace` 的 bundle-identifier 定位和 URL 打开接口查找 `com.microsoft.VSCode` 稳定版，然后再次校验 `CFBundlePackageType = APPL`、精确 bundle ID 和可打开状态；不使用 `code` 命令、进程启动、AppleScript、Apple Events、私有 API 或窗口参数。

自定义工具选择器只接受用户明确选择的 `.app` URL，拒绝 alias 和 symlink；登记及执行时都重新验证 APPL、主 executable 存在且为可执行普通文件、`NSWorkspace` 可打开。保存普通持久 bookmark 和 optional bundle ID；解析 stale bookmark 后先原子刷新，再调用指定 application URL 的公开 `NSWorkspace` 接口。重复标准化路径复用已有记录；相同 bundle ID 不同路径必须由用户确认替换或取消；不得按 bundle ID 自动替换为另一副本，也不得产生两个指向同一标准化 URL 的菜单项。

Terminal 只读取 Task 8 已批准且 SHA-256 仍匹配的 `TerminalServiceDescriptors.swift` 和公开 Service 调用 API；Task 13 不修改或扩大该表。`newWindow`/`newTab` 映射 descriptor 语义；调用成功即为 `succeeded`，不把窗口/标签页是否可见作为成功证明。

外部调用在受控执行队列运行，并按 API 契约分别产生一次性完成事件。Terminal 的完成事件就是 `NSPerformService` 的同步返回：返回接受立即写 `succeeded`，返回拒绝立即写 `failed`；窗口或标签页的可见性只进入人工观察记录，不产生第二次 completion，也不能把已经返回的接受状态改为 `unknown`。VS Code 和自定义 `.app` 才使用 `NSWorkspace` 的同步返回加异步 completion：同步拒绝或 completion 报错写 `failed`，同步接受且 completion 无错误写 `succeeded`，在同步接受后没有可观察 completion、completion 超时、事件丢失或调用边界崩溃写 `unknown`。coordinator 在相应完成边界内保留 subject 执行租约，只有 result 持久化与 processing 收尾后才释放并执行排队的工具状态事务。重复 completion 只接受第一个，任何状态都不得触发第二次外部调用；`succeeded` 只表示系统接受 URL 交付，不声称第三方应用已经处理全部 URL。

- [ ] **Step 4: 运行工具测试。**

```bash
swift test --filter DeveloperToolLauncherTests
swift test --filter CustomDeveloperToolStoreTests
```

预期：所有登记、失效、completion 和 at-most-once 测试通过。

- [ ] **Step 5: 提交工具服务。**

```bash
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/DeveloperToolLauncher.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/CustomDeveloperToolStore.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift
stage_task_path Tests/DockHoverPreviewProbeTests/DeveloperToolLauncherTests.swift
stage_task_path Tests/DockHoverPreviewProbeTests/CustomDeveloperToolStoreTests.swift
stage_task_path Tests/DockHoverPreviewProbeTests/FinderCommandCoordinatorTests.swift
git commit -m "feat: open Finder context in developer tools"
```

### Task 14：将正式菜单、extension 和主程序协调器接通

**Files:**

- Modify: `Sources/RightClickFinderExtension/RightClickFinderExtension.swift`
- Create: `Sources/RightClickFinderExtension/FinderDirectoryRegistration.swift`
- Create: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderCommandSubmitter.swift`
- Modify: `Sources/DockHoverPreviewProbe/App/AppDelegate.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift`
- Modify: `zongMacTools.xcodeproj/project.pbxproj`
- Create: `Tests/DockHoverPreviewProbeTests/FinderCommandSubmitterTests.swift`
- Create: `Tests/DockHoverPreviewProbeTests/FinderMenuIntegrationTests.swift`

- [ ] **Step 1: 写正式菜单行为失败测试。**

`FinderCommandSubmitterTests` 使用显式临时 queue root、可注入 queue、validator、UUID/clock、URL opener 和提示音 adapter，覆盖：从同一次菜单构造的 `FrozenFinderContext`、action、subject ID 和语言生成完整正式命令；回调后 Finder 选择变化不改变编码 bytes；写入端 validator 拒绝时不预留、不发布、不唤醒；`queueBusy`/`queueFull`、staging write/`fsync`/close/rename 失败均不打开 URL；成功时 pending 已经可完整解码后才调用精确 `zongmactools://command/<UUID>`；URL 打开失败保留唯一 pending、不重写或重发命令，并只触发一次非阻塞系统提示音。测试不得访问真实 Group Container。

`FinderMenuIntegrationTests` 固定内置分组、用户模板在内置之后、Terminal/VS Code 一级固定顺序、自定义工具子菜单顺序、停用过滤、空分组无分隔线、多选创建禁用、Terminal 目录不唯一禁用、descriptor 缺失禁用、无动作状态和 context/identity 变化时主程序拒绝执行。每个可点击纯菜单 action 都必须保留同一次冻结 context 和 subject ID 并只调用一次 submitter；禁用项不能调用 submitter。命令集成还覆盖主程序对 schema、文件名/ID、createdAt、本机 file URL、数组对应、action/context、实时 identity、最新配置和登记 subject 的完整复验；损坏 action 的 `unknown` result、过期 pending 的无路径 `failed` result 及明确过期错误分类、`resultStoreFull` 不执行且不删除 pending、`feedbackClaimedAt` 最多领取一次、后台失败不抢焦点以及已领取未显示时崩溃不重复。另以可注入的已挂载卷列表测试目录注册：始终包含 `/`；若阶段 0 记录 `/` 不覆盖正常外置卷，则包含每个当前正常本地卷根；挂载/卸载通知刷新集合，且不把云盘、网络卷或文件提供程序目录加入支持承诺。

同一 suite 必须增加正式启动状态机的顺序测试，使用记录事件的 fake store/queue/template/publisher 断言：取得 host lock 后，先验证 current，失败时只尝试有效 previous；随后恢复 processing（已有 result 优先，否则写 `unknown` 后删除）、按 Task 3/5 顺序处理过期 pending、验证内置模板；只有 current 完整有效时才恢复或清理 template staging/孤儿/缺失 active 内容；最后才发布与已验证状态一致的 catalog 并 arm-before-scan 启动正常 drainer。previous 有效回退时不得执行模板破坏性清理，只发布和执行能由 previous、当前资源与登记记录共同完整证明的 subject，其他项目停用并产生恢复提示；current/previous 双损坏时不得发布可点击业务 catalog或领取业务 pending。每个顺序边界都要覆盖进程终止后重新启动，证明不会越过较早失败状态。

- [ ] **Step 2: 运行失败测试。**

```bash
swift test --filter FinderCommandSubmitterTests
swift test --filter FinderMenuIntegrationTests
```

预期：编译失败，因为正式 submitter 尚不存在，extension 仍只渲染 probe action。

- [ ] **Step 3: 将 catalog 渲染为正式 `NSMenu`。**

`FinderCommandSubmitter` 接收完整冻结 context、action 和 subject ID，使用 Task 9 共享 validator 在写入前验证正式命令，再调用 Task 3 已验证的 `FinderCommandQueue` 完成 queue lock 内计数/预留和 staging 到 pending 的原子发布。只有 pending 发布成功才调用 URL opener；打开失败保留 pending 供正常启动或观察器排空，不创建第二条命令。`queueBusy`/`queueFull` 或任一发布失败都不唤醒主程序，只返回结构化错误并由 extension 发出一次系统提示音。submitter 不读取 Finder API、catalog、配置、模板、工具路径或用户文件内容。

extension 移除阶段 0 固定 action、probe request/response 和 queue-contention 运行时入口，只从 `menu-catalog.json` 读取可显示字段。每个 `NSMenuItem` 持有完整不可变 `FrozenFinderContext` 和 subject ID；回调不得重新调用 Finder selection API，只能把冻结值交给同一个 `FinderCommandSubmitter` 一次。`FinderDirectoryRegistration` 在 extension 启动、`NSWorkspace.didMountNotification` 与 `NSWorkspace.didUnmountNotification` 后，按阶段 0 已记录的覆盖结论重算并赋值 `FIFinderSyncController.default().directoryURLs`；不递归扫描目录。

主程序启动 `TemplateLibrary` 时只注入 `Bundle.main.resourceURL/BuiltInTemplates`；目录缺失或验证失败时不发布模板 action。正式 coordinator 复用 Task 3 的 managed-root opener 和 Task 5 的 host lock/observer/drainer，不重新实现路径或锁原语；取得 host lock 后严格执行：`validate current/previous -> recover processing -> expire pending with persisted failed results -> validate built-ins -> only with a complete current recover/clean template state -> publish catalog for fully proven subjects -> arm observer then scan pending`。previous 有效回退时保留未知 staging/final/工具记录并禁止破坏性清理，但允许对 previous 与当前资源共同完整证明的 subject 发布菜单和验证命令；无法证明的 subject 停用。两个副本均无效时不发布可点击业务 catalog，也不领取业务命令。

coordinator 删除运行时对 `FinderProbeCommand` 和 `FinderProbeHost` 的引用，改为先完成 Task 9 的正式协议验证，再在同一串行状态域验证 identity、最新配置、模板/工具状态并取得 subject 执行租约，全部通过后才执行相应服务；result 持久化和 processing 收尾后释放租约，再执行排队的设置事务。由本次有效 URL 直接触发且即将显示的错误才领取 `feedbackClaimedAt`；目录观察、普通启动或恢复发现的错误保持未领取，等用户主动打开主程序或设置页时领取。任何 Finder 命令都不得自动激活主设置窗口，领取后显示前崩溃允许漏报但不得重复。

在同一 project 修改中，把 `FinderCommandSubmitter.swift` 加入 extension target，保留 Task 9 的三个正式共享源、`FinderCommandQueue.swift` 和 `AtomicFileSupport.swift`，并移除三个 `FinderProbe*` 源的 extension target membership。正式 extension 和 coordinator 不得再引用任何 probe 类型；probe 源保留在 SwiftPM probe/test 编译范围供历史证据复现。

- [ ] **Step 4: 运行自动集成测试。**

```bash
swift test --filter FinderCommandSubmitterTests
swift test --filter FinderMenuIntegrationTests
swift test
Scripts/build_probe_app.sh
Scripts/verify_app_bundle.sh build/zongMacTools.app
```

预期：focused suites 与完整 SwiftPM suite 通过；正式 `.appex` 编译、嵌入、签名和 bundle 验证通过，且 extension binary/source membership 不包含 `FinderProbeCommand`、`FinderProbeMenuPlan` 或 `FinderProbeHost` 引用。

- [ ] **Step 5: 提交菜单集成。**

```bash
stage_task_path Sources/RightClickFinderExtension/RightClickFinderExtension.swift
stage_task_path Sources/RightClickFinderExtension/FinderDirectoryRegistration.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/Shared/FinderCommandSubmitter.swift
stage_task_path Sources/DockHoverPreviewProbe/App/AppDelegate.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift
stage_task_path zongMacTools.xcodeproj/project.pbxproj
stage_task_path Tests/DockHoverPreviewProbeTests/FinderCommandSubmitterTests.swift
stage_task_path Tests/DockHoverPreviewProbeTests/FinderMenuIntegrationTests.swift
git commit -m "feat: integrate Finder context menu actions"
```

### Task 15：实现设置页、本地化与扩展状态

**Files:**

- Create: `Sources/DockHoverPreviewProbe/Settings/FinderContextMenuSettingsView.swift`
- Create: `Sources/DockHoverPreviewProbe/Settings/FinderContextMenuSettingsViewModel.swift`
- Modify: `Sources/DockHoverPreviewProbe/Settings/SettingsPage.swift`
- Modify: `Sources/DockHoverPreviewProbe/Settings/SettingsRootView.swift`
- Modify: `Sources/DockHoverPreviewProbe/Settings/ToolDescriptor.swift`
- Modify: `Sources/DockHoverPreviewProbe/Settings/SettingsViewModel.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift`
- Modify: `Sources/DockHoverPreviewProbe/Shared/AppTextProvider.swift`
- Modify: `Sources/DockHoverPreviewProbe/Shared/Text/AppTextProvider+App.swift`
- Create: `Sources/DockHoverPreviewProbe/Shared/Text/AppTextProvider+FinderContextMenu.swift`
- Create: `Tests/DockHoverPreviewProbeTests/FinderContextMenuSettingsTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/FinderCommandCoordinatorTests.swift`

- [ ] **Step 1: 写 settings model/view model 失败测试。**

覆盖 `FIFinderSyncController.isExtensionEnabled` true/false、heartbeat 有/无/过期且两类信号独立组合、设置窗口首次显示/重新 active/从管理界面返回时刷新、管理按钮唯一调用 `showExtensionManagementInterface()`、代码路径中不启动 `pluginkit`/Finder 重启/Apple Events、模板/工具数量限制、显示名称边界、分组内排序、非法跨组移动拒绝、Terminal/VS Code 固定顺序、重复自定义工具路径去重、Terminal 默认值和非法值回退、descriptor 不可用、设置变化只在完整事务提交后增加 catalog revision。view model 必须通过注入的 coordinator setting-transaction API 提交变更，测试直接调用 store/publisher 的生产入口应不可用。coordinator 测试覆盖设置提交与已领取 subject 执行租约的顺序：无关 subject 事务可按串行队列顺序提交；同一模板/工具的停用、删除、重绑等待 result 和 processing 收尾；尚未领取命令在事务后按最新配置失败。

- [ ] **Step 2: 运行失败测试。**

```bash
swift test --filter FinderContextMenuSettingsTests
```

预期：失败，因为真实右键扩展设置 page 与 view model 尚不存在。

- [ ] **Step 3: 替换设置占位。**

在 `SettingsPage` 添加 `.finderContextMenu`，将 `ToolDescriptor.contextMenuExtensionPlaceholder` 改为可导航的真实 tool。页面展示查询时刻的 extension enabled 状态与独立 heartbeat 状态，提供系统 extension 管理按钮、内置模板固定分组内排序/启停、自定义模板导入/删除、Terminal 模式、Terminal/VS Code 固定顺序启停、自定义 `.app` 添加/重绑/独立排序/启停/删除。enabled 不得由 heartbeat 推断，heartbeat 也不得替代 enabled。所有持久化变更只调用 coordinator 的 setting-transaction API；view model 不直接持有 configuration store、template library、custom tool store 或 catalog publisher 的可写引用。事务必须先完成配置/模板/工具状态写入，再发布与完整状态对应的唯一新 catalog revision；任一步失败保留前一有效配置和 catalog。

“管理 Finder 扩展”是唯一管理入口，只调用 `FIFinderSyncController.showExtensionManagementInterface()`；不得运行 `pluginkit`、自动重启 Finder、请求辅助功能或 Apple Events。Terminal descriptor 缺失时保留用户启用偏好，但控件与菜单均显示不可用，不能提供绕过 descriptor 的调用入口。

所有用户可见文案通过 `LocalizedTextKey` 和 `AppTextProvider+FinderContextMenu.swift` 同时提供英语与简体中文；不新增 Finder 功能所不需要的辅助功能、屏幕录制或 Apple Events 权限提示。

- [ ] **Step 4: 运行设置测试。**

```bash
swift test --filter FinderContextMenuSettingsTests
```

预期：设置状态、语言、排序和 snapshot 更新测试通过。

- [ ] **Step 5: 提交设置实现。**

```bash
stage_task_path Sources/DockHoverPreviewProbe/Settings/FinderContextMenuSettingsView.swift
stage_task_path Sources/DockHoverPreviewProbe/Settings/FinderContextMenuSettingsViewModel.swift
stage_task_path Sources/DockHoverPreviewProbe/Settings/SettingsPage.swift
stage_task_path Sources/DockHoverPreviewProbe/Settings/SettingsRootView.swift
stage_task_path Sources/DockHoverPreviewProbe/Settings/ToolDescriptor.swift
stage_task_path Sources/DockHoverPreviewProbe/Settings/SettingsViewModel.swift
stage_task_path Sources/DockHoverPreviewProbe/Tools/FinderContextMenu/FinderCommandCoordinator.swift
stage_task_path Sources/DockHoverPreviewProbe/Shared/AppTextProvider.swift
stage_task_path Sources/DockHoverPreviewProbe/Shared/Text/AppTextProvider+App.swift
stage_task_path Sources/DockHoverPreviewProbe/Shared/Text/AppTextProvider+FinderContextMenu.swift
stage_task_path Tests/DockHoverPreviewProbeTests/FinderContextMenuSettingsTests.swift
stage_task_path Tests/DockHoverPreviewProbeTests/FinderCommandCoordinatorTests.swift
git commit -m "feat: add Finder extension settings"
```

### Task 16：完成隐私说明、资源打包与 release 验证

**Files:**

- Modify: `Sources/DockHoverPreviewProbe/Info.plist`
- Create: `Sources/DockHoverPreviewProbe/Resources/en.lproj/InfoPlist.strings`
- Create: `Sources/DockHoverPreviewProbe/Resources/zh-Hans.lproj/InfoPlist.strings`
- Modify: `Scripts/build_probe_app.sh`
- Modify: `Scripts/verify_app_bundle.sh`
- Modify: `Scripts/package_release_app.sh`
- Modify: `Tests/DockHoverPreviewProbeTests/PackagingTests.swift`
- Modify: `README.md`
- Create: `docs/verification/finder-context-menu-manual-checklist.md`
- Create: `docs/verification/finder-context-menu-release-candidate-record.md`

- [ ] **Step 1: 写最终 bundle/本地化失败测试。**

在 `PackagingTests.swift` 增加检查：最终外层 plist 含非空 `NSDesktopFolderUsageDescription`、`NSDocumentsFolderUsageDescription`、`NSDownloadsFolderUsageDescription`、`NSRemovableVolumesUsageDescription`；英语/简体中文 `InfoPlist.strings` 都能解析且文案明确“仅在用户触发 Finder 动作时访问目标位置”；14 个资源、`.appex`、URL Scheme、主/extension entitlement、架构和签名顺序均存在。测试还必须断言展开后的 `NSExtensionPrincipalClass` 解析到配置的 `RightClickFinderExtension` class、SwiftPM platform、外层 `LSMinimumSystemVersion` 和 extension deployment target 都是 14.0，主程序/extension 架构集合相同，两者实际签名均报告为 ad-hoc，Finder 功能没有新增 `NSAppleEventsUsageDescription` 或辅助功能/屏幕录制用途说明。release fixture 还必须生成 `SHA256SUMS.txt` 与 `release-metadata.txt`，两者记录的最终 ZIP 文件名和小写 64 位十六进制 SHA-256 完全一致，并在重新计算 ZIP bytes 后通过；随后解压 ZIP 并对归档中的唯一 `.app` 重新运行完整 bundle verifier，不能只检查压缩前 `.app`、构建目录或 ZIP 文件列表。

- [ ] **Step 2: 运行失败测试。**

```bash
swift test --filter PackagingTests
```

预期：失败，因为目前 Info.plist 和手工打包脚本没有这些 Finder 功能资源与用途说明。

- [ ] **Step 3: 更新 bundle 和 release 文案。**

打包脚本复制 BuiltInTemplates、两种 `InfoPlist.strings` 和 extension，先签 `.appex` 后签外层 app，禁止以 `codesign --deep --force` 代替内层签名。`verify_app_bundle.sh` 导出两边实际 entitlements，验证 `CFBundleURLTypes` 与 `zongmactools`、Finder extension point、principal class、sandbox 差异、三个最低系统版本边界、`lipo -archs` 一致、两层实际 ad-hoc 签名身份与各用途说明本地化；验证 `codesign --verify --deep --strict` 只作为最终检查。`package_release_app.sh` 完成 ZIP 后必须解压到新临时目录，对归档中的唯一 `.app` 再调用同一个 verifier，失败时不得发布 artifact/metadata。

README 与 ZIP 安装说明必须区分 Dock 预览所需的系统辅助功能/屏幕录制权限与 Finder 文件功能的目标目录 TCC 提示，并分别说明 Desktop、Documents、Downloads、Removable Volumes 的允许、拒绝和撤销后行为；明确 Finder 文件功能本身不需要辅助功能、屏幕录制或自动化权限。声明未使用 Developer ID、未公证、首次打开和 extension 启用需要用户操作、只支持真实验证的系统/架构、同用户非沙盒进程属于可信环境，不承诺云盘或未验证外置卷。

创建 `finder-context-menu-release-candidate-record.md` 模板，固定记录 release ZIP 文件名、来自 `release-metadata.txt` 的 SHA-256、独立重算值、Git commit、app 版本/build、两个 OS build/架构/签名/entitlements、干净安装环境、独立升级环境和每个正式矩阵结论。模板只能包含 `not-run` 初始状态，不复制或修改 stage-0 record；Task 17 只把真实结果写入此记录。

- [ ] **Step 4: 运行打包验证。**

```bash
swift test --filter PackagingTests
swift test
swift build
Scripts/build_probe_app.sh
Scripts/verify_app_bundle.sh build/zongMacTools.app
release_dist="$(Scripts/package_release_app.sh)"
artifact="$(awk -F= '$1 == "artifact" { print $2 }' "$release_dist/release-metadata.txt")"
metadata_sha="$(awk -F= '$1 == "sha256" { print $2 }' "$release_dist/release-metadata.txt")"
sums_sha="$(awk -v artifact="$artifact" '$2 == artifact { print $1 }' "$release_dist/SHA256SUMS.txt")"
actual_sha="$(shasum -a 256 "$release_dist/$artifact" | awk '{ print $1 }')"
unpacked_dir="$(mktemp -d)"
ditto -x -k "$release_dist/$artifact" "$unpacked_dir"
test "$(find "$unpacked_dir" -maxdepth 1 -type d -name '*.app' | wc -l | tr -d ' ')" = "1"
unpacked_app="$(find "$unpacked_dir" -maxdepth 1 -type d -name '*.app' -print -quit)"
Scripts/verify_app_bundle.sh "$unpacked_app"
test -n "$artifact"
test "$metadata_sha" = "$sums_sha"
test "$metadata_sha" = "$actual_sha"
```

预期：所有命令退出 0，三处 ZIP SHA-256 完全一致，归档中唯一 `.app` 的完整 Bundle/签名复验通过；将 `$artifact` 和 `$actual_sha` 写入尚为 `not-run` 的 release-candidate record。临时目录只在 verifier 完成且确认其绝对路径由本步骤的 `mktemp -d` 生成后清理；验证失败时保留路径供诊断，不做宽范围删除。

- [ ] **Step 5: 提交发布输入与人工清单。**

```bash
stage_task_path Sources/DockHoverPreviewProbe/Info.plist
stage_task_path Sources/DockHoverPreviewProbe/Resources/en.lproj/InfoPlist.strings
stage_task_path Sources/DockHoverPreviewProbe/Resources/zh-Hans.lproj/InfoPlist.strings
stage_task_path Scripts/build_probe_app.sh Scripts/verify_app_bundle.sh Scripts/package_release_app.sh
stage_task_path Tests/DockHoverPreviewProbeTests/PackagingTests.swift README.md
stage_task_path docs/verification/finder-context-menu-manual-checklist.md
stage_task_path docs/verification/finder-context-menu-release-candidate-record.md
git commit -m "docs: define Finder extension release verification"
```

### Task 17：执行正式人工验收并更新发布结论

**Files:**

- Modify: `docs/verification/finder-context-menu-manual-checklist.md`
- Modify: `docs/verification/finder-context-menu-release-candidate-record.md`
- Modify: `README.md`

- [ ] **Step 1: 验收本地普通目录。**

依次验证 Finder 空白、单文件夹、单文件、多选、package、`.app`、symlink、alias 和卷根；创建 14 个内置类型，覆盖中文/英语命名、冲突编号、10,000 上限、并发候选竞争、Finder 选中和 Return 手动重命名。大小写敏感与不敏感真实卷各至少验证一种；无法取得相应卷格式时在清单中单独标记未覆盖且不得扩大该卷语义承诺。确认多选创建禁用、非空模板未留下可见零字节/截断文件。

在每个规定系统上使用正式 release candidate、最大合法 catalog（14 个内置模板、32 个自定义模板、16 个自定义工具均启用且名称达到允许上限）重新执行真实 Finder `menu(for:)` 性能矩阵：启动磁盘普通本地目录下 1/64/256 项各做冷/热 20 次，记录全部样本、中位数和 p95。正式菜单 p95 必须不超过 150 ms；不能引用 Task 4 的单一 probe action 测量代替，也不能以单元测试渲染时间作为真实 Finder 证据。任一规定系统超限均是核心 `fail`，阻止发布并回到 Task 14 优化或重新设计分类/菜单路径。

- [ ] **Step 2: 验收模板和完整开发工具矩阵。**

导入自定义模板后删除原件再创建；在导入/删除/创建边界终止后检查恢复。用 TextEdit 打开 RTF，用 WPS 打开 DOCX/XLSX/PPTX；有 Microsoft Office 时分别记录版本和结果，否则把 Microsoft Office 标为未验证。

在两个规定系统和 English/简体中文环境分别对正式 launcher 执行 Terminal `newWindow`/`newTab`：Terminal 未运行、已运行且有窗口、已运行但无窗口、Service 启用和禁用；上下文覆盖空白目录、单文件夹、单文件、同目录多选和不同目录多选。每格分别记录 selector 命中的 descriptor tuple、`NSPerformService` 接受/失败状态和人工观察到的窗口/标签结果；公开调用状态决定 `succeeded`/`failed`，不可观察结果不得覆盖该状态。descriptor 缺失必须在菜单构造时禁用，Service 运行时拒绝必须产生一次 failed result，二者不能混用。

VS Code 验证文件、文件夹、多选以及同步失败、异步成功/失败和 completion 超时；一款自定义 `.app` 验证添加、普通 bookmark stale 刷新、同 bundle ID 多副本确认、重绑、停用、删除、失效和 completion 超时。所有 `succeeded` 只表述系统接受 URL 交付，不声称第三方应用完成处理。

- [ ] **Step 3: 验收 TCC、外置卷和下载安装。**

在 macOS 14 的最新可用小版本和发布时当前支持的最新 macOS（两者必须不同）的干净用户/VM 中重置 TCC，分别测试 Desktop、Documents、Downloads 的首次允许、首次拒绝和允许后撤销；每次以真实文件操作结果判定，不读取缓存权限状态。在 extension 已运行的状态下真实挂载一块正常外置卷，验证菜单出现和注册集合刷新；保持 Finder/extension 运行时卸载该卷，验证陈旧卷根不再产生可执行上下文；随后重新挂载同一卷并再次验证菜单、读写、不覆盖提交、首次允许、首次拒绝、撤销和 `NSRemovableVolumesUsageDescription`。记录每次挂载/卸载通知时间、卷根、extension heartbeat 和实际菜单结果；不得用注入卷列表单元测试或“启动前已经挂载”的单次观察代替。无法取得外置硬件时明确写 `blocked / not available` 并删除下载页外置卷承诺。

另把一份测试 `.app` 分别放在 Desktop、Documents、Downloads 和可用外置卷，验证普通 bookmark 解析、Bundle/executable 复验、公开 `NSWorkspace` 打开请求以及 TCC 拒绝/撤销错误；不得把 Finder 目标目录的访问结果当作应用 Bundle 位置已经授权。每个系统的干净安装环境都从浏览器下载与 release-candidate record 文件名和 SHA-256 完全一致的隔离 ZIP，重算 SHA-256；解压后先对归档中的唯一 `.app` 运行完整 bundle verifier并把 principal class、签名身份、entitlements 和架构输出附入记录，再移到 `/Applications`，按系统流程手动放行并通过 `showExtensionManagementInterface()` 进入管理界面启用 extension，复跑 App Group、菜单、正式最大 catalog 性能、文件创建、完整 Terminal 正式矩阵和最小队列流程；Finder 命令冷启动不得无故打开设置窗口或抢焦点。

- [ ] **Step 4: 在独立升级环境验证保留与迁移。**

升级验证不能复用上述干净安装环境。在另一个先安装旧版本的用户/VM 中，创建旧版本的有效设置、自定义模板、自定义工具普通 bookmark、Terminal 模式和菜单排序，并保存旧 schema fixture 的 SHA-256。替换为本次 release ZIP 后验证：只存在 `/Applications` 中一个 scheme 处理者；extension 按系统流程重新启用；App Group 容器保持一致；设置、模板 bytes、bookmark 绑定和排序保留；若 schema 提升，则迁移只执行一次、重复启动幂等、迁移失败回退 previous、未知未来 schema 拒绝且不写默认值。随后完整执行 App Group、菜单、一次文件创建、Terminal 两种模式和 pending/processing/result 恢复。任何数据丢失、重复迁移、默认值覆盖或 URL Scheme 副本争用均为 `fail`。

- [ ] **Step 5: 更新结论。**

手工清单和 release-candidate record 每项写 `pass`、`fail` 或设计规格明确允许的 `blocked / not available`，包含 release ZIP 文件名及三方一致的 SHA-256、Git commit、app 版本/build、OS build、CPU 架构、签名模式、实际 entitlements、验证日期、干净/升级环境标识和实际限制。App Group/Finder/URL/队列/启动磁盘原子提交/完整 Terminal 正式矩阵、普通本地目录文件创建、正式最大 catalog 的真实 Finder 性能、14 个内置模板、at-most-once、浏览器下载后解压 Bundle/签名复验、两个系统的隔离安装和独立升级保留是核心验收：任一 `fail` 都阻止技术预览发布，必须回到相应任务修复并重新执行受影响矩阵，不能只从 README 删除承诺后继续发布。外置卷挂载/卸载/重挂只在真实硬件不可用时允许 `blocked / not available`；一旦对外承诺外置卷支持，该矩阵必须为 `pass`。

只有真实外置硬件不可用以及机器未安装 Microsoft Office 可以按设计规格降级披露：外置卷不得承诺支持；Office 未安装时保留 WPS 结果并明确 Microsoft Office 未验证。云盘观察结果不得扩大支持范围。所有核心项为 `pass`、允许的限制已准确披露，且 stage-0 review 中冻结的 probe record/descriptor SHA-256 仍匹配后，才能把 release-candidate record 和 README 发布结论写为“技术预览可发布”。

- [ ] **Step 6: 提交验收记录。**

```bash
stage_task_path docs/verification/finder-context-menu-manual-checklist.md
stage_task_path docs/verification/finder-context-menu-release-candidate-record.md
stage_task_path README.md
git commit -m "docs: record Finder context menu acceptance"
```

## 最终验证顺序

每次合并前至少运行：

```bash
git diff --check
swift test
swift build
Scripts/build_probe_app.sh
Scripts/verify_app_bundle.sh build/zongMacTools.app
```

阶段 0 还必须完成 `Scripts/Probes/run_finder_context_menu_probe.sh` 的 `app-group-round-trip`、`queue-contention`、`finder-context`、`finder-coverage`、`menu-performance`、`extension-status`、`url-cold-hot`、`queue-recovery`、`frozen-context-revalidation`、`lifecycle-restart`、带显式 `--startup-volume-test-root` 的 `atomic-commit`、`terminal-services` 子命令并更新 probe record。正式发布还必须完成正式最大 catalog 的真实 Finder 性能矩阵、可承诺外置卷时的挂载/卸载/重挂矩阵、浏览器下载后解压 Bundle/签名复验、`docs/verification/finder-context-menu-manual-checklist.md`、`docs/verification/finder-context-menu-release-candidate-record.md`、两个规定系统的带下载隔离属性干净安装、独立旧版本升级环境和最终 ZIP SHA-256 三方复核。

没有新的 Git 工作树或 isolated worktree 时，任何执行者必须在每个任务前查看 `git diff -- <task file>`，只 stage 本任务明确列出的文件。现有 Dock 窗口速览未提交改动与本计划无关，不得混入 Finder 功能提交。
