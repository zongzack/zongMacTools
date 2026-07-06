# Dock Hover Preview P4 正式应用化开发文档

> **给后续执行者：** 实施本计划时按任务逐项执行，优先先写测试再改实现；每个任务结束后运行对应阶段检查。步骤使用 checkbox 语法，方便执行时追踪。

**目标：** 将当前可用的 `zongMacTools` 菜单栏工具从本地原型收敛为可长期自用、可稳定授权、可诊断、可发布的正式 macOS 应用流程。

**架构：** 保持现有 Dock hover preview 运行路径不变，把 P4 能力放在应用壳、签名打包、诊断导出、版本发布和状态展示边界内。核心预览状态机、窗口查询、缩略图、窗口操作服务不为 P4 扩能力，只暴露必要的只读状态给诊断和状态窗口。

**技术栈：** Swift 6、SwiftPM、AppKit、SwiftUI、ScreenCaptureKit、ApplicationServices、ServiceManagement、XCTest、`codesign`、`notarytool`、`hdiutil`、shell build scripts。

---

日期：2026-07-06

## 背景

`zongMacTools` 已完成 MVP/P0、P1 基础设置、P2 界面打磨和 P3 窗口操作增强。当前应用已经能通过 `Scripts/build_probe_app.sh` 构建为 `build/zongMacTools.app`，并在 Finder、系统辅助功能、屏幕录制权限和登录项中使用 `zongMacTools` 名称与图标。

P4 不继续扩展窗口管理能力。它要解决的是长期使用时的工程摩擦：ad-hoc 重新签名容易让 TCC 重新授权、版本号和发布记录没有流程、诊断信息分散在统一日志里、菜单里缺少正式 About / 状态入口、release 构建脚本不够完整。

## P4 范围

- 使用更稳定的签名方式，减少每次构建后 TCC 重新授权。
- 维护版本号和 release notes。
- 增加诊断日志导出。
- 增加 app 内 About / 状态信息。
- 评估 Sparkle 自动更新或轻量本地更新流程。
- 整理 release build 脚本。
- 形成普通本地安装流程和 P4 人工验收清单。

## 非目标

- 不实现 App Store 分发。
- 不引入沙盒化迁移；是否沙盒化另开设计。
- 不实现实时视频缩略图、搜索窗口、跨 Space 主动拉起窗口或 Cmd+Tab 替代。
- 不新增私有 API，不增加私有接口封装。
- 不复制、翻译或机械改写 DockDoor GPLv3 源码、结构、helper、注释或私有接口封装。
- 不改变屏幕录制权限缺失时静默抑制预览 UI 的策略。
- 不改变 `build/zongMacTools.app` 打包路径。
- 不重命名 SwiftPM executable / target `DockHoverPreviewProbe`；如将来要正式改 target 名，必须单独做命名迁移计划。
- 不把 release artifact、notary log、dmg、zip、临时 iconset 或 `.xcarchive` 提交进 git。

## 不回退约束

P4 执行期间必须继续满足以下已有行为：

- P1 默认行为保持：启用、250 ms、standard retention、最多 8 张卡片、排除应用为空、English。
- P1 打包身份保持：`build/zongMacTools.app`、bundle id `com.zong.zongMacTools`、用户可见名 `zongMacTools`、图标来自 `Assets/AppIcon/zong-mac-tools-logo.png`。
- P1 Launch at Login 继续使用公开 `ServiceManagement` / `SMAppService.mainApp`，真实状态以系统为准。
- P2 行为不回退：缩略图 fit/fill、加载中/不可用占位、显示/隐藏动画、减少动态效果降级、面板更新/隐藏逻辑。
- P3 行为不回退：右键菜单期间 session 保留、旧菜单或旧 action closure 不影响新 session、窗口操作失败安静降级并记录足够诊断信息。
- 屏幕录制权限缺失时仍然不显示预览 UI，不显示加载中、占位状态或弹窗。

## 文件地图

预计新增：

- `Sources/DockHoverPreviewProbe/AppMetadata.swift`
  - 读取 app 名称、版本号、build number、bundle id、bundle path、executable name、签名摘要。
- `Sources/DockHoverPreviewProbe/AppStatusSnapshot.swift`
  - 聚合权限、登录项、设置、签名、运行环境和最近诊断摘要，供菜单状态和导出共用。
- `Sources/DockHoverPreviewProbe/DiagnosticExportService.swift`
  - 用户主动触发本地诊断导出，不上传、不后台采集。
- `Sources/DockHoverPreviewProbe/AboutStatusWindowController.swift`
  - 显示 About / 状态窗口或面板。
- `Scripts/package_release_app.sh`
  - release 构建、签名、验证、打包 dmg/zip、checksum 和 release notes 汇总。
- `Scripts/verify_app_bundle.sh`
  - 对任意 `.app` 执行 Info.plist、图标、签名、bundle 路径和执行文件一致性检查。
- `docs/releases/CHANGELOG.md`
  - 维护版本发布记录。
- `docs/architecture/release-update-strategy.md`
  - 记录 Sparkle 与轻量本地更新流程评估结论。
- `docs/verification/dock-hover-preview-p4-formal-app-manual-checklist.md`
  - P4 人工验收清单。

预计修改：

- `Sources/DockHoverPreviewProbe/Info.plist`
  - 继续维护 `CFBundleShortVersionString` 和 `CFBundleVersion`，不改变 bundle id、display name、icon key、LSUIElement。
- `Sources/DockHoverPreviewProbe/AppDelegate.swift`
  - 初始化 app metadata、status provider、diagnostic export service 和 About / 状态窗口控制器。
- `Sources/DockHoverPreviewProbe/MenuBarController.swift`
  - 增加 About / 状态、Export Diagnostics、release/version 文案入口。
- `Sources/DockHoverPreviewProbe/AppTextProvider.swift`
  - 增加中英文静态文案；不翻译 app 名称、bundle id、系统权限名称、窗口标题或日志事件名。
- `Scripts/build_probe_app.sh`
  - 保持默认输出 `build/zongMacTools.app`，增加可选稳定签名配置，不破坏 ad-hoc fallback。
- `Scripts/run_probe_app.sh`
  - 如需要，复用 build script 输出路径，不硬编码旧名称。
- `.gitignore`
  - 增加 `dist/` 或其他 release artifact 目录，避免发布产物污染工作区。
- `README.md`
  - 更新普通本地安装、签名说明、诊断导出、版本发布和 P4 状态。
- `docs/roadmap.md`
  - P4 完成后更新状态和验收结果。

预计新增或扩展测试：

- `Tests/DockHoverPreviewProbeTests/PackagingTests.swift`
- `Tests/DockHoverPreviewProbeTests/AppMetadataTests.swift`
- `Tests/DockHoverPreviewProbeTests/AppStatusSnapshotTests.swift`
- `Tests/DockHoverPreviewProbeTests/DiagnosticExportServiceTests.swift`
- `Tests/DockHoverPreviewProbeTests/MenuBarControllerTests.swift`
- `Tests/DockHoverPreviewProbeTests/AppTextProviderTests.swift`
- `Tests/DockHoverPreviewProbeTests/DocumentationConsistencyTests.swift`

## 设计原则

- **公开接口。** P4 只能使用公开 AppKit、SwiftUI、ServiceManagement、ApplicationServices、ScreenCaptureKit、Foundation 和系统命令行工具。
- **用户主动导出。** 诊断信息只能在用户点击菜单动作后写入本地文件，不自动上传，不后台定时采集。
- **隐私保守。** 导出内容默认包含权限状态、版本、签名、设置摘要和本工具统一日志；窗口标题和第三方 app 名称可能出现在日志时，导出前在 UI 文案中说明文件仅供本地排障。
- **release 可复现。** 同一 git commit、版本号、签名身份和输入资源应生成结构一致的 app bundle；构建脚本只写入 ignored 目录。
- **ad-hoc 可用，正式签名更稳。** 没有开发者证书时仍能本地构建；使用稳定身份签名时，应减少因 cdhash 变化导致的 TCC 重新授权。
- **不掩盖系统事实。** 权限和登录项状态都读取系统真实状态；UI 不把“用户意图启用”展示成“系统已授权”。

## 签名与 TCC 策略

当前 `Scripts/build_probe_app.sh` 使用 ad-hoc 签名：

```bash
codesign --force --sign - "$APP_DIR"
```

P4 保留这个 fallback，但增加可配置身份：

```bash
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
CODE_SIGN_OPTIONS=()
if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  CODE_SIGN_OPTIONS+=(--options runtime --timestamp)
fi
codesign --force --sign "$CODE_SIGN_IDENTITY" "${CODE_SIGN_OPTIONS[@]}" "$APP_DIR"
```

规则：

- 默认仍可在无证书环境构建。
- `CODE_SIGN_IDENTITY=-` 时，脚本必须输出清晰提示：ad-hoc 重新签名可能导致系统辅助功能和屏幕录制权限需要重新授权。
- 指定 `CODE_SIGN_IDENTITY` 时，脚本必须打印实际签名身份摘要，并运行 `codesign --verify --deep --strict`。
- 不在仓库中写入个人证书名称、Apple ID、team id、notary password 或 keychain profile。
- notarization 只在 release packaging 任务中作为可选路径；没有 Developer ID 时跳过并说明原因。

## Task 1: Baseline Release Guardrails

**目标：** 先用测试固定当前 app 身份、构建路径和默认行为，防止 P4 开发时回退。

- [ ] 扩展 `PackagingTests`，确认 `Info.plist` 仍包含：
  - `CFBundleExecutable = DockHoverPreviewProbe`
  - `CFBundleIdentifier = com.zong.zongMacTools`
  - `CFBundleName = zongMacTools`
  - `CFBundleDisplayName = zongMacTools`
  - `CFBundleIconFile = zongMacTools`
  - `CFBundleShortVersionString` 非空且为三段语义版本。
  - `CFBundleVersion` 非空且为递增整数。
- [ ] 扩展 `PackagingTests`，确认 `Scripts/build_probe_app.sh` 仍输出 `build/zongMacTools.app`，并仍把 executable 复制为 `Contents/MacOS/DockHoverPreviewProbe`。
- [ ] 保留或扩展 `PreviewSessionControllerTests.testP1SettingsDefaultsRemainUnchanged`，确认 P1 defaults 未变化。
- [ ] 增加文档一致性测试，确保当前说明不再使用 P1 之前的旧 app bundle 路径。

阶段检查：

```bash
swift test --filter PackagingTests
swift test --filter PreviewSessionControllerTests/testP1SettingsDefaultsRemainUnchanged
swift test --filter DocumentationConsistencyTests
git diff --check
```

## Task 2: Stable Signing Configuration

**目标：** 让本地开发仍能 ad-hoc 构建，同时支持用户配置稳定签名身份，减少 TCC 重新授权。

- [ ] 修改 `Scripts/build_probe_app.sh`：
  - 增加 `CODE_SIGN_IDENTITY` 环境变量，默认 `-`。
  - 增加 `CODE_SIGN_REQUIREMENTS` 或同等诊断输出，只打印摘要，不写入 repo。
  - 指定非 ad-hoc 身份时使用 hardened runtime 和 timestamp。
  - 签名后运行 `codesign --verify --deep --strict "$APP_DIR"`。
  - 继续 `echo "$APP_DIR"` 作为最后一行 stdout，保持 `Scripts/run_probe_app.sh` 可复用。
- [ ] 新增 `Scripts/verify_app_bundle.sh`：
  - 参数为 `.app` 路径，默认 `build/zongMacTools.app`。
  - 检查 bundle path、Info.plist、executable、icon、签名状态。
  - 打印 `codesign -dv --verbose=4` 摘要到 stderr。
  - 对 ad-hoc 签名返回成功但输出 TCC caveat。
- [ ] 扩展 `PackagingTests`，通过读取脚本文本确认新增变量和 verify script 入口存在。
- [ ] 文档更新 README：解释 ad-hoc 和稳定签名的区别，以及重新签名后权限可能需要重新添加。

阶段检查：

```bash
swift test --filter PackagingTests
Scripts/build_probe_app.sh
Scripts/verify_app_bundle.sh build/zongMacTools.app
codesign --verify --deep --strict build/zongMacTools.app
git diff --check
```

## Task 3: Version And Release Notes Flow

**目标：** 让 app 版本、build number 和发布记录有单一、可审查的流程。

- [ ] 保持 `Sources/DockHoverPreviewProbe/Info.plist` 为版本来源：
  - `CFBundleShortVersionString` 使用 `major.minor.patch`。
  - `CFBundleVersion` 使用单调递增整数。
- [ ] 新增 `docs/releases/CHANGELOG.md`，按版本记录：
  - 发布日期。
  - 主要变更。
  - 验证命令。
  - 已知限制。
  - 是否完成人工验收。
- [ ] 可选新增 `Scripts/bump_version.sh`：
  - 参数为 version 和 build number。
  - 使用 `plutil` 修改 Info.plist。
  - 不自动提交。
  - 修改后打印当前版本摘要。
- [ ] 新增 `AppMetadata`，从 `Bundle.main` 读取版本信息，并提供测试可注入 initializer。
- [ ] 新增 `AppMetadataTests`，覆盖真实 Info.plist 读取、缺失值 fallback 和显示字符串。

阶段检查：

```bash
swift test --filter AppMetadataTests
swift test --filter PackagingTests
plutil -p Sources/DockHoverPreviewProbe/Info.plist
git diff --check
```

## Task 4: About And Status Information

**目标：** 菜单栏提供正式的 About / 状态入口，用户能看见当前 app 身份、权限、登录项、签名和版本。

- [ ] 新增 `AppStatusSnapshot`：
  - app name、version、build、bundle id、bundle path。
  - accessibility granted、screen recording granted。
  - launch at login status。
  - current settings summary：enabled、hover delay、retention、max cards、excluded count、display language。
  - signing summary：ad-hoc / signed identity / unknown。
- [ ] 新增 `AboutStatusWindowController`：
  - 从菜单动作打开。
  - 显示 app icon、`zongMacTools`、版本、build、bundle id、权限状态、登录项状态、签名状态。
  - 提供 `Copy Status` 按钮，把状态摘要复制到剪贴板。
  - 不展示第三方窗口标题或第三方 app 名称。
- [ ] 修改 `MenuBarController`：
  - 增加 `About zongMacTools` 或 `About / Status`。
  - 增加 `Export Diagnostics...`。
  - 保持现有权限、P1 settings、Launch at Login、Debug preview 菜单项顺序清晰。
- [ ] 修改 `AppTextProvider`：
  - 增加中英文文案。
  - 不翻译 app 名称、bundle id、权限页面名称和日志事件名。
- [ ] 增加 `AppStatusSnapshotTests`、`MenuBarControllerTests`、`AppTextProviderTests`。

阶段检查：

```bash
swift test --filter AppStatusSnapshotTests
swift test --filter MenuBarControllerTests
swift test --filter AppTextProviderTests
swift build
git diff --check
```

## Task 5: Diagnostic Export

**目标：** 用户遇到权限、Dock 订阅、窗口查询、缩略图或激活问题时，可以一键导出足够排障的信息。

- [ ] 新增 `DiagnosticExportService`：
  - 生成纯文本或 zip 诊断包。
  - 包含 `AppStatusSnapshot`。
  - 包含最近 15 分钟本工具统一日志：
    ```bash
    /usr/bin/log show --last 15m --info --style compact --predicate 'subsystem == "com.zong.zongMacTools"'
    ```
  - 包含当前构建签名摘要：
    ```bash
    codesign -dv --verbose=4 /path/to/zongMacTools.app
    ```
  - 包含 `Scripts/verify_app_bundle.sh` 输出摘要。
  - 不包含截图、缩略图图像、屏幕录制内容或用户文件内容。
- [ ] 诊断导出通过 `NSSavePanel` 由用户选择位置。
- [ ] 导出失败时只在菜单动作日志里记录错误，并用简短 alert 告知用户文件未保存；不影响 hover preview。
- [ ] 增加 `DiagnosticExportServiceTests`：
  - 使用 fake log collector。
  - 使用临时目录。
  - 验证文件名包含 app name、version、timestamp。
  - 验证导出内容包含权限、bundle id、signing、settings summary。
  - 验证不写入生成目录之外的文件。
- [ ] 更新 README 的排障章节，说明诊断包本地生成、不自动上传。

阶段检查：

```bash
swift test --filter DiagnosticExportServiceTests
swift test --filter MenuBarControllerTests
swift build
git diff --check
```

## Task 6: Release Packaging Script

**目标：** 形成清晰、不会污染 git 工作区的 release 构建流程。

- [ ] 新增 `Scripts/package_release_app.sh`：
  - 默认 `CONFIGURATION=release`。
  - 调用 `Scripts/build_probe_app.sh` 生成 `build/zongMacTools.app`。
  - 调用 `Scripts/verify_app_bundle.sh`。
  - 读取 Info.plist 的 version/build。
  - 输出到 `dist/zongMacTools-<version>-<build>/`。
  - 生成 `.zip` 或 `.dmg`。
  - 生成 `SHA256SUMS.txt`。
  - 生成 `release-metadata.txt`，包含 git commit、version、build、signing mode、artifact checksum、验证命令。
  - 如果设置 notarization profile，则执行 notarization；未设置则跳过并记录。
- [ ] `.gitignore` 增加 `dist/`。
- [ ] dmg 推荐结构：
  - `zongMacTools.app`
  - `Applications` symlink
  - `README-install.txt`
- [ ] 不自动修改 `docs/releases/CHANGELOG.md`，只读取并复制对应版本 release notes 到 artifact。
- [ ] 增加 `PackagingTests` 或新的 release script 文本测试，确认脚本写入 `dist/` 而不是 repo 根目录。

阶段检查：

```bash
swift test --filter PackagingTests
Scripts/package_release_app.sh
git status --short
git diff --check
```

期望：

- `git status --short` 只显示受控源码/文档改动，不显示 `build/` 或 `dist/` 产物。
- `build/zongMacTools.app` 路径仍存在。
- release artifact 位于 ignored 的 `dist/`。

## Task 7: Update Strategy Decision

**目标：** 明确 P4 是否引入 Sparkle，或者先采用轻量本地更新流程。

- [ ] 新增 `docs/architecture/release-update-strategy.md`。
- [ ] 比较两个方案：
  - Sparkle 自动更新：需要稳定签名、更新 feed、ed25519 key、下载托管、版本检查 UI。
  - 轻量本地更新：通过 release artifact 手动替换 `/Applications/zongMacTools.app`，配合 changelog 和 checksum。
- [ ] 默认建议：
  - P4 不直接引入 Sparkle 依赖。
  - 先完成 signed local release、dmg、checksum、release notes。
  - 当 release cadence 和托管方式稳定后，再单独做 Sparkle P5/P4.5 计划。
- [ ] 如果评估决定引入 Sparkle，必须单独列出依赖许可证、签名要求、feed 管理和回滚策略，并在 code review 中重点审查。

阶段检查：

```bash
git diff --check
rg -n "Sparkle|update|更新" docs/architecture/release-update-strategy.md docs/roadmap.md README.md
```

## Task 8: P4 Manual Validation Checklist

**目标：** 把正式应用化需要人工确认的项目固定下来，避免只靠自动测试误判完成。

- [ ] 新增 `docs/verification/dock-hover-preview-p4-formal-app-manual-checklist.md`，至少覆盖：
  - 新构建 app 在 Finder 显示 `zongMacTools` 名称和图标。
  - 系统辅助功能和屏幕录制权限列表显示 `zongMacTools` 名称和图标。
  - ad-hoc 重新构建后的 TCC caveat 文档清楚。
  - 使用稳定签名身份重复构建后，权限稳定性较 ad-hoc 改善。
  - Launch at Login 状态与系统 Login Items 一致。
  - About / 状态窗口显示版本、build、bundle id、权限、登录项、签名状态。
  - Copy Status 内容可用于排障，且不包含第三方窗口标题。
  - Export Diagnostics 生成本地文件，包含权限、Dock 订阅、窗口查询、缩略图、激活相关日志。
  - 屏幕录制权限缺失时 hover preview UI 仍静默抑制。
  - release dmg 或 zip 可从干净位置安装并启动。
  - release 构建后 `git status --short` 不出现生成产物。
- [ ] README 增加“正式本地安装”和“导出诊断”章节。
- [ ] `docs/verification/dock-hover-preview-probe-summary.md` 在 P4 完成后记录自动验证和人工验收状态，不提前写 pass。

阶段检查：

```bash
git diff --check
rg -n "P4|正式应用化|Export Diagnostics|About" README.md docs/verification docs/roadmap.md
```

## Final Verification Gate

P4 合并前建议执行：

```bash
git status --short --branch
git diff --stat
git diff --cached --stat
swift test
swift build
Scripts/build_probe_app.sh
Scripts/verify_app_bundle.sh build/zongMacTools.app
Scripts/package_release_app.sh
git diff --check
rg -n "\b(CGS|SLS|AXUIElementSetMessagingTimeout|_AX)\b" Sources Tests
```

人工验收必须单独记录在 `docs/verification/dock-hover-preview-p4-formal-app-manual-checklist.md`。如果没有稳定签名证书或多显示器硬件，相关项标记为 `blocked / not available`，不能标记为通过。

## Code Review Checklist

合并前审查按以下重点进行：

- 是否仍只使用公开 AppKit、SwiftUI、ApplicationServices、ScreenCaptureKit、ServiceManagement 和系统命令行工具。
- 是否没有复制、翻译或机械改写 DockDoor GPLv3 源码、结构、helper、注释或私有接口封装。
- `build/zongMacTools.app` 打包路径是否未改变。
- SwiftPM executable / target `DockHoverPreviewProbe` 是否未重命名。
- P1 默认行为是否未改变。
- P2 UI 行为是否无回退。
- P3 窗口操作、右键菜单 session 保留和失败降级是否无回退。
- 屏幕录制权限缺失时是否仍然不显示预览 UI。
- ad-hoc 签名 warning 是否清楚，稳定签名路径是否不写入个人 secret。
- 诊断导出是否只在用户主动触发时生成本地文件。
- release 构建是否不污染 git 工作区。
- 新增源文件、测试、文档是否都被纳入需要提交的变更范围，避免 untracked 文件遗漏。

## Residual Risk

- TCC 对签名、bundle id、路径和系统版本的具体判定可能随 macOS 更新变化；稳定签名能降低摩擦，但不能保证所有机器都不需要重新授权。
- Developer ID、notarization 和 Sparkle 都依赖开发者账号和外部托管环境；没有对应凭据时只能验证本地 fallback。
- 真实 app 的系统辅助功能能力差异仍需要人工验收覆盖，尤其是 Electron、多窗口 IDE、全屏窗口、台前调度和多显示器。
- 诊断日志可能包含用户环境中的 app 名称或窗口标题；必须保持用户主动导出、本地保存、文档明确。
- release dmg 视觉布局和 Gatekeeper 行为需要在干净下载位置验证，不能只依赖本机 build 目录打开。
