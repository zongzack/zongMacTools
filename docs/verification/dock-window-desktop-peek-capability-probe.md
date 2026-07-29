# Dock Window Desktop Peek Capability Probe

## Environment

| Field | Value |
| --- | --- |
| macOS build | macOS 26.5.2 (25F84) |
| Display count | One main display, 6,016 x 3,384 physical / 3,008 x 1,692 logical at 160 Hz |
| Displays have separate Spaces | Not available from the current non-interactive environment |
| Stage Manager | Not observed; requires manual UI validation |
| Dock position | Bottom |

## Probe Contract

`Scripts/Probes/window_peek_capability_probe.swift` is a standalone development probe. It uses only AppKit, SwiftUI, ScreenCaptureKit, CoreGraphics, and ApplicationServices. It does not use private API, write screenshots to disk, activate a target application, raise an AX window, or modify a target window's level.

The probe logs:

- Panel ordering, key/main state, mouse-event behavior, current frontmost application, and public `CGWindowListCopyWindowInfo` levels.
- Session epoch, hover sequence, and SwiftUI root-content refresh ticks for three cards.
- `SCWindow.frame`, AX frame, same-query `SCDisplay.frame`, matching `NSScreen.frame`, backing scale, and diagnostic-only `CGDisplayBounds`.
- A one-physical-call capture broker experiment that replaces pending desktop-peek B with latest desktop-peek C while thumbnail A is in flight.
- Capture cancellation timestamps for request start, `Task.cancel()`, async return, and the next request start. This records public API behavior only; production remains non-cancelling for entered calls.
- `AXObserverCreate`, destroyed-notification registration/removal status, and delivery on the main run loop.
- A self-owned, opt-in full-screen host. It uses the same panel configuration, verifies `isVisible` and `isOnActiveSpace`, then exercises active-Space, screen-parameter, and Escape teardown. It never activates, raises, closes, or changes the level of an external target application.

Run the probe with:

```bash
Scripts/Probes/run_window_peek_capability_probe.sh
```

## Results

| Check | Status | Evidence |
| --- | --- | --- |
| Compiles with public frameworks | Pass | `xcrun swiftc -parse-as-library` completed successfully on the current source with only AppKit, SwiftUI, ScreenCaptureKit, CoreGraphics, and ApplicationServices linked. The prescribed launcher also passes `zsh -n`. |
| SwiftUI card hover remains stable across content updates | Pass | Public CoreGraphics mouse moves crossed the three real card regions while the SwiftUI root tick advanced. The log recorded ordered pairs: `enter card=1 sequence=1 tick=1`, `exit card=1 sequence=2 tick=1`, `enter card=2 sequence=3 tick=1`, `exit card=2 sequence=4 tick=1`, `enter card=3 sequence=5 tick=1`, and `exit card=3 sequence=6 tick=2`. No update-induced repeat or persistent enter/exit gap occurred. |
| Three panels remain non-key/non-main and ordered below Dock in normal Space | Pass | Repeated `CGWindowListCopyWindowInfo` inspection reported visible levels dimming `1`, mirror `2`, and cards `3`. All reported `key=false` and `main=false`; dimming/mirror had `ignoresMouse=true`, cards had `ignoresMouse=false`, and the external frontmost app remained `com.termius-dmg.mac`. |
| Full-screen Space panel ordering, Dock, menu bar, and notification-center interaction | Pass with note | An opt-in self-owned host entered an actual full-screen Space (`fullScreen.entered styleMaskFullScreen=true`). The same configured panels then reported `visible=true`, `activeSpace=true`, `key=false`, and `main=false`. Their fixed levels remained `1 < 2 < 3`, below the public Dock level `20` and main-menu level `24`. The UI automation screenshot is scoped to the focused host window and omits sibling panels, so the public AppKit visibility/active-Space state is the authoritative evidence. The host necessarily became frontmost to enter its own full-screen Space; the normal-Space run separately proves the overlays themselves do not change an external frontmost application. |
| One physical screenshot at a time across A/B/C | Pass | `sck.broker.capture.started id=1 origin=thumbnail inFlight=1`; B became pending, then `sck.broker.capture.replaced old=2 new=3`; only after A returned did C start. No second `started` occurred before the preceding `finished`. |
| `SCDisplay.frame` to `NSScreen.frame` alignment | Pass with note | Single-display sample logged `displayID=2`, identical `SCDisplay.frame` and `NSScreen.frame` `(0, 0, 3008, 1692)`, scale `2.0`, and matching same-window ScreenCaptureKit/AX frames `(203, 169, 1883, 1286)`. `CGDisplayBounds` was logged only as a diagnostic. Multi-display hardware coverage remains unavailable and is not represented as a hardware pass. |
| Cancellation timing | Pass with note | `Task.cancel()` was recorded about 0.6 ms after the request began and `captureImage` returned about 48 ms later. The next broker request started only after the real return. This supports the production rule to stale tokens and never cancel an entered capture worker. |
| Space change, screen parameters, and Esc leave no residual panel | Pass with note | Entering and exiting the self-owned full-screen host delivered both `hidden.activeSpaceChanged` and `hidden.screenParametersChanged`; all three panels immediately logged `visible=false`, `key=false`, and `main=false`. The probe sent a public AppKit key-code-53 event through `NSApp.sendEvent`; the local monitor synchronously logged `hidden.escape` before `escape.automation.afterSendEvent`, where all three panels were already `visible=false`. The desktop controller's synthetic keyboard facility did not reach AppKit's local monitor, so this records the production-equivalent AppKit dispatch path rather than claiming a physical-key experiment. |
| AX destroyed callback reaches main run loop | Pass | For a self-owned ordinary test window, `AXObserverCreate` and `AXObserverAddNotification(kAXUIElementDestroyedNotification)` both returned `0`; after the test window closed, the probe logged `ax.destroyedNotification callbackThreadMain=true` and `ax.selfDestroyed callbackReceived=true`. The test did not close or alter an external window. |

## Decision Gate

Task 2 through Task 8 must not begin until the live results above establish the following:

1. Root-view refresh does not produce a persistent hover enter/exit gap. Otherwise use a lightweight `NSTrackingArea` bridge, not a delay.
2. The public non-key panels preserve `dimming < mirror < preview < Dock` in normal and full-screen Spaces without changing the frontmost app. Otherwise stop and return to design review.
3. `SCDisplay.frame` paired with `NSScreen.frame` by display ID gives aligned overlay geometry. `CGDisplayBounds` is diagnostic only; if it is required for alignment, stop and revise the coordinate contract.
4. One broker serializes both thumbnail and desktop-peek physical screenshot calls, retaining only latest queued desktop peek. Otherwise stop and revise the broker API.
5. Cancellation timing never changes the production rule: do not cancel an entered `captureImage`; stale its token and wait for its real return.
6. AX window destroyed notification registration and callback delivery work on the main run loop. Otherwise stop and revise the lifecycle acceptance criteria before implementation.

## Gate Decision

**Pass with notes. Task 2 through Task 8 may begin.**

The probe establishes the production decisions required by the plan:

1. Continue with SwiftUI `.onHover`; root-content updates did not produce a persistent event gap.
2. Use the public non-key panel subclass and fixed levels `dimming < mirror < preview`; the same configuration remains visible in a real full-screen Space and remains below the public Dock and menu-bar levels.
3. Pair same-query `SCDisplay.frame` and `NSScreen.frame` by display ID. `CGDisplayBounds` remains diagnostic-only.
4. Require one shared MainActor broker for thumbnail and desktop-peek requests, preserving only the latest queued desktop-peek request.
5. Never cancel a capture worker that has entered `SCScreenshotManager.captureImage`; invalidate its token and wait for the API call to return.
6. Install the public AX destroyed observer on the main run loop; callback delivery is available for a target whose owning process remains alive.

The current hardware has one display, so multi-display alignment remains a documented hardware limitation. Task 3 must supply the required display-placement and mixed-scale mathematical coverage; no multi-display physical result is claimed here.
