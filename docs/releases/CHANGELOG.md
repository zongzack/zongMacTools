# zongMacTools Changelog

本文记录 `zongMacTools` 本地 release 流程的人工可审查变更。版本号来源为 `Sources/DockHoverPreviewProbe/Info.plist` 的 `CFBundleShortVersionString`，build number 来源为 `CFBundleVersion`。

## Unreleased

- P4 正式应用化：新增稳定签名配置、app bundle 验证脚本、release packaging 脚本。
- P4 正式应用化：新增 About / Status、Copy Status 和 Export Diagnostics 菜单入口。
- P4 正式应用化：新增本地诊断导出，包含状态快照、签名摘要、bundle 验证摘要和最近本工具统一日志。
- P4 正式应用化：新增 Sparkle 与轻量本地更新流程评估文档。

Validation commands:

- `swift test`
- `swift build`
- `Scripts/build_probe_app.sh`
- `Scripts/verify_app_bundle.sh build/zongMacTools.app`
- `Scripts/package_release_app.sh`
- `git diff --check`

Known limitations:

- Manual validation: not run.
- Stable Developer ID signing, notarization, and TCC stability across repeated signed builds require local developer credentials and real macOS permission checks.
- Multiple displays remain blocked / not available on single-display hardware.
- Diagnostic logs may include local app names, window titles, bundle identifiers, and environment details because the user explicitly exports recent unified logs for local troubleshooting.

## 0.1.0 (2026-07-06)

- MVP/P0、P1、P2 和 P3 自动验证基础版本。
- P3 窗口操作增强已实现并通过自动测试；P3 人工验收尚未执行。

Validation commands:

- `swift test`
- `swift build`
- `Scripts/build_probe_app.sh`
- `git diff --check`

Known limitations:

- Manual validation: partial for MVP/P1/P2; P3 not run.
- Multiple displays remain blocked / not available.
