# Dock Hover Preview MVP UI Manual Checklist

Date: 2026-06-29

## Build

- [x] `swift test` passes. 2026-06-29 final run passed 27 XCTest cases, 0 failures, after quitting the running probe app.
- [x] `swift build` passes. 2026-06-29 final run completed successfully.
- [x] `Scripts/build_probe_app.sh` produces `build/DockHoverPreviewProbe.app`. 2026-06-29 final run produced `/Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app`.

## Permissions

- [x] Accessibility granted for `DockHoverPreviewProbe.app`. Fresh launch log at 2026-06-29 13:42:49 Asia/Shanghai reported `accessibility=true` and `dock.subscribed pid=639`.
- [x] Screen Recording granted for `DockHoverPreviewProbe.app`. Fresh launch log at 2026-06-29 13:42:49 Asia/Shanghai reported `screenRecording=true`.
- [ ] With Screen Recording disabled, Dock hover does not show a panel and logs `screenRecording=false`.

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
- [x] Escape hides the panel. User reported functionality normal after manual run.
- [x] `killall Dock` recovers without leaving a stuck panel. User reported functionality normal after manual run.

## Visual Acceptance

- [x] Panel is anchored near the hovered Dock icon. User reported functionality normal after manual run.
- [x] Panel is clamped inside the visible screen frame. User reported functionality normal after manual run.
- [x] Card titles fit without overlapping thumbnails. User reported functionality normal after manual run.
- [x] Missing thumbnail fallback is quiet and usable. User reported functionality normal after manual run.
- [ ] Panel works in light and dark appearance. Not separately run in both appearances during this pass.

## Environment Variants

- [ ] Other normal Space.
- [ ] Full-screen Space.
- [ ] Stage Manager enabled.
- [ ] Dock auto-hide enabled.
- [ ] Dock on left.
- [ ] Dock on right.
- [ ] Multiple displays.
