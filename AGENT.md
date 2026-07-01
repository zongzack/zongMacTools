# Agent Guide

本项目是一个 macOS/Swift 菜单栏工具原型：`DockHoverPreviewProbe`。它通过 Dock 悬停显示窗口预览，并使用 AppKit、SwiftUI、ScreenCaptureKit 和 Accessibility 实现窗口查询、缩略图和点击激活。

## 开始前必读

每次接手任务前先运行：

```bash
git status --short --branch
```

优先阅读：

- `README.md`
- `docs/roadmap.md`
- `docs/architecture/dock-hover-preview-technical-design.md`
- `docs/verification/dock-hover-preview-probe-summary.md`
- `docs/verification/dock-hover-preview-mvp-ui-manual-checklist.md`
- `docs/verification/dock-hover-preview-environment-variant-verification-plan.md`

## 当前优先级

当前主线是 `docs/roadmap.md` 的 P0：环境变体验证和稳定性修复。

优先验证：

1. Full-screen Space
2. Dock auto-hide
3. Dock on left
4. Dock on right
5. Stage Manager
6. Multiple displays

一次只处理一个环境场景。发现 bug 时先记录复现步骤和日志，再补最小回归测试并小范围修复。

## 工程约束

- 不使用私有 API。
- 不复制、翻译或机械改写 DockDoor GPLv3 源码。
- 不扩大 MVP 范围。
- Screen Recording 缺失时继续静默抑制 preview UI。
- stale hover cancellation 是一等状态。
- 不要覆盖或 revert 用户已有未提交改动。
- 不要 stage `.build/`、`build/`、`.DS_Store` 等生成物。

## 常用命令

```bash
swift test
swift build
Scripts/build_probe_app.sh
git diff --check
```

查看日志：

```bash
/usr/bin/log show --last 5m --info --style compact --predicate 'subsystem == "com.zong.DockHoverPreviewProbe"'
```

退出 app：

```bash
pkill -x DockHoverPreviewProbe
```

## 验证重点日志

- `permissions.refresh accessibility=true screenRecording=true`
- `orchestrator.start accessibility=true screenRecording=true`
- `dock.subscribed pid=...`
- `dock.hover`
- `dock.hoverDelayed`
- `dock.hoverLost`
- `dock.hoverLost.panelRetained`
- `preview.panel.show`
- `preview.panel.hide reason=mouseLeftPreviewRegion`
- `preview.panel.hide reason=activated`
- `preview.session.skipped screenRecording=false`
- `thumbnail.success`
- `activation.result`

## 文档更新规则

验证通过或发现 blocked 场景时，更新：

- `docs/verification/dock-hover-preview-mvp-ui-manual-checklist.md`
- `docs/verification/dock-hover-preview-probe-summary.md`

如果实际验证步骤和计划不同，也更新：

- `docs/verification/dock-hover-preview-environment-variant-verification-plan.md`

后续功能优先级写在：

- `docs/roadmap.md`
