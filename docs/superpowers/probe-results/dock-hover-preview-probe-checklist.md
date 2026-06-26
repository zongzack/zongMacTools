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
- Screen Recording: granted for Task 5 final binary after packaging and reauthorization; logs at 2026-06-26 14:56:36 Asia/Shanghai showed `permissions.refresh accessibility=true screenRecording=true`, `orchestrator.start accessibility=true screenRecording=true`, and `dock.subscribed pid=35521`

## Dock Hover

| App | Bundle ID | PID Logged | Dock Frame Logged | 250 ms Mouse-Inside Validation | Leave Before Delay Suppressed |
| --- | --- | --- | --- | --- | --- |
| VS Code | `com.microsoft.VSCode` | `pid=761` | `frame=Optional((1036.9737548828125, 10.0, 38.371826171875, 50.371826171875))` | passed at 2026-06-26 14:27 Asia/Shanghai: `matches=true mouseInside=true frame=Optional((1017.964599609375, 10.0, 74.99951171875, 86.99951171875))` | not separately run |
| Chrome | `com.google.Chrome` | `pid=46872` | `frame=Optional((821.587646484375, 10.0, 36.51177978515625, 48.51171875))` | passed at 2026-06-26 14:27 Asia/Shanghai: `matches=true mouseInside=true frame=Optional((800.1087646484375, 10.0, 74.982177734375, 86.982177734375))` | not separately run |
| WPS | `com.kingsoft.wpsoffice.mac` | `pid=78012` | `frame=Optional((1107.90625, 10.0, 37.9429931640625, 49.9429931640625))` | passed at 2026-06-26 14:27 Asia/Shanghai: `matches=true mouseInside=true frame=Optional((1094.4002685546875, 10.0, 74.93896484375, 86.93896484375))` | passed: quick leave at 14:27:37.972 logged `dock.hover`, followed by `14:27:38.130 dock.hoverLost reason=mouseOutside ...` before any delayed success for that WPS hover |
| Typora | `abnerworks.Typora` | `pid=46874` | `frame=Optional((1145.800048828125, 10.0, 36.0, 48.0))` | passed at 2026-06-26 14:27 Asia/Shanghai: `matches=true mouseInside=true frame=Optional((1121.71923828125, 10.0, 74.9212646484375, 86.9212646484375))` | not separately run |
| IINA | `com.colliderli.iina` | `pid=36247` | `frame=Optional((1989.351806640625, 10.0, 36.7789306640625, 48.7789306640625))` | passed at 2026-06-26 14:27 Asia/Shanghai: `matches=true mouseInside=true frame=Optional((1967.94091796875, 10.0, 74.9757080078125, 86.9757080078125))` | not separately run |

## Dock Restart

- `killall Dock` recovery time: approximately 0.02 seconds from `dock.pidChanged` to resubscribe, within 10 seconds
- Recovery notes: passed after final hover verification; logs at 2026-06-26 14:28:07 Asia/Shanghai showed `dock.pidChanged old=Optional(6627) new=Optional(35521)`, `dock.stop` twice from the stop/start path, `dock.subscribed pid=35521`, and `dock.start`

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

## Space And Display Characterization

- Other normal Space result: not run
- Full-screen Space result: not run
- Stage Manager result: not run
- Multiple display result: not run; current environment remains the single-display setup recorded above
