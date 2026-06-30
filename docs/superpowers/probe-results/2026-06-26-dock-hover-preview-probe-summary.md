# Dock Hover Preview Probe Summary

Date: 2026-06-26

## Verdict

- Proceed to MVP UI: proceed with concerns
- Blocking issues: non-current environment variants still require manual/system-context runs; normal bottom-Dock Screen Recording granted and denied paths passed the hard probe gates.

## Hard Gate Results

| Gate | Result | Evidence |
| --- | --- | --- |
| Dock hover stale item suppressed | pass with log-shape concern | Task 8 WPS quick leave at 16:20:04 logged `dock.selectedStale bundle=com.kingsoft.wpsoffice.mac`, `dock.hoverLost reason=noCandidate`, and no stale delayed `mouseInside=true`; earlier Task 4 WPS quick leave logged `dock.hoverLost reason=mouseOutside`. |
| Dock frame or list fallback available | pass | Dock AX list was queryable at 16:19 with target positions for VS Code, Chrome, WPS, Typora, and IINA; Task 8 hoverDelayed logs validated current frames with `matches=true mouseInside=true`. |
| VS Code windows listed and AX matched | pass | Task 8 query at 16:16:13 returned 3 Code windows, 3/3 AX matched, elapsed 52 ms. |
| Chrome windows listed and AX matched | pass | Task 8 query at 16:16:34 returned 1 Chrome window, 1/1 AX matched, elapsed 46 ms. |
| Typora windows listed and AX matched | pass | Task 8 query at 16:16:45 returned 1 Typora window, 1/1 AX matched, elapsed 36 ms. |
| IINA windows listed and AX matched | pass | Task 8 query at 16:16:50 returned 1 IINA window, 1/1 AX matched, elapsed 45 ms. |
| Static thumbnail works | pass | Task 8 SCK thumbnails succeeded for all queried windows: VS Code 3/3, Chrome 1/1, Typora 1/1, IINA 1/1, WPS 1/1. |
| Query timing within target | pass | Task 8 app query times were 52 ms, 46 ms, 36 ms, 45 ms, and 47 ms, all under 100 ms in the current environment. |
| Dock restart recovery under 10 seconds | pass | Task 8 `killall Dock` logged `dock.pidChanged` at 16:20:24.190 and `dock.subscribed pid=13971` at 16:20:24.211, about 0.021 seconds. |

## Permission Gate

- Screen Recording granted path: pass; fresh packaged startup at 16:15:39 logged `permissions.refresh accessibility=true screenRecording=true` and `orchestrator.start accessibility=true screenRecording=true`.
- Screen Recording denied path: pass; after the user manually disabled Screen Recording, controller relaunch and DHP `Debug: Show Preview For Frontmost App` produced `2026-06-26T08:30:17Z [INFO] permissions.refresh accessibility=true screenRecording=false`, `2026-06-26T08:30:17Z [INFO] orchestrator.start accessibility=true screenRecording=false`, `2026-06-26T08:30:21Z [INFO] permissions.refresh accessibility=true screenRecording=false`, and `2026-06-26T08:30:21Z [WARN] debug.frontmost.skipped screenRecording=false`.
- Screen Recording restore path: pass; after the user manually restored Screen Recording, controller relaunch logs at 2026-06-26 16:30-16:31 Asia/Shanghai showed `permissions.refresh accessibility=true screenRecording=true`, `orchestrator.start accessibility=true screenRecording=true`, and `dock.subscribed pid=13971`.

## WPS Characterization

- Process ownership: pass; WPS Office ran as `com.kingsoft.wpsoffice.mac` with `pid=78012`.
- AX hierarchy: pass; Task 8 query had `axCount=1 matched=true bestScore=1.000`.
- Window query result: pass; Task 8 returned 1 WPS window, title `首页`, elapsed 47 ms.
- Activation result: pass; Task 8 activation selected id `5396` and logged `hadAX=true raise=true appActivate=true`.

## Space And Display Characterization

- Other Space: blocked; no additional normal Space was prepared. Needs manual Space setup/switching.
- Full-screen Space: blocked; no full-screen Space was prepared. Needs manual full-screen Space setup.
- Stage Manager disabled: characterized; setting was not set/enabled, and current checks did not crash or leave stuck state.
- Stage Manager enabled: blocked; enabling Stage Manager is a user system setting change.
- Multiple displays: not available; current machine reported one online display.
- Dock auto-hide disabled: characterized; `defaults read com.apple.dock autohide` returned `0`, and current checks did not crash or leave stuck state.
- Dock auto-hide enabled: blocked; enabling auto-hide is a user system setting change.
- Left Dock: blocked; moving Dock left is a user system setting change.
- Right Dock: blocked; moving Dock right is a user system setting change.

## Required Design Changes Before MVP UI

- Treat stale hover clear as a first-class state: Task 8 commonly logged `dock.selectedStale` plus `dock.hoverLost reason=noCandidate` on leave after Dock magnification collapsed frames, so MVP should clear pending/visible preview state on either `mouseOutside`, `selectedStale`, or `noCandidate`.
- Keep Screen Recording denied suppression in the MVP path; the denied-permission evidence now confirms normal preview work is skipped when Screen Recording is false.
- Gate cross-Space/full-screen/Stage Manager/multiple-display behavior behind explicit environment testing; current evidence supports only the normal, single-display, bottom-Dock, auto-hide-disabled environment.

## Verification

- `swift test`: passed; 10 XCTest cases, 0 failures.
- `swift build`: passed; debug build completed.
- `Scripts/build_probe_app.sh`: passed; printed `/Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app`.

## MVP UI Plan

- Plan: `docs/superpowers/plans/2026-06-26-dock-hover-preview-mvp-ui-implementation-plan.md`
- Manual UI checklist: `docs/superpowers/probe-results/dock-hover-preview-mvp-ui-manual-checklist.md`
- DockDoor is a visual and interaction reference only. The MVP UI implementation must not copy DockDoor GPLv3 source, file structure, helper code, comments, or private API wrappers.

## MVP UI Result

- MVP UI status: pass with concerns.
- Recommended next step: run environment variants before broadening scope; then consider polish UI for thumbnail aspect-ratio presentation.
- Main evidence:
  - `swift test`: pass; 2026-06-29 final run passed 27 XCTest cases, 0 failures, after quitting the running probe app.
  - `swift build`: pass; 2026-06-29 final run completed successfully.
  - `Scripts/build_probe_app.sh`: pass; 2026-06-29 final run produced `/Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app`.
  - Permissions: pass; fresh packaged launch at 2026-06-29 13:42:49 Asia/Shanghai logged `accessibility=true`, `screenRecording=true`, and `dock.subscribed pid=639`. Final Screen Recording denied run on 2026-06-30 logged `screenRecording=false`, suppressed Dock hover preview with `preview.session.skipped screenRecording=false`, suppressed DHP debug preview with `debug.frontmost.skipped screenRecording=false`, and showed no panel by user report. Restore run on 2026-06-30 logged `screenRecording=true`, `dock.subscribed pid=1943`, and Code hover showed `preview.panel.show` plus thumbnail success.
  - Appearance: pass with log evidence; dark appearance hovers on 2026-06-30 logged `preview.panel.show`, `preview.panel.update`, and `thumbnail.success`; light appearance Code hover after restore logged the same. Shell screenshot capture was unavailable, so no screenshot artifact was attached.
  - Sample apps and interactions: pass by user report after manual run. User observed a Typora narrow-window thumbnail aspect-ratio presentation; accepted as a polish candidate rather than an MVP blocker.
- Remaining risks:
  - Other Spaces, full-screen Spaces, Stage Manager, Dock auto-hide, left/right Dock, and multiple displays remain unverified in the MVP UI pass.
