# Dock Window Desktop Peek Manual Checklist

Date: 2026-07-28

## Environment

| Field | Recorded value |
| --- | --- |
| Build artifact | `build/zongMacTools.app` |
| Bundle verification | Pass: Info.plist and ad-hoc signature verified by `Scripts/build_probe_app.sh` |
| Automated verification | Pass: focused capture, geometry, overlay, coordinator, lifecycle, panel, session, orchestrator, and settings XCTest suites; `swift test` completed 250 XCTest cases with 0 failures on 2026-07-28 |
| Screen topology | Single-display desktop environment expected; hardware inspection was not available while the Mac session was locked |
| Manual execution availability | Blocked: Computer Use reported that the Mac was locked and could not be automatically unlocked |
| Log command | `/usr/bin/log stream --info --style compact --predicate 'subsystem == "com.zong.zongMacTools"'` |

## Results

| Scenario | Expected result | Actual result / evidence | Status |
| --- | --- | --- | --- |
| Coarse then high-resolution mirror | Hovering each of three visually distinct VS Code project windows shows the thumbnail immediately, replaces it in the same frame with the high-resolution crop, dims the target display at alpha 0.22, and never activates a preview, mirror, or dimming panel. | Blocked before UI inspection because the Mac was locked. Automated evidence: `WindowPeekCoordinatorTests.testEnterShowsCoarseBeforeStartingHighResolutionCapture`, `WindowPeekOverlayControllerTests`, and the capability probe report. | blocked |
| Fast A-B-C hover sweep | No stale image, intermediate mirror, or residual dimming remains; only the latest pending target is captured after the active request returns. | Blocked before UI inspection. Automated evidence: broker FIFO/latest tests and `WindowPeekCoordinatorTests.testSwitchDropsStaleResultAndOnlyCapturesLatestPendingTarget`. | blocked |
| Primary selection | Overlay is removed before real-window activation; input focus and real window ordering do not change while hovering. | Blocked before UI inspection. Automated evidence: `PreviewSessionControllerTests.testPrimarySelectionStopsPeekBeforeActivation`. | blocked |
| Context menu | Overlay is removed before menu tracking; the existing right-click operations remain available. | Blocked before UI inspection. Automated evidence: context-menu preflight and session ordering tests. | blocked |
| Independent desktop-peek setting | Toggling the desktop-peek preference immediately stops or restores only the desktop mirror; the main hover setting does not overwrite its persisted value. | Blocked before UI inspection. Automated evidence: `SettingsStoreTests` and `ProbeOrchestratorPreviewTests.testOrchestratorStopStopsPeekWithoutChangingIndependentPeekSetting`. | blocked |
| Exit and lifecycle cleanup | Esc, hover loss, session replacement, Space changes, screen changes, target window destruction, and target app termination remove every overlay. | Blocked before UI inspection. Automated evidence: coordinator, session, and lifecycle observer suites. | blocked |
| Permission revocation | After a high-resolution mirror is visible, revoking Screen Recording hides it within one refresh interval. | Blocked before UI inspection. Automated evidence: `WindowPeekCoordinatorTests.testPermissionRefreshRevocationHidesAlreadyDisplayedHighResolutionImage`. | blocked |
| Dock and system interaction | Bottom/left/right Dock, auto-hide, light/dark mode, Reduce Motion, menu bar, and Notification Center interactions retain the existing preview behavior. | Blocked before UI inspection. Existing capability evidence covers normal and full-screen panel policy; this feature-specific pass remains unverified. | blocked |
| Multi-display coordinates | Primary/secondary arrangements, negative coordinates, mixed backing scale, separate Spaces, and cross-screen windows follow display-ID geometry pairing. | Blocked / not available: no multi-display hardware was available. Automated geometry tests cover display-ID pairing, mixed scale, crop direction, and returned-image pixel sizing. | blocked |
| Shared capture flight | Concurrent thumbnail work and A-B-C desktop peek produce one physical ScreenCaptureKit capture at a time, retain only C while A is active, and never cancel an entered capture. | Blocked before runtime log inspection. Automated evidence: `ScreenCaptureKitCaptureBrokerTests`. | blocked |
| Protected content | Blank protected-content captures are recorded as the system returns them; the app does not add pixel-level black-frame detection. | Blocked before UI inspection. No pixel-level detection is implemented by design. | blocked |

## Required Follow-up

Unlock the Mac, launch `build/zongMacTools.app`, authorize the expected local Accessibility and Screen Recording permissions if required after ad-hoc signing, and execute the scenarios above. Record `pass`, `pass with note`, or `fail` with the matching unified-log evidence. Retain `blocked / not available` for multiple-display checks until compatible hardware is connected.
