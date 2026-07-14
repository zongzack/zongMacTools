# Agent Guide

本项目是一个 macOS/Swift 菜单栏工具原型：`DockHoverPreviewProbe`。它通过 Dock 悬停显示窗口预览，并使用 AppKit、SwiftUI、ScreenCaptureKit 和系统辅助功能实现窗口查询、缩略图和点击激活。

## 开始前必读

每次接手任务前先运行：

```bash
git status --short --branch
```

优先阅读：

- `README.md`
- `docs/roadmap.md`
- `docs/architecture/dock-hover-preview-technical-design.md`
- `docs/architecture/release-update-strategy.md`
- `docs/verification/dock-hover-preview-probe-summary.md`
- `docs/verification/dock-hover-preview-environment-variant-verification-plan.md`
- 与任务对应的 P3、P4 或多工具人工验收清单

## 当前优先级

当前主线是补齐已实现能力的人工验收和受硬件限制的环境验证。

优先级：

1. P3 窗口操作人工验收。
2. P4 正式应用化人工验收。
3. 多工具设置窗口人工 smoke test。
4. 多显示器验证；硬件不可用时维持 `blocked / not available`。

一次只处理一个环境场景。发现 bug 时先记录复现步骤和日志，再补最小回归测试并小范围修复。

## 工程约束

- 不使用私有 API。
- 不复制、翻译或机械改写 DockDoor GPLv3 源码。
- 不扩大 MVP 范围。
- 屏幕录制权限缺失时继续静默抑制预览 UI。
- 悬停失效取消是一等状态。
- 不要覆盖或 revert 用户已有未提交改动。
- 不要 stage `.build/`、`build/`、`.DS_Store` 等生成物。

## 中文表达偏好

面向用户说明验证步骤、验收清单或操作指引时，尽量使用中文术语，不要夹杂 `panel material`、`Accessibility`、`Reduce Motion` 这类英文表达。推荐写法：

- 预览面板、面板材质、边框、阴影。
- 系统辅助功能、屏幕录制权限。
- 减少动态效果。
- 浅色外观 / 深色外观。
- 台前调度。
- 悬停失效取消、旧预览面板残留、缩略图不可用。

只有文件名、命令、日志事件名、代码符号、框架名、系统设置中的原始英文专有名词需要精确引用时，才保留英文。

## 常用命令

```bash
swift test
swift build
Scripts/build_probe_app.sh
git diff --check
```

查看日志：

```bash
/usr/bin/log show --last 5m --info --style compact --predicate 'subsystem == "com.zong.zongMacTools"'
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

验证通过或发现 blocked 场景时，更新当前对应的验收清单和验证总结：

- `docs/verification/dock-hover-preview-p3-window-actions-manual-checklist.md`
- `docs/verification/dock-hover-preview-p4-formal-app-manual-checklist.md`
- `docs/verification/dock-hover-preview-multi-tool-settings-window-manual-checklist.md`
- `docs/verification/dock-hover-preview-probe-summary.md`

如果实际验证步骤和计划不同，也更新：

- `docs/verification/dock-hover-preview-environment-variant-verification-plan.md`

后续功能优先级写在：

- `docs/roadmap.md`
