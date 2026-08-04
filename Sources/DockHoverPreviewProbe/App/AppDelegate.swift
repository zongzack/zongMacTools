import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var logger: ProbeLogger!
    private var permissionService: PermissionService!
    private var settingsStore: DockHoverPreviewSettingsStore!
    private var targetTracker: AppTargetTracker!
    private var previewPanelController: PreviewPanelController!
    private var previewSessionController: PreviewSessionController!
    private var menuBarController: MenuBarController!
    private var appSettingsViewModel: AppSettingsViewModel!
    private var dockWindowQuickLookSettingsViewModel: DockWindowQuickLookSettingsViewModel!
    private var settingsViewModel: SettingsViewModel!
    private var settingsWindowController: SettingsWindowController!
    private var launchAtLoginService: LaunchAtLoginService!
    private var appNameResolver: AppNameResolving!
    private var appMetadataProvider: CachedAppMetadataProvider!
    private var appStatusProvider: LiveAppStatusProvider!
    private var diagnosticExportService: DiagnosticExportService!
    private var diagnosticExportPresenter: DiagnosticExportPresenter!
    private var excludedAppSelectionPresenter: ExcludedAppSelectionPresenting!
    private var screenCaptureKitCaptureBroker: ScreenCaptureKitCaptureBroker!
    private var windowPeekLifecycleObserver: WindowPeekLifecycleObserver!
    private var windowPeekCoordinator: WindowPeekCoordinator!
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
        appSettingsViewModel = AppSettingsViewModel(
            settingsStore: settingsStore,
            launchAtLoginService: launchAtLoginService,
            logger: logger
        )
        dockWindowQuickLookSettingsViewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: settingsStore,
            targetTracker: targetTracker,
            appNameResolver: appNameResolver,
            excludedAppSelectionPresenter: excludedAppSelectionPresenter,
            logger: logger
        )
        settingsViewModel = SettingsViewModel(
            appSettings: appSettingsViewModel,
            dockWindowQuickLookSettings: dockWindowQuickLookSettingsViewModel
        )
        settingsWindowController = SettingsWindowController(
            settingsViewModel: settingsViewModel,
            permissionService: permissionService,
            appStatusProvider: appStatusProvider,
            diagnosticExportPresenter: diagnosticExportPresenter
        )
        previewPanelController = PreviewPanelController(logger: logger)
        screenCaptureKitCaptureBroker = ScreenCaptureKitCaptureBroker(logger: logger)
        let windowQueryService: WindowQueryService = ScreenCaptureWindowQueryService(logger: logger)
        let thumbnailService: ThumbnailService = StaticThumbnailService(
            logger: logger,
            captureBroker: screenCaptureKitCaptureBroker
        )
        let captureBackend = ScreenCaptureKitWindowPeekCaptureBackend(
            logger: logger,
            captureBroker: screenCaptureKitCaptureBroker
        )
        let captureService = DefaultWindowPeekCaptureService(
            logger: logger,
            backend: captureBackend
        )
        let activationService: ActivationService = AXActivationService(logger: logger)
        let windowOperationService: WindowOperationService = AXWindowOperationService(
            activationService: activationService,
            logger: logger
        )
        let lifecycleObserver = WindowPeekLifecycleObserver(
            workspaceNotificationCenter: NSWorkspace.shared.notificationCenter,
            applicationNotificationCenter: NotificationCenter.default,
            destroyedObserver: SystemWindowDestroyedObserver(logger: logger),
            logger: logger
        )
        windowPeekLifecycleObserver = lifecycleObserver
        let overlay = WindowPeekOverlayController(logger: logger)
        let coordinator = WindowPeekCoordinator(
            captureService: captureService,
            overlay: overlay,
            settingsStore: settingsStore,
            permissionService: permissionService,
            logger: logger,
            permissionRefreshScheduler: MainRunLoopWindowPeekPermissionRefreshScheduler(),
            onCurrentTargetChanged: { [weak lifecycleObserver] target in
                lifecycleObserver?.observeTargetWindow(
                    id: target?.id,
                    element: target?.axElement
                )
            }
        )
        windowPeekCoordinator = coordinator
        previewSessionController = PreviewSessionController(
            permissionService: permissionService,
            windowQueryService: windowQueryService,
            thumbnailService: thumbnailService,
            activationService: activationService,
            windowOperationService: windowOperationService,
            panelDisplay: previewPanelController,
            settingsStore: settingsStore,
            targetTracker: targetTracker,
            windowPeekCoordinator: coordinator,
            logger: logger
        )
        previewSessionController.startObservingSettings()
        previewPanelController.onRequestHide = { [weak previewSessionController] reason, epoch in
            previewSessionController?.hide(reason: reason, expectedSessionEpoch: epoch)
        }
        lifecycleObserver.start { [weak coordinator, weak previewSessionController] event in
            switch event {
            case .activeSpaceChanged:
                if let previewSessionController {
                    previewSessionController.invalidateWindowPeekScreens(reason: .activeSpaceChanged)
                } else {
                    coordinator?.stop(reason: .activeSpaceChanged)
                }
            case .screenParametersChanged:
                if let previewSessionController {
                    previewSessionController.invalidateWindowPeekScreens(reason: .screenParametersChanged)
                } else {
                    coordinator?.stop(reason: .screenParametersChanged)
                }
            case let .applicationTerminated(pid):
                coordinator?.targetApplicationTerminated(pid: pid)
            case let .targetWindowDestroyed(id):
                coordinator?.targetWindowDestroyed(id)
            }
        }
        coordinator.startObservingSettings()
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
        windowPeekCoordinator.stop(reason: .appTermination)
        windowPeekLifecycleObserver.stop()
        previewSessionController.stopObservingSettings()
        orchestrator.stop()
        windowPeekCoordinator.stopObservingSettings()
        targetTracker.stopWorkspaceObservation()
        logger.info("app.terminated")
    }
}
