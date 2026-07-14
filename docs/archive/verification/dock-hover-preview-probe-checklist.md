# Dock Hover Preview Probe Checklist

Date: 2026-06-26

## Environment

- macOS: ProductVersion `26.5.1`, BuildVersion `25F80`
- Xcode: `Xcode 26.5`, build `17F42`
- Dock position: bottom inferred from converted Dock item frames at y≈10 and visibleFrame minY=54; `defaults read com.apple.dock orientation` was not set
- Dock auto-hide: false; `defaults read com.apple.dock autohide` returned `0`
- Stage Manager: not set / not enabled; `defaults read com.apple.WindowManager GloballyEnabled` returned not set
- Displays: one display; `NSScreen screen0=(0.0, 0.0, 3008.0, 1692.0) visible=(0.0, 54.0, 3008.0, 1608.0)`

## Permissions

- Accessibility: granted for final binary at 2026-06-26 14:26:32 Asia/Shanghai; logs showed `permissions.refresh accessibility=true screenRecording=false`, `orchestrator.start accessibility=true screenRecording=false`, and `dock.subscribed pid=6627`
- Re-signing note: earlier ad-hoc re-signing temporarily reset Accessibility for the packaged app identity; final Task 4 packaged run is Accessibility granted
- Screen Recording: granted for Task 5 final binary after packaging and reauthorization; logs at 2026-06-26 14:56:36 Asia/Shanghai showed `permissions.refresh accessibility=true screenRecording=true`, `orchestrator.start accessibility=true screenRecording=true`, and `dock.subscribed pid=35521`; remained granted for Task 6 final binary at 2026-06-26 15:43:08 Asia/Shanghai with `permissions.refresh accessibility=true screenRecording=true`, `orchestrator.start accessibility=true screenRecording=true`, and `dock.subscribed pid=35521`
- Task 7 final startup: permissions remained granted at 2026-06-26 16:07:03 Asia/Shanghai with `permissions.refresh accessibility=true screenRecording=true`, `orchestrator.start accessibility=true screenRecording=true`, and `dock.subscribed pid=35521`
- Task 8 fresh packaged startup after `Scripts/build_probe_app.sh`: permissions remained granted at 2026-06-26 16:15:39 Asia/Shanghai with `permissions.refresh accessibility=true screenRecording=true`, `orchestrator.start accessibility=true screenRecording=true`, and `dock.subscribed pid=35521`
- Task 8 Screen Recording denied check: passed after manual permission change. User manually disabled Screen Recording for `DockHoverPreviewProbe.app`; controller relaunched `build/DockHoverPreviewProbe.app` and triggered `Debug: Show Preview For Frontmost App` from DHP. Logs at 2026-06-26 16:30 Asia/Shanghai showed `2026-06-26T08:30:17Z [INFO] permissions.refresh accessibility=true screenRecording=false`, `2026-06-26T08:30:17Z [INFO] orchestrator.start accessibility=true screenRecording=false`, `2026-06-26T08:30:17Z [INFO] dock.subscribed pid=13971`, `2026-06-26T08:30:21Z [INFO] permissions.refresh accessibility=true screenRecording=false`, and `2026-06-26T08:30:21Z [WARN] debug.frontmost.skipped screenRecording=false`; normal hover preview work was suppressed while Screen Recording was denied.
- Task 8 Screen Recording restore check: passed after manual restore. User manually restored Screen Recording; controller relaunched the app, and logs at 2026-06-26 16:30-16:31 Asia/Shanghai showed `permissions.refresh accessibility=true screenRecording=true`, `orchestrator.start accessibility=true screenRecording=true`, and `dock.subscribed pid=13971`.

## Dock Hover

| App | Bundle ID | PID Logged | Dock Frame Logged | 250 ms Mouse-Inside Validation | Leave Before Delay Suppressed |
| --- | --- | --- | --- | --- | --- |
| VS Code | `com.microsoft.VSCode` | `pid=761` | `frame=Optional((1036.9737548828125, 10.0, 38.371826171875, 50.371826171875))` | passed at 2026-06-26 14:27 Asia/Shanghai: `matches=true mouseInside=true frame=Optional((1017.964599609375, 10.0, 74.99951171875, 86.99951171875))`; Task 8 fresh pass at 16:19:38: `matches=true mouseInside=true frame=Optional((1019.148193359375, 10.0, 74.997314453125, 86.997314453125))` | not separately tested for leave-before-delay; WPS stale case covers stale validation gate |
| Chrome | `com.google.Chrome` | `pid=46872` | `frame=Optional((821.587646484375, 10.0, 36.51177978515625, 48.51171875))` | passed at 2026-06-26 14:27 Asia/Shanghai: `matches=true mouseInside=true frame=Optional((800.1087646484375, 10.0, 74.982177734375, 86.982177734375))`; Task 8 fresh pass at 16:19:40: `matches=true mouseInside=true frame=Optional((803.1480712890625, 10.0, 74.997314453125, 86.997314453125))` | not separately tested for leave-before-delay; WPS stale case covers stale validation gate |
| WPS | `com.kingsoft.wpsoffice.mac` | `pid=78012` | `frame=Optional((1107.90625, 10.0, 37.9429931640625, 49.9429931640625))` | passed at 2026-06-26 14:27 Asia/Shanghai: `matches=true mouseInside=true frame=Optional((1094.4002685546875, 10.0, 74.93896484375, 86.93896484375))` | passed: quick leave at 14:27:37.972 logged `dock.hover`, followed by `14:27:38.130 dock.hoverLost reason=mouseOutside ...` before any delayed success for that WPS hover |
| Typora | `abnerworks.Typora` | `pid=46874` | `frame=Optional((1145.800048828125, 10.0, 36.0, 48.0))` | passed at 2026-06-26 14:27 Asia/Shanghai: `matches=true mouseInside=true frame=Optional((1121.71923828125, 10.0, 74.9212646484375, 86.9212646484375))`; Task 8 fresh pass at 16:19:42: `matches=true mouseInside=true frame=Optional((1127.148193359375, 10.0, 74.997314453125, 86.997314453125))` | not separately tested for leave-before-delay; WPS stale case covers stale validation gate |
| IINA | `com.colliderli.iina` | `pid=36247` | `frame=Optional((1989.351806640625, 10.0, 36.7789306640625, 48.7789306640625))` | passed at 2026-06-26 14:27 Asia/Shanghai: `matches=true mouseInside=true frame=Optional((1967.94091796875, 10.0, 74.9757080078125, 86.9757080078125))`; Task 8 fresh pass at 16:19:43 with current Dock position from AX list: `frame=Optional((2098.0, 10.0, 36.0, 48.0))` then `matches=true mouseInside=true frame=Optional((2079.560546875, 10.0, 74.995849609375, 86.995849609375))` | not separately tested for leave-before-delay; WPS stale case covers stale validation gate |

- Task 8 WPS stale leave-before-delay: passed at 2026-06-26 16:20:04 Asia/Shanghai. Logs showed `dock.hover app=WPS Office bundle=com.kingsoft.wpsoffice.mac ...`, then after about 94 ms `dock.selectedStale bundle=com.kingsoft.wpsoffice.mac mouse=(1500.0, 892.0) ...`, `dock.hoverLost reason=noCandidate`, and `dock.hoverLost.orchestrator`; no delayed WPS `mouseInside=true` log followed that stale hover.
- Task 8 leave-after-delay note: deliberate leave after successful delayed validation logged `dock.selectedStale ...` and `dock.hoverLost reason=noCandidate` for the target apps rather than the expected `dock.hoverLost reason=mouseOutside`. The stale state was cleared and no stuck hover/panel behavior was observed in logs.

## Dock Restart

- `killall Dock` recovery time: approximately 0.02 seconds from `dock.pidChanged` to resubscribe, within 10 seconds
- Recovery notes: passed after final hover verification; logs at 2026-06-26 14:28:07 Asia/Shanghai showed `dock.pidChanged old=Optional(6627) new=Optional(35521)`, `dock.stop` twice from the stop/start path, `dock.subscribed pid=35521`, and `dock.start`
- Task 8 fresh recovery: passed at 2026-06-26 16:20:24 Asia/Shanghai after `killall Dock`; logs showed `dock.pidChanged old=Optional(35521) new=Optional(13971)` at 16:20:24.190 and `dock.subscribed pid=13971` at 16:20:24.211, measured recovery approximately 0.021 seconds.

## Window Query And AX Mapping

| App | Expected Visible Windows | Returned Windows | AX Matched Windows | Query Time ms | Notes |
| --- | --- | --- | --- | --- | --- |
| VS Code | 3 | 3 | 3 | 64 | all AX scores 1.000; 3 Code windows from System Events |
| Chrome | 1 | 1 | 1 | 42 | AX score 1.000 |
| Typora | 1 | 1 | 1 | 30 | opened `项目信息.md`; title `项目信息.md`; AX score 1.000 |
| IINA | 1 | 1 | 1 | 42 | AX score 1.000 |
| WPS | 1 | 1 | 1 | 46 | opened xlsx; title `AI开发岗试用期考核表_修改版_原格式_更新版.xlsx`; AX score 1.000 |

- Query run time: 2026-06-26 14:58-14:59 Asia/Shanghai via DHP menu item `Debug: Show Preview For Frontmost App`
- Frontmost starts observed: `Code` (`com.microsoft.VSCode`, `pid=761`), `Google Chrome` (`com.google.Chrome`, `pid=46872`), `Typora` (`abnerworks.Typora`, `pid=46874`), `IINA` (`com.colliderli.iina`, `pid=36247`), and `WPS Office` (`com.kingsoft.wpsoffice.mac`, `pid=78012`)
- Completion logs matched returned counts for all apps: Code 3, Chrome 1, Typora 1, IINA 1, WPS Office 1
- Task 8 fresh query run time: 2026-06-26 16:16-16:17 Asia/Shanghai via DHP menu item `Debug: Show Preview For Frontmost App`
- Task 8 fresh query results: Code 3 windows / 3 AX matched / elapsed 52 ms / SCK thumbnails 3 succeeded; Chrome 1 / 1 AX matched / 46 ms / SCK thumbnail succeeded; Typora 1 / 1 AX matched / 36 ms / SCK thumbnail succeeded; IINA 1 / 1 AX matched / 45 ms / SCK thumbnail succeeded; WPS Office 1 / 1 AX matched / 47 ms / SCK thumbnail succeeded.

## Space And Display Characterization

- Other normal Space result: blocked; no additional normal Space was prepared or switched to during Task 8. Required manual action: move one target app to another normal Space and run hover/query/activation there without enabling intentional cross-Space switching.
- Full-screen Space result: blocked; no full-screen Space was prepared or switched to during Task 8. Required manual action: place a target app in macOS full-screen Space, run hover/query/activation, and record whether the probe avoids intentional cross-Space switching.
- Stage Manager disabled result: current environment characterized as disabled/not set; `defaults read com.apple.WindowManager GloballyEnabled` returned not set at 2026-06-26 16:14 Asia/Shanghai, and normal-space query/activation checks did not crash or leave a stuck panel.
- Stage Manager enabled result: blocked; enabling Stage Manager is a user system setting change and was not performed by the implementer. Required manual action: enable Stage Manager, relaunch/run the probe, exercise hover/query/activation, then disable or restore Stage Manager as desired.
- Multiple display result: not available in current environment; `system_profiler SPDisplaysDataType` reported one online display, `Mi Monitor`, 6016x3384 physical / 3008x1692 UI looks like.
- Dock auto-hide disabled result: current environment characterized as disabled; `defaults read com.apple.dock autohide` returned `0` at 2026-06-26 16:14 Asia/Shanghai, and Task 8 hover/query/activation/Dock-restart checks did not crash or leave a stuck panel.
- Dock auto-hide enabled result: blocked; changing Dock auto-hide is a user system setting change and was not performed by the implementer. Required manual action: enable Dock auto-hide, run hover/leave/query checks, then restore the previous setting if desired.
- Left Dock result: blocked; changing Dock orientation is a user system setting change and was not performed by the implementer. Required manual action: move Dock to the left, run hover/leave/query checks, then restore the previous setting if desired.
- Right Dock result: blocked; changing Dock orientation is a user system setting change and was not performed by the implementer. Required manual action: move Dock to the right, run hover/leave/query checks, then restore the previous setting if desired.

## Thumbnail Capture

| App | Windows Tested | ScreenCaptureKit Success | CoreGraphics Fallback Success | Blank/Stale Observed | Notes |
| --- | --- | --- | --- | --- | --- |
| VS Code | 3 | 3/3 | not used | not observed in logs; visual render not inspected | Code query count 3; SCK thumbnails were 440x248 with elapsed 134/28/25 ms |
| Chrome | 1 | 1/1 | not used | not observed in logs; visual render not inspected | Google Chrome query count 1; SCK thumbnail was 440x248 with elapsed 26 ms |
| Typora | 1 | 1/1 | not used | not observed in logs; visual render not inspected | Typora query count 1; SCK thumbnail was 440x248 with elapsed 18 ms |
| IINA | 1 | 1/1 | not used | not observed in logs; visual render not inspected | IINA query count 1; SCK thumbnail was 440x248 with elapsed 19 ms |
| WPS | 1 | 1/1 | not used | not observed in logs; visual render not inspected | WPS Office query count 1; SCK thumbnail was 440x248 with elapsed 25 ms |

## Activation

| App | Windows Tested | AX Matched | Exact Raise Success | App Activation Fallback Observed | Notes |
| --- | --- | --- | --- | --- | --- |
| VS Code | 3 queried / first sorted activated | yes | yes | appActivate=true but exact raise succeeded | selected `01-model-init-online.ipynb — langchain`; System Events confirmed `frontWindow=01-model-init-online.ipynb — langchain` |
| Chrome | 1 | yes | yes | appActivate=true but exact raise succeeded | selected `LINUX DO - 新的理想型社区 - Google Chrome`; System Events confirmed `frontWindow=LINUX DO - 新的理想型社区 - Google Chrome` |
| Typora | 1 | yes | yes | appActivate=true but exact raise succeeded | selected `项目信息.md`; System Events confirmed `frontWindow=项目信息.md` |
| IINA | 1 | yes | yes | appActivate=true but exact raise succeeded | selected `harness-3x-finally.mp4  —  /Users/zong/Desktop/Work/AI演示`; System Events confirmed same front window title |
| WPS | 1 | yes | yes | appActivate=true but exact raise succeeded | selected `首页`; System Events confirmed `frontWindow=首页` |

- Task 8 fresh activation run time: 2026-06-26 16:17 Asia/Shanghai via DHP menu item `Debug: Activate First Frontmost Window`
- Task 8 fresh activation results: VS Code selected id `2445`, `hadAX=true raise=true appActivate=true`; Chrome selected id `240`, `hadAX=true raise=true appActivate=true`; Typora selected id `5247`, `hadAX=true raise=true appActivate=true`; IINA selected id `2837`, `hadAX=true raise=true appActivate=true`; WPS Office selected id `5396`, `hadAX=true raise=true appActivate=true`.

## Task 8 Automated Verification

- `swift test`: passed at 2026-06-26 16:14:25 Asia/Shanghai; 10 XCTest cases executed with 0 failures, Swift Testing reported 0 tests in 0 suites and passed.
- `swift build`: passed at 2026-06-26 16:14 Asia/Shanghai; debug build completed successfully.
- `Scripts/build_probe_app.sh`: passed at 2026-06-26 16:14 Asia/Shanghai; script built the debug executable, validated `build/DockHoverPreviewProbe.app/Contents/Info.plist`, replaced the existing signature, and printed `/Users/zong/Desktop/Project/zongMacTools/build/DockHoverPreviewProbe.app`.
