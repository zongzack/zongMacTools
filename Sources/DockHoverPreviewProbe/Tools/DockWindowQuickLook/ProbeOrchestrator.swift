import AppKit

struct HoverPreviewCandidate {
    let app: NSRunningApplication
    let bundleIdentifier: String
    let dockItemFrame: CGRect?
}

@MainActor
final class ProbeOrchestrator: DockHoverMonitorDelegate {
    private let permissionService: PermissionService
    private let logger: ProbeLogger
    private let previewSessionController: PreviewSessionController
    private let settingsStore: DockWindowQuickLookSettingsStore
    private let targetTracker: AppTargetTracker
    private let hoverDelayScheduler: HoverDelayScheduling
    private let frontmostApplicationProvider: FrontmostApplicationProviding

    private lazy var dockHoverMonitor = DockHoverMonitor(logger: logger)
    private var pendingHoverCancellation: HoverDelayCancellation?
    private var pendingHoverBundleIdentifier: String?
    private var pendingHoverGeneration = 0
    private var settingsObserverToken: UUID?
    private var observedSettingsSnapshot: DockWindowQuickLookSettingsSnapshot?
    private var isStopping = false

    init(
        permissionService: PermissionService,
        logger: ProbeLogger,
        previewSessionController: PreviewSessionController,
        settingsStore: DockWindowQuickLookSettingsStore,
        targetTracker: AppTargetTracker,
        hoverDelayScheduler: HoverDelayScheduling = DispatchHoverDelayScheduler(),
        frontmostApplicationProvider: FrontmostApplicationProviding = WorkspaceFrontmostApplicationProvider()
    ) {
        self.permissionService = permissionService
        self.logger = logger
        self.previewSessionController = previewSessionController
        self.settingsStore = settingsStore
        self.targetTracker = targetTracker
        self.hoverDelayScheduler = hoverDelayScheduler
        self.frontmostApplicationProvider = frontmostApplicationProvider
        self.dockHoverMonitor.delegate = self
    }

    func start() {
        startObservingSettings()
        let state = permissionService.refresh()
        logger.info("orchestrator.start accessibility=\(state.accessibilityGranted) screenRecording=\(state.screenRecordingGranted)")
        if state.accessibilityGranted {
            dockHoverMonitor.start()
        } else {
            logger.warning("orchestrator.dockSkipped accessibility=false")
        }
    }

    func stop() {
        cancelPendingHover()
        stopObservingSettings()
        previewSessionController.hide(reason: "orchestratorStop")
        isStopping = true
        dockHoverMonitor.stop()
        isStopping = false
        logger.info("orchestrator.stop")
    }

    func showFrontmostAppProbe() {
        guard permissionService.refresh().screenRecordingGranted else {
            previewSessionController.hide(reason: "screenRecording=false")
            logger.warning("debug.frontmost.skipped screenRecording=false")
            return
        }
        guard let app = frontmostApplicationProvider.frontmostApplication() else {
            logger.warning("debug.frontmost.noApp")
            return
        }
        if isExcluded(app.bundleIdentifier, in: settingsStore.dockWindowQuickLookSettingsSnapshot) {
            previewSessionController.hide(reason: "appExcluded")
            logger.info("debug.frontmost.skipped reason=appExcluded bundle=\(app.bundleIdentifier ?? "nil")")
            return
        }
        let anchor = makeAnchor(dockItemFrame: nil)
        logger.info("debug.frontmost.start app=\(app.localizedName ?? "unknown") bundle=\(app.bundleIdentifier ?? "nil") pid=\(app.processIdentifier)")
        Task { @MainActor [weak self] in
            await self?.previewSessionController.showPreview(for: app, anchor: anchor)
        }
    }

    func dockHoverMonitor(_ monitor: DockHoverMonitor, didHover app: HoveredDockApp) {
        targetTracker.updateLatestHoveredDockApp(
            AppTarget(
                bundleIdentifier: app.bundleIdentifier,
                displayName: app.app.localizedName ?? app.bundleIdentifier
            )
        )
        let candidate = HoverPreviewCandidate(
            app: app.app,
            bundleIdentifier: app.bundleIdentifier,
            dockItemFrame: app.dockItemFrame
        )
        schedulePreviewAfterDelay(candidate: candidate) { [weak monitor] in
            guard let hovered = monitor?.resolveCurrentHoveredDockApp() else {
                return nil
            }
            return HoverPreviewCandidate(
                app: hovered.app,
                bundleIdentifier: hovered.bundleIdentifier,
                dockItemFrame: hovered.dockItemFrame
            )
        }
    }

    func dockHoverMonitorDidLoseHover(_ monitor: DockHoverMonitor) {
        guard !isStopping else {
            return
        }
        cancelPendingHover()
        let mouse = NSEvent.mouseLocation
        if previewSessionController.isMouseInsidePanelTransitionRegion(mouse) {
            logger.info("dock.hoverLost.panelRetained")
            return
        }
        previewSessionController.hide(reason: "hoverLost")
        logger.info("dock.hoverLost.orchestrator")
    }

    func schedulePreviewAfterDelayForTesting(
        app: NSRunningApplication,
        bundleIdentifier: String,
        dockItemFrame: CGRect?
    ) {
        let candidate = HoverPreviewCandidate(
            app: app,
            bundleIdentifier: bundleIdentifier,
            dockItemFrame: dockItemFrame
        )
        schedulePreviewAfterDelay(candidate: candidate) {
            candidate
        }
    }

    func validateDelayedHoverForTesting(
        candidate: HoverPreviewCandidate,
        resolved: HoverPreviewCandidate?,
        mouseInside: Bool
    ) {
        validateDelayedHover(candidate: candidate, resolved: resolved, mouseInside: mouseInside)
    }

    private func startObservingSettings() {
        guard settingsObserverToken == nil else {
            return
        }
        observedSettingsSnapshot = settingsStore.dockWindowQuickLookSettingsSnapshot
        settingsObserverToken = settingsStore.addDockWindowQuickLookSettingsObserver { [weak self] settings in
            self?.settingsDidChange(settings)
        }
    }

    private func stopObservingSettings() {
        guard let settingsObserverToken else {
            return
        }
        settingsStore.removeObserver(settingsObserverToken)
        self.settingsObserverToken = nil
        observedSettingsSnapshot = nil
    }

    private func settingsDidChange(_ settings: DockWindowQuickLookSettingsSnapshot) {
        let previousSettings = observedSettingsSnapshot ?? settings
        let pendingBundleIdentifier = pendingHoverBundleIdentifier
        let currentPreviewBundleIdentifier = targetTracker.currentPreviewBundleIdentifier
        defer {
            observedSettingsSnapshot = settings
        }

        if previousSettings.isDockHoverPreviewEnabled && !settings.isDockHoverPreviewEnabled {
            cancelPendingHoverForSettings(reason: "settingsDisabled")
            previewSessionController.hide(reason: "settingsDisabled")
            logger.info("dock.hoverSkipped reason=settingsDisabled source=settingsObserver")
            return
        }

        if previousSettings.hoverDelayMilliseconds != settings.hoverDelayMilliseconds {
            cancelPendingHoverForSettings(reason: "settingsChanged")
        }

        let newlyExcludedBundleIdentifiers = settings.excludedAppBundleIdentifiers
            .subtracting(previousSettings.excludedAppBundleIdentifiers)
        guard !newlyExcludedBundleIdentifiers.isEmpty else {
            return
        }

        let excludedMatchingBundleIdentifier = [pendingBundleIdentifier, currentPreviewBundleIdentifier]
            .compactMap { $0 }
            .first { newlyExcludedBundleIdentifiers.contains($0) }
        guard let excludedMatchingBundleIdentifier else {
            return
        }

        cancelPendingHoverForSettings(reason: "appExcluded")
        previewSessionController.hide(reason: "appExcluded")
        logger.info("dock.hoverSkipped reason=appExcluded source=settingsObserver bundle=\(excludedMatchingBundleIdentifier)")
    }

    private func schedulePreviewAfterDelay(
        candidate: HoverPreviewCandidate,
        resolveCurrentCandidate: @escaping @MainActor () -> HoverPreviewCandidate?
    ) {
        cancelPendingHover()

        let settings = settingsStore.dockWindowQuickLookSettingsSnapshot
        guard settings.isDockHoverPreviewEnabled else {
            previewSessionController.hide(reason: "settingsDisabled")
            logger.info("dock.hoverSkipped reason=settingsDisabled bundle=\(candidate.bundleIdentifier)")
            return
        }
        guard !settings.excludedAppBundleIdentifiers.contains(candidate.bundleIdentifier) else {
            previewSessionController.hide(reason: "appExcluded")
            logger.info("dock.hoverSkipped reason=appExcluded bundle=\(candidate.bundleIdentifier)")
            return
        }

        pendingHoverGeneration += 1
        let hoverGeneration = pendingHoverGeneration
        pendingHoverBundleIdentifier = candidate.bundleIdentifier
        pendingHoverCancellation = hoverDelayScheduler.schedule(afterMilliseconds: settings.hoverDelayMilliseconds) { [weak self] in
            guard let self else { return }
            guard self.isCurrentPendingHover(hoverGeneration) else { return }
            let resolved = resolveCurrentCandidate()
            self.handleDelayedHover(candidate: candidate, resolved: resolved, generation: hoverGeneration)
        }
    }

    private func handleDelayedHover(
        candidate: HoverPreviewCandidate,
        resolved: HoverPreviewCandidate?,
        generation: Int
    ) {
        guard isCurrentPendingHover(generation) else {
            return
        }
        pendingHoverCancellation = nil
        pendingHoverBundleIdentifier = nil
        let validationFrame = resolved?.dockItemFrame
        let mouseInside = validationFrame.map {
            GeometryHelpers.containsDockItemHover(
                NSEvent.mouseLocation,
                dockItemFrame: $0,
                screenFrame: makeAnchor(dockItemFrame: $0).screenFrame,
                tolerance: 2
            )
        } ?? false
        validateDelayedHover(candidate: candidate, resolved: resolved, mouseInside: mouseInside)
    }

    private func validateDelayedHover(
        candidate: HoverPreviewCandidate,
        resolved: HoverPreviewCandidate?,
        mouseInside: Bool
    ) {
        let matches = resolved?.bundleIdentifier == candidate.bundleIdentifier
        let validationFrame = resolved?.dockItemFrame
        logger.info("dock.hoverDelayed bundle=\(candidate.bundleIdentifier) matches=\(matches) mouseInside=\(mouseInside) frame=\(String(describing: validationFrame))")

        let settings = settingsStore.dockWindowQuickLookSettingsSnapshot
        guard settings.isDockHoverPreviewEnabled else {
            previewSessionController.hide(reason: "settingsDisabled")
            logger.info("dock.hoverDelayed.skipped reason=settingsDisabled bundle=\(candidate.bundleIdentifier)")
            return
        }
        guard !settings.excludedAppBundleIdentifiers.contains(candidate.bundleIdentifier) else {
            previewSessionController.hide(reason: "appExcluded")
            logger.info("dock.hoverDelayed.skipped reason=appExcluded bundle=\(candidate.bundleIdentifier)")
            return
        }
        guard matches, mouseInside, let resolved else {
            previewSessionController.hide(reason: "hoverValidationFailed")
            return
        }

        let anchor = makeAnchor(dockItemFrame: validationFrame)
        Task { @MainActor [previewSessionController] in
            await previewSessionController.showPreview(for: resolved.app, anchor: anchor)
        }
    }

    private func cancelPendingHover() {
        pendingHoverCancellation?.cancel()
        pendingHoverCancellation = nil
        pendingHoverBundleIdentifier = nil
        pendingHoverGeneration += 1
    }

    private func cancelPendingHoverForSettings(reason: String) {
        let hadPendingHover = pendingHoverCancellation != nil || pendingHoverBundleIdentifier != nil
        cancelPendingHover()
        if hadPendingHover {
            logger.info("orchestrator.pendingHoverCancelled reason=\(reason) source=settingsObserver")
        }
    }

    private func isCurrentPendingHover(_ generation: Int) -> Bool {
        generation == pendingHoverGeneration
    }

    private func isExcluded(_ bundleIdentifier: String?, in settings: DockWindowQuickLookSettingsSnapshot) -> Bool {
        guard let bundleIdentifier else {
            return false
        }
        return settings.excludedAppBundleIdentifiers.contains(bundleIdentifier)
    }

    private func makeAnchor(dockItemFrame: CGRect?) -> PreviewPanelAnchor {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { GeometryHelpers.contains(mouse, in: $0.frame, tolerance: 0) }
            ?? NSScreen.main
        let screenFrame = screen?.frame ?? CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visibleFrame = screen?.visibleFrame ?? screenFrame
        return PreviewPanelAnchor(
            dockItemFrame: dockItemFrame,
            mouseLocation: mouse,
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )
    }
}
