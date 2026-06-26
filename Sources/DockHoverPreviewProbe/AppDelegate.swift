import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var logger: ProbeLogger!
    private var permissionService: PermissionService!
    private var menuBarController: MenuBarController!
    private var orchestrator: ProbeOrchestrator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger = ProbeLogger()
        permissionService = SystemPermissionService(logger: logger)
        orchestrator = ProbeOrchestrator(permissionService: permissionService, logger: logger)
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
