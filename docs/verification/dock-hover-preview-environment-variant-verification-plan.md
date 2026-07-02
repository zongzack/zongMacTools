# Dock 悬停窗口预览环境变体验证计划

日期：2026-06-30

最近更新：2026-07-02

## 目标

验证 `DockHoverPreviewProbe` 在不同 macOS 环境变体下是否仍然稳定、安静、可恢复，并把证据写入文档。

本计划不新增产品功能。若验证发现可复现 bug，应先记录证据，再单独走 bugfix 流程。

## 相关文档

- [验证总结](dock-hover-preview-probe-summary.md)
- [MVP UI 手动验收清单](dock-hover-preview-mvp-ui-manual-checklist.md)
- [Probe 原始证据](dock-hover-preview-probe-checklist.md)
- [技术设计](../architecture/dock-hover-preview-technical-design.md)
- [后续路线](../roadmap.md)

## 通用验证规则

每个场景开始前：

1. 退出正在运行的 app：`pkill -x DockHoverPreviewProbe || true`。
2. 运行基础验证：
   - `swift test`
   - `swift build`
   - `Scripts/build_probe_app.sh`
   - `git diff --check`
3. 启动打包 app：`open build/zongMacTools.app`。
4. 确认日志包含：
   - `permissions.refresh accessibility=true screenRecording=true`
   - `orchestrator.start accessibility=true screenRecording=true`
   - `dock.subscribed pid=...`

每个场景至少检查：

- Hover 有窗口的 Dock app 是否显示 panel。
- Panel 是否出现在合理位置且不越界。
- 快速离开是否取消 stale preview。
- 从 Dock 图标移动到 panel 是否保留 panel。
- 离开 panel 是否及时隐藏。
- 点击卡片是否激活窗口并隐藏 panel。
- `Esc` 是否隐藏 panel。
- 移到相邻未启动 Dock app 时是否隐藏旧 panel。
- P1 设置抽样：Disable / Enable、delay、retention、max cards、excluded app 不应引入 stuck panel 或过期 hover。

每次改系统设置前必须记录原始状态，验证后恢复。

## 场景清单

### 1. Full-screen Space

目标：确认在全屏 Space 中 hover 不会触发 disruptive Space 切换，也不会留下 stuck panel。

步骤：

1. 打开一个 app 的全屏窗口。
2. 切到全屏 Space。
3. Hover Dock 中可见 app 图标。
4. 观察是否出现 panel、是否触发意外 Space 切换。
5. 离开 Dock 和 panel 后确认隐藏。

记录：

- 是否显示 panel。
- 是否出现跨 Space 窗口。
- 是否有 `preview.panel.show`、`mouseLeftPreviewRegion`、`hoverValidationFailed` 等日志。
- 结论：pass / pass with note / blocked / fail。

执行备注（2026-07-01）：

- 结果：pass with note。
- 设置：macOS 26.5.2，单显示器，Dock 位于底部，Dock auto-hide 关闭，Stage Manager 未启用；验证过程中未改系统设置。重新打包后 macOS TCC 曾要求重新授权 Accessibility 和 Screen Recording，恢复后日志确认权限正常。
- 操作：在 Chrome 全屏 Space 中 hover Dock 图标，并复核普通 Space。检查 preview 展示、位置不越界、quick leave/stale cancellation、Dock-to-panel 保留、离开隐藏、点击激活并隐藏、`Esc` 隐藏、移到相邻未启动 Dock app 隐藏旧 panel、Dock 重启恢复。
- 观察：初次验证发现 Chrome 全屏下 panel 出现 3 张卡片。日志显示 ScreenCaptureKit 返回一个真实 Chrome 窗口和两个空标题浅条带窗口。已补回归测试并过滤空标题、极宽、低高度的辅助条带；复测后 Chrome 全屏 `windows.query count=1`、`preview.panel.show count=1`，人工反馈全屏和非全屏均恢复正常。
- 关键日志：`permissions.refresh accessibility=true screenRecording=true`、`orchestrator.start accessibility=true screenRecording=true`、`dock.subscribed pid=...`、`dock.hoverDelayed bundle=com.google.Chrome matches=true mouseInside=true`、`windows.query app=Google Chrome count=1`、`preview.panel.show app=Google Chrome count=1`、`thumbnail.success`、`activation.result`、`preview.panel.hide reason=activated`、`preview.panel.hide reason=mouseLeftPreviewRegion`。
- 恢复动作：无系统环境设置变更；仅在重新签名 app 后恢复 TCC 权限。
- 后续问题：未发现 stuck panel 或意外 Space 切换。Dock auto-hide、Dock left/right、Stage Manager 后续均已完成；Multiple displays 因当前硬件环境不可用记录为 blocked / not available。

### 2. Dock auto-hide

目标：确认 Dock 自动隐藏时，只有 Dock item 实际在鼠标下才显示 preview，Dock 收起时不留下 panel。

步骤：

1. 记录原始设置：`defaults read com.apple.dock autohide || true`。
2. 开启 Dock 自动隐藏。
3. 重启 Dock 或通过系统设置使配置生效。
4. Hover 有窗口 app。
5. 测试快速离开、进入 panel、离开 panel、点击卡片。
6. 恢复原始设置。

记录：

- Dock 弹出/收起时 panel 行为。
- 是否出现旧 panel 残留。
- 恢复动作。

执行备注（2026-07-01）：

- 结果：pass with note。
- 设置：原始 `defaults read com.apple.dock autohide` 为 `0`；临时写入 `autohide=true` 并 `killall Dock` 使配置生效。Dock orientation 未设置，Stage Manager 未设置，单显示器。
- 操作：在 Dock auto-hide 开启时启动打包 app，确认权限和 Dock 订阅正常；让 Dock 从底部弹出后 hover VS Code/Codex/Termius 等有窗口 app，检查 preview 展示、位置、Dock-to-panel 保留、离开隐藏、点击激活、相邻未启动 app 隐藏旧 panel、Dock 重启恢复。
- 观察：初次验证发现点击卡片激活后，再 hover 同一 Dock app 时不再显示 preview。日志显示 auto-hide reveal edge 下鼠标位于屏幕底部 `y≈0`，Dock item frame 已移动到 `y≈10...86`，delayed validation 误判 `mouseInside=false` 并隐藏为 `hoverValidationFailed`。已补回归测试并允许底部 reveal edge 命中对应 Dock item；复测后人工反馈问题解决。
- 关键日志：`permissions.refresh accessibility=true screenRecording=true`、`orchestrator.start accessibility=true screenRecording=true`、`dock.subscribed pid=...`、`dock.hoverDelayed ... matches=true mouseInside=true`、`preview.panel.show`、`thumbnail.success`、`activation.result`、再次 hover 后 `preview.panel.show`、`preview.panel.hide reason=mouseLeftPreviewRegion`、`dock.pidChanged`、`dock.subscribed pid=...`。
- 恢复动作：验证后执行 `defaults write com.apple.dock autohide -bool false && killall Dock`，确认 `defaults read com.apple.dock autohide` 返回 `0`。
- 后续问题：未发现 stuck panel；若后续在左右 Dock auto-hide 中出现类似 reveal edge 问题，需要为侧边 reveal edge 单独补测试。

### 3. Dock on left

目标：确认左侧 Dock 时 panel 能出现在 Dock item 旁边并保持在可见屏幕内。

步骤：

1. 记录原始 Dock orientation。
2. 把 Dock 移到左侧。
3. Hover 样本 app。
4. 验证 panel 位置、保留区、隐藏、点击激活。
5. 恢复原始 orientation。

记录：

- Panel frame 是否合理。
- Dock-to-panel 桥接区是否顺手。
- 是否需要进一步调 side Dock 几何。

执行备注（2026-07-01）：

- 结果：pass with note。
- 设置：用户手动验证 Dock on left；验证后未要求保留系统设置变更。
- 操作：hover 有窗口 Dock app，检查 preview 展示、位置不越界、Dock-to-panel 保留、离开隐藏、点击激活、`Esc` 隐藏、移到相邻未启动 app 隐藏旧 panel。
- 观察：功能行为反馈正常。视觉上横向 panel 在 side Dock 下横向侵入工作区较多；已将 side Dock panel 改为纵向排列，单张卡片仍保持完整缩略图和标题尺寸，最多 3 张完整卡片后竖向滚动。
- 后续问题：Stage Manager 和 Multiple displays 仍需继续验证。

### 4. Dock on right

目标：同左侧 Dock，验证右侧 Dock 的定位和隐藏行为。

步骤与记录同 Dock on left。

执行备注（2026-07-01）：

- 结果：pass with note。
- 设置：用户手动验证 Dock on right；验证后未要求保留系统设置变更。
- 操作：同 Dock on left。
- 观察：功能行为反馈正常。与 Dock on left 一样，side Dock 使用纵向完整卡片 panel，bottom Dock 保持横向 panel。
- 后续问题：Stage Manager 和 Multiple displays 仍需继续验证。

### 5. Stage Manager enabled

目标：确认 Stage Manager 开启时，ScreenCaptureKit 返回窗口不会造成错误预览或 stuck panel。

步骤：

1. 记录原始 Stage Manager 状态。
2. 开启 Stage Manager。
3. 准备至少两个 app 窗口，其中一个处于当前台前调度分组，一个处于左侧最近使用分组。
4. Hover 当前台前调度分组 app 和非当前台前调度分组 app 的程序坞图标。
5. 验证窗口列表、缩略图、点击激活和隐藏行为。
6. 恢复原始设置。

记录：

- ScreenCaptureKit 是否返回非当前台前调度分组窗口。
- 点击是否造成意外切换。
- 是否需要 Stage Manager 特化策略。

执行备注（2026-07-01）：

- 结果：pass with note。
- 设置：原始 `defaults read com.apple.WindowManager GloballyEnabled` 未开启；用户手动开启台前调度后执行验证。Dock 位于底部，Dock auto-hide 关闭，当前仅 1 个显示器 `Mi Monitor`。
- 操作：hover 程序坞中有窗口的 app 图标，覆盖当前台前调度分组和左侧最近使用分组中的 app；检查 preview 展示、位置不越界、quick leave/stale cancellation、Dock-to-panel 保留、离开 panel 隐藏、点击激活并隐藏、`Esc` 隐藏、移到相邻未启动 Dock app 隐藏旧 panel、Dock 重启恢复。
- 观察：初次验证发现左侧最近使用分组下 ScreenCaptureKit 可能返回斜的系统缩略图；随后尝试屏幕区域截图会显示桌面/台前调度界面，而不是 app 自身窗口内容。最终策略为：若 ScreenCaptureKit 候选窗口能匹配 AX 真实窗口，则继续显示真实缩略图；若候选窗口无法匹配 AX 真实窗口，则使用 AX fallback 生成 preview 卡片，并且没有真实 thumbnail source 时只显示图标占位，不显示斜图或桌面假图。左侧台前调度缩略栏本身不是程序坞，不纳入 MVP hover 范围。
- 关键日志：`permissions.refresh accessibility=true screenRecording=true`、`orchestrator.start accessibility=true screenRecording=true`、`dock.subscribed pid=...`、`dock.hoverDelayed ... matches=true mouseInside=true`、`windows.axFallback`、`preview.panel.show`、`thumbnail.success`、`dock.hoverLost.panelRetained`、`preview.panel.hide reason=mouseLeftPreviewRegion`。
- 恢复动作：验证后恢复台前调度到原始关闭状态，`defaults read com.apple.WindowManager GloballyEnabled` 返回 `0`。
- 后续问题：公开 API 无法保证为左侧最近使用分组提供真实窗口像素；当前按稳定性优先降级为图标占位，后续若要优化显示效果应进入 P2 polish 或单独研究，不扩大 MVP。

### 6. Multiple displays

目标：确认多显示器时 panel 出现在 Dock/鼠标所在屏幕，且不越界。

前提：需要外接显示器或多显示器环境。

步骤：

1. 记录显示器信息：`system_profiler SPDisplaysDataType`。
2. 在主显示器和副显示器分别准备 app 窗口。
3. Hover Dock app。
4. 验证 panel 所在屏幕、frame clamp、点击激活。

记录：

- 显示器数量和排列。
- Panel 是否出现在正确屏幕。
- 是否出现跨屏 frame 计算错误。

执行备注（2026-07-01）：

- 结果：blocked / not available。
- 设置：`system_profiler SPDisplaysDataType` 仅检测到 1 个显示器 `Mi Monitor`，分辨率 5120 x 2880，UI Looks like 2560 x 1440，Main Display: Yes，Mirror: Off。
- 操作：未执行多显示器 hover 行为验证，因为当前没有副显示器或可用多显示器环境。
- 观察：不能将单显示器结果外推为多显示器 pass。
- 恢复动作：无系统设置变更。
- 后续问题：接入外接显示器后，需要重新执行本场景并检查 panel 所在屏幕、frame clamp 和点击激活行为。

## 结果记录模板

每完成一个场景，在 [MVP UI 手动验收清单](dock-hover-preview-mvp-ui-manual-checklist.md) 更新对应条目，并在验证总结中追加摘要。

建议记录格式：

```markdown
### 场景名

- 日期：YYYY-MM-DD
- 结果：pass / pass with note / blocked / fail
- 设置：
- 操作：
- 观察：
- 关键日志：
- 恢复动作：
- 后续问题：
```

## 完成标准

- 每个可执行场景都有明确结果和证据。
- 受硬件或系统限制无法执行的场景标记为 `blocked` 或 `not available`，不能标记为 pass。
- 所有临时系统设置已恢复。
- 验证后 `swift test`、`swift build`、`Scripts/build_probe_app.sh`、`git diff --check` 通过。
