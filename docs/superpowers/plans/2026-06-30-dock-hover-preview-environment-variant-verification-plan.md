# Dock Hover Preview Environment Variant Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 验证 Dock Hover Preview MVP UI 在权限 denied、light/dark 外观、不同 Space、Stage Manager、Dock 自动隐藏、左右 Dock 和多显示器等环境变体下的行为，并把证据记录到 docs。

**Architecture:** 本计划不新增产品功能，主要执行手动/半自动验证并更新文档。验证以 `build/DockHoverPreviewProbe.app` 为对象，使用现有菜单栏 app、系统设置、Dock hover 操作和 unified log 作为证据来源。每个环境变体必须先记录基线、执行验证、恢复系统设置，再写入结果文档，避免把系统状态留在非预期配置。

**Tech Stack:** SwiftPM, AppKit app bundle, macOS System Settings, unified logging (`/usr/bin/log`), shell commands, Markdown documentation.

---

## Source Documents

执行本计划时以这些现有文档为需求来源：

- `docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md`
- `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`
- `docs/superpowers/probe-results/dock-hover-preview-probe-checklist.md`
- `docs/superpowers/specs/2026-06-25-dock-hover-preview-mvp-technical-design.md`

## Files

Create:

- `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`
  - 新一轮环境变体验证的主证据文件，记录命令输出摘要、人工观察、恢复动作和结论。

Modify:

- `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`
  - 将已完成的 Screen Recording denied、light/dark 和环境变体项改为 `[x]`，或按实际情况保留未勾选并记录 blocked/not available 原因。
- `docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md`
  - 追加环境变体验证结果摘要，更新 `MVP UI status` 的 concerns 描述。

Do not modify product Swift code unless the verification uncovers a reproducible bug and the user explicitly asks to fix it.

## General Verification Rules

- 每次开始前退出正在运行的 probe app：`pkill -x DockHoverPreviewProbe || true`。
- 每次手动改系统设置前记录原始状态，验证后恢复。
- 每个场景至少验证：panel 是否出现、位置是否合理、快速离开是否取消、进入 panel 是否保持、离开区域是否隐藏、点击卡片是否激活窗口、`Esc` 是否隐藏。
- 如果某个场景受硬件或用户环境限制无法执行，记录为 `blocked` 或 `not available`，并写明原因。
- 不要把未执行场景写成 pass。

## Task 1: Baseline Build, Launch, And Evidence File

**Files:**
- Create: `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`

- [ ] **Step 1: Quit existing app process**

Run:

```bash
pkill -x DockHoverPreviewProbe || true
pgrep -fl DockHoverPreviewProbe || true
```

Expected:

- No `DockHoverPreviewProbe` process is printed after `pkill`.

- [ ] **Step 2: Run baseline automated verification**

Run:

```bash
swift test
swift build
Scripts/build_probe_app.sh
git diff --check
```

Expected:

- `swift test` reports all XCTest cases passing.
- `swift build` exits 0.
- `Scripts/build_probe_app.sh` prints `/Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app`.
- `git diff --check` prints no errors.

- [ ] **Step 3: Record current system baseline**

Run:

```bash
sw_vers
xcode-select -p
xcodebuild -version
defaults read com.apple.dock autohide || true
defaults read com.apple.dock orientation || true
defaults read com.apple.WindowManager GloballyEnabled || true
system_profiler SPDisplaysDataType | sed -n '/Displays:/,/Graphics\/Displays:/p'
```

Expected:

- Commands complete and provide enough information to record macOS version, Xcode version, Dock auto-hide, Dock orientation, Stage Manager state and display count.

- [ ] **Step 4: Launch packaged app and confirm permissions**

Run:

```bash
open /Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app
sleep 2
pgrep -fl DockHoverPreviewProbe
/usr/bin/log show --last 2m --info --style compact --predicate 'subsystem == "com.zong.DockHoverPreviewProbe"'
```

Expected:

- `pgrep` prints a running `DockHoverPreviewProbe` process.
- Logs include `permissions.refresh accessibility=true screenRecording=true`.
- Logs include `orchestrator.start accessibility=true screenRecording=true`.
- Logs include `dock.subscribed pid=...`.

- [ ] **Step 5: Create the evidence document**

Create `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md` with this exact initial structure:

```markdown
# Dock Hover Preview Environment Variant Verification

Date: 2026-06-30

## Baseline

- App bundle: `/Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app`
- Automated verification:
  - `swift test`: pending execution record
  - `swift build`: pending execution record
  - `Scripts/build_probe_app.sh`: pending execution record
  - `git diff --check`: pending execution record
- Permission state: pending execution record
- macOS/Xcode/Dock/Stage Manager/display baseline: pending execution record

## Result Summary

| Scenario | Result | Notes |
| --- | --- | --- |
| Screen Recording denied final UI path | pending | |
| Light appearance | pending | |
| Dark appearance | pending | |
| Other normal Space | pending | |
| Full-screen Space | pending | |
| Dock auto-hide enabled | pending | |
| Dock on left | pending | |
| Dock on right | pending | |
| Stage Manager enabled | pending | |
| Multiple displays | pending | |

## Detailed Evidence

### Screen Recording denied final UI path

- Result: pending
- Setup:
- Observed behavior:
- Relevant logs:
- Restore action:

### Light appearance

- Result: pending
- Setup:
- Observed behavior:
- Relevant logs:
- Restore action:

### Dark appearance

- Result: pending
- Setup:
- Observed behavior:
- Relevant logs:
- Restore action:

### Other normal Space

- Result: pending
- Setup:
- Observed behavior:
- Relevant logs:
- Restore action:

### Full-screen Space

- Result: pending
- Setup:
- Observed behavior:
- Relevant logs:
- Restore action:

### Dock auto-hide enabled

- Result: pending
- Setup:
- Observed behavior:
- Relevant logs:
- Restore action:

### Dock on left

- Result: pending
- Setup:
- Observed behavior:
- Relevant logs:
- Restore action:

### Dock on right

- Result: pending
- Setup:
- Observed behavior:
- Relevant logs:
- Restore action:

### Stage Manager enabled

- Result: pending
- Setup:
- Observed behavior:
- Relevant logs:
- Restore action:

### Multiple displays

- Result: pending
- Setup:
- Observed behavior:
- Relevant logs:
- Restore action:

## Final Recommendation

- MVP UI status after environment variants: pending
- Recommended next step: pending
- Product or UI polish candidates:
```

- [ ] **Step 6: Commit baseline evidence file**

Run:

```bash
git add docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md
git commit -m "docs: start environment variant verification"
```

Expected:

- Commit succeeds.

## Task 2: Screen Recording Denied Final UI Path

**Files:**
- Modify: `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`

- [ ] **Step 1: Ask user to disable Screen Recording**

Manual user action:

1. Open System Settings > Privacy & Security > Screen Recording.
2. Disable `DockHoverPreviewProbe.app`.
3. Quit `DockHoverPreviewProbe.app` if macOS asks for restart.

Expected:

- User confirms Screen Recording is disabled for `DockHoverPreviewProbe.app`.

- [ ] **Step 2: Relaunch app and trigger preview path**

Run:

```bash
pkill -x DockHoverPreviewProbe || true
open /Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app
sleep 2
/usr/bin/log show --last 2m --info --style compact --predicate 'subsystem == "com.zong.DockHoverPreviewProbe"'
```

Manual action:

1. Hover any running app in the Dock, or click DHP > `Debug: Show Preview For Frontmost App`.
2. Confirm no preview panel appears.

Expected:

- Logs include `screenRecording=false`.
- Logs include `debug.frontmost.skipped screenRecording=false` when using debug action, or equivalent hover suppression evidence.
- No preview panel appears.

- [ ] **Step 3: Restore Screen Recording**

Manual user action:

1. Re-enable Screen Recording for `DockHoverPreviewProbe.app`.
2. Relaunch `DockHoverPreviewProbe.app`.

Run:

```bash
pkill -x DockHoverPreviewProbe || true
open /Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app
sleep 2
/usr/bin/log show --last 2m --info --style compact --predicate 'subsystem == "com.zong.DockHoverPreviewProbe"'
```

Expected:

- Logs include `permissions.refresh accessibility=true screenRecording=true`.
- Logs include `dock.subscribed pid=...`.

- [ ] **Step 4: Update docs and commit**

Update `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`:

- Set `Screen Recording denied final UI path` result to `pass` if no panel appeared and logs included `screenRecording=false`.
- Include the timestamp and the log lines that prove suppression.

Update `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`:

- Change `With Screen Recording disabled, Dock hover does not show a panel and logs screenRecording=false` to `[x]` if the check passed.

Run:

```bash
git diff --check
git add docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md
git commit -m "docs: verify screen recording denied UI path"
```

Expected:

- Diff check exits 0.
- Commit succeeds.

## Task 3: Light And Dark Appearance Verification

**Files:**
- Modify: `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`

- [ ] **Step 1: Record current appearance**

Run:

```bash
defaults read -g AppleInterfaceStyle || true
```

Expected:

- If output is `Dark`, current appearance is dark.
- If output is `The domain/default pair of ... does not exist`, current appearance is light.

- [ ] **Step 2: Verify light appearance**

Manual user action:

1. Open System Settings > Appearance.
2. Set Appearance to Light.
3. Relaunch `DockHoverPreviewProbe.app`.
4. Hover VS Code or another app with visible windows.

Expected:

- Preview panel appears near the Dock icon.
- Card text is readable.
- Border/material/shadow are visible.
- Thumbnail or placeholder is readable.
- Panel hides on Escape and mouse leave.

- [ ] **Step 3: Verify dark appearance**

Manual user action:

1. Open System Settings > Appearance.
2. Set Appearance to Dark.
3. Relaunch `DockHoverPreviewProbe.app`.
4. Hover VS Code or another app with visible windows.

Expected:

- Preview panel appears near the Dock icon.
- Card text is readable.
- Border/material/shadow are visible.
- Thumbnail or placeholder is readable.
- Panel hides on Escape and mouse leave.

- [ ] **Step 4: Restore prior appearance**

Manual user action:

- Restore the appearance recorded in Step 1.

- [ ] **Step 5: Update docs and commit**

Update result doc:

- Set `Light appearance` and `Dark appearance` to `pass`, `fail`, or `blocked`.
- Include notes about readability, panel material, card title fit and dismissal.

Update manual checklist:

- Change `Panel works in light and dark appearance` to `[x]` if both appearances pass.

Run:

```bash
git diff --check
git add docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md
git commit -m "docs: verify preview panel appearances"
```

Expected:

- Diff check exits 0.
- Commit succeeds.

## Task 4: Other Normal Space Verification

**Files:**
- Modify: `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`

- [ ] **Step 1: Prepare another normal Space**

Manual user action:

1. Open Mission Control.
2. Create another normal desktop Space.
3. Move one target app window, preferably Typora or Chrome, to that Space.
4. Keep another target app window visible in the current Space if possible.

Expected:

- There is at least one target app window on a different normal Space.

- [ ] **Step 2: Run hover and activation checks**

Manual user action:

1. Stay on the current Space.
2. Hover the Dock icon for the app whose window is on another Space.
3. Observe whether the panel appears.
4. If a panel appears, click a card and observe whether macOS switches Space or activates an expected current-Space window.
5. Switch to the Space containing the target window and repeat hover/click.

Expected:

- MVP should not intentionally list or switch to windows on another Space from the current Space.
- On the Space containing the visible target window, preview and activation should work if ScreenCaptureKit reports the window as on-screen.
- No stuck panel remains after switching Spaces.

- [ ] **Step 3: Capture logs**

Run:

```bash
/usr/bin/log show --last 10m --info --style compact --predicate 'subsystem == "com.zong.DockHoverPreviewProbe"'
```

Expected:

- Logs show hover/query/activation behavior for the tested app.
- Logs do not show repeated crashes or stuck recovery loops.

- [ ] **Step 4: Restore Space setup and commit docs**

Manual user action:

- Move windows back or leave Spaces only if the user wants to keep them.

Update docs:

- Set `Other normal Space` to `pass`, `fail`, or `blocked`.
- Record whether windows from the other Space appeared unexpectedly.

Run:

```bash
git diff --check
git add docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md
git commit -m "docs: verify normal space behavior"
```

Expected:

- Commit succeeds.

## Task 5: Full-Screen Space Verification

**Files:**
- Modify: `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`

- [ ] **Step 1: Prepare full-screen app Space**

Manual user action:

1. Put a target app, preferably Chrome or Typora, into macOS full-screen mode.
2. Keep `DockHoverPreviewProbe.app` running.

Expected:

- A full-screen Space exists for a target app.

- [ ] **Step 2: Verify behavior from normal Space and full-screen Space**

Manual user action:

1. From a normal Space, hover the Dock icon for the full-screen app.
2. Observe whether preview appears or is suppressed.
3. Switch to the full-screen Space and attempt Dock hover if the Dock can be revealed.
4. Click a card only if a preview appears and the behavior is non-disruptive.

Expected:

- The app must not trigger disruptive Space switching from hover alone.
- If no eligible windows are returned, no panel should appear.
- If a panel appears in full-screen context, it should hide cleanly on Escape/mouse leave.

- [ ] **Step 3: Capture logs and restore**

Run:

```bash
/usr/bin/log show --last 10m --info --style compact --predicate 'subsystem == "com.zong.DockHoverPreviewProbe"'
```

Manual user action:

- Exit full-screen mode after recording behavior.

Update docs and commit:

```bash
git diff --check
git add docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md
git commit -m "docs: verify full-screen space behavior"
```

Expected:

- Commit succeeds.

## Task 6: Dock Auto-Hide Verification

**Files:**
- Modify: `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`

- [ ] **Step 1: Record current Dock auto-hide setting**

Run:

```bash
defaults read com.apple.dock autohide || true
```

Expected:

- Output records whether auto-hide was enabled (`1`) or disabled (`0` or not set).

- [ ] **Step 2: Ask user to enable Dock auto-hide**

Manual user action:

1. Open System Settings > Desktop & Dock.
2. Enable automatically hide and show the Dock.
3. Relaunch `DockHoverPreviewProbe.app`.

Expected:

- Dock auto-hide is enabled.

- [ ] **Step 3: Verify hover and leave behavior**

Manual user action:

1. Reveal the Dock.
2. Hover VS Code, Chrome or Typora.
3. Confirm preview appears only while the Dock item is actually under the mouse.
4. Move into panel and confirm it remains visible.
5. Move away and confirm it hides.
6. Let Dock hide and confirm no stuck panel remains.

Expected:

- Panel appears only for valid hover.
- Panel hides cleanly when Dock hides or mouse leaves both Dock item and panel.

- [ ] **Step 4: Restore auto-hide and commit docs**

Manual user action:

- Restore the auto-hide setting recorded in Step 1.

Run:

```bash
/usr/bin/log show --last 10m --info --style compact --predicate 'subsystem == "com.zong.DockHoverPreviewProbe"'
git diff --check
git add docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md
git commit -m "docs: verify dock auto-hide behavior"
```

Expected:

- Logs support the observed behavior.
- Commit succeeds.

## Task 7: Left Dock Verification

**Files:**
- Modify: `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`

- [ ] **Step 1: Record current Dock orientation**

Run:

```bash
defaults read com.apple.dock orientation || true
```

Expected:

- Output records the current Dock orientation. If not set, treat baseline as bottom.

- [ ] **Step 2: Ask user to move Dock left**

Manual user action:

1. Open System Settings > Desktop & Dock.
2. Set Dock position on screen to Left.
3. Relaunch `DockHoverPreviewProbe.app`.

Expected:

- Dock is on the left edge.

- [ ] **Step 3: Verify panel positioning and interactions**

Manual user action:

1. Hover VS Code, Chrome or Typora in the left Dock.
2. Confirm panel appears beside the Dock item and remains inside visible screen bounds.
3. Click a card and confirm activation/hide.
4. Test quick leave, move into panel, mouse leave and Escape.

Expected:

- Panel positions to the right of the left Dock item or falls back near mouse without leaving screen bounds.
- Dismissal behavior remains correct.

- [ ] **Step 4: Restore orientation and commit docs**

Manual user action:

- Restore the Dock orientation recorded in Step 1 after left and right Dock tests are complete, or proceed directly to Task 8 before restoring.

Run:

```bash
/usr/bin/log show --last 10m --info --style compact --predicate 'subsystem == "com.zong.DockHoverPreviewProbe"'
git diff --check
git add docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md
git commit -m "docs: verify left dock behavior"
```

Expected:

- Commit succeeds.

## Task 8: Right Dock Verification

**Files:**
- Modify: `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`

- [ ] **Step 1: Ask user to move Dock right**

Manual user action:

1. Open System Settings > Desktop & Dock.
2. Set Dock position on screen to Right.
3. Relaunch `DockHoverPreviewProbe.app`.

Expected:

- Dock is on the right edge.

- [ ] **Step 2: Verify panel positioning and interactions**

Manual user action:

1. Hover VS Code, Chrome or Typora in the right Dock.
2. Confirm panel appears beside the Dock item and remains inside visible screen bounds.
3. Click a card and confirm activation/hide.
4. Test quick leave, move into panel, mouse leave and Escape.

Expected:

- Panel positions to the left of the right Dock item or falls back near mouse without leaving screen bounds.
- Dismissal behavior remains correct.

- [ ] **Step 3: Restore original Dock orientation and commit docs**

Manual user action:

- Restore Dock orientation recorded in Task 7 Step 1.

Run:

```bash
/usr/bin/log show --last 10m --info --style compact --predicate 'subsystem == "com.zong.DockHoverPreviewProbe"'
git diff --check
git add docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md
git commit -m "docs: verify right dock behavior"
```

Expected:

- Commit succeeds.

## Task 9: Stage Manager Verification

**Files:**
- Modify: `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`

- [ ] **Step 1: Record current Stage Manager setting**

Run:

```bash
defaults read com.apple.WindowManager GloballyEnabled || true
```

Expected:

- Output records whether Stage Manager was enabled or not set/disabled.

- [ ] **Step 2: Ask user to enable Stage Manager**

Manual user action:

1. Open System Settings > Desktop & Dock.
2. Enable Stage Manager.
3. Arrange at least two target apps with visible windows, preferably Chrome and Typora.
4. Relaunch `DockHoverPreviewProbe.app`.

Expected:

- Stage Manager is enabled and target windows exist.

- [ ] **Step 3: Verify window listing and preview behavior**

Manual user action:

1. Hover Dock icons for VS Code, Chrome, Typora and WPS if available.
2. Observe whether hidden/recent Stage Manager sets appear unexpectedly.
3. Click visible cards and verify activation.
4. Test quick leave and Escape.

Expected:

- Visible current Stage Manager set windows may appear.
- Hidden/recent sets should not create misleading or unusable preview cards; if they do, record exact app and behavior as a concern.
- No stuck panel remains.

- [ ] **Step 4: Restore Stage Manager and commit docs**

Manual user action:

- Restore the Stage Manager setting recorded in Step 1.

Run:

```bash
/usr/bin/log show --last 10m --info --style compact --predicate 'subsystem == "com.zong.DockHoverPreviewProbe"'
git diff --check
git add docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md
git commit -m "docs: verify stage manager behavior"
```

Expected:

- Commit succeeds.

## Task 10: Multiple Displays Verification

**Files:**
- Modify: `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`

- [ ] **Step 1: Detect display count**

Run:

```bash
system_profiler SPDisplaysDataType | grep -E "Resolution|UI Looks like|Display Type|Main Display|Online" || true
```

Expected:

- Output shows whether more than one display is connected and online.

- [ ] **Step 2: If only one display is available, record not available**

If the machine has only one display, update the result doc:

- Set `Multiple displays` result to `not available`.
- Include the `system_profiler` evidence.

Then commit:

```bash
git diff --check
git add docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md
git commit -m "docs: record display availability"
```

Expected:

- Commit succeeds.

- [ ] **Step 3: If multiple displays are available, verify panel placement**

Manual user action:

1. Connect or enable the second display.
2. Place Dock on the active display if macOS allows it.
3. Put target app windows on each display.
4. Relaunch `DockHoverPreviewProbe.app`.
5. Hover Dock icons and confirm panel appears on the expected display and stays inside that display's visible frame.
6. Click cards and confirm activation.

Expected:

- Panel anchors to the screen containing the Dock/mouse.
- Panel stays inside visible bounds.
- No card click activates a surprising off-screen or unrelated window.

- [ ] **Step 4: Capture logs and commit docs**

Run:

```bash
/usr/bin/log show --last 10m --info --style compact --predicate 'subsystem == "com.zong.DockHoverPreviewProbe"'
git diff --check
git add docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md
git commit -m "docs: verify multiple display behavior"
```

Expected:

- Commit succeeds.

## Task 11: Final Summary And Recommendation

**Files:**
- Modify: `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`
- Modify: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`
- Modify: `docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md`

- [ ] **Step 1: Run final verification commands**

Run:

```bash
pkill -x DockHoverPreviewProbe || true
swift test
swift build
Scripts/build_probe_app.sh
git diff --check
```

Expected:

- `swift test` passes.
- `swift build` passes.
- `Scripts/build_probe_app.sh` produces `/Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app`.
- `git diff --check` exits 0.

- [ ] **Step 2: Update final recommendation**

Update `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`:

- Set `MVP UI status after environment variants` to one of:
  - `pass` if all applicable checks pass and unavailable checks are hardware-limited only.
  - `pass with concerns` if any applicable environment has a non-blocking issue.
  - `blocked` if a major environment breaks core preview behavior.
- Set `Recommended next step` to one of:
  - `polish UI` if environment verification is acceptable.
  - `fix environment-specific behavior` if any bug is found.
  - `revisit architecture` if public APIs cannot support the required behavior.
- Record polish candidates, including thumbnail aspect-ratio presentation if still desired.

Update `docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md`:

- Add a section named `Environment Variant Verification Result`.
- Link to `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md`.
- Summarize pass/fail/blocked status for every scenario.
- Update the remaining risks list.

- [ ] **Step 3: Documentation self-review**

Run:

```bash
rg -n "T[B]D|TO[D]O|fill[[:space:]]+in|implement[[:space:]]+later" docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md
git diff --check
```

Expected:

- `rg` exits with no matches.
- `git diff --check` exits 0.

- [ ] **Step 4: Commit final verification summary**

Run:

```bash
git add docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md docs/superpowers/probe-results/2026-06-26-dock-hover-preview-probe-summary.md
git commit -m "docs: summarize environment variant verification"
```

Expected:

- Commit succeeds.

## Completion Criteria

This plan is complete when:

- Screen Recording denied final UI path is manually verified or recorded with a clear blocker.
- Light and dark appearance are manually verified or recorded with a clear blocker.
- Other normal Space, full-screen Space, Dock auto-hide, left Dock, right Dock and Stage Manager are verified or recorded with clear blockers.
- Multiple display behavior is verified or recorded as not available with display evidence.
- System settings changed during verification are restored or intentionally left changed by user choice.
- `swift test`, `swift build`, `Scripts/build_probe_app.sh` and `git diff --check` pass after verification.
- `docs/superpowers/probe-results/2026-06-30-dock-hover-preview-environment-variants.md` contains concrete evidence for each scenario.
- Existing manual checklist and probe summary are updated without overstating unverified scenarios.

## Execution Notes

- Many tasks require manual macOS System Settings changes. Stop and ask the user before changing Screen Recording, Appearance, Spaces, Stage Manager, Dock auto-hide, Dock position or display setup.
- If a task is blocked by hardware or unavailable apps, record the blocker and continue with other independent tasks.
- Do not fix product bugs inside this verification plan. If verification reveals a bug, record exact reproduction steps, logs and expected behavior, then create a separate bugfix plan.
