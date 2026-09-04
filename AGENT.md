# Agent Guide

`zongMacTools` 是一组 macOS 桌面效率工具，目前包含 Dock 窗口速览和 Finder 右键新建文件功能。主要技术栈为 SwiftPM、AppKit、SwiftUI、ScreenCaptureKit、辅助功能 API 与 Finder Sync。

## 开始前必读

每次接手任务前先运行：

```bash
git status --short --branch
```

优先阅读：

- `README.md`
- `docs/README.md`
- 与当前任务相关的源码、测试和脚本

## 当前优先级

以用户当前请求为准。涉及图形界面、系统权限或 Finder Sync 的变更，应区分自动测试与需要在真实 macOS 环境完成的人工验收。

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

功能、验收或发布流程变化时，只更新仍在维护的对应文档：

- `README.md`
- `docs/README.md`
