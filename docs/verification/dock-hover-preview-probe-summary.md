# Dock 悬停窗口预览验证总结

日期：2026-06-26

最近更新：2026-07-02

## 总结

MVP UI / P0 环境变体结论：`pass with note`。当前可执行环境已完成验证；Multiple displays 因当前只有一个显示器，记录为 `blocked / not available`。

核心功能已经可用，普通底部 Dock、单显示器、常规 Space 的主流程通过自动测试、打包验证和人工 UI 验收。Full-screen Space 已完成跟进验证并修复 Chrome 全屏辅助条带误收录问题；Dock auto-hide 已完成跟进验证并修复底部 reveal edge stale hover 误判；Dock left/right 已完成跟进验证并将 side Dock panel 调整为纵向完整卡片布局；Stage Manager 已完成跟进验证并避免使用斜的系统缩略图或桌面假截图。剩余未实测项只有多显示器，原因是当前硬件环境不可用。

P1 settings implementation 自动验证已通过，P1 manual validation 已于 2026-07-02 由用户反馈完成。已验证范围包括 settings 持久化和非法值回退、hover delay、enabled/disabled、retention、max cards、excluded apps、display language、Launch at Login fake/system service wrapper、AppDelegate wiring、`zongMacTools.app` 打包、icon 生成，以及 Finder/TCC/Login Items/真实菜单交互人工复验。

P2 UI polish 自动验证已完成，覆盖 preview panel fit/fill 显示模式、窄窗口 fit、loading/unavailable placeholder、本地化 `No thumbnail` / `无缩略图`、show/hide animation、Reduce Motion 降级以及 Light / Dark visual token。P2 manual visual validation 尚未运行；bottom Dock、left/right Dock、auto-hide、Stage Manager、Light / Dark、Reduce Motion、Typora 窄窗口、多窗口 app、Screen Recording denied 和 quick stale cancellation 均保持 `not run`。

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

- `swift test`：2026-07-02 Task 11 门禁记录为 98 个 XCTest、0 失败。
- `swift build`：通过。
- `Scripts/build_probe_app.sh`：可生成 `build/zongMacTools.app`，其中 executable 仍为 `DockHoverPreviewProbe`。
- `git diff --check`：通过。
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
- Dock auto-hide 通过跟进验证，结果 `pass with note`。初次验证发现点击卡片激活后，再 hover 同一 Dock app 时，auto-hide reveal edge 会让 delayed validation 误判 stale，导致 preview 不再显示；已补回归测试并允许底部 reveal edge 命中对应 Dock item。复测日志包含 `dock.hoverDelayed ... matches=true mouseInside=true`、`preview.panel.show`、`activation.result`、再次 hover 后 `preview.panel.show`，以及 `killall Dock` 后 `dock.pidChanged`、`dock.subscribed pid=...`。验证后已恢复原始 `autohide=0`。
- Dock left/right 通过跟进验证，结果 `pass with note`。人工验证显示左右 Dock 下 preview 展示、位置不越界、Dock-to-panel 保留、离开隐藏、点击激活、`Esc` 和相邻未启动 app 隐藏旧 panel均正常。基于验证后的视觉判断，side Dock panel 改为纵向排列完整卡片，bottom Dock 保持横向排列；新增测试覆盖 bottom/side Dock layout 选择和 side Dock 3 张完整卡片高度上限。
- Stage Manager 通过跟进验证，结果 `pass with note`。人工验证显示 hover 程序坞中有窗口的 app 图标可显示 preview panel，位置合理且不越界；quick leave/stale cancellation、Dock-to-panel 保留、离开隐藏、点击激活、`Esc`、相邻未启动 app 隐藏旧 panel 和 Dock 重启恢复均正常。初次验证发现台前调度左侧最近使用分组下，ScreenCaptureKit 可能返回斜的系统缩略图，或者屏幕区域截图会显示桌面/台前调度界面而不是 app 自身内容；已改为当 ScreenCaptureKit 窗口无法匹配 AX 真实窗口时使用 AX fallback 生成卡片，并且无真实 thumbnail source 时只显示图标占位，不再尝试 CoreGraphics 或屏幕区域截图。关键日志包含 `permissions.refresh accessibility=true screenRecording=true`、`dock.hoverDelayed ... matches=true mouseInside=true`、`windows.axFallback`、`preview.panel.show`、`thumbnail.success`、`preview.panel.hide reason=mouseLeftPreviewRegion`。验证后 `defaults read com.apple.WindowManager GloballyEnabled` 返回 `0`，已恢复验证前关闭状态。
- 修复并验证了两个 hover 手感问题：
  - Dock 到 panel 之间不再过早隐藏。
  - 从有 preview 的 app 移到相邻未启动 Dock app 时，旧 panel 会隐藏。

## P1 自动验证结果

已通过：

- `swift test`：2026-07-02 Task 11 门禁记录为 98 个 XCTest、0 失败。
- `swift build`：通过。
- `Scripts/build_probe_app.sh`：通过，输出 `/Users/zong/Desktop/Project/zongMacTools/build/zongMacTools.app`。
- `git diff --check`：通过。
- `plutil -p build/zongMacTools.app/Contents/Info.plist | grep zongMacTools`：通过，包含 `CFBundleName`、`CFBundleDisplayName`、`CFBundleIconFile` 和 usage descriptions。
- `test -f build/zongMacTools.app/Contents/Resources/zongMacTools.icns`：通过。
- `codesign --verify --deep --strict build/zongMacTools.app`：通过。

P1 manual validation 已完成：

- Finder shows `zongMacTools.app` with the Z icon：通过，用户反馈完成。
- System Settings permission rows show `zongMacTools` and icon after re-adding permissions if TCC requires it：通过，用户反馈完成。
- Launch at Login 状态跟随 `SMAppService.mainApp.status`；`.requiresApproval` 可打开 Login Items Settings 且不重复打扰：通过，用户反馈完成。
- 真实菜单 actions 更新 checkmark，不留下 stale panel：通过，用户反馈完成。
- Dock auto-hide、left/right Dock、Stage Manager 下抽样确认 P1 设置不破坏 P0 行为：通过，用户反馈完成。

## P2 自动验证结果

已通过：

- `swift test`：2026-07-03 13:31:05 Asia/Shanghai，130 XCTest，0 failures，exit 0。
- `swift build`：通过，exit 0。
- `Scripts/build_probe_app.sh`：通过，exit 0，输出 `/Users/zong/Desktop/Project/zongMacTools/build/zongMacTools.app`，Info.plist OK，替换 existing signature。

覆盖范围：

- `PreviewPanelViewModelTests`：缩略图更新、nil thumbnail 停止 loading、默认 fill、窄窗口 fit、宽窗口 fill、panel unavailable 文案。
- `PreviewPanelViewRenderingTests`：fill / fit render plan、固定 thumbnail container、loading spinner、unavailable text branch。
- `PreviewSessionControllerTests`：从窗口 frame 选择 thumbnail display mode、thumbnail unavailable 文案随 display language 使用 `No thumbnail` / `无缩略图`、Screen Recording denied 保持不 show panel。
- `PreviewPanelControllerTests`：show/hide animation、Reduce Motion 降级、hide 后 panel frame 与命中测试、hide animation race、update 不重复触发 show animation。
- `PreviewPanelVisualStyleTests`：Light / Dark visual token 的 panel border、shadow、placeholder surface 和 hover state 基础约束。
- `AppTextProviderTests`：English `No thumbnail` 与简体中文 `无缩略图`。

P2 manual visual validation：

- 状态：`not run`。
- 未运行项：bottom Dock、left/right Dock、auto-hide、Stage Manager、Light / Dark、Reduce Motion、Typora 窄窗口、多窗口 app、Screen Recording denied、quick stale cancellation。

## 未实测 / 受限项

- Multiple displays：2026-07-01 当前硬件环境仅检测到 1 个显示器 `Mi Monitor`，无法执行多显示器行为验证；结果记录为 `blocked / not available`，不写成 pass。

## 相关文档

- 架构设计：[dock-hover-preview-technical-design.md](../architecture/dock-hover-preview-technical-design.md)
- MVP UI 手动验收：[dock-hover-preview-mvp-ui-manual-checklist.md](dock-hover-preview-mvp-ui-manual-checklist.md)
- P2 UI polish 手动验收：[dock-hover-preview-p2-ui-polish-manual-checklist.md](dock-hover-preview-p2-ui-polish-manual-checklist.md)
- Probe 原始证据：[dock-hover-preview-probe-checklist.md](dock-hover-preview-probe-checklist.md)
- 环境变体验证计划：[dock-hover-preview-environment-variant-verification-plan.md](dock-hover-preview-environment-variant-verification-plan.md)
- 后续路线：[roadmap.md](../roadmap.md)
