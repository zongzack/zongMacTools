import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var logger: ProbeLogger!
    private var permissionService: PermissionService!
    private var settingsStore: DockHoverPreviewSettingsStore!
    private var targetTracker: AppTargetTracker!
    private var previewPanelController: PreviewPanelController!
    private var previewSessionController: PreviewSessionController!
    private var menuBarController: MenuBarController!
    private var launchAtLoginService: LaunchAtLoginService!
    private var orchestrator: ProbeOrchestrator!

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        logger = ProbeLogger()
        permissionService = SystemPermissionService(logger: logger)
        settingsStore = UserDefaultsSettingsStore(logger: logger)
        targetTracker = AppTargetTracker(selfBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.zong.DockHoverPreviewProbe")
        targetTracker.startWorkspaceObservation()
        launchAtLoginService = SystemLaunchAtLoginService()
        previewPanelController = PreviewPanelController(logger: logger)
        let windowQueryService: WindowQueryService = ScreenCaptureWindowQueryService(logger: logger)
        let thumbnailService: ThumbnailService = StaticThumbnailService(logger: logger)
        let activationService: ActivationService = AXActivationService(logger: logger)
        previewSessionController = PreviewSessionController(
            permissionService: permissionService,
            windowQueryService: windowQueryService,
            thumbnailService: thumbnailService,
            activationService: activationService,
            panelDisplay: previewPanelController,
            settingsStore: settingsStore,
            targetTracker: targetTracker,
            logger: logger
        )
        previewSessionController.startObservingSettings()
        previewPanelController.onRequestHide = { [weak previewSessionController] reason in
            Task { @MainActor in
                previewSessionController?.hide(reason: reason)
            }
        }
        orchestrator = ProbeOrchestrator(
            permissionService: permissionService,
            logger: logger,
            previewSessionController: previewSessionController,
            settingsStore: settingsStore,
            targetTracker: targetTracker
        )
        menuBarController = MenuBarController(
            permissionService: permissionService,
            orchestrator: orchestrator,
            settingsStore: settingsStore,
            launchAtLoginService: launchAtLoginService,
            targetTracker: targetTracker,
            logger: logger
        )
        menuBarController.install()
        orchestrator.start()
        logger.info("app.launched bundleIdentifier=com.zong.DockHoverPreviewProbe")
    }

    @MainActor func applicationWillTerminate(_ notification: Notification) {
        previewSessionController.stopObservingSettings()
        orchestrator.stop()
        targetTracker.stopWorkspaceObservation()
        logger.info("app.terminated")
    }
}
