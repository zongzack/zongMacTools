import AppKit
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class PreviewSessionControllerTests: XCTestCase {
    func testPrimarySelectionStopsPeekBeforeActivation() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        harness.eventLog.removeAll()

        harness.display.actionHandler?(.primarySelect(window.id))

        XCTAssertEqual(harness.eventLog.events, [
            .peekStopped(.primarySelection),
            .panelDismissed,
            .activated(window.id)
        ])
    }

    func testContextMenuWillOpenStopsPeekBeforeMenuTracking() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        harness.eventLog.removeAll()

        harness.display.actionHandler?(.contextMenuWillOpen(window.id))

        XCTAssertEqual(harness.eventLog.events, [.peekStopped(.contextMenu)])
    }

    func testShowPreviewBeginsEpochAndUpdatesQueryScreens() async {
        let window = makeWindow(id: 1)
        let screen = WindowPeekScreen(
            identifier: 1,
            localizedName: "Built-in Display",
            captureFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            appKitFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            backingScaleFactor: 2
        )
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window], screens: [screen])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(Array(harness.eventLog.events.prefix(2)), [
            .beganSession(1),
            .screensUpdated(1, 1)
        ])
        XCTAssertEqual(harness.display.sessionEpoch, 1)
    }

    func testScreenChangeRejectsAnInFlightQueryResultForTheCurrentSession() async {
        let window = makeWindow(id: 1)
        let screen = WindowPeekScreen(
            identifier: 1,
            localizedName: "Built-in Display",
            captureFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            appKitFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            backingScaleFactor: 2
        )
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [window],
            screens: [screen]
        )
        harness.queryService.suspend = true

        let showTask = Task { @MainActor in
            await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        }
        await harness.queryService.waitUntilSuspended()

        harness.controller.invalidateWindowPeekScreens(reason: .screenParametersChanged)
        harness.queryService.resume()
        await showTask.value

        XCTAssertEqual(harness.eventLog.events, [
            .beganSession(1),
            .peekStopped(.screenParametersChanged)
        ])
        XCTAssertEqual(harness.display.showCount, 0)
    }

    func testThumbnailAvailabilityIsForwardedToPeekCoordinatorWithSessionEpoch() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        harness.thumbnailService.images[window.id] = makeImage()

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertTrue(harness.eventLog.events.contains(.coarseAvailable(window.id, 1)))
    }

    func testReplacementStopsPreviousPeekAndOldEpochHideCannotHideNewSession() async {
        let firstWindow = makeWindow(id: 1)
        let secondWindow = makeWindow(id: 2)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [firstWindow])
        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        let firstEpoch = try! XCTUnwrap(harness.display.sessionEpoch)
        harness.queryService.windows = [secondWindow]
        harness.eventLog.removeAll()

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(Array(harness.eventLog.events.prefix(2)), [
            .peekStopped(.sessionReplaced),
            .beganSession(2)
        ])
        let hideCountBeforeStaleRequest = harness.display.hideReasons.count
        harness.display.onRequestHide?("escape", firstEpoch)
        XCTAssertEqual(harness.display.hideReasons.count, hideCountBeforeStaleRequest)

        harness.display.onRequestHide?("escape", 2)
        XCTAssertEqual(harness.eventLog.events.last, .peekStopped(.sessionHidden))
        XCTAssertEqual(harness.display.hideReasons.last, "escape")
    }

    func testSinglePreviewableWindowDoesNotForwardHoverIntentToDesktopPeekCoordinator() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        harness.eventLog.removeAll()

        harness.display.actionHandler?(.hoverEntered(window.id, sessionEpoch: 1, sequence: 1))

        XCTAssertEqual(harness.eventLog.events, [])
        XCTAssertEqual(harness.display.showCount, 1)
    }

    func testHoverIntentForMissingWindowIsForwardedToCoordinatorWhenMultipleWindowsArePreviewable() async {
        let window = makeWindow(id: 1)
        let secondWindow = makeWindow(id: 3)
        let missingID = PreviewWindowID(pid: window.id.pid, windowID: 2)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window, secondWindow])
        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        harness.eventLog.removeAll()

        harness.display.actionHandler?(.hoverEntered(missingID, sessionEpoch: 1, sequence: 1))

        XCTAssertEqual(harness.eventLog.events, [.hoverEntered(missingID, 1, 1)])
    }

    func testHoverIntentWithStaleActionEpochIsIgnored() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        harness.eventLog.removeAll()

        harness.display.actionHandler?(.hoverEntered(window.id, sessionEpoch: 99, sequence: 1))

        XCTAssertEqual(harness.eventLog.events, [])
    }

    func testScreenRecordingMissingSuppressesPanel() async {
        let harness = PreviewSessionHarness(screenRecordingGranted: false, windows: [makeWindow(id: 1)])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.hideReasons, ["screenRecording=false"])
        XCTAssertEqual(harness.display.showCount, 0)
        XCTAssertNil(harness.display.lastModel)
    }

    func testNoWindowsHidesPanel() async {
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.hideReasons, ["noWindows"])
        XCTAssertEqual(harness.display.showCount, 0)
    }

    func testShowsPlaceholderCardsThenUpdatesThumbnails() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        harness.thumbnailService.images[window.id] = makeImage()

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.showCount, 1)
        XCTAssertEqual(harness.display.updateCount, 1)
        XCTAssertEqual(harness.display.lastModel?.cards.count, 1)
        XCTAssertTrue(harness.display.lastModel?.cards.first?.isLoadingThumbnail == false)
        XCTAssertNotNil(harness.display.lastModel?.cards.first?.thumbnail)
    }

    func testThumbnailFailureMarksCardUnavailableWithoutImage() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.showCount, 1)
        XCTAssertEqual(harness.display.updateCount, 1)
        XCTAssertNil(harness.display.lastModel?.cards.first?.thumbnail)
        XCTAssertEqual(harness.display.lastModel?.cards.first?.isLoadingThumbnail, false)
    }

    func testPreviewSessionUsesCaptureFrameForThumbnailDisplayMode() async {
        let narrowWindow = makeWindow(
            id: 1,
            captureFrame: CGRect(x: 100, y: 100, width: 700, height: 700)
        )
        let wideWindow = makeWindow(
            id: 2,
            captureFrame: CGRect(x: 100, y: 100, width: 1600, height: 900)
        )
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [narrowWindow, wideWindow]
        )

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.lastModel?.cards.map(\.thumbnailDisplayMode), [.fit, .fill])
    }

    func testPreviewSessionInjectsLocalizedThumbnailUnavailableText() async {
        let settingsStore = FakeSettingsStore(snapshot: .defaultsWith(language: .simplifiedChinese))
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [makeWindow(id: 1)],
            settingsStore: settingsStore
        )

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.lastModel?.thumbnailUnavailableText, "\u{65E0}\u{7F29}\u{7565}\u{56FE}")
    }

    func testPreviewSessionUsesConfiguredMaxCardCount() async {
        let windows = (1...6).map { makeWindow(id: CGWindowID($0)) }
        let settingsStore = FakeSettingsStore(snapshot: .defaultsWith(maxCardCount: 3))
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: windows,
            settingsStore: settingsStore
        )

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.lastModel?.cards.count, 3)
        XCTAssertEqual(harness.queryService.requestedLimits, [3])
    }

    func testShowPreviewTracksCurrentPreviewApp() async throws {
        let app = try bundledRunningApplication()
        let bundleIdentifier = try XCTUnwrap(app.bundleIdentifier)
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [makeWindow(id: 1)],
            app: app
        )

        await harness.controller.showPreview(for: app, anchor: harness.anchor)

        XCTAssertEqual(harness.targetTracker.exclusionTarget?.bundleIdentifier, bundleIdentifier)
        XCTAssertEqual(harness.targetTracker.exclusionTarget?.displayName, app.localizedName ?? bundleIdentifier)
    }

    func testHideClearsCurrentPreviewAppTarget() async throws {
        let app = try bundledRunningApplication()
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [makeWindow(id: 1)],
            app: app
        )

        await harness.controller.showPreview(for: app, anchor: harness.anchor)
        harness.controller.hide(reason: "test")

        XCTAssertNil(harness.targetTracker.exclusionTarget)
    }

    func testHideInvalidatesStaleThumbnailUpdates() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        harness.thumbnailService.images[window.id] = makeImage()
        harness.thumbnailService.suspend = true

        let task = Task {
            await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        }
        await harness.thumbnailService.waitUntilSuspended()
        harness.controller.hide(reason: "test")
        harness.thumbnailService.resume()
        await task.value

        XCTAssertEqual(harness.display.hideReasons, ["test"])
        XCTAssertEqual(harness.display.updateCount, 0)
        XCTAssertNil(harness.display.lastModel?.cards.first?.thumbnail)
        XCTAssertEqual(harness.display.lastModel?.cards.first?.isLoadingThumbnail, true)
    }

    func testStaleThumbnailFromPreviousGenerationDoesNotUpdateNextPanel() async {
        let staleWindow = makeWindow(id: 1)
        let currentWindow = makeWindow(id: 2)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [staleWindow])
        harness.thumbnailService.images[staleWindow.id] = makeImage()
        harness.thumbnailService.suspend = true

        let staleTask = Task {
            await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        }
        await harness.thumbnailService.waitUntilSuspended()

        harness.queryService.windows = [currentWindow]
        harness.thumbnailService.images = [:]
        harness.thumbnailService.suspend = false

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        harness.thumbnailService.resume()
        await staleTask.value

        XCTAssertEqual(harness.display.showCount, 2)
        XCTAssertEqual(harness.display.updateCount, 1)
        XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [currentWindow.id])
        XCTAssertNil(harness.display.lastModel?.cards.first?.thumbnail)
        XCTAssertEqual(harness.display.lastModel?.cards.first?.isLoadingThumbnail, false)
    }

    func testSelectingCardActivatesWindowAndHidesPanel() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        harness.display.actionHandler?(.primarySelect(window.id))
        await Task.yield()

        XCTAssertEqual(harness.activationService.activatedIDs, [window.id])
        XCTAssertEqual(harness.display.immediateHideReasons, ["activated"])
        XCTAssertEqual(harness.display.hideReasons, [])
    }

    func testPreviewSessionInjectsWindowOperationAvailabilityIntoCards() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        harness.windowOperationService.availabilities[.closeWindow] = .disabled(.closeWindow, reason: "Missing close button")

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.lastModel?.cards.first?.operationMenu.activate.isEnabled, true)
        XCTAssertEqual(harness.display.lastModel?.cards.first?.operationMenu.closeWindow.isEnabled, false)
        XCTAssertEqual(harness.display.lastModel?.cards.first?.operationMenu.closeWindow.disabledReason, "Missing close button")
    }

    func testPreviewSessionInjectsScreenEnvironmentDescriptionIntoCards() async {
        let window = makeWindow(id: 1, captureFrame: CGRect(x: 100, y: 100, width: 800, height: 600))
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [window],
            screens: [
                WindowPeekScreen(
                    identifier: 1,
                    localizedName: "Built-in Display",
                    captureFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                    appKitFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                    backingScaleFactor: 2
                )
            ]
        )

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertEqual(harness.display.lastModel?.cards.first?.operationMenu.environmentDescription, "Screen: Built-in Display")
    }

    func testWindowOperationActivateReusesActivationPath() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        harness.display.actionHandler?(.windowOperation(window.id, .activate))
        await Task.yield()

        XCTAssertEqual(harness.activationService.activatedIDs, [window.id])
        XCTAssertEqual(harness.windowOperationService.performedOperations, [])
        XCTAssertEqual(harness.display.immediateHideReasons, ["activated"])
        XCTAssertEqual(harness.display.hideReasons, [])
    }

    func testSuccessfulWindowOperationRoutesThroughServiceAndHidesPanel() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        harness.display.actionHandler?(.windowOperation(window.id, .hideApplication))
        await Task.yield()

        XCTAssertEqual(harness.windowOperationService.performedOperations, [.hideApplication])
        XCTAssertEqual(harness.display.hideReasons, ["windowOperation.hideApplication"])
    }

    func testFailedWindowOperationDoesNotHidePanel() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        harness.windowOperationService.results[.closeWindow] = WindowOperationResult(
            operation: .closeWindow,
            windowID: window.id,
            requestSucceeded: false,
            failure: WindowOperationFailure(reason: .missingButton, stage: .copyAttribute, axErrorCode: nil)
        )

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        harness.display.actionHandler?(.windowOperation(window.id, .closeWindow))
        await Task.yield()

        XCTAssertEqual(harness.windowOperationService.performedOperations, [.closeWindow])
        XCTAssertEqual(harness.display.hideReasons, [])
        XCTAssertTrue(harness.logger.snapshot().contains { $0.contains("windowOperation.result") && $0.contains("requestSucceeded=false") })
    }

    func testContextMenuTrackingKeepsPreviewRegionActiveUntilMenuEnds() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        let outsidePoint = CGPoint(x: -100, y: -100)

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        XCTAssertFalse(harness.controller.isMouseInsidePreviewRegion(outsidePoint))

        harness.display.actionHandler?(.contextMenuBegan(window.id))
        await Task.yield()

        XCTAssertTrue(harness.controller.isMouseInsidePreviewRegion(outsidePoint))

        harness.display.actionHandler?(.windowOperation(window.id, .minimizeWindow))
        await Task.yield()

        XCTAssertEqual(harness.windowOperationService.performedOperations, [.minimizeWindow])

        harness.display.actionHandler?(.contextMenuEnded(window.id))
        await Task.yield()

        XCTAssertFalse(harness.controller.isMouseInsidePreviewRegion(outsidePoint))
    }

    func testContextMenuTrackingKeepsPanelTransitionRegionActiveUntilMenuEnds() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [window])
        let outsidePoint = CGPoint(x: -100, y: -100)

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        XCTAssertFalse(harness.controller.isMouseInsidePanelTransitionRegion(outsidePoint))

        harness.display.actionHandler?(.contextMenuBegan(window.id))
        await Task.yield()

        XCTAssertTrue(harness.controller.isMouseInsidePanelTransitionRegion(outsidePoint))

        harness.display.actionHandler?(.contextMenuEnded(window.id))
        await Task.yield()

        XCTAssertFalse(harness.controller.isMouseInsidePanelTransitionRegion(outsidePoint))
    }

    func testNewPreviewSessionClearsStaleContextMenuTracking() async {
        let firstWindow = makeWindow(id: 1)
        let secondWindow = makeWindow(id: 2)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [firstWindow])
        let outsidePoint = CGPoint(x: -100, y: -100)

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        harness.display.actionHandler?(.contextMenuBegan(firstWindow.id))
        await Task.yield()
        XCTAssertTrue(harness.controller.isMouseInsidePreviewRegion(outsidePoint))

        harness.queryService.windows = [secondWindow]
        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertFalse(harness.controller.isMouseInsidePreviewRegion(outsidePoint))
        XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [secondWindow.id])
    }

    func testStaleMenuActionAfterHideDoesNotAffectNewSession() async {
        let staleWindow = makeWindow(id: 1)
        let currentWindow = makeWindow(id: 2)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [staleWindow])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        harness.controller.hide(reason: "test")

        harness.queryService.windows = [currentWindow]
        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        harness.display.actionHandler?(.windowOperation(staleWindow.id, .closeWindow))
        await Task.yield()

        XCTAssertEqual(harness.windowOperationService.performedOperations, [])
        XCTAssertTrue(harness.logger.snapshot().contains { $0.contains("windowOperation.missingWindow") && $0.contains("id=1") })
        XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [currentWindow.id])
    }

    func testStaleActionClosureAfterNewSessionWithSameWindowIDIsIgnored() async {
        let firstWindow = makeWindow(id: 1)
        let secondWindow = makeWindow(id: 1)
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [firstWindow])

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        let staleActionHandler = harness.display.actionHandler
        harness.controller.hide(reason: "test")

        harness.queryService.windows = [secondWindow]
        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        staleActionHandler?(.windowOperation(firstWindow.id, .closeWindow))
        await Task.yield()

        XCTAssertEqual(harness.windowOperationService.performedOperations, [])
        XCTAssertTrue(harness.logger.snapshot().contains { $0.contains("preview.session.staleAction") })
        XCTAssertEqual(harness.display.lastModel?.cards.map(\.id), [secondWindow.id])
    }

    func testMouseInsidePanelDelegatesToDisplay() {
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [])
        harness.display.isMouseInsidePanelResult = true

        XCTAssertTrue(harness.controller.isMouseInsidePanel(CGPoint(x: 12, y: 34)))
        XCTAssertEqual(harness.display.checkedPoints, [CGPoint(x: 12, y: 34)])
    }

    func testStandardRetentionMatchesExistingBridgeBehavior() async {
        let window = makeWindow(id: 1)
        let settingsStore = FakeSettingsStore(snapshot: .defaultsWith(retention: .standard))
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [window],
            settingsStore: settingsStore,
            anchor: PreviewPanelAnchor(
                dockItemFrame: CGRect(x: 700, y: 0, width: 52, height: 48),
                mouseLocation: CGPoint(x: 726, y: 24),
                screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 900)
            )
        )
        harness.display.panelFrameResult = CGRect(x: 600, y: 58, width: 256, height: 196)

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertTrue(harness.controller.isMouseInsidePreviewRegion(CGPoint(x: 726, y: 53)))
        XCTAssertFalse(harness.controller.isMouseInsidePreviewRegion(CGPoint(x: 300, y: 53)))
    }

    func testTightRetentionShrinksDockTolerance() async {
        let window = makeWindow(id: 1)
        let settingsStore = FakeSettingsStore(snapshot: .defaultsWith(retention: .tight))
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [window],
            settingsStore: settingsStore,
            anchor: PreviewPanelAnchor(
                dockItemFrame: CGRect(x: 700, y: 0, width: 52, height: 48),
                mouseLocation: CGPoint(x: 726, y: 24),
                screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 900)
            )
        )
        harness.display.panelFrameResult = CGRect(x: 600, y: 58, width: 256, height: 196)

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertFalse(harness.controller.isMouseInsidePreviewRegion(CGPoint(x: 775, y: 40)))
    }

    func testForgivingRetentionExpandsDockTolerance() async {
        let window = makeWindow(id: 1)
        let settingsStore = FakeSettingsStore(snapshot: .defaultsWith(retention: .forgiving))
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [window],
            settingsStore: settingsStore,
            anchor: PreviewPanelAnchor(
                dockItemFrame: CGRect(x: 700, y: 0, width: 52, height: 48),
                mouseLocation: CGPoint(x: 726, y: 24),
                screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 900)
            )
        )
        harness.display.panelFrameResult = CGRect(x: 600, y: 58, width: 256, height: 196)

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertTrue(harness.controller.isMouseInsidePreviewRegion(CGPoint(x: 787, y: 40)))
    }

    func testSettingsObserverUpdatesRetentionImmediatelyWithoutShowingAgain() async {
        let window = makeWindow(id: 1)
        let settingsStore = FakeSettingsStore(snapshot: .defaultsWith(retention: .standard))
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [window],
            settingsStore: settingsStore,
            anchor: PreviewPanelAnchor(
                dockItemFrame: CGRect(x: 700, y: 0, width: 52, height: 48),
                mouseLocation: CGPoint(x: 726, y: 24),
                screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 900)
            )
        )
        harness.display.panelFrameResult = CGRect(x: 600, y: 58, width: 256, height: 196)

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)
        XCTAssertTrue(harness.controller.isMouseInsidePreviewRegion(CGPoint(x: 775, y: 40)))

        harness.controller.startObservingSettings()
        settingsStore.replaceSnapshot(.defaultsWith(retention: .tight))

        XCTAssertFalse(harness.controller.isMouseInsidePreviewRegion(CGPoint(x: 775, y: 40)))
        XCTAssertEqual(harness.queryService.requestedLimits, [8])
        XCTAssertEqual(harness.display.hideReasons, [])

        settingsStore.replaceSnapshot(.defaultsWith(retention: .forgiving))

        XCTAssertTrue(harness.controller.isMouseInsidePreviewRegion(CGPoint(x: 787, y: 40)))
        XCTAssertEqual(harness.queryService.requestedLimits, [8])
        XCTAssertEqual(harness.display.hideReasons, [])

        harness.controller.stopObservingSettings()
    }

    func testSettingsObserverStartIsIdempotentAndStopRemovesObserver() {
        let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [])

        harness.controller.startObservingSettings()
        harness.controller.startObservingSettings()

        XCTAssertEqual(harness.settingsStore.observers.count, 1)

        harness.controller.stopObservingSettings()

        XCTAssertEqual(harness.settingsStore.observers.count, 0)

        harness.controller.stopObservingSettings()

        XCTAssertEqual(harness.settingsStore.observers.count, 0)
    }

    func testMouseInsideBridgeBetweenDockAndPanelIsInsidePanelTransitionRegion() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [window],
            anchor: PreviewPanelAnchor(
                dockItemFrame: CGRect(x: 700, y: 0, width: 52, height: 48),
                mouseLocation: CGPoint(x: 726, y: 24),
                screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 900)
            )
        )
        harness.display.panelFrameResult = CGRect(x: 600, y: 58, width: 256, height: 196)

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertTrue(harness.controller.isMouseInsidePanelTransitionRegion(CGPoint(x: 726, y: 53)))
    }

    func testMouseJustOutsideCurrentDockIconEdgeIsInsidePanelTransitionRegion() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [window],
            settingsStore: FakeSettingsStore(snapshot: .defaultsWith(retention: .tight)),
            anchor: PreviewPanelAnchor(
                dockItemFrame: CGRect(x: 700, y: 0, width: 52, height: 48),
                mouseLocation: CGPoint(x: 726, y: 24),
                screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 900)
            )
        )
        harness.display.panelFrameResult = CGRect(x: 600, y: 58, width: 256, height: 196)

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertTrue(harness.controller.isMouseInsidePanelTransitionRegion(CGPoint(x: 700, y: 51)))
    }

    func testMouseInsideDockToleranceBesideIconIsOutsidePanelTransitionRegion() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [window],
            anchor: PreviewPanelAnchor(
                dockItemFrame: CGRect(x: 700, y: 0, width: 52, height: 48),
                mouseLocation: CGPoint(x: 726, y: 24),
                screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 900)
            )
        )
        harness.display.panelFrameResult = CGRect(x: 600, y: 58, width: 256, height: 196)

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        let adjacentDockPoint = CGPoint(x: 775, y: 40)
        XCTAssertTrue(harness.controller.isMouseInsidePreviewRegion(adjacentDockPoint))
        XCTAssertFalse(harness.controller.isMouseInsidePanelTransitionRegion(adjacentDockPoint))
    }

    func testMouseBesidePanelOutsideBridgeIsOutsidePreviewRegion() async {
        let window = makeWindow(id: 1)
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [window],
            anchor: PreviewPanelAnchor(
                dockItemFrame: CGRect(x: 500, y: 0, width: 52, height: 48),
                mouseLocation: CGPoint(x: 526, y: 24),
                screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 900)
            )
        )
        harness.display.panelFrameResult = CGRect(x: 390, y: 106, width: 256, height: 196)

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        XCTAssertFalse(harness.controller.isMouseInsidePreviewRegion(CGPoint(x: 660, y: 180)))
    }

    func testMouseInsideBridgeBetweenSideDockAndPanelIsInsidePreviewRegion() async {
        let window = makeWindow(id: 1)
        let settingsStore = FakeSettingsStore(snapshot: .defaultsWith(retention: .tight))
        let harness = PreviewSessionHarness(
            screenRecordingGranted: true,
            windows: [window],
            settingsStore: settingsStore,
            anchor: PreviewPanelAnchor(
                dockItemFrame: CGRect(x: 0, y: 430, width: 48, height: 52),
                mouseLocation: CGPoint(x: 24, y: 456),
                screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 900)
            )
        )
        harness.display.panelFrameResult = CGRect(x: 58, y: 366, width: 256, height: 196)

        await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

        let gapCenterPoint = CGPoint(x: 53, y: 456)
        XCTAssertTrue(harness.controller.isMouseInsidePreviewRegion(gapCenterPoint))
        XCTAssertTrue(harness.controller.isMouseInsidePanelTransitionRegion(gapCenterPoint))
        XCTAssertFalse(harness.controller.isMouseInsidePreviewRegion(CGPoint(x: 53, y: 700)))
    }

    func testP1SettingsDefaultsRemainUnchanged() {
        XCTAssertTrue(DockHoverPreviewSettings.defaults.isDockHoverPreviewEnabled)
        XCTAssertEqual(DockHoverPreviewSettings.defaults.hoverDelayMilliseconds, 250)
        XCTAssertEqual(DockHoverPreviewSettings.defaults.panelRetentionMode, .standard)
        XCTAssertEqual(DockHoverPreviewSettings.defaults.maxCardCount, 8)
        XCTAssertEqual(DockHoverPreviewSettings.defaults.excludedAppBundleIdentifiers, [])
        XCTAssertEqual(DockHoverPreviewSettings.defaults.displayLanguage, .english)
        XCTAssertFalse(SettingsKey.allCases.contains { $0.rawValue.contains("thumbnailDisplayMode") })
    }
}

@MainActor
private final class FakePermissionService: PermissionService {
    var currentState: PermissionState

    init(accessibilityGranted: Bool, screenRecordingGranted: Bool) {
        currentState = PermissionState(
            accessibilityGranted: accessibilityGranted,
            screenRecordingGranted: screenRecordingGranted
        )
    }

    func refresh() -> PermissionState { currentState }
    func requestAccessibilityPrompt() {}
    func openAccessibilitySettings() {}
    func openScreenRecordingSettings() {}
}

@MainActor
private final class FakeWindowQueryService: WindowQueryService {
    var windows: [PreviewWindow]
    var screens: [WindowPeekScreen]
    var suspend = false
    private(set) var requestedLimits: [Int] = []
    private var continuation: CheckedContinuation<Void, Never>?
    private var suspendedContinuation: CheckedContinuation<Void, Never>?
    private var isSuspended = false

    init(windows: [PreviewWindow], screens: [WindowPeekScreen]) {
        self.windows = windows
        self.screens = screens
    }

    func query(for app: NSRunningApplication, limit: Int) async -> WindowQueryResult {
        requestedLimits.append(limit)
        if suspend {
            await withCheckedContinuation {
                isSuspended = true
                continuation = $0
                suspendedContinuation?.resume()
                suspendedContinuation = nil
            }
        }
        return WindowQueryResult(windows: Array(windows.prefix(limit)), screens: screens)
    }

    func waitUntilSuspended() async {
        guard !isSuspended else { return }
        await withCheckedContinuation {
            suspendedContinuation = $0
        }
    }

    func resume() {
        suspend = false
        isSuspended = false
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class FakeSettingsStore: DockHoverPreviewSettingsStore {
    private(set) var observers: [UUID: @MainActor (DockHoverPreviewSettings) -> Void] = [:]
    private(set) var updateCount = 0
    var snapshot: DockHoverPreviewSettings

    init(snapshot: DockHoverPreviewSettings = .defaults) {
        self.snapshot = snapshot
    }

    @discardableResult
    func addObserver(_ observer: @MainActor @escaping (DockHoverPreviewSettings) -> Void) -> UUID {
        let token = UUID()
        observers[token] = observer
        return token
    }

    func removeObserver(_ token: UUID) {
        observers.removeValue(forKey: token)
    }

    func update(transform: (inout DockHoverPreviewSettings) -> Void) {
        updateCount += 1
        transform(&snapshot)
        observers.values.forEach { $0(snapshot) }
    }

    func replaceSnapshot(_ next: DockHoverPreviewSettings) {
        snapshot = next
        observers.values.forEach { $0(snapshot) }
    }
}

private extension DockHoverPreviewSettings {
    static func defaultsWith(
        enabled: Bool = true,
        hoverDelayMilliseconds: Int = 250,
        maxCardCount: Int = 8,
        retention: PanelRetentionMode = .standard,
        excludedApps: Set<String> = [],
        language: DisplayLanguage = .english
    ) -> DockHoverPreviewSettings {
        var settings = DockHoverPreviewSettings.defaults
        settings.isDockHoverPreviewEnabled = enabled
        settings.hoverDelayMilliseconds = hoverDelayMilliseconds
        settings.maxCardCount = maxCardCount
        settings.panelRetentionMode = retention
        settings.excludedAppBundleIdentifiers = excludedApps
        settings.displayLanguage = language
        return settings
    }
}

@MainActor
private final class FakeThumbnailService: ThumbnailService {
    var images: [PreviewWindowID: CGImage] = [:]
    var suspend = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var suspendedContinuation: CheckedContinuation<Void, Never>?
    private var isSuspended = false

    func thumbnail(for window: PreviewWindow) async -> CGImage? {
        if suspend {
            await withCheckedContinuation {
                isSuspended = true
                continuation = $0
                suspendedContinuation?.resume()
                suspendedContinuation = nil
            }
        }
        return images[window.id]
    }

    func waitUntilSuspended() async {
        if isSuspended { return }

        await withCheckedContinuation {
            suspendedContinuation = $0
        }
    }

    func resume() {
        suspend = false
        isSuspended = false
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class FakeActivationService: ActivationService {
    var activatedIDs: [PreviewWindowID] = []
    var onActivate: ((PreviewWindowID) -> Void)?

    func activate(window: PreviewWindow) -> ActivationProbeResult {
        activatedIDs.append(window.id)
        onActivate?(window.id)
        return ActivationProbeResult(
            windowID: window.cgWindowID,
            title: window.title,
            hadAXElement: window.axElement != nil,
            raiseSucceeded: window.axElement != nil,
            appActivateRequestSucceeded: true
        )
    }
}

@MainActor
private final class FakePreviewPanelDisplay: PreviewPanelDisplaying {
    var onRequestHide: ((String, UInt64) -> Void)?

    var showCount = 0
    var updateCount = 0
    var lastModel: PreviewPanelViewModel?
    var hideReasons: [String] = []
    var immediateHideReasons: [String] = []
    var onImmediateDismiss: (() -> Void)?
    var checkedPoints: [CGPoint] = []
    var isMouseInsidePanelResult = false
    var panelFrameResult: CGRect?
    var actionHandler: ((PreviewPanelAction) -> Void)?
    var sessionEpoch: UInt64?

    func show(
        model: PreviewPanelViewModel,
        anchor: PreviewPanelAnchor,
        sessionEpoch: UInt64,
        onAction: @escaping (PreviewPanelAction) -> Void
    ) {
        showCount += 1
        lastModel = model
        actionHandler = onAction
        self.sessionEpoch = sessionEpoch
    }

    func update(model: PreviewPanelViewModel) {
        updateCount += 1
        lastModel = model
    }

    func hide(reason: String) {
        hideReasons.append(reason)
    }

    func hideImmediately(reason: String) {
        immediateHideReasons.append(reason)
        onImmediateDismiss?()
    }

    func isMouseInsidePanel(_ point: CGPoint) -> Bool {
        checkedPoints.append(point)
        return isMouseInsidePanelResult
    }

    func panelFrame() -> CGRect? {
        panelFrameResult
    }
}

@MainActor
private final class FakeWindowOperationService: WindowOperationService {
    var availabilities: [PreviewWindowOperation: WindowOperationAvailability] = [:]
    var results: [PreviewWindowOperation: WindowOperationResult] = [:]
    private(set) var performedOperations: [PreviewWindowOperation] = []

    func availability(for operation: PreviewWindowOperation, window: PreviewWindow) -> WindowOperationAvailability {
        availabilities[operation] ?? .enabled(operation)
    }

    func perform(_ operation: PreviewWindowOperation, on window: PreviewWindow) -> WindowOperationResult {
        performedOperations.append(operation)
        return results[operation] ?? WindowOperationResult(
            operation: operation,
            windowID: window.id,
            requestSucceeded: true,
            failure: nil
        )
    }
}

@MainActor
private final class PreviewSessionHarness {
    let app: NSRunningApplication
    let permissionService: FakePermissionService
    let queryService: FakeWindowQueryService
    let thumbnailService = FakeThumbnailService()
    let activationService = FakeActivationService()
    let windowOperationService = FakeWindowOperationService()
    let display = FakePreviewPanelDisplay()
    let logger = ProbeLogger()
    let settingsStore: FakeSettingsStore
    let targetTracker: AppTargetTracker
    let eventLog = SessionEventLog()
    let windowPeekCoordinator: RecordingWindowPeekCoordinator
    let anchor: PreviewPanelAnchor
    let controller: PreviewSessionController

    init(
        screenRecordingGranted: Bool,
        windows: [PreviewWindow],
        settingsStore: FakeSettingsStore = FakeSettingsStore(),
        targetTracker: AppTargetTracker? = nil,
        app: NSRunningApplication = .current,
        screens: [WindowPeekScreen] = [],
        anchor: PreviewPanelAnchor = PreviewPanelAnchor(
            dockItemFrame: CGRect(x: 700, y: 0, width: 52, height: 48),
            mouseLocation: CGPoint(x: 726, y: 24),
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 50, width: 1512, height: 900)
        )
    ) {
        self.app = app
        self.anchor = anchor
        self.settingsStore = settingsStore
        self.targetTracker = targetTracker ?? AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools")
        permissionService = FakePermissionService(
            accessibilityGranted: true,
            screenRecordingGranted: screenRecordingGranted
        )
        queryService = FakeWindowQueryService(windows: windows, screens: screens)
        windowPeekCoordinator = RecordingWindowPeekCoordinator(eventLog: eventLog)
        display.onImmediateDismiss = { [eventLog] in
            eventLog.append(.panelDismissed)
        }
        activationService.onActivate = { [eventLog] id in
            eventLog.append(.activated(id))
        }
        let controller = PreviewSessionController(
            permissionService: permissionService,
            windowQueryService: queryService,
            thumbnailService: thumbnailService,
            activationService: activationService,
            windowOperationService: windowOperationService,
            panelDisplay: display,
            settingsStore: settingsStore,
            targetTracker: self.targetTracker,
            windowPeekCoordinator: windowPeekCoordinator,
            logger: logger
        )
        self.controller = controller
        display.onRequestHide = { [weak controller] reason, epoch in
            controller?.hide(reason: reason, expectedSessionEpoch: epoch)
        }
    }
}

@MainActor
private enum SessionEvent: Equatable {
    case beganSession(UInt64)
    case screensUpdated(UInt64, Int)
    case peekStopped(WindowPeekStopReason)
    case hoverEntered(PreviewWindowID, UInt64, UInt64)
    case hoverExited(PreviewWindowID, UInt64, UInt64)
    case coarseAvailable(PreviewWindowID, UInt64)
    case panelDismissed
    case activated(PreviewWindowID)
}

@MainActor
private final class SessionEventLog {
    private(set) var events: [SessionEvent] = []

    func append(_ event: SessionEvent) {
        events.append(event)
    }

    func removeAll() {
        events.removeAll()
    }
}

@MainActor
private final class RecordingWindowPeekCoordinator: WindowPeekCoordinating {
    let eventLog: SessionEventLog

    init(eventLog: SessionEventLog) {
        self.eventLog = eventLog
    }

    func beginSession(epoch: UInt64) {
        eventLog.append(.beganSession(epoch))
    }

    func updateScreens(_ screens: [WindowPeekScreen], sessionEpoch: UInt64) {
        eventLog.append(.screensUpdated(sessionEpoch, screens.count))
    }

    func hoverEntered(
        windowID: PreviewWindowID,
        window: PreviewWindow?,
        coarseImage: CGImage?,
        sessionEpoch: UInt64,
        sequence: UInt64
    ) {
        eventLog.append(.hoverEntered(windowID, sessionEpoch, sequence))
    }

    func hoverExited(windowID: PreviewWindowID, sessionEpoch: UInt64, sequence: UInt64) {
        eventLog.append(.hoverExited(windowID, sessionEpoch, sequence))
    }

    func coarseImageDidBecomeAvailable(_ image: CGImage?, for windowID: PreviewWindowID, sessionEpoch: UInt64) {
        eventLog.append(.coarseAvailable(windowID, sessionEpoch))
    }

    func targetWindowDestroyed(_ windowID: PreviewWindowID) {}

    func targetApplicationTerminated(pid: pid_t) {}

    func stop(reason: WindowPeekStopReason) {
        eventLog.append(.peekStopped(reason))
    }
}

private func makeWindow(
    id: CGWindowID,
    captureFrame: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600)
) -> PreviewWindow {
    PreviewWindow(
        id: PreviewWindowID(pid: NSRunningApplication.current.processIdentifier, windowID: id),
        cgWindowID: id,
        app: NSRunningApplication.current,
        title: "Window \(id)",
        captureFrame: captureFrame,
        axElement: nil,
        appIcon: NSImage(size: NSSize(width: 32, height: 32)),
        thumbnailSource: nil,
        desktopPeekCaptureSource: nil,
        desktopPeekEligible: false
    )
}

private func makeImage() -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: 2,
        height: 2,
        bitsPerComponent: 8,
        bytesPerRow: 8,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}

private func bundledRunningApplication(
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> NSRunningApplication {
    try XCTUnwrap(
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier != nil },
        "Expected at least one running application with a bundle identifier",
        file: file,
        line: line
    )
}
