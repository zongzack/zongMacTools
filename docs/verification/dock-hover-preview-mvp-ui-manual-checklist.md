# Dock 悬停窗口预览 MVP UI 手动验收清单

日期：2026-06-29

最近更新：2026-07-01

## 构建验证

- [x] `swift test` 通过。2026-07-01 side Dock 布局适配后最终记录为 38 个 XCTest、0 失败。
- [x] `swift build` 通过。
- [x] `Scripts/build_probe_app.sh` 可生成 `build/DockHoverPreviewProbe.app`。

## 权限验证

- [x] Accessibility 授权后可订阅 Dock，日志包含 `accessibility=true` 和 `dock.subscribed pid=...`。
- [x] Screen Recording 授权后可查询窗口并生成缩略图。
- [x] Screen Recording 禁用时，Dock hover 不显示 panel，日志包含 `screenRecording=false` 和 `preview.session.skipped screenRecording=false`。
- [x] Screen Recording 恢复后，重新启动 app 可恢复 preview。

## 样本 app

| App | 预期 | 结果 | 备注 |
| --- | --- | --- | --- |
| VS Code | 显示多个独立窗口卡片 | 通过 | 人工反馈 preview 行为正常。 |
| Chrome | 显示浏览器窗口，不把 tab 当成窗口 | 通过 | 人工反馈 preview 行为正常。 |
| Typora | 显示 1 个窗口卡片 | 通过，有备注 | 窄窗口缩略图按真实比例显示，接受为后续 polish。 |
| IINA | 显示静态缩略图或占位图 | 通过 | 人工反馈 preview 行为正常。 |
| WPS | 显示 `首页` 窗口卡片 | 通过 | 人工反馈 preview 行为正常。 |

## 交互验收

- [x] 点击卡片能激活目标窗口，并隐藏 panel。
- [x] 250 ms 前快速离开不会出现 stale panel。
- [x] 鼠标从 Dock 图标移动到 panel 时，panel 不会过早消失。
- [x] 鼠标离开 Dock 图标和 panel 后，panel 会及时隐藏。
- [x] 鼠标从有 preview 的 app 移到相邻未启动 Dock app 时，旧 panel 会隐藏。
- [x] `Esc` 可隐藏 panel。
- [x] `killall Dock` 后可恢复监听，不留下 stuck panel。

## 视觉验收

- [x] Panel 锚定在 hovered Dock icon 附近。
- [x] Panel 会限制在可见屏幕区域内。
- [x] 卡片标题不遮挡缩略图。
- [x] 缩略图缺失时 fallback 安静可用。
- [x] Light / Dark 外观下功能路径通过日志和人工观察验证。

## 环境变体

- [x] Other normal Space。2026-06-30 和 2026-07-01 在第二个普通桌面验证：preview 展示、缩略图、stale/quick leave、Dock-to-panel 保留、离开隐藏、Esc、点击激活、Dock 重启恢复均正常。后续发现并修复了“移动到相邻未启动 Dock app 时旧 panel 保留”的回归，2026-07-01 人工复测正常。
- [x] Full-screen Space。2026-07-01 在 Chrome 全屏 Space 验证：preview panel 可显示，位置合理且不越界；快速离开不会留下 stale preview；Dock-to-panel 保留、离开隐藏、点击激活并隐藏、`Esc` 隐藏、移到相邻未启动 Dock app 隐藏旧 panel、Dock 重启恢复均由人工反馈正常。初次验证发现 Chrome 全屏下 ScreenCaptureKit 返回空标题浅条带，导致 panel 出现 3 张卡片；已补回归测试并过滤该类辅助条带，复测后 Chrome 全屏 `windows.query count=1`、`preview.panel.show count=1`、`activation.result` 正常。结果：pass with note。
- [x] Dock auto-hide enabled。2026-07-01 临时开启 Dock auto-hide 验证：Dock 弹出后 preview panel 可显示，位置在 Dock 图标附近且不越界；Dock-to-panel 保留、离开隐藏、移动到相邻未启动 app 隐藏旧 panel、Dock 重启恢复由日志和人工反馈正常。初次验证发现点击卡片激活后，再 hover 同一 Dock app 时 auto-hide reveal edge 会被 delayed validation 误判为 stale，导致不再显示 preview；已补回归测试并允许底部 reveal edge 命中对应 Dock item，复测后人工反馈问题解决。验证后已恢复原始 `autohide=0`。结果：pass with note。
- [x] Dock on left。2026-07-01 人工验证：preview panel 可显示，位置在 Dock item 旁边且不越界；hover、Dock-to-panel 保留、离开隐藏、点击激活、`Esc`、相邻未启动 app 隐藏旧 panel等行为反馈正常。验证后将 side Dock panel 从横向卡片条改为纵向排列，单张卡片仍保留完整缩略图和标题尺寸，最多显示 3 张完整卡片后竖向滚动。结果：pass with note。
- [x] Dock on right。2026-07-01 人工验证：preview panel 可显示，位置在 Dock item 旁边且不越界；hover、Dock-to-panel 保留、离开隐藏、点击激活、`Esc`、相邻未启动 app 隐藏旧 panel等行为反馈正常。验证后同 Dock on left 使用纵向排列的完整卡片，减少横向侵入工作区。结果：pass with note。
- [ ] Stage Manager enabled。
- [ ] Multiple displays。

## 备注

- 当前验收结论是 `pass with concerns`。
- 未完成的环境变体不应写成通过，需按 [环境变体验证计划](dock-hover-preview-environment-variant-verification-plan.md) 继续执行。
