import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var logger: ProbeLogger!
    private var permissionService: PermissionService!
    private var settingsStore: DockHoverPreviewSettingsStore!
    private var targetTracker: AppTargetTracker!
    private var previewPanelController: PreviewPanelController!
    private var previewSessionController: PreviewSessionController!
    private var menuBarController: MenuBarController!
    private var settingsViewModel: SettingsViewModel!
    private var settingsWindowController: SettingsWindowController!
    private var launchAtLoginService: LaunchAtLoginService!
    private var appNameResolver: AppNameResolving!
    private var appMetadataProvider: CachedAppMetadataProvider!
    private var appStatusProvider: LiveAppStatusProvider!
    private var diagnosticExportService: DiagnosticExportService!
    private var diagnosticExportPresenter: DiagnosticExportPresenter!
    private var excludedAppSelectionPresenter: ExcludedAppSelectionPresenting!
    private var orchestrator: ProbeOrchestrator!

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        logger = ProbeLogger()
        permissionService = SystemPermissionService(logger: logger)
        settingsStore = UserDefaultsSettingsStore(logger: logger)
        targetTracker = AppTargetTracker(selfBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.zong.zongMacTools")
        targetTracker.startWorkspaceObservation()
        launchAtLoginService = SystemLaunchAtLoginService()
        appNameResolver = WorkspaceAppNameResolver()
        appMetadataProvider = CachedAppMetadataProvider()
        appStatusProvider = LiveAppStatusProvider(
            permissionService: permissionService,
            launchAtLoginService: launchAtLoginService,
            settingsStore: settingsStore,
            metadataProvider: { [weak appMetadataProvider] in
                appMetadataProvider?.currentMetadata() ?? AppMetadata()
            }
        )
        diagnosticExportService = DiagnosticExportService(
            logger: logger
        )
        diagnosticExportPresenter = DiagnosticExportPresenter(
            exportService: diagnosticExportService,
            statusProvider: appStatusProvider
        )
        excludedAppSelectionPresenter = AppKitExcludedAppSelectionPresenter()
        settingsViewModel = SettingsViewModel(
            settingsStore: settingsStore,
            launchAtLoginService: launchAtLoginService,
            targetTracker: targetTracker,
            appNameResolver: appNameResolver,
            excludedAppSelectionPresenter: excludedAppSelectionPresenter,
            logger: logger
        )
        settingsWindowController = SettingsWindowController(
            settingsViewModel: settingsViewModel,
            permissionService: permissionService,
            appStatusProvider: appStatusProvider,
            diagnosticExportPresenter: diagnosticExportPresenter
        )
        previewPanelController = PreviewPanelController(logger: logger)
        let windowQueryService: WindowQueryService = ScreenCaptureWindowQueryService(logger: logger)
        let thumbnailService: ThumbnailService = StaticThumbnailService(logger: logger)
        let activationService: ActivationService = AXActivationService(logger: logger)
        let windowOperationService: WindowOperationService = AXWindowOperationService(
            activationService: activationService,
            logger: logger
        )
        previewSessionController = PreviewSessionController(
            permissionService: permissionService,
            windowQueryService: windowQueryService,
            thumbnailService: thumbnailService,
            activationService: activationService,
            windowOperationService: windowOperationService,
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
            settingsStore: settingsStore,
            diagnosticExportPresenter: diagnosticExportPresenter,
            settingsWindowPresenter: settingsWindowController,
            logger: logger
        )
        menuBarController.install()
        orchestrator.start()
        logger.info("app.launched bundleIdentifier=\(Bundle.main.bundleIdentifier ?? "com.zong.zongMacTools")")
    }

    @MainActor func applicationWillTerminate(_ notification: Notification) {
        previewSessionController.stopObservingSettings()
        orchestrator.stop()
        targetTracker.stopWorkspaceObservation()
        logger.info("app.terminated")
    }
}
