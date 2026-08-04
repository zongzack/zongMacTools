import AppKit
import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class ProbeOrchestratorPreviewTests: XCTestCase {
    func testFrontmostPreviewSuppressesPanelWhenScreenRecordingIsMissing() async {
        let harness = ProbeOrchestratorPreviewHarness(screenRecordingGranted: false)

        harness.orchestrator.showFrontmostAppProbe()
        await Task.yield()

        XCTAssertEqual(harness.display.hideReasons, ["screenRecording=false"])
        XCTAssertEqual(harness.display.showCount, 0)
    }

    func testFrontmostDebugPreviewIgnoresDisabledSettingButRespectsScreenRecording() async throws {
        let app = try bundledRunningApplication()
        let settingsStore = OrchestratorFakeSettingsStore(snapshot: .defaultsWith(enabled: false))
        let harness = ProbeOrchestratorPreviewHarness(
            screenRecordingGranted: true,
            settingsStore: settingsStore,
            frontmostApp: app
        )

        harness.orchestrator.showFrontmostAppProbe()
        await waitForPreviewDisplayChange(harness.display)

        XCTAssertEqual(harness.display.hideReasons, ["noWindows"])
        XCTAssertEqual(harness.display.showCount, 0)
    }

    func testFrontmostDebugPreviewRespectsExcludedApp() throws {
        let app = try bundledRunningApplication()
        let bundleIdentifier = try XCTUnwrap(app.bundleIdentifier)
        let settingsStore = OrchestratorFakeSettingsStore(
            snapshot: .defaultsWith(excludedApps: [bundleIdentifier])
        )
        let harness = ProbeOrchestratorPreviewHarness(
            screenRecordingGranted: true,
            settingsStore: settingsStore,
            frontmostApp: app
        )

        harness.orchestrator.showFrontmostAppProbe()

        XCTAssertEqual(harness.display.hideReasons, ["appExcluded"])
        XCTAssertEqual(harness.display.showCount, 0)
    }

    func testHoverDelayUsesSettingsSnapshot() {
        let settingsStore = OrchestratorFakeSettingsStore(snapshot: .defaultsWith(hoverDelayMilliseconds: 400))
        let harness = ProbeOrchestratorPreviewHarness(
            screenRecordingGranted: true,
            settingsStore: settingsStore
        )

        harness.orchestrator.schedulePreviewAfterDelayForTesting(
            app: NSRunningApplication.current,
            bundleIdentifier: "com.example.delay",
            dockItemFrame: CGRect(x: 10, y: 10, width: 32, height: 32)
        )

        XCTAssertEqual(harness.scheduler.scheduledMilliseconds, [400])
    }

    func testDockHoverTracksHoveredDockApp() throws {
        let app = try bundledRunningApplication()
        let bundleIdentifier = try XCTUnwrap(app.bundleIdentifier)
        let harness = ProbeOrchestratorPreviewHarness(screenRecordingGranted: true)
        let monitor = DockHoverMonitor(logger: harness.logger)
        let hoveredApp = HoveredDockApp(
            app: app,
            bundleIdentifier: bundleIdentifier,
            dockItemElement: AXUIElementCreateApplication(app.processIdentifier),
            dockItemFrame: CGRect(x: 10, y: 10, width: 32, height: 32)
        )

        harness.orchestrator.dockHoverMonitor(monitor, didHover: hoveredApp)

        XCTAssertEqual(harness.targetTracker.exclusionTarget?.bundleIdentifier, bundleIdentifier)
        XCTAssertEqual(harness.targetTracker.exclusionTarget?.displayName, app.localizedName ?? bundleIdentifier)
    }

    func testStaleScheduledHoverCannotClearNewPendingHover() {
        let settingsStore = OrchestratorFakeSettingsStore()
        let harness = ProbeOrchestratorPreviewHarness(
            accessibilityGranted: false,
            screenRecordingGranted: true,
            settingsStore: settingsStore
        )

        harness.orchestrator.start()
        harness.orchestrator.schedulePreviewAfterDelayForTesting(
            app: NSRunningApplication.current,
            bundleIdentifier: "com.example.first",
            dockItemFrame: nil
        )
        harness.orchestrator.schedulePreviewAfterDelayForTesting(
            app: NSRunningApplication.current,
            bundleIdentifier: "com.example.second",
            dockItemFrame: nil
        )

        harness.scheduler.actions[0]()
        settingsStore.replaceSnapshot(.defaultsWith(excludedApps: ["com.example.second"]))

        XCTAssertEqual(harness.scheduler.tokens[1].isCancelled, true)
        XCTAssertEqual(harness.display.hideReasons, ["appExcluded"])
    }

    func testDisablingSettingsCancelsPendingHoverAndHidesPreview() {
        let settingsStore = OrchestratorFakeSettingsStore()
        let harness = ProbeOrchestratorPreviewHarness(
            accessibilityGranted: false,
            screenRecordingGranted: true,
            settingsStore: settingsStore
        )

        harness.orchestrator.start()
        harness.orchestrator.schedulePreviewAfterDelayForTesting(
            app: NSRunningApplication.current,
            bundleIdentifier: "com.example.disabled",
            dockItemFrame: CGRect(x: 10, y: 10, width: 32, height: 32)
        )
        settingsStore.replaceSnapshot(.defaultsWith(enabled: false))

        XCTAssertEqual(harness.scheduler.tokens.last?.isCancelled, true)
        XCTAssertEqual(harness.display.hideReasons, ["settingsDisabled"])
    }

    func testSettingsObserverDoesNotHideAgainWhenSettingsStayDisabled() {
        let settingsStore = OrchestratorFakeSettingsStore(snapshot: .defaultsWith(enabled: false))
        let harness = ProbeOrchestratorPreviewHarness(
            accessibilityGranted: false,
            screenRecordingGranted: true,
            settingsStore: settingsStore
        )

        harness.orchestrator.start()
        settingsStore.replaceSnapshot(.defaultsWith(enabled: false, hoverDelayMilliseconds: 400))

        XCTAssertEqual(harness.display.hideReasons, [])
    }

    func testChangingHoverDelayCancelsPendingHoverWithoutHidingPreview() {
        let settingsStore = OrchestratorFakeSettingsStore()
        let harness = ProbeOrchestratorPreviewHarness(
            accessibilityGranted: false,
            screenRecordingGranted: true,
            settingsStore: settingsStore
        )

        harness.orchestrator.start()
        harness.orchestrator.schedulePreviewAfterDelayForTesting(
            app: NSRunningApplication.current,
            bundleIdentifier: "com.example.delayChange",
            dockItemFrame: CGRect(x: 10, y: 10, width: 32, height: 32)
        )
        settingsStore.replaceSnapshot(.defaultsWith(hoverDelayMilliseconds: 400))

        XCTAssertEqual(harness.scheduler.tokens.last?.isCancelled, true)
        XCTAssertEqual(harness.display.hideReasons, [])
    }

    func testAddingPendingAppToExclusionsCancelsPendingHoverAndHidesPreview() {
        let bundleIdentifier = "com.example.excluded"
        let settingsStore = OrchestratorFakeSettingsStore()
        let harness = ProbeOrchestratorPreviewHarness(
            accessibilityGranted: false,
            screenRecordingGranted: true,
            settingsStore: settingsStore
        )

        harness.orchestrator.start()
        harness.orchestrator.schedulePreviewAfterDelayForTesting(
            app: NSRunningApplication.current,
            bundleIdentifier: bundleIdentifier,
            dockItemFrame: CGRect(x: 10, y: 10, width: 32, height: 32)
        )
        settingsStore.replaceSnapshot(.defaultsWith(excludedApps: [bundleIdentifier]))

        XCTAssertEqual(harness.scheduler.tokens.last?.isCancelled, true)
        XCTAssertEqual(harness.display.hideReasons, ["appExcluded"])
    }

    func testAddingCurrentPreviewAppToExclusionsHidesPreview() {
        let bundleIdentifier = "com.example.preview"
        let targetTracker = AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools")
        targetTracker.updateCurrentPreviewApp(AppTarget(bundleIdentifier: bundleIdentifier, displayName: "Preview App"))
        let settingsStore = OrchestratorFakeSettingsStore()
        let harness = ProbeOrchestratorPreviewHarness(
            accessibilityGranted: false,
            screenRecordingGranted: true,
            settingsStore: settingsStore,
            targetTracker: targetTracker
        )

        harness.orchestrator.start()
        settingsStore.replaceSnapshot(.defaultsWith(excludedApps: [bundleIdentifier]))

        XCTAssertEqual(harness.display.hideReasons, ["appExcluded"])
    }

    func testAddingUnrelatedExclusionDoesNotHideCurrentPreview() {
        let targetTracker = AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools")
        targetTracker.updateCurrentPreviewApp(AppTarget(bundleIdentifier: "com.example.preview", displayName: "Preview App"))
        let settingsStore = OrchestratorFakeSettingsStore()
        let harness = ProbeOrchestratorPreviewHarness(
            accessibilityGranted: false,
            screenRecordingGranted: true,
            settingsStore: settingsStore,
            targetTracker: targetTracker
        )

        harness.orchestrator.start()
        settingsStore.replaceSnapshot(.defaultsWith(excludedApps: ["com.example.unrelated"]))

        XCTAssertEqual(harness.display.hideReasons, [])
    }

    func testDelayedValidationRechecksDisabledSettingBeforeShowingPreview() {
        let settingsStore = OrchestratorFakeSettingsStore()
        let harness = ProbeOrchestratorPreviewHarness(
            screenRecordingGranted: true,
            settingsStore: settingsStore
        )
        let candidate = HoverPreviewCandidate(
            app: NSRunningApplication.current,
            bundleIdentifier: "com.example.disabled",
            dockItemFrame: CGRect(x: 10, y: 10, width: 32, height: 32)
        )

        settingsStore.replaceSnapshot(.defaultsWith(enabled: false))
        harness.orchestrator.validateDelayedHoverForTesting(
            candidate: candidate,
            resolved: candidate,
            mouseInside: true
        )

        XCTAssertEqual(harness.display.hideReasons, ["settingsDisabled"])
        XCTAssertEqual(harness.display.showCount, 0)
    }

    func testDelayedValidationRechecksExcludedAppBeforeShowingPreview() {
        let bundleIdentifier = "com.example.delayedExcluded"
        let settingsStore = OrchestratorFakeSettingsStore()
        let harness = ProbeOrchestratorPreviewHarness(
            screenRecordingGranted: true,
            settingsStore: settingsStore
        )
        let candidate = HoverPreviewCandidate(
            app: NSRunningApplication.current,
            bundleIdentifier: bundleIdentifier,
            dockItemFrame: CGRect(x: 10, y: 10, width: 32, height: 32)
        )

        settingsStore.replaceSnapshot(.defaultsWith(excludedApps: [bundleIdentifier]))
        harness.orchestrator.validateDelayedHoverForTesting(
            candidate: candidate,
            resolved: candidate,
            mouseInside: true
        )

        XCTAssertEqual(harness.display.hideReasons, ["appExcluded"])
        XCTAssertEqual(harness.display.showCount, 0)
    }

    func testOrchestratorStopStopsPeekWithoutChangingIndependentPeekSetting() {
        var settings = DockHoverPreviewSettings.defaults
        settings.isDesktopWindowPeekEnabled = false
        let settingsStore = OrchestratorFakeSettingsStore(snapshot: settings)
        let harness = ProbeOrchestratorPreviewHarness(
            accessibilityGranted: false,
            screenRecordingGranted: true,
            settingsStore: settingsStore
        )

        harness.orchestrator.stop()

        XCTAssertEqual(harness.windowPeekCoordinator.stopReasons, [.sessionHidden])
        XCTAssertFalse(settingsStore.snapshot.isDesktopWindowPeekEnabled)
    }
}

@MainActor
private final class OrchestratorFakePermissionService: PermissionService {
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
private final class OrchestratorFakeWindowQueryService: WindowQueryService {
    func query(for app: NSRunningApplication, limit: Int) async -> WindowQueryResult {
        WindowQueryResult(windows: [], screens: [])
    }
}

@MainActor
private final class OrchestratorFakeThumbnailService: ThumbnailService {
    func thumbnail(for window: PreviewWindow) async -> CGImage? { nil }
}

@MainActor
private final class OrchestratorFakeActivationService: ActivationService {
    func activate(window: PreviewWindow) -> ActivationProbeResult {
        ActivationProbeResult(
            windowID: window.cgWindowID,
            title: window.title,
            hadAXElement: false,
            raiseSucceeded: false,
            appActivateRequestSucceeded: true
        )
    }
}

@MainActor
private final class OrchestratorFakeWindowOperationService: WindowOperationService {
    func availability(for operation: PreviewWindowOperation, window: PreviewWindow) -> WindowOperationAvailability {
        .enabled(operation)
    }

    func perform(_ operation: PreviewWindowOperation, on window: PreviewWindow) -> WindowOperationResult {
        WindowOperationResult(
            operation: operation,
            windowID: window.id,
            requestSucceeded: true,
            failure: nil
        )
    }
}

@MainActor
private final class OrchestratorFakePreviewDisplay: PreviewPanelDisplaying {
    var onRequestHide: ((String, UInt64) -> Void)?

    var showCount = 0
    var hideReasons: [String] = []

    func show(
        model: PreviewPanelViewModel,
        anchor: PreviewPanelAnchor,
        sessionEpoch: UInt64,
        onAction: @escaping (PreviewPanelAction) -> Void
    ) {
        showCount += 1
    }

    func update(model: PreviewPanelViewModel) {}

    func hide(reason: String) {
        hideReasons.append(reason)
    }

    func hideImmediately(reason: String) {
        hideReasons.append(reason)
    }

    func isMouseInsidePanel(_ point: CGPoint) -> Bool { false }

    func panelFrame() -> CGRect? { nil }
}

@MainActor
private final class OrchestratorFakeHoverDelayCancellation: HoverDelayCancellation {
    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
    }
}

@MainActor
private final class OrchestratorFakeHoverDelayScheduler: HoverDelayScheduling {
    private(set) var scheduledMilliseconds: [Int] = []
    private(set) var actions: [@MainActor () -> Void] = []
    private(set) var tokens: [OrchestratorFakeHoverDelayCancellation] = []

    func schedule(
        afterMilliseconds milliseconds: Int,
        action: @escaping @MainActor () -> Void
    ) -> HoverDelayCancellation {
        let token = OrchestratorFakeHoverDelayCancellation()
        scheduledMilliseconds.append(milliseconds)
        actions.append(action)
        tokens.append(token)
        return token
    }
}

@MainActor
private final class OrchestratorFakeFrontmostApplicationProvider: FrontmostApplicationProviding {
    var app: NSRunningApplication?

    init(app: NSRunningApplication?) {
        self.app = app
    }

    func frontmostApplication() -> NSRunningApplication? {
        app
    }
}

@MainActor
private final class ProbeOrchestratorPreviewHarness {
    let logger = ProbeLogger()
    let permissionService: OrchestratorFakePermissionService
    let display = OrchestratorFakePreviewDisplay()
    let scheduler: OrchestratorFakeHoverDelayScheduler
    let settingsStore: OrchestratorFakeSettingsStore
    let frontmostProvider: OrchestratorFakeFrontmostApplicationProvider
    let targetTracker: AppTargetTracker
    let windowPeekCoordinator = OrchestratorRecordingWindowPeekCoordinator()
    let orchestrator: ProbeOrchestrator

    init(
        accessibilityGranted: Bool = true,
        screenRecordingGranted: Bool,
        settingsStore: OrchestratorFakeSettingsStore = OrchestratorFakeSettingsStore(),
        scheduler: OrchestratorFakeHoverDelayScheduler = OrchestratorFakeHoverDelayScheduler(),
        targetTracker: AppTargetTracker? = nil,
        frontmostApp: NSRunningApplication? = nil
    ) {
        self.settingsStore = settingsStore
        self.scheduler = scheduler
        self.frontmostProvider = OrchestratorFakeFrontmostApplicationProvider(app: frontmostApp)
        self.targetTracker = targetTracker ?? AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools")
        permissionService = OrchestratorFakePermissionService(
            accessibilityGranted: accessibilityGranted,
            screenRecordingGranted: screenRecordingGranted
        )
        let previewSessionController = PreviewSessionController(
            permissionService: permissionService,
            windowQueryService: OrchestratorFakeWindowQueryService(),
            thumbnailService: OrchestratorFakeThumbnailService(),
            activationService: OrchestratorFakeActivationService(),
            windowOperationService: OrchestratorFakeWindowOperationService(),
            panelDisplay: display,
            settingsStore: settingsStore,
            targetTracker: self.targetTracker,
            windowPeekCoordinator: windowPeekCoordinator,
            windowDestroyedObserver: OrchestratorFakeWindowDestroyedObserver(),
            logger: logger
        )
        orchestrator = ProbeOrchestrator(
            permissionService: permissionService,
            logger: logger,
            previewSessionController: previewSessionController,
            settingsStore: settingsStore,
            targetTracker: self.targetTracker,
            hoverDelayScheduler: scheduler,
            frontmostApplicationProvider: frontmostProvider
        )
    }
}

@MainActor
private final class OrchestratorFakeWindowDestroyedObserver: WindowDestroyedObserving {
    func observeWindow(
        id: PreviewWindowID,
        element: AXUIElement?,
        onDestroyed: @escaping @MainActor (PreviewWindowID) -> Void
    ) -> (any WindowDestroyedObservation)? {
        nil
    }
}

@MainActor
private final class OrchestratorRecordingWindowPeekCoordinator: WindowPeekCoordinating {
    private(set) var stopReasons: [WindowPeekStopReason] = []

    func beginSession(epoch: UInt64) {}

    func updateScreens(_ screens: [WindowPeekScreen], sessionEpoch: UInt64) {}

    func hoverEntered(
        windowID: PreviewWindowID,
        window: PreviewWindow?,
        coarseImage: CGImage?,
        sessionEpoch: UInt64,
        sequence: UInt64
    ) {}

    func hoverExited(windowID: PreviewWindowID, sessionEpoch: UInt64, sequence: UInt64) {}

    func coarseImageDidBecomeAvailable(_ image: CGImage?, for windowID: PreviewWindowID, sessionEpoch: UInt64) {}

    func targetWindowDestroyed(_ windowID: PreviewWindowID) {}

    func targetApplicationTerminated(pid: pid_t) {}

    func stop(reason: WindowPeekStopReason) {
        stopReasons.append(reason)
    }

    func completePrimarySelectionHandoff() {}
}

@MainActor
private final class OrchestratorFakeSettingsStore: DockHoverPreviewSettingsStore {
    private(set) var observers: [UUID: @MainActor (DockHoverPreviewSettings) -> Void] = [:]
    var snapshot = DockHoverPreviewSettings.defaults

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
        transform(&snapshot)
        notifyObservers()
    }

    func replaceSnapshot(_ next: DockHoverPreviewSettings) {
        snapshot = next
        notifyObservers()
    }

    private func notifyObservers() {
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

@MainActor
private func waitForPreviewDisplayChange(_ display: OrchestratorFakePreviewDisplay) async {
    for _ in 0..<20 where display.hideReasons.isEmpty && display.showCount == 0 {
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}
