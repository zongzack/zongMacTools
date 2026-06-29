# Dock Hover Preview MVP UI Manual Checklist

Date: 2026-06-29

## Build

- [ ] `swift test` passes.
- [ ] `swift build` passes.
- [ ] `Scripts/build_probe_app.sh` produces `build/DockHoverPreviewProbe.app`.

## Permissions

- [ ] Accessibility granted for `DockHoverPreviewProbe.app`.
- [ ] Screen Recording granted for `DockHoverPreviewProbe.app`.
- [ ] With Screen Recording disabled, Dock hover does not show a panel and logs `screenRecording=false`.

## Hover UI

| App | Expected | Result | Notes |
| --- | --- | --- | --- |
| VS Code | Shows 3 cards for 3 windows | not run | |
| Chrome | Shows separate browser windows, not tabs | not run | |
| Typora | Shows 1 card | not run | |
| IINA | Shows static thumbnail or icon placeholder | not run | |
| WPS | Shows 1 card for `首页` | not run | |

## Interaction

- [ ] Card click activates the selected window and hides the panel.
- [ ] Quick leave before 250 ms does not show a stale panel.
- [ ] Moving from Dock icon into panel keeps the panel visible.
- [ ] Moving outside Dock icon and panel hides the panel.
- [ ] Escape hides the panel.
- [ ] `killall Dock` recovers without leaving a stuck panel.

## Visual Acceptance

- [ ] Panel is anchored near the hovered Dock icon.
- [ ] Panel is clamped inside the visible screen frame.
- [ ] Card titles fit without overlapping thumbnails.
- [ ] Missing thumbnail fallback is quiet and usable.
- [ ] Panel works in light and dark appearance.

## Environment Variants

- [ ] Other normal Space.
- [ ] Full-screen Space.
- [ ] Stage Manager enabled.
- [ ] Dock auto-hide enabled.
- [ ] Dock on left.
- [ ] Dock on right.
- [ ] Multiple displays.
