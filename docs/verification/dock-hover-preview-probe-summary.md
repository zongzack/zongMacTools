# Dock 悬停窗口预览验证总结

日期：2026-06-26

最近更新：2026-07-01

## 总结

MVP UI 结论：`pass with concerns`。

核心功能已经可用，普通底部 Dock、单显示器、常规 Space 的主流程通过自动测试、打包验证和人工 UI 验收。Full-screen Space 已完成跟进验证并修复 Chrome 全屏辅助条带误收录问题。剩余风险集中在 Stage Manager、Dock 自动隐藏、左右 Dock 和多显示器。

## 硬门槛结果

| 验证项 | 结果 | 证据摘要 |
| --- | --- | --- |
| stale hover 被抑制 | 通过 | 快速离开 WPS 时记录 `dock.selectedStale`、`dock.hoverLost reason=noCandidate`，没有过期 delayed preview。 |
| Dock item frame 可用 | 通过 | Dock AX list 能读取 VS Code、Chrome、WPS、Typora、IINA 的 frame，并在延迟后命中验证。 |
| VS Code 窗口查询与 AX 匹配 | 通过 | 查询返回 3 个窗口，3/3 AX matched。 |
| Chrome 窗口查询与 AX 匹配 | 通过 | 查询返回 1 个窗口，1/1 AX matched。 |
| Typora 窗口查询与 AX 匹配 | 通过 | 查询返回 1 个窗口，1/1 AX matched。 |
| IINA 窗口查询与 AX 匹配 | 通过 | 查询返回 1 个窗口，1/1 AX matched。 |
| WPS 行为 | 通过 | WPS Office 以 `com.kingsoft.wpsoffice.mac` 运行，窗口 `首页` 可查询、缩略图可生成、点击可激活。 |
| 静态缩略图 | 通过 | 样本 app 的 SCK 缩略图均成功生成。 |
| 查询耗时 | 通过 | 样本查询耗时均低于 100 ms。 |
| Dock 重启恢复 | 通过 | `killall Dock` 后约 0.021 秒重新订阅；后续 UI 验收中也验证过恢复路径。 |

## 权限验证

- Accessibility granted：通过，授权后日志包含 `permissions.refresh accessibility=true` 和 `dock.subscribed pid=...`。
- Screen Recording granted：通过，授权后窗口查询与缩略图可工作。
- Screen Recording denied：通过，禁用后正常 Dock hover preview 被静默抑制，日志包含 `screenRecording=false`、`preview.session.skipped screenRecording=false`，没有弹出重复提示。
- Screen Recording restore：通过，重新授权并重启 app 后恢复 preview。

## MVP UI 结果

已通过：

- `swift test`：2026-07-01 Full-screen Space 修复后最终记录为 34 个 XCTest、0 失败。
- `swift build`：通过。
- `Scripts/build_probe_app.sh`：可生成 `build/DockHoverPreviewProbe.app`。
- 样本 app 主流程：VS Code、Chrome、Typora、IINA、WPS 由人工反馈为功能正常。
- 点击卡片激活窗口并隐藏 panel。
- 快速离开取消 stale preview。
- 鼠标从 Dock 图标移动到 panel 时保持 panel。
- 鼠标离开 preview region 后隐藏 panel。
- `Esc` 隐藏 panel。
- `killall Dock` 后恢复监听。
- Light / Dark 外观功能路径通过日志和人工观察验证。
- Other normal Space 通过跟进验证。
- Full-screen Space 通过跟进验证，结果 `pass with note`。初次验证发现 Chrome 全屏下 ScreenCaptureKit 返回空标题浅条带，导致 panel 出现 3 张卡片；已补回归测试并过滤该类辅助条带。复测日志包含 `permissions.refresh accessibility=true screenRecording=true`、`dock.subscribed pid=...`、Chrome 全屏 `windows.query app=Google Chrome count=1`、`preview.panel.show app=Google Chrome count=1`、`thumbnail.success`、`activation.result` 和 `preview.panel.hide reason=activated`。
- 修复并验证了两个 hover 手感问题：
  - Dock 到 panel 之间不再过早隐藏。
  - 从有 preview 的 app 移到相邻未启动 Dock app 时，旧 panel 会隐藏。

## 仍需验证

- Dock auto-hide。
- Dock left。
- Dock right。
- Stage Manager。
- Multiple displays。

## 相关文档

- 架构设计：[dock-hover-preview-technical-design.md](../architecture/dock-hover-preview-technical-design.md)
- MVP UI 手动验收：[dock-hover-preview-mvp-ui-manual-checklist.md](dock-hover-preview-mvp-ui-manual-checklist.md)
- Probe 原始证据：[dock-hover-preview-probe-checklist.md](dock-hover-preview-probe-checklist.md)
- 环境变体验证计划：[dock-hover-preview-environment-variant-verification-plan.md](dock-hover-preview-environment-variant-verification-plan.md)
- 后续路线：[roadmap.md](../roadmap.md)
