# Dock 悬停窗口预览环境变体验证计划

日期：2026-06-30

最近更新：2026-07-01

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
3. 启动打包 app：`open build/DockHoverPreviewProbe.app`。
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
- 后续问题：未发现 stuck panel 或意外 Space 切换。仍需继续执行 Dock auto-hide、Dock left/right、Stage Manager 和 Multiple displays。

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

### 4. Dock on right

目标：同左侧 Dock，验证右侧 Dock 的定位和隐藏行为。

步骤与记录同 Dock on left。

### 5. Stage Manager enabled

目标：确认 Stage Manager 开启时，ScreenCaptureKit 返回窗口不会造成错误预览或 stuck panel。

步骤：

1. 记录原始 Stage Manager 状态。
2. 开启 Stage Manager。
3. 准备至少两个 app 窗口，其中一个处于当前 stage，一个处于 recent set。
4. Hover 当前 stage app 和非当前 stage app。
5. 验证窗口列表、缩略图、点击激活和隐藏行为。
6. 恢复原始设置。

记录：

- ScreenCaptureKit 是否返回非当前 stage 窗口。
- 点击是否造成意外切换。
- 是否需要 Stage Manager 特化策略。

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
