# Dock 悬停窗口预览 MVP UI 手动验收清单

日期：2026-06-29

最近更新：2026-07-02

## 构建验证

- [x] `swift test` 通过。2026-07-02 Task 11 门禁记录为 98 个 XCTest、0 失败。
- [x] `swift build` 通过。
- [x] `Scripts/build_probe_app.sh` 可生成 `build/zongMacTools.app`，其中 executable 仍为 `DockHoverPreviewProbe`。
- [x] `git diff --check` 通过。

## P1 自动验证

- [x] Settings defaults 保持 MVP 行为：enabled、250 ms、standard retention、max 8 cards、excluded apps 为空、English。
- [x] Settings 非法值回退并记录 `settings.invalid`，不会覆盖原始 defaults 或导致 hover preview 崩溃。
- [x] Hover delay、enabled/disabled、excluded apps、retention、max cards、language、Launch at Login 菜单路径均有 XCTest 覆盖。
- [x] Screen Recording 缺失时继续静默抑制 preview UI。
- [x] Stale hover cancellation 仍有 generation / delayed hover 回归测试覆盖。
- [x] `Scripts/build_probe_app.sh` 生成 `build/zongMacTools.app/Contents/Resources/zongMacTools.icns` 并通过 `codesign --verify --deep --strict build/zongMacTools.app`。

## P1 手动验证队列

- [ ] Finder 显示 `zongMacTools.app` 和 Z icon。
- [ ] System Settings > Privacy & Security 的 Accessibility / Screen Recording 权限行显示 `zongMacTools` 名称和 icon；如 TCC 需要，删除旧项后重新添加再确认。
- [ ] Login Items 中状态与 `SMAppService.mainApp.status` 一致；`.requiresApproval` 时 Open Login Items Settings 可打开系统设置且不反复提示。
- [ ] 真实菜单交互更新 checkmark，且 Disable / Exclude 不留下 stale panel。
- [ ] 默认启动行为保持 MVP 等价：enabled、250 ms、standard retention、max 8 cards、excluded apps 为空、English。
- [ ] 抽样 Dock auto-hide、left/right Dock、Stage Manager 环境下 P1 设置不会引入 stuck panel 或过期 hover。

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
- [x] Stage Manager enabled。2026-07-01 人工验证：hover 程序坞中有窗口的 app 图标可显示 preview panel，位置合理且不越界；快速离开取消 stale preview；Dock-to-panel 保留、离开 panel 隐藏、点击卡片激活并隐藏、`Esc` 隐藏、移动到相邻未启动 app 隐藏旧 panel、Dock 重启恢复均反馈正常。初次验证发现台前调度左侧最近使用分组会让 ScreenCaptureKit 返回斜的系统缩略图，或返回无法代表 app 自身内容的桌面区域；已补 AX fallback 和缩略图源保护。当前策略是：当前台前调度分组能拿到真实窗口缩略图时显示真实缩略图；最近使用分组若公开 API 只暴露斜图或非真实窗口像素，则显示图标占位，不显示错误缩略图。验证后台前调度已恢复为原始关闭状态。结果：pass with note。
- [x] Multiple displays。2026-07-01 当前硬件环境仅检测到 1 个显示器：Mi Monitor，无法执行多显示器行为验证。结果：blocked / not available。

## 备注

- 当前 P0 环境变体验收结论是 `pass with note`；多显示器因当前硬件不可用，明确记录为 `blocked / not available`，不计为通过。
- 后续若接入外接显示器，需按 [环境变体验证记录与复验指南](../../verification/dock-hover-preview-environment-variant-verification-plan.md) 重新执行 Multiple displays 场景。
