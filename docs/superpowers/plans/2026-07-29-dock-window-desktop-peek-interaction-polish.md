# Dock Window Desktop Peek Interaction Polish Implementation Plan

**Goal:** Suppress desktop mirrors for single-window applications, show only a captured high-resolution mirror, and eliminate panel-animation overlap when selecting a window.

**Architecture:** `PreviewSessionController` owns the query result and therefore decides whether a session has enough cards to permit Desktop Peek. `WindowPeekCoordinator` continues to request a single high-resolution ScreenCaptureKit image but no longer presents thumbnail-derived coarse imagery. The preview-panel display gains an immediate dismissal path used exclusively before real-window activation.

**Tech Stack:** Swift 6, AppKit, SwiftUI, ScreenCaptureKit, XCTest.

---

### Task 1: Lock the interaction contract with regression tests

**Files:**
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/WindowPeekCoordinatorTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelControllerTests.swift`

- [ ] Add a session test that renders one previewable window, emits its hover-enter action, and asserts that the recording coordinator receives no desktop-peek hover request while the normal panel remains displayed.
- [ ] Replace the coarse-first coordinator expectation with a test that supplies a thumbnail, starts a capture, and asserts no overlay is shown until the capture completes; the first overlay event must be `.show(.highResolution)`.
- [ ] Add a primary-selection ordering test with a recording panel display and activation service. Assert the order is `peekStopped(.primarySelection)`, immediate panel dismissal, then activation.
- [ ] Add a concrete panel-controller test that its immediate dismissal removes the panel from screen without queuing a hide animation and clears the interactive frame.

Run: `swift test --filter 'PreviewSessionControllerTests|WindowPeekCoordinatorTests|PreviewPanelControllerTests'`

Expected: New tests initially fail because the coordinator accepts the single card and presents `.coarse`, and the panel display has no immediate dismissal API.

### Task 2: Gate Desktop Peek and remove the coarse mirror path

**Files:**
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewSessionController.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekCoordinator.swift`

- [ ] In `PreviewSessionController.handle(_:expectedGeneration:expectedSessionEpoch:)`, only forward `.hoverEntered` and `.hoverExited` to the coordinator when `currentWindowsByID.count >= 2`. A one-card session must leave the Dock panel, thumbnail loading, context menu, and primary selection behavior unchanged.
- [ ] In `WindowPeekCoordinator.hoverEntered`, preserve request creation, token validation, permissions, and single-flight scheduling, but do not call `overlay.show` with the thumbnail. Leave `currentQuality` unset until a high-resolution capture succeeds.
- [ ] In `coarseImageDidBecomeAvailable`, retain stale-event guards but do not present or update the desktop overlay. Card thumbnails remain owned by the preview panel.
- [ ] In `captureDidFinish`, make the accepted first image call `overlay.show(..., quality: .highResolution)` and keep the existing update path only for a future visible high-resolution replacement.

Run: `swift test --filter 'PreviewSessionControllerTests|WindowPeekCoordinatorTests'`

Expected: The single-window session creates no desktop capture request; a multi-window hover only displays the cropped ScreenCaptureKit image.

### Task 3: Dismiss the preview panel before activation

**Files:**
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelController.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewSessionController.swift`
- Modify fakes in: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`

- [ ] Add `hideImmediately(reason:)` to `PreviewPanelDisplaying`.
- [ ] Implement `PreviewPanelController.hideImmediately(reason:)` by invalidating the presentation generation, removing event monitors, cancelling any panel animation, clearing the logical frame, making the panel noninteractive, and calling `orderOut(nil)` synchronously.
- [ ] Extend `PreviewSessionController.hide` with an internal immediate-presentation option. Its state cleanup and coordinator stop behavior must remain identical to the animated path; only panel presentation changes.
- [ ] In `activate(windowID:)`, capture the target window first, then immediately hide the panel/session, and only then call `activationService.activate(window:)`. The existing handler still stops Desktop Peek with `.primarySelection` before this sequence.

Run: `swift test --filter 'PreviewSessionControllerTests|PreviewPanelControllerTests'`

Expected: Selecting a card has no pending panel-hide animation and does not overlap an overlay/panel transition with real-window activation.

### Task 4: Verify the integrated change

**Files:**
- Verify: all modified source and test files

- [ ] Run the focused Desktop Peek suites and confirm the new single-card, high-resolution-only, and selection-order tests are discovered.
- [ ] Run `swift test` and `swift build`.
- [ ] Run `git diff --check`, `git diff --cached --check`, and `git status --short`; confirm the pre-existing staged plan and design specification retain their staged status and are not modified by this work.

Run: `swift test && swift build && git diff --check && git diff --cached --check`

Expected: All commands exit successfully. Manual visual validation remains necessary for real Dock timing and ScreenCaptureKit latency.
