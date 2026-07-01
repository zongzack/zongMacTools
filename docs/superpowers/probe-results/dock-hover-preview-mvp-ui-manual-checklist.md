# Dock Hover Preview MVP UI Manual Checklist

Date: 2026-06-29
Updated: 2026-07-01

## Build

- [x] `swift test` passes. 2026-06-29 final run passed 27 XCTest cases, 0 failures, after quitting the running probe app.
- [x] `swift build` passes. 2026-06-29 final run completed successfully.
- [x] `Scripts/build_probe_app.sh` produces `build/DockHoverPreviewProbe.app`. 2026-06-29 final run produced `/Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app`.

## Permissions

- [x] Accessibility granted for `DockHoverPreviewProbe.app`. Fresh launch log at 2026-06-29 13:42:49 Asia/Shanghai reported `accessibility=true` and `dock.subscribed pid=639`.
- [x] Screen Recording granted for `DockHoverPreviewProbe.app`. Fresh launch log at 2026-06-29 13:42:49 Asia/Shanghai reported `screenRecording=true`. Restore check at 2026-06-30 17:33-17:34 Asia/Shanghai reported `screenRecording=true`, `dock.subscribed pid=1943`, and Code hover showed `preview.panel.show` plus `thumbnail.success`.
- [x] With Screen Recording disabled, Dock hover does not show a panel and logs `screenRecording=false`. User manually disabled Screen Recording and reported no panel. Relaunch at 2026-06-30 17:22:46 Asia/Shanghai logged `permissions.refresh accessibility=true screenRecording=false` and `orchestrator.start accessibility=true screenRecording=false`; Code hover at 17:22:53 logged `preview.session.skipped screenRecording=false`; DHP debug at 17:23:02 logged `debug.frontmost.skipped screenRecording=false`.

## Hover UI

| App | Expected | Result | Notes |
| --- | --- | --- | --- |
| VS Code | Shows 3 cards for 3 windows | pass | User reported preview panel behavior normal after manual run. |
| Chrome | Shows separate browser windows, not tabs | pass | User reported preview panel behavior normal after manual run. |
| Typora | Shows 1 card | pass with note | User reported preview panel behavior normal. Narrow Typora windows render narrower image content inside the fixed thumbnail region; accepted as a polish candidate rather than MVP blocker. |
| IINA | Shows static thumbnail or icon placeholder | pass | User reported preview panel behavior normal after manual run. |
| WPS | Shows 1 card for `首页` | pass | User reported preview panel behavior normal after manual run. |

## Interaction

- [x] Card click activates the selected window and hides the panel. User reported functionality normal after manual run.
- [x] Quick leave before 250 ms does not show a stale panel. User reported functionality normal after manual run.
- [x] Moving from Dock icon into panel keeps the panel visible. User reported functionality normal after manual run.
- [x] Moving outside Dock icon and panel hides the panel. User reported functionality normal after manual run.
- [x] Dock-to-panel hover retention is usable after tuning. 2026-07-01 manual retest reported `this version feels normal`; logs showed `dock.hoverLost.panelRetained` while moving from Dock to panel, `preview.panel.hide reason=mouseLeftPreviewRegion` after leaving the preview region, and `preview.panel.hide reason=activated` after card click.
- [x] Moving from an app with a visible preview to an adjacent non-running Dock app hides the old panel. 2026-07-01 regression retest passed by user report after distinguishing Dock-to-panel transition retention from adjacent Dock-item hover loss.
- [x] Escape hides the panel. User reported functionality normal after manual run.
- [x] `killall Dock` recovers without leaving a stuck panel. User reported functionality normal after manual run.

## Visual Acceptance

- [x] Panel is anchored near the hovered Dock icon. User reported functionality normal after manual run.
- [x] Panel is clamped inside the visible screen frame. User reported functionality normal after manual run.
- [x] Card titles fit without overlapping thumbnails. User reported functionality normal after manual run.
- [x] Missing thumbnail fallback is quiet and usable. User reported functionality normal after manual run.
- [x] Panel works in light and dark appearance. Dark appearance was enabled with `System Events` at 2026-06-30 17:36 Asia/Shanghai; Finder/Code/Codex hovers between 17:40-17:41 logged `preview.panel.show`, `preview.panel.update`, and `thumbnail.success`. Light appearance was restored by 17:42; Code hover at 17:43:34 logged `preview.panel.show`, `preview.panel.update`, and `thumbnail.success`. Shell screenshot capture was unavailable (`screencapture` returned `could not create image from display`), so this pass records functional display logs rather than attached screenshots.

## Environment Variants

- [x] Other normal Space. 2026-06-30 and 2026-07-01 runs on a second normal desktop used Finder/Code windows. Hover produced `preview.panel.show`, thumbnails succeeded, stale/quick leave paths logged `mouseOutside`, `noCandidate`, and `hoverValidationFailed`, moving from Dock into panel logged `dock.hoverLost.panelRetained`, leaving panel logged `mouseLeftPreviewRegion`, Escape logged `preview.panel.hide reason=escape`, card click logged `activation.result` and `preview.panel.hide reason=activated`, and `killall Dock` resubscribed from `dock.pidChanged` to `dock.subscribed pid=88629` in about 0.007 seconds. A follow-up regression where an old preview stayed visible after moving to an adjacent non-running Dock app was fixed and manually retested as normal on 2026-07-01.
- [ ] Full-screen Space.
- [ ] Stage Manager enabled.
- [ ] Dock auto-hide enabled.
- [ ] Dock on left.
- [ ] Dock on right.
- [ ] Multiple displays.
