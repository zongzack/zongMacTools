import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var logger: ProbeLogger!
    private var permissionService: PermissionService!
    private var previewPanelController: PreviewPanelController!
    private var previewSessionController: PreviewSessionController!
    private var menuBarController: MenuBarController!
    private var orchestrator: ProbeOrchestrator!

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        logger = ProbeLogger()
        permissionService = SystemPermissionService(logger: logger)
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
            logger: logger
        )
        orchestrator = ProbeOrchestrator(
            permissionService: permissionService,
            logger: logger,
            previewSessionController: previewSessionController
        )
        menuBarController = MenuBarController(permissionService: permissionService, orchestrator: orchestrator, logger: logger)
        menuBarController.install()
        orchestrator.start()
        logger.info("app.launched bundleIdentifier=com.zong.DockHoverPreviewProbe")
    }

    func applicationWillTerminate(_ notification: Notification) {
        orchestrator.stop()
        logger.info("app.terminated")
    }
}
