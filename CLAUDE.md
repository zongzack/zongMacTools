# Claude Project Instructions

你是这个仓库里的 macOS/Swift 编码协作者。默认用中文沟通，除非用户明确要求英文。

## 项目概览

`zongMacTools` 当前主要包含 `DockHoverPreviewProbe`：一个 macOS 菜单栏 app，用 Dock 悬停触发窗口预览。技术栈是 SwiftPM、AppKit、SwiftUI、ScreenCaptureKit、Accessibility 和 CoreGraphics。

## 每次开始任务

先运行：

```bash
git status --short --branch
```

然后按任务相关性阅读：

- `README.md`
- `docs/roadmap.md`
- `docs/architecture/dock-hover-preview-technical-design.md`
- `docs/architecture/release-update-strategy.md`
- `docs/verification/dock-hover-preview-probe-summary.md`
- `docs/verification/dock-hover-preview-environment-variant-verification-plan.md`
- 与任务对应的 P3、P4 或多工具人工验收清单

## 当前工作主线

优先执行已实现能力的人工验收和仍受硬件限制的环境验证。

不要一次性处理所有场景。一次验证一个场景，记录结果，再决定是否修 bug。

当前待验收场景：

- P3 window actions
- P4 formal-app workflow
- Multi-tool settings-window smoke test
- Multiple displays

## 必须遵守

- 不使用私有 API。
- 不复制 DockDoor GPLv3 源码、文件结构、helper、注释或私有 API wrapper。
- 不扩大 MVP 范围。
- Screen Recording 缺失时继续静默抑制 preview UI。
- stale hover cancellation 是一等状态。
- pending preview 必须能被 `mouseOutside`、`selectedStale`、`noCandidate`、`hoverValidationFailed` 等状态取消。
- 不要覆盖、revert 或删除用户已有未提交改动。
- 不要提交 `.build/`、`build/`、`.DS_Store`。

## 验证命令

修改代码或文档后，根据风险运行：

```bash
swift test
swift build
Scripts/build_probe_app.sh
git diff --check
```

如果菜单栏 app 正在运行，测试前可以先退出：

```bash
pkill -x DockHoverPreviewProbe
```

## 日志

统一日志命令：

```bash
/usr/bin/log show --last 5m --info --style compact --predicate 'subsystem == "com.zong.zongMacTools"'
```

排障时重点看：

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
- `preview.session.noWindows`
- `preview.session.skipped screenRecording=false`
- `thumbnail.success`
- `activation.result`

## 发现 bug 时

不要盲改。先做：

1. 记录复现步骤。
2. 抓相关日志。
3. 判断是 Dock hover、window query、thumbnail、activation 还是 panel region 问题。
4. 补最小回归测试。
5. 小范围修复。
6. 重新跑验证命令。

## 提交规则

- 只 stage 当前任务相关文件。
- 不 stage 用户无关改动。
- 提交前看 `git diff --cached --stat` 和 `git diff --cached --check`。
- 文档整理提交和代码 bugfix 提交尽量分开。
