# Dock Preview Card Close Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move each preview card's application icon and title above the thumbnail, and add a hover-only left-click close control that removes only the card whose real window has actually closed.

**Architecture:** Keep the new close icon separate from the card's primary activation button and route it through a dedicated `PreviewPanelAction.closePreviewCard` intent. Reuse `WindowOperationService` for the public Accessibility close request, then remove the card only after a generalized, cancellable `kAXUIElementDestroyedNotification` subscription confirms destruction. The existing right-click menu keeps its current `windowOperation` route and behavior.

**Tech Stack:** Swift 6, AppKit, SwiftUI, ApplicationServices Accessibility APIs, XCTest, SwiftPM.

---

## Preconditions And File Map

The worktree already contains uncommitted changes to Desktop Peek activation handoff in `PreviewSessionController.swift`, `WindowPeekCoordinator.swift`, `WindowPeekOverlayController.swift`, and their tests. Preserve those changes. Before each task, inspect `git diff -- <file>` for every overlapping file and apply the task on top of the current content; do not reset, checkout, or revert those changes.

Task 3 shares `PreviewSessionController.swift`, `PreviewSessionControllerTests.swift`, and `ProbeOrchestratorPreviewTests.swift` with those pre-existing changes. Implement and verify Task 3 on top of them, but do **not** run a whole-file `git add` or create its feature commit until their owner has committed them or supplied a clean baseline. A whole-file stage would incorrectly include unrelated work. Tasks 1, 2, 4, and 5 may use their scoped commits when their listed files are clean.

| File | Responsibility in this feature |
| --- | --- |
| `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelModels.swift` | New close-icon intent, close-control render plan, fixed title metrics, and in-place card removal. |
| `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelView.swift` | Card title bar above thumbnail; sibling activation and close buttons; hover-only `xmark` rendering. |
| `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekLifecycleObserver.swift` | Generalized cancellable multi-window `AXObserver` destruction subscriptions, while retaining the existing Desktop Peek lifecycle adapter. |
| `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewSessionController.swift` | Close request state, generation-safe destruction handling, incremental model update, and pending-subscription cleanup. |
| `Sources/DockHoverPreviewProbe/App/AppDelegate.swift` | Construct one shared destruction observer and forward application termination to the preview session. |
| `Tests/DockHoverPreviewProbeTests/PreviewPanelViewRenderingTests.swift` | Pure close-control and title-metric tests. |
| `Tests/DockHoverPreviewProbeTests/WindowPeekLifecycleObserverTests.swift` | Multi-subscription observer ownership, cancellation, and Desktop Peek adapter regressions. |
| `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift` | Close-card routing, confirmed removal, stale callback, fallback, and cleanup tests. |
| `docs/verification/dock-hover-preview-p3-window-actions-manual-checklist.md` | Manual acceptance steps for the left-click card close control. |

### Task 1: Lock The Card-Close Model Contract

**Files:**
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelViewRenderingTests.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelModels.swift`

- [ ] **Step 1: Add failing tests for close control state, dispatch, title geometry, and model removal.**

Add these tests to `PreviewPanelViewRenderingTests`:

```swift
func testCloseControlPlanShowsOnlyDuringHoverAndPreservesAvailability() {
    let enabledCard = makeCard()
    let disabledCard = makeCard(operationMenu: .init(
        activate: .enabled(.activate),
        hideApplication: .enabled(.hideApplication),
        closeWindow: .disabled(.closeWindow, reason: "Missing close button"),
        minimizeWindow: .enabled(.minimizeWindow),
        environmentDescription: "Screen: Built-in Display"
    ))

    XCTAssertEqual(
        PreviewCardCloseControlPlan.plan(for: enabledCard, isHovered: false),
        .init(isVisible: false, isEnabled: true)
    )
    XCTAssertEqual(
        PreviewCardCloseControlPlan.plan(for: enabledCard, isHovered: true),
        .init(isVisible: true, isEnabled: true)
    )
    XCTAssertEqual(
        PreviewCardCloseControlPlan.plan(for: disabledCard, isHovered: true),
        .init(isVisible: true, isEnabled: false)
    )
}

func testCloseActionDispatcherEmitsDedicatedCloseIntentOnlyWhenEnabled() {
    let id = PreviewWindowID(pid: 100, windowID: 7)
    let enabledCard = makeCard(id: id)
    let disabledCard = makeCard(id: id, operationMenu: .init(
        activate: .enabled(.activate),
        hideApplication: .enabled(.hideApplication),
        closeWindow: .disabled(.closeWindow, reason: "Missing close button"),
        minimizeWindow: .enabled(.minimizeWindow),
        environmentDescription: "Screen: Built-in Display"
    ))
    var actions: [PreviewPanelAction] = []

    PreviewCardCloseActionDispatcher.dispatch(for: enabledCard) { actions.append($0) }
    PreviewCardCloseActionDispatcher.dispatch(for: disabledCard) { actions.append($0) }

    XCTAssertEqual(actions, [.closePreviewCard(id)])
}

func testTitleMetricsReserveTheCloseControlWithoutChangingCardGeometry() {
    XCTAssertEqual(PreviewPanelMetrics.cardWidth, 232, accuracy: 0.001)
    XCTAssertEqual(PreviewPanelMetrics.cardHeight, 172, accuracy: 0.001)
    XCTAssertEqual(
        PreviewPanelMetrics.titleTextWidth,
        PreviewPanelMetrics.titleRowWidth
            - PreviewPanelMetrics.iconSize
            - PreviewPanelMetrics.titleIconSpacing
            - PreviewPanelMetrics.closeButtonSpacing
            - PreviewPanelMetrics.closeButtonSize,
        accuracy: 0.001
    )
}

func testRemovingCardKeepsOtherCardsAndReturnsWhetherModelChanged() {
    let first = makeCard(id: .init(pid: 100, windowID: 1))
    let second = makeCard(id: .init(pid: 100, windowID: 2))
    var model = PreviewPanelViewModel(appName: "Code", cards: [first, second], maxCardCount: 8)

    XCTAssertTrue(model.removeCard(for: first.id))
    XCTAssertEqual(model.cards.map(\.id), [second.id])
    XCTAssertFalse(model.removeCard(for: first.id))
}
```

- [ ] **Step 2: Run the focused suite and confirm that the new API is absent.**

Run:

```bash
swift test --filter PreviewPanelViewRenderingTests
```

Expected: the compilation fails because `PreviewCardCloseControlPlan`, `PreviewCardCloseActionDispatcher`, `.closePreviewCard`, `closeButtonSize`, `closeButtonSpacing`, and `removeCard(for:)` do not exist.

- [ ] **Step 3: Implement only the model and dispatch contract.**

In `PreviewPanelModels.swift`, extend the action enum and add the pure plan and dispatcher:

```swift
enum PreviewPanelAction: Equatable, Sendable {
    case primarySelect(PreviewWindowID)
    case closePreviewCard(PreviewWindowID)
    case windowOperation(PreviewWindowID, PreviewWindowOperation)
    case contextMenuWillOpen(PreviewWindowID)
    case contextMenuBegan(PreviewWindowID)
    case contextMenuEnded(PreviewWindowID)
    case hoverEntered(PreviewWindowID, sessionEpoch: UInt64, sequence: UInt64)
    case hoverExited(PreviewWindowID, sessionEpoch: UInt64, sequence: UInt64)
}

struct PreviewCardCloseControlPlan: Equatable {
    let isVisible: Bool
    let isEnabled: Bool

    static func plan(for card: PreviewCardViewModel, isHovered: Bool) -> Self {
        Self(
            isVisible: isHovered,
            isEnabled: card.operationMenu.closeWindow.isEnabled
        )
    }
}

enum PreviewCardCloseActionDispatcher {
    static func dispatch(
        for card: PreviewCardViewModel,
        onAction: (PreviewPanelAction) -> Void
    ) {
        guard card.operationMenu.closeWindow.isEnabled else { return }
        onAction(.closePreviewCard(card.id))
    }
}
```

Add the incremental mutation to `PreviewPanelViewModel`:

```swift
@discardableResult
mutating func removeCard(for id: PreviewWindowID) -> Bool {
    guard let index = cards.firstIndex(where: { $0.id == id }) else { return false }
    cards.remove(at: index)
    return true
}
```

Keep existing metrics unchanged except for the close slot and its title deduction:

```swift
static let closeButtonSize: CGFloat = 22
static let closeButtonSpacing: CGFloat = 4
static let titleTextWidth: CGFloat = titleRowWidth
    - iconSize
    - titleIconSpacing
    - closeButtonSpacing
    - closeButtonSize
```

- [ ] **Step 4: Run the focused suite and verify the contract passes.**

Run:

```bash
swift test --filter PreviewPanelViewRenderingTests
```

Expected: all `PreviewPanelViewRenderingTests` pass, including the existing right-click menu tests.

- [ ] **Step 5: Commit the model contract.**

Run:

```bash
git add Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelModels.swift
git add Tests/DockHoverPreviewProbeTests/PreviewPanelViewRenderingTests.swift
git commit -m "test: specify preview card close contract"
```

Expected: the commit contains only the two files above and does not stage the pre-existing Desktop Peek changes.

### Task 2: Generalize The Existing Window-Destroyed Observer

**Files:**
- Modify: `Tests/DockHoverPreviewProbeTests/WindowPeekLifecycleObserverTests.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekLifecycleObserver.swift`

- [ ] **Step 1: Add failing tests for independent destruction subscriptions.**

Replace the single-target recording fake with a multi-subscription fake and add these tests:

```swift
func testMultipleDestroyedSubscriptionsDeliverOnlyToTheirMatchingWindow() {
    let observer = RecordingWindowDestroyedObserver()
    let first = PreviewWindowID(pid: 100, windowID: 1)
    let second = PreviewWindowID(pid: 100, windowID: 2)
    var destroyed: [PreviewWindowID] = []

    _ = observer.observeWindow(id: first, element: AXUIElementCreateApplication(first.pid)) {
        destroyed.append($0)
    }
    _ = observer.observeWindow(id: second, element: AXUIElementCreateApplication(second.pid)) {
        destroyed.append($0)
    }
    observer.emitDestroyed(id: second)
    observer.emitDestroyed(id: first)

    XCTAssertEqual(destroyed, [second, first])
}

func testCancellingDestroyedSubscriptionSuppressesItsLateCallback() {
    let observer = RecordingWindowDestroyedObserver()
    let id = PreviewWindowID(pid: 100, windowID: 1)
    var destroyed: [PreviewWindowID] = []

    let token = try! XCTUnwrap(observer.observeWindow(id: id, element: AXUIElementCreateApplication(id.pid)) {
        destroyed.append($0)
    })
    token.cancel()
    observer.emitDestroyed(id: id)

    XCTAssertEqual(destroyed, [])
}
```

Define the test fake in the same test file so it exercises the public contract rather than a production implementation detail:

```swift
@MainActor
private final class RecordingWindowDestroyedObserver: WindowDestroyedObserving {
    private var handlers: [UUID: (PreviewWindowID, @MainActor (PreviewWindowID) -> Void)] = [:]

    func observeWindow(
        id: PreviewWindowID,
        element: AXUIElement?,
        onDestroyed: @escaping @MainActor (PreviewWindowID) -> Void
    ) -> (any WindowDestroyedObservation)? {
        guard element != nil else { return nil }
        let tokenID = UUID()
        handlers[tokenID] = (id, onDestroyed)
        return Token { [weak self] in self?.handlers.removeValue(forKey: tokenID) }
    }

    func emitDestroyed(id: PreviewWindowID) {
        let callbacks = handlers.values
            .filter { $0.0 == id }
        callbacks.forEach { $0.1(id) }
    }

    @MainActor
    private final class Token: WindowDestroyedObservation {
        private var onCancel: (() -> Void)?

        init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }

        func cancel() {
            onCancel?()
            onCancel = nil
        }
    }
}
```

Keep and adapt the existing lifecycle-observer tests so `observeTargetWindow` replaces only its own Desktop Peek token; a pending close-card subscription must not be cancelled by a Desktop Peek target change.

- [ ] **Step 2: Run the observer tests and confirm the multi-subscription protocol is missing.**

Run:

```bash
swift test --filter WindowPeekLifecycleObserverTests
```

Expected: compilation fails because `WindowDestroyedObserving`, `WindowDestroyedObservation`, and `observeWindow(id:element:onDestroyed:)` do not exist.

- [ ] **Step 3: Replace the single-target subscriber implementation with cancellable subscriptions.**

Define the shared protocol at the top of `WindowPeekLifecycleObserver.swift`:

```swift
@MainActor
protocol WindowDestroyedObservation: AnyObject {
    func cancel()
}

@MainActor
protocol WindowDestroyedObserving: AnyObject {
    @discardableResult
    func observeWindow(
        id: PreviewWindowID,
        element: AXUIElement?,
        onDestroyed: @escaping @MainActor (PreviewWindowID) -> Void
    ) -> (any WindowDestroyedObservation)?
}
```

Rename `SystemWindowPeekTargetDestroyedSubscriber` to `SystemWindowDestroyedObserver` and make it conform to `WindowDestroyedObserving`. Its `observeWindow` implementation must:

```swift
guard let element else {
    logger.warning("peek.lifecycle.destroyObservationUnavailable id=\(id.windowID) code=noElement")
    return nil
}

var axObserver: AXObserver?
let createResult = AXObserverCreate(id.pid, windowDestroyedCallback, &axObserver)
guard createResult == .success, let axObserver else {
    logger.warning("peek.lifecycle.destroyObservationUnavailable id=\(id.windowID) code=\(createResult.rawValue)")
    return nil
}
```

Create one reference-type token per subscription. The token retains the `AXObserver`, its run-loop source, expected `AXUIElement`, ID, and callback. Pass the token itself as the `AXObserverAddNotification` refcon, add its source to `CFRunLoopGetMain()` in `.commonModes`, and make `cancel()` idempotently remove the notification/source and unregister itself from the observer registry. The C callback must call the token only when `CFEqual(expectedElement, callbackElement)` succeeds.

Refactor `WindowPeekLifecycleObserver` to receive `any WindowDestroyedObserving`, keep one optional Desktop Peek token, and implement `observeTargetWindow` as:

```swift
private var targetDestroyedObservation: (any WindowDestroyedObservation)?

func observeTargetWindow(id: PreviewWindowID?, element: AXUIElement?) {
    targetDestroyedObservation?.cancel()
    targetDestroyedObservation = nil
    guard let id else { return }
    targetDestroyedObservation = destroyedObserver.observeWindow(id: id, element: element) { [weak self] id in
        self?.emit(.targetWindowDestroyed(id))
    }
}
```

`stop()` must cancel its Desktop Peek token, then remove the existing workspace and application notification handlers. Do not change the `WindowPeekLifecycleEvent` cases or the public behavior of active-space/screen/application lifecycle notifications.

- [ ] **Step 4: Run the observer tests and the Desktop Peek coordinator tests.**

Run:

```bash
swift test --filter 'WindowPeekLifecycleObserverTests|WindowPeekCoordinatorTests'
```

Expected: the new independent subscription tests pass and existing Desktop Peek destroyed-target tests retain their behavior.

- [ ] **Step 5: Commit the generalized observer.**

Run:

```bash
git add Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/WindowPeekLifecycleObserver.swift
git add Tests/DockHoverPreviewProbeTests/WindowPeekLifecycleObserverTests.swift
git commit -m "refactor: support multiple window destruction observers"
```

Expected: the commit contains only the observer implementation and observer tests.

### Task 3: Remove A Card Only After Its Window Is Destroyed

**Files:**
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewSessionController.swift`
- Modify: `Sources/DockHoverPreviewProbe/App/AppDelegate.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/ProbeOrchestratorPreviewTests.swift`

- [ ] **Step 1: Extend the session harness with a destruction-observer fake and add failing close-card tests.**

Add `@preconcurrency import ApplicationServices` beside the existing imports in `PreviewSessionControllerTests.swift`. The close-confirmation tests must use a non-`nil` AX element: the proposed observer fake intentionally declines `nil` elements, while the existing general-purpose `makeWindow(id:)` helper currently creates `axElement: nil`.

Keep existing tests unchanged by extending the helper's signature and adding a close-specific wrapper:

```swift
private func makeWindow(
    id: CGWindowID,
    captureFrame: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600),
    processID: pid_t = NSRunningApplication.current.processIdentifier,
    axElement: AXUIElement? = nil
) -> PreviewWindow {
    PreviewWindow(
        id: PreviewWindowID(pid: processID, windowID: id),
        cgWindowID: id,
        app: NSRunningApplication.current,
        title: "Window \(id)",
        captureFrame: captureFrame,
        axElement: axElement,
        appIcon: NSImage(size: NSSize(width: 32, height: 32)),
        thumbnailSource: nil,
        desktopPeekCaptureSource: nil,
        desktopPeekEligible: false
    )
}

private func makeCloseObservableWindow(
    id: CGWindowID,
    processID: pid_t = NSRunningApplication.current.processIdentifier
) -> PreviewWindow {
    makeWindow(
        id: id,
        processID: processID,
        axElement: AXUIElementCreateApplication(processID)
    )
}
```

Add `let windowDestroyedObserver = FakeWindowDestroyedObserver()` to `PreviewSessionHarness`, pass it to the controller initializer, and add tests with these assertions:

```swift
func testClosePreviewCardWaitsForDestroyedNotificationBeforeRemovingCard() async {
    let first = makeCloseObservableWindow(id: 1)
    let second = makeCloseObservableWindow(id: 2)
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [first, second])
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    harness.display.actionHandler?(.closePreviewCard(first.id))

    XCTAssertEqual(harness.windowOperationService.performedOperations, [.closeWindow])
    XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [first.id, second.id])
    XCTAssertEqual(harness.display.hideReasons, [])
}

func testDestroyedCloseTargetRemovesOnlyThatCardAndUpdatesPanel() async {
    let first = makeCloseObservableWindow(id: 1)
    let second = makeCloseObservableWindow(id: 2)
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [first, second])
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
    let updatesBeforeClose = harness.display.updateCount

    harness.display.actionHandler?(.closePreviewCard(first.id))
    harness.windowDestroyedObserver.emitDestroyed(id: first.id)

    XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [second.id])
    XCTAssertEqual(harness.display.updateCount, updatesBeforeClose + 1)
    XCTAssertEqual(harness.display.hideReasons, [])
}

func testDestroyedLastCloseTargetHidesPanel() async {
    let window = makeCloseObservableWindow(id: 1)
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    harness.display.actionHandler?(.closePreviewCard(window.id))
    harness.windowDestroyedObserver.emitDestroyed(id: window.id)

    XCTAssertEqual(harness.display.hideReasons, ["closePreviewCard.lastCardClosed"])
}

func testClosePreviewCardFailureCancelsObservationAndKeepsCard() async {
    let window = makeCloseObservableWindow(id: 1)
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
    harness.windowOperationService.results[.closeWindow] = .init(
        operation: .closeWindow,
        windowID: window.id,
        requestSucceeded: false,
        failure: .init(reason: .actionFailed, stage: .pressButton, axErrorCode: nil)
    )

    let updatesBeforeClose = harness.display.updateCount
    harness.display.actionHandler?(.closePreviewCard(window.id))
    harness.windowDestroyedObserver.emitDestroyed(id: window.id)

    XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [window.id])
    XCTAssertEqual(harness.display.hideReasons, [])
    XCTAssertEqual(harness.display.updateCount, updatesBeforeClose)
    XCTAssertEqual(harness.windowDestroyedObserver.activeIDs, Set<PreviewWindowID>())
}
```

Add a separate observer-unavailable test that leaves the fake service successful, and verify the required next-hover reconciliation rather than only the immediate non-removal state:

```swift
func testClosePreviewCardStillRequestsCloseWhenDestroyedObservationIsUnavailable() async {
    let window = makeCloseObservableWindow(id: 1)
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
    harness.windowDestroyedObserver.unavailableIDs.insert(window.id)
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    harness.display.actionHandler?(.closePreviewCard(window.id))
    harness.display.actionHandler?(.closePreviewCard(window.id))

    XCTAssertEqual(harness.windowOperationService.performedOperations, [.closeWindow])
    XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [window.id])
    XCTAssertEqual(harness.display.hideReasons, [])
}

func testUnavailableDestroyedObservationReconcilesOnNextDockHover() async {
    let first = makeCloseObservableWindow(id: 1)
    let second = makeCloseObservableWindow(id: 2)
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [first, second])
    harness.windowDestroyedObserver.unavailableIDs.insert(first.id)
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    harness.display.actionHandler?(.closePreviewCard(first.id))
    XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [first.id, second.id])

    // The next query represents the real window list after the close request succeeded.
    harness.queryService.windows = [second]
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [second.id])
    XCTAssertEqual(harness.windowDestroyedObserver.activeIDs, Set<PreviewWindowID>())
}

func testClosingMultipleCardsKeepsRequestsAndObservationsIndependent() async {
    let first = makeCloseObservableWindow(id: 1)
    let second = makeCloseObservableWindow(id: 2)
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [first, second])
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    harness.display.actionHandler?(.closePreviewCard(first.id))
    harness.display.actionHandler?(.closePreviewCard(first.id))
    harness.display.actionHandler?(.closePreviewCard(second.id))

    XCTAssertEqual(harness.windowOperationService.performedOperations, [.closeWindow, .closeWindow])
    XCTAssertEqual(harness.windowOperationService.performedWindowIDs, [first.id, second.id])
    XCTAssertEqual(harness.windowDestroyedObserver.activeIDs, Set([first.id, second.id]))

    harness.windowDestroyedObserver.emitDestroyed(id: first.id)

    XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [second.id])
    XCTAssertEqual(harness.windowDestroyedObserver.activeIDs, Set([second.id]))
    XCTAssertEqual(harness.display.hideReasons, [])

    harness.windowDestroyedObserver.emitDestroyed(id: second.id)

    XCTAssertEqual(harness.display.hideReasons, ["closePreviewCard.lastCardClosed"])
    XCTAssertEqual(harness.windowDestroyedObserver.activeIDs, Set<PreviewWindowID>())
}
```

Extend `FakeWindowOperationService` so tests can prove the close request targets the card that was clicked:

```swift
private(set) var performedOperations: [PreviewWindowOperation] = []
private(set) var performedWindowIDs: [PreviewWindowID] = []

func perform(_ operation: PreviewWindowOperation, on window: PreviewWindow) -> WindowOperationResult {
    performedOperations.append(operation)
    performedWindowIDs.append(window.id)
    return results[operation] ?? WindowOperationResult(
        operation: operation,
        windowID: window.id,
        requestSucceeded: true,
        failure: nil
    )
}
```

Define the test fake beside the other `PreviewSessionControllerTests` fakes:

```swift
@MainActor
private final class FakeWindowDestroyedObserver: WindowDestroyedObserving {
    var unavailableIDs: Set<PreviewWindowID> = []
    private var handlers: [UUID: (PreviewWindowID, @MainActor (PreviewWindowID) -> Void)] = [:]

    var activeIDs: Set<PreviewWindowID> {
        Set(handlers.values.map { $0.0 })
    }

    func observeWindow(
        id: PreviewWindowID,
        element: AXUIElement?,
        onDestroyed: @escaping @MainActor (PreviewWindowID) -> Void
    ) -> (any WindowDestroyedObservation)? {
        guard element != nil, !unavailableIDs.contains(id) else { return nil }
        let tokenID = UUID()
        handlers[tokenID] = (id, onDestroyed)
        return Token { [weak self] in self?.handlers.removeValue(forKey: tokenID) }
    }

    func emitDestroyed(id: PreviewWindowID) {
        let callbacks = handlers.values.filter { $0.0 == id }
        callbacks.forEach { $0.1(id) }
    }

    @MainActor
    private final class Token: WindowDestroyedObservation {
        private var onCancel: (() -> Void)?

        init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }

        func cancel() {
            onCancel?()
            onCancel = nil
        }
    }
}
```

Also add these explicit regression tests. Each begins with a `makeCloseObservableWindow` so it validates cancellation of a real registered fake token, not the observer-unavailable fallback:

```swift
func testHideCancelsCloseObservationAndDropsItsLateCallback() async {
    let window = makeCloseObservableWindow(id: 1)
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    harness.display.actionHandler?(.closePreviewCard(window.id))
    harness.controller.hide(reason: "test")
    harness.windowDestroyedObserver.emitDestroyed(id: window.id)

    XCTAssertEqual(harness.windowDestroyedObserver.activeIDs, Set<PreviewWindowID>())
    XCTAssertEqual(harness.display.hideReasons, ["test"])
}

func testNewSessionCancelsOldCloseObservationBeforeReusingTheSameWindowID() async {
    let stale = makeCloseObservableWindow(id: 1)
    let current = makeCloseObservableWindow(id: 1)
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [stale])
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    harness.display.actionHandler?(.closePreviewCard(stale.id))
    harness.queryService.windows = [current]
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
    harness.windowDestroyedObserver.emitDestroyed(id: stale.id)

    XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [current.id])
    XCTAssertEqual(harness.windowDestroyedObserver.activeIDs, Set<PreviewWindowID>())
}

func testTargetApplicationTerminationCancelsOnlyMatchingCloseObservation() async {
    let terminated = makeCloseObservableWindow(id: 1, processID: 10_001)
    let surviving = makeCloseObservableWindow(id: 2, processID: 10_002)
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [terminated, surviving])
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    harness.display.actionHandler?(.closePreviewCard(terminated.id))
    harness.display.actionHandler?(.closePreviewCard(surviving.id))
    harness.controller.targetApplicationTerminated(pid: terminated.id.pid)

    XCTAssertEqual(harness.windowDestroyedObserver.activeIDs, Set([surviving.id]))

    harness.windowDestroyedObserver.emitDestroyed(id: terminated.id)
    XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [terminated.id, surviving.id])

    harness.windowDestroyedObserver.emitDestroyed(id: surviving.id)
    XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [terminated.id])
}

func testRightClickCloseWindowKeepsExistingHideOnRequestSuccessPath() async {
    let window = makeCloseObservableWindow(id: 1)
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    harness.display.actionHandler?(.windowOperation(window.id, .closeWindow))

    XCTAssertEqual(harness.windowOperationService.performedOperations, [.closeWindow])
    XCTAssertEqual(harness.windowOperationService.performedWindowIDs, [window.id])
    XCTAssertEqual(harness.display.hideReasons, ["windowOperation.closeWindow"])
}
```

The final test locks the existing right-click close semantics: it must continue to hide after a successful close request and must not enter the new notification-confirmed card-removal route.

- [ ] **Step 2: Run the focused suite and confirm the close-card route does not exist.**

Run:

```bash
swift test --filter PreviewSessionControllerTests
```

Expected: the new tests fail because the controller has no destruction-observer dependency or `.closePreviewCard` handler.

- [ ] **Step 3: Inject the observer and implement generation-safe close state.**

Add this dependency and pending state to `PreviewSessionController`:

```swift
private let windowDestroyedObserver: any WindowDestroyedObserving

private struct PendingClose {
    let generation: Int
    let sessionEpoch: UInt64
    let observation: (any WindowDestroyedObservation)?
}

private var pendingCloses: [PreviewWindowID: PendingClose] = [:]
```

Add a required initializer argument immediately after `windowPeekCoordinator`:

```swift
windowDestroyedObserver: any WindowDestroyedObserving,
```

Route the new action without changing the existing context-menu branch:

```swift
case let .closePreviewCard(id):
    closePreviewCard(windowID: id, expectedGeneration: expectedGeneration, expectedSessionEpoch: expectedSessionEpoch)
case let .windowOperation(id, operation):
    performWindowOperation(operation, windowID: id)
```

Implement the close request in this order:

```swift
private func closePreviewCard(
    windowID: PreviewWindowID,
    expectedGeneration: Int,
    expectedSessionEpoch: UInt64
) {
    guard let window = currentWindowsByID[windowID] else {
        logger.warning("closePreviewCard.missingWindow id=\(windowID.windowID)")
        return
    }
    guard currentModel?.cards.first(where: { $0.id == windowID })?.operationMenu.closeWindow.isEnabled == true else {
        logger.info("closePreviewCard.unavailable id=\(windowID.windowID)")
        return
    }
    guard pendingCloses[windowID] == nil else {
        logger.info("closePreviewCard.duplicate id=\(windowID.windowID)")
        return
    }

    let observation = windowDestroyedObserver.observeWindow(id: windowID, element: window.axElement) { [weak self] id in
        self?.confirmedClosedWindow(
            id,
            expectedGeneration: expectedGeneration,
            expectedSessionEpoch: expectedSessionEpoch
        )
    }
    pendingCloses[windowID] = .init(
        generation: expectedGeneration,
        sessionEpoch: expectedSessionEpoch,
        observation: observation
    )

    let result = windowOperationService.perform(.closeWindow, on: window)
    guard !result.requestSucceeded else { return }
    cancelPendingClose(for: windowID)
    logger.warning("closePreviewCard.requestFailed id=\(windowID.windowID)")
}
```

`confirmedClosedWindow` must first validate `isCurrent(expectedGeneration, sessionEpoch:)` and the stored `PendingClose` generation/epoch. It then cancels/removes the token when present, removes the matching entry from `currentWindowsByID`, calls `windowPeekCoordinator.targetWindowDestroyed(id)`, mutates `currentModel` with `removeCard(for:)`, and either calls `panelDisplay.update(model:)` or `hide(reason: "closePreviewCard.lastCardClosed")` when no cards remain.

Add `cancelPendingClose(for:)`, `cancelAllPendingCloses()`, and `targetApplicationTerminated(pid:)`. `cancelPendingClose(for:)` must remove the dictionary entry first and then call its optional token's `cancel()`. Call `cancelAllPendingCloses()` at the beginning of `showPreview` before replacing a session and in `hide`; `targetApplicationTerminated(pid:)` must cancel only dictionary entries whose `PreviewWindowID.pid` matches. Keeping a pending entry even when observation setup returns `nil` is required to suppress duplicate close clicks until the panel is refreshed or hidden.

Do not alter `performWindowOperation`; preserving it is what keeps the existing right-click menu behavior unchanged.

Update `AppDelegate` composition to create one shared `SystemWindowDestroyedObserver`, inject it into both `WindowPeekLifecycleObserver` and `PreviewSessionController`, and forward the existing lifecycle event to both consumers:

```swift
case let .applicationTerminated(pid):
    coordinator?.targetApplicationTerminated(pid: pid)
    previewSessionController?.targetApplicationTerminated(pid: pid)
```

Update each `PreviewSessionController` test construction, including `ProbeOrchestratorPreviewTests`, to pass a no-op or recording fake observer explicitly.

- [ ] **Step 4: Run session and orchestrator regressions.**

Run:

```bash
swift test --filter 'PreviewSessionControllerTests|ProbeOrchestratorPreviewTests'
```

Expected: confirmed closes update only the matching card, cancellation/failure paths keep the model untouched, and existing primary-selection handoff tests continue to pass with the worktree's current Desktop Peek changes.

- [ ] **Step 5: Record the verified Task 3 boundary; defer its commit until overlapping work is clean.**

Run:

```bash
git diff -- Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewSessionController.swift
git diff -- Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift
git diff -- Tests/DockHoverPreviewProbeTests/ProbeOrchestratorPreviewTests.swift
```

Expected: the diff contains both the pre-existing activation-handoff work and this task's close-confirmation work. Do not stage these whole files. Once the owner has committed the pre-existing changes or supplied a clean baseline, stage only the Task 3 files, run `git diff --cached --check`, and commit with `feat: remove confirmed closed preview card`.

### Task 4: Render The Hover-Only Close Control Above The Thumbnail

**Files:**
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelViewRenderingTests.swift`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelView.swift`

- [ ] **Step 1: Keep the pure layout-state assertions as a regression guard during SwiftUI work.**

Extend `PreviewPanelViewRenderingTests` with a test that exercises the state consumed by the view and confirms the title slot is stable across hover:

```swift
func testCloseControlKeepsTheSameTitleWidthAcrossHoverStates() {
    let card = makeCard()
    let resting = PreviewCardCloseControlPlan.plan(for: card, isHovered: false)
    let hovered = PreviewCardCloseControlPlan.plan(for: card, isHovered: true)

    XCTAssertFalse(resting.isVisible)
    XCTAssertTrue(hovered.isVisible)
    XCTAssertEqual(PreviewPanelMetrics.titleTextWidth, 170, accuracy: 0.001)
    XCTAssertEqual(PreviewPanelMetrics.cardHeight, 172, accuracy: 0.001)
}
```

- [ ] **Step 2: Run the view-rendering suite before implementation.**

Run:

```bash
swift test --filter PreviewPanelViewRenderingTests
```

Expected: the pure layout contract added in Task 1 continues to pass. This is intentionally a regression check, not a red test for the forthcoming SwiftUI hierarchy change: Task 1 already owns the red-green contract for state, dispatch, and geometry. SwiftUI hierarchy order has no supported unit-test introspection in this target, so the interaction and visual constraints must be manually checked immediately after Step 3 and again in the final Task 5 acceptance pass.

- [ ] **Step 3: Refactor `PreviewCardView` into sibling buttons and reorder its content.**

Replace the current outer `Button` with a `ZStack(alignment: .topTrailing)` containing two sibling buttons:

```swift
ZStack(alignment: .topTrailing) {
    Button {
        onAction(.primarySelect(card.id))
    } label: {
        VStack(alignment: .leading, spacing: PreviewPanelMetrics.cardContentSpacing) {
            titleBar
            thumbnailView
        }
        .padding(PreviewPanelMetrics.cardPadding)
        .frame(
            width: PreviewPanelMetrics.cardWidth,
            height: PreviewPanelMetrics.cardHeight,
            alignment: .topLeading
        )
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: PreviewPanelMetrics.cardCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(isHovered ? style.cardHoverBorderOpacity : style.cardBorderOpacity), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: PreviewPanelMetrics.cardCornerRadius, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(card.accessibilityLabel)
    .help(card.title)

    closeButton
}
.onHover { isInside in
    isHovered = isInside
    hoverIntentRelay.emit(isInside: isInside)
}
```

Implement `titleBar` with a permanently reserved close slot:

```swift
private var titleBar: some View {
    HStack(spacing: 0) {
        Image(nsImage: card.appIcon)
            .resizable()
            .scaledToFit()
            .frame(width: PreviewPanelMetrics.iconSize, height: PreviewPanelMetrics.iconSize)
            .padding(.trailing, PreviewPanelMetrics.titleIconSpacing)

        Text(card.title)
            .font(.caption)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: PreviewPanelMetrics.titleTextWidth, alignment: .leading)
            .padding(.trailing, PreviewPanelMetrics.closeButtonSpacing)

        Color.clear.frame(
            width: PreviewPanelMetrics.closeButtonSize,
            height: PreviewPanelMetrics.closeButtonSize
        )
    }
    .frame(width: PreviewPanelMetrics.titleRowWidth, height: 28, alignment: .leading)
}
```

Implement `closeButton` from the pure plan. It must remain a sibling of the primary button, have a fixed `22 x 22` frame, be invisible/noninteractive/accessibility-hidden at rest, and dispatch only the dedicated action:

```swift
private var closeButton: some View {
    let plan = PreviewCardCloseControlPlan.plan(for: card, isHovered: isHovered)
    return Button {
        PreviewCardCloseActionDispatcher.dispatch(for: card, onAction: onAction)
    } label: {
        Image(systemName: "xmark")
            .font(.system(size: 10, weight: .semibold))
            .frame(
                width: PreviewPanelMetrics.closeButtonSize,
                height: PreviewPanelMetrics.closeButtonSize
            )
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!plan.isEnabled)
    .opacity(plan.isVisible ? (plan.isEnabled ? 1 : 0.38) : 0)
    .allowsHitTesting(plan.isVisible && plan.isEnabled)
    .accessibilityHidden(!plan.isVisible)
    .accessibilityLabel("\(operationMenuText.title(for: .closeWindow)), \(card.title)")
    .help(operationMenuText.title(for: .closeWindow))
    .padding(.top, PreviewPanelMetrics.cardPadding + 3)
    .padding(.trailing, PreviewPanelMetrics.cardPadding)
}
```

Keep `PreviewCardContextMenuBridge` as the root overlay after the `ZStack`; it continues to consume right-clicks only. Do not change `thumbnailView`, its placeholder states, the panel scroll containers, or visual style tokens.

- [ ] **Step 4: Perform an immediate real-panel smoke check before committing the SwiftUI hierarchy change.**

Run:

```bash
Scripts/run_probe_app.sh
```

Before exercising the card, confirm the launched `build/zongMacTools.app` has Accessibility and Screen Recording permission and the unified log contains `permissions.refresh accessibility=true screenRecording=true`, `orchestrator.start accessibility=true screenRecording=true`, and `dock.subscribed pid=...`. Re-grant the permissions to this rebuilt app when ad-hoc signing has changed its TCC identity.

Use a real multi-window app and verify all of the following before continuing:

1. The application icon and one-line title are above every thumbnail; hover does not change card size or title width.
2. The `xmark` appears only while its own card is hovered. With a window that lacks an AX close button, it appears disabled and cannot be clicked.
3. Left-clicking the enabled `xmark` does not activate its target application or dispatch the card's primary activation behavior; the active foreground app remains unchanged until the target app itself responds to the close request.
4. Right-clicking the card still opens the existing context menu, and selecting its close item retains the pre-existing request-success hide behavior.

Record pass, fail, or blocked. A failure here blocks the Task 4 commit; do not defer a hierarchy or hit-testing failure to the broad final checklist.

- [ ] **Step 5: Run the focused view and panel suites.**

Run:

```bash
swift test --filter 'PreviewPanelViewRenderingTests|PreviewPanelControllerTests'
```

Expected: all pure layout/action tests pass and the existing panel controller behavior is unchanged.

- [ ] **Step 6: Commit the card UI.**

Run:

```bash
git add Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/PreviewPanelView.swift
git add Tests/DockHoverPreviewProbeTests/PreviewPanelViewRenderingTests.swift
git commit -m "feat: add preview card close icon"
```

Expected: the commit changes only card rendering and its focused test coverage.

### Task 5: Complete Regression Verification And Manual Acceptance Documentation

**Files:**
- Modify: `docs/verification/dock-hover-preview-p3-window-actions-manual-checklist.md`
- Verify: all files listed in the file map

- [ ] **Step 1: Add a dedicated left-click close-icon section to the P3 manual checklist.**

Append a section with these exact manual checks:

```markdown
### 关闭图标卡片更新

- [ ] 悬停多窗口应用：每张卡片的应用图标和标题位于缩略图上方；标题过长时单行省略，卡片尺寸不跳动。
- [ ] 将鼠标移入单张卡片：标题栏右侧出现关闭图标；移出卡片后图标消失且不能命中。
- [ ] 左键点击关闭图标：对应真实窗口收到关闭请求，预览卡片本身不会激活该窗口，其他卡片保持可用。
- [ ] 对未保存文档选择取消：窗口和对应预览卡片都保持。
- [ ] 对未保存文档确认关闭：仅对应卡片在真实窗口关闭后消失；其余卡片不重建、不消失。
- [ ] 关闭最后一张卡片：预览面板隐藏，桌面窗口放大预览没有残留。
- [ ] 对没有关闭按钮的窗口：关闭图标以禁用状态显示，点击不会触发操作。
- [ ] 右键菜单的“关闭窗口”：行为与本次改动前一致。
```

- [ ] **Step 2: Run all automated verification commands from a cleanly built app state.**

Run:

```bash
pkill -x DockHoverPreviewProbe
swift test
swift build
Scripts/build_probe_app.sh
git diff --check
```

Expected: every command exits `0`; `swift test` includes the new card-close, multi-observer, and close-confirmation cases.

- [ ] **Step 3: Perform the P3 manual checks in a real multi-window application.**

Run:

```bash
Scripts/run_probe_app.sh
```

Expected: the new checklist records pass/fail/blocked for layout, enabled and disabled close controls, cancellation of an unsaved document, confirmed removal of one card, last-card dismissal, and unchanged right-click behavior.

- [ ] **Step 4: Record the manual result and commit verification documentation.**

Update the result/status fields in `docs/verification/dock-hover-preview-p3-window-actions-manual-checklist.md`, then run:

```bash
git add docs/verification/dock-hover-preview-p3-window-actions-manual-checklist.md
git diff --cached --check
git commit -m "docs: verify preview card close icon"
```

Expected: the verification commit contains only the checklist and records the actual environment result rather than assuming a pass.

## Final Review Checklist

- [ ] The close icon is a left-click-only, hover-only sibling button and never causes `.primarySelect`.
- [ ] Existing right-click menu actions still use `.windowOperation` and retain their current close behavior.
- [ ] The real close request uses only `WindowOperationService.perform(.closeWindow, on:)` and public Accessibility APIs.
- [ ] No model mutation occurs on a successful close request alone; only a generation-valid matching destruction callback removes a card.
- [ ] Pending close subscriptions are cancelled for request failure, panel hide, session replacement, and matching app termination.
- [ ] A listener setup failure falls back safely: the requested close still runs, but the card is not removed until a later fresh preview query.
- [ ] New and existing focused tests, `swift test`, `swift build`, `Scripts/build_probe_app.sh`, and `git diff --check` are green.
