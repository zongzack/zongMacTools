import Combine
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testSettingsViewModelHasAppAndDockToolChildren() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let expectedFiles = [
            "Sources/DockHoverPreviewProbe/Settings/AppSettingsViewModel.swift",
            "Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/DockWindowQuickLookSettingsViewModel.swift"
        ]

        for relativePath in expectedFiles {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: packageRoot.appendingPathComponent(relativePath).path),
                "\(relativePath) should exist"
            )
        }

        let sourceURL = packageRoot
            .appendingPathComponent("Sources/DockHoverPreviewProbe/Settings/SettingsViewModel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(source.contains("let appSettings: AppSettingsViewModel"))
        XCTAssertTrue(source.contains("let dockWindowQuickLookSettings: DockWindowQuickLookSettingsViewModel"))
    }

    func testInitialSnapshotMapsToSplitUIStates() {
        let settings = DockHoverPreviewSettings.viewModelSettings(
            enabled: false,
            hoverDelayMilliseconds: 400,
            maxCardCount: 12,
            retention: .forgiving,
            excludedApps: ["com.example.Editor", "com.example.Unknown"],
            language: .simplifiedChinese
        )
        let store = RecordingSettingsStore(snapshot: settings)
        let launchAtLoginService = FakeLaunchAtLoginService(status: .requiresApproval)
        let targetTracker = AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools")
        targetTracker.updateCurrentPreviewApp(
            AppTarget(bundleIdentifier: "com.example.Editor", displayName: "Editor")
        )
        let appNameResolver = FakeAppNameResolver(displayNames: [
            "com.example.Editor": "Example Editor"
        ])

        let appViewModel = AppSettingsViewModel(
            settingsStore: store,
            launchAtLoginService: launchAtLoginService,
            logger: ProbeLogger()
        )
        let dockViewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: targetTracker,
            appNameResolver: appNameResolver,
            logger: ProbeLogger()
        )

        XCTAssertEqual(appViewModel.state.displayLanguage, .simplifiedChinese)
        XCTAssertEqual(appViewModel.state.launchAtLoginStatus, .requiresApproval)
        XCTAssertFalse(appViewModel.state.canEnableLaunchAtLogin)
        XCTAssertFalse(appViewModel.state.canDisableLaunchAtLogin)
        XCTAssertTrue(appViewModel.state.canOpenLaunchAtLoginSettings)
        XCTAssertFalse(dockViewModel.state.isDockWindowQuickLookEnabled)
        XCTAssertEqual(dockViewModel.state.hoverDelayMilliseconds, 400)
        XCTAssertEqual(dockViewModel.state.hoverDelaySliderIndex, 2)
        XCTAssertEqual(dockViewModel.state.panelRetentionMode, .forgiving)
        XCTAssertEqual(dockViewModel.state.panelRetentionSliderIndex, 2)
        XCTAssertEqual(dockViewModel.state.maxCardCount, 12)
        XCTAssertEqual(dockViewModel.state.maxCardSliderIndex, 3)
        XCTAssertEqual(dockViewModel.state.displayLanguage, .simplifiedChinese)
        XCTAssertEqual(
            dockViewModel.state.excludedApps.map(\.title),
            ["Example Editor (com.example.Editor)", "com.example.Unknown"]
        )
        XCTAssertEqual(dockViewModel.state.currentExclusionTarget?.bundleIdentifier, "com.example.Editor")
        XCTAssertTrue(dockViewModel.state.isCurrentExclusionTargetExcluded)
    }

    func testStoreObserverRefreshesSplitMappedStates() {
        let store = RecordingSettingsStore(snapshot: .defaults)
        let appViewModel = AppSettingsViewModel(
            settingsStore: store,
            launchAtLoginService: FakeLaunchAtLoginService(),
            logger: ProbeLogger()
        )
        let dockViewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
            logger: ProbeLogger()
        )

        store.replaceSnapshot(.viewModelSettings(
            enabled: false,
            hoverDelayMilliseconds: 150,
            maxCardCount: 3,
            retention: .tight,
            excludedApps: ["com.example.One"],
            language: .simplifiedChinese
        ))

        XCTAssertEqual(appViewModel.state.displayLanguage, .simplifiedChinese)
        XCTAssertFalse(dockViewModel.state.isDockWindowQuickLookEnabled)
        XCTAssertEqual(dockViewModel.state.hoverDelayMilliseconds, 150)
        XCTAssertEqual(dockViewModel.state.hoverDelaySliderIndex, 0)
        XCTAssertEqual(dockViewModel.state.panelRetentionMode, .tight)
        XCTAssertEqual(dockViewModel.state.panelRetentionSliderIndex, 0)
        XCTAssertEqual(dockViewModel.state.maxCardCount, 3)
        XCTAssertEqual(dockViewModel.state.maxCardSliderIndex, 0)
        XCTAssertEqual(dockViewModel.state.displayLanguage, .simplifiedChinese)
        XCTAssertEqual(dockViewModel.state.excludedApps.map(\.bundleIdentifier), ["com.example.One"])
    }

    func testNonPresetUserDefaultsValuesFallBackBeforeMappingToUIState() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(999, forKey: SettingsKey.hoverDelayMilliseconds.rawValue)
        defaults.set(7, forKey: SettingsKey.maxCardCount.rawValue)

        let logger = ProbeLogger()
        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: logger)
        let viewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
            logger: logger
        )

        XCTAssertEqual(viewModel.state.hoverDelayMilliseconds, 250)
        XCTAssertEqual(viewModel.state.hoverDelaySliderIndex, 1)
        XCTAssertEqual(viewModel.state.maxCardCount, 8)
        XCTAssertEqual(viewModel.state.maxCardSliderIndex, 2)
        XCTAssertTrue(logger.snapshot().contains { $0.contains("settings.invalid") })
    }

    func testSliderIndexesClampRoundAndOnlyWritePresetValues() {
        let store = RecordingSettingsStore(snapshot: .defaults)
        let viewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
            logger: ProbeLogger()
        )

        viewModel.setHoverDelaySliderIndex(-2)
        viewModel.setHoverDelaySliderIndex(1.6)
        viewModel.setPanelRetentionSliderIndex(0.49)
        viewModel.setPanelRetentionSliderIndex(1.5)
        viewModel.setMaxCardSliderIndex(1.49)
        viewModel.setMaxCardSliderIndex(99)

        XCTAssertEqual(store.writtenSnapshots.map(\.hoverDelayMilliseconds), [150, 400, 400, 400, 400, 400])
        XCTAssertEqual(store.writtenSnapshots.map(\.panelRetentionMode), [
            .standard, .standard, .tight, .forgiving, .forgiving, .forgiving
        ])
        XCTAssertEqual(store.writtenSnapshots.map(\.maxCardCount), [8, 8, 8, 8, 5, 12])
        XCTAssertTrue(store.writtenSnapshots.allSatisfy { snapshot in
            DockHoverPreviewSettings.validHoverDelayMilliseconds.contains(snapshot.hoverDelayMilliseconds)
                && DockHoverPreviewSettings.validMaxCardCounts.contains(snapshot.maxCardCount)
        })
        XCTAssertEqual(viewModel.state.hoverDelaySliderIndex, 2)
        XCTAssertEqual(viewModel.state.panelRetentionSliderIndex, 2)
        XCTAssertEqual(viewModel.state.maxCardSliderIndex, 3)
    }

    func testSplitSettingIntentsWriteOnlySettingsStore() {
        let store = RecordingSettingsStore(snapshot: .viewModelSettings(
            enabled: true,
            hoverDelayMilliseconds: 250,
            maxCardCount: 8,
            retention: .standard,
            excludedApps: ["com.example.One"],
            language: .english
        ))
        let appViewModel = AppSettingsViewModel(
            settingsStore: store,
            launchAtLoginService: FakeLaunchAtLoginService(),
            logger: ProbeLogger()
        )
        let dockViewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
            logger: ProbeLogger()
        )

        dockViewModel.toggleDockWindowQuickLook()
        appViewModel.setDisplayLanguage(.simplifiedChinese)

        XCTAssertEqual(store.writtenSnapshots.count, 2)
        XCTAssertFalse(store.snapshot.isDockHoverPreviewEnabled)
        XCTAssertEqual(store.snapshot.displayLanguage, .simplifiedChinese)
        XCTAssertEqual(store.snapshot.hoverDelayMilliseconds, 250)
        XCTAssertEqual(store.snapshot.panelRetentionMode, .standard)
        XCTAssertEqual(store.snapshot.maxCardCount, 8)
        XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers, ["com.example.One"])
    }

    func testCurrentExclusionUsesTrackerTargetPriorityAndTogglesExcludeAndRestore() {
        let store = RecordingSettingsStore(snapshot: .defaults)
        let targetTracker = AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools")
        targetTracker.updateLatestNonSelfActiveApp(
            AppTarget(bundleIdentifier: "com.apple.TextEdit", displayName: "TextEdit")
        )
        targetTracker.updateLatestHoveredDockApp(
            AppTarget(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
        )
        targetTracker.updateCurrentPreviewApp(
            AppTarget(bundleIdentifier: "com.microsoft.VSCode", displayName: "Code")
        )
        let viewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: targetTracker,
            logger: ProbeLogger()
        )

        viewModel.toggleCurrentExclusionTarget()

        XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers, ["com.microsoft.VSCode"])
        XCTAssertTrue(viewModel.state.isCurrentExclusionTargetExcluded)

        viewModel.toggleCurrentExclusionTarget()

        XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers, [])
        XCTAssertFalse(viewModel.state.isCurrentExclusionTargetExcluded)
    }

    func testCurrentExclusionNoOpsWithoutValidTrackerTarget() {
        let store = RecordingSettingsStore(snapshot: .defaults)
        let targetTracker = AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools")
        targetTracker.updateLatestNonSelfActiveApp(
            AppTarget(bundleIdentifier: "com.zong.zongMacTools", displayName: "zongMacTools")
        )
        let viewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: targetTracker,
            logger: ProbeLogger()
        )

        viewModel.toggleCurrentExclusionTarget()

        XCTAssertEqual(store.writtenSnapshots, [])
        XCTAssertNil(viewModel.state.currentExclusionTarget)
    }

    func testManualAddEntryCallsInjectedSelectionPresenterWithLocalizedTitle() {
        var settings = DockHoverPreviewSettings.defaults
        settings.displayLanguage = .simplifiedChinese
        let store = RecordingSettingsStore(snapshot: settings)
        let selectionPresenter = FakeExcludedAppSelectionPresenter(selection: nil)
        let viewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
            excludedAppSelectionPresenter: selectionPresenter,
            logger: ProbeLogger()
        )

        viewModel.addExcludedAppFromSelection()

        XCTAssertEqual(selectionPresenter.presentedTitles, ["\u{9009}\u{62E9}\u{8981}\u{6392}\u{9664}\u{7684} App"])
        XCTAssertEqual(store.writtenSnapshots, [])
    }

    func testSuccessfulManualSelectionWritesExcludedBundleIdentifier() {
        let store = RecordingSettingsStore(snapshot: .defaults)
        let selectionPresenter = FakeExcludedAppSelectionPresenter(
            selection: ExcludedAppSelection(bundleIdentifier: "com.example.Editor", displayName: "Editor")
        )
        let viewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
            excludedAppSelectionPresenter: selectionPresenter,
            logger: ProbeLogger()
        )

        viewModel.addExcludedAppFromSelection()

        XCTAssertEqual(selectionPresenter.presentedTitles, ["Choose App to Exclude"])
        XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers, ["com.example.Editor"])
        XCTAssertEqual(store.writtenSnapshots.count, 1)
    }

    func testCancelledManualSelectionDoesNotWriteSettingsStore() {
        let store = RecordingSettingsStore(snapshot: .defaults)
        let viewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
            excludedAppSelectionPresenter: FakeExcludedAppSelectionPresenter(selection: nil),
            logger: ProbeLogger()
        )

        viewModel.addExcludedAppFromSelection()

        XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers, [])
        XCTAssertEqual(store.writtenSnapshots, [])
    }

    func testManualAddRejectsEmptySelfInvalidAndDuplicateBundleIdentifiers() {
        let store = RecordingSettingsStore(snapshot: .viewModelSettings(
            enabled: true,
            hoverDelayMilliseconds: 250,
            maxCardCount: 8,
            retention: .standard,
            excludedApps: ["com.example.Existing"],
            language: .english
        ))
        let viewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
            selfBundleIdentifier: "com.zong.zongMacTools",
            logger: ProbeLogger()
        )

        XCTAssertFalse(viewModel.addExcludedApp(ExcludedAppSelection(bundleIdentifier: "", displayName: nil)))
        XCTAssertFalse(viewModel.addExcludedApp(ExcludedAppSelection(bundleIdentifier: "   ", displayName: nil)))
        XCTAssertFalse(viewModel.addExcludedApp(ExcludedAppSelection(bundleIdentifier: "bad id", displayName: nil)))
        XCTAssertFalse(viewModel.addExcludedApp(ExcludedAppSelection(
            bundleIdentifier: "com.zong.zongMacTools",
            displayName: "zongMacTools"
        )))
        XCTAssertFalse(viewModel.addExcludedApp(ExcludedAppSelection(
            bundleIdentifier: "com.example.Existing",
            displayName: "Existing"
        )))

        XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers, ["com.example.Existing"])
        XCTAssertEqual(store.writtenSnapshots, [])
    }

    func testManualAddOnlyMutatesExcludedSet() {
        let initialSettings = DockHoverPreviewSettings.viewModelSettings(
            enabled: false,
            hoverDelayMilliseconds: 400,
            maxCardCount: 12,
            retention: .forgiving,
            excludedApps: ["com.example.One"],
            language: .simplifiedChinese
        )
        let store = RecordingSettingsStore(snapshot: initialSettings)
        let viewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
            logger: ProbeLogger()
        )

        XCTAssertTrue(viewModel.addExcludedApp(
            ExcludedAppSelection(bundleIdentifier: "com.example.Two", displayName: "Example Two")
        ))

        var expected = initialSettings
        expected.excludedAppBundleIdentifiers = ["com.example.One", "com.example.Two"]
        XCTAssertEqual(store.snapshot, expected)
        XCTAssertEqual(store.writtenSnapshots, [expected])
    }

    func testRemoveAndClearExcludedAppsOnlyMutateExcludedSet() {
        let initialSettings = DockHoverPreviewSettings.viewModelSettings(
            enabled: false,
            hoverDelayMilliseconds: 400,
            maxCardCount: 12,
            retention: .forgiving,
            excludedApps: ["com.example.One", "com.example.Two"],
            language: .simplifiedChinese
        )
        let store = RecordingSettingsStore(snapshot: initialSettings)
        let viewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
            logger: ProbeLogger()
        )

        viewModel.removeExcludedApp(bundleIdentifier: "com.example.One")
        var expected = initialSettings
        expected.excludedAppBundleIdentifiers = ["com.example.Two"]
        XCTAssertEqual(store.snapshot, expected)

        viewModel.clearExcludedApps()
        expected.excludedAppBundleIdentifiers = []
        XCTAssertEqual(store.snapshot, expected)
    }

    func testLaunchAtLoginIntentsUseServiceStateAndSwallowFailures() {
        let logger = ProbeLogger()
        let launchAtLoginService = FakeLaunchAtLoginService(status: .notRegistered)
        launchAtLoginService.enableError = LaunchAtLoginTestError.failed
        let viewModel = AppSettingsViewModel(
            settingsStore: RecordingSettingsStore(snapshot: .defaults),
            launchAtLoginService: launchAtLoginService,
            logger: logger
        )

        viewModel.enableLaunchAtLogin()
        XCTAssertEqual(launchAtLoginService.enableCount, 1)
        XCTAssertTrue(logger.snapshot().contains { $0.contains("launchAtLogin.enableFailed") })

        launchAtLoginService.status = .enabled
        launchAtLoginService.disableError = LaunchAtLoginTestError.failed
        viewModel.refresh()
        viewModel.disableLaunchAtLogin()
        XCTAssertEqual(launchAtLoginService.disableCount, 1)
        XCTAssertTrue(logger.snapshot().contains { $0.contains("launchAtLogin.disableFailed") })

        launchAtLoginService.status = .requiresApproval
        viewModel.refresh()
        viewModel.openLaunchAtLoginSettings()
        XCTAssertEqual(launchAtLoginService.openSettingsCount, 1)

        launchAtLoginService.status = .notFound
        viewModel.refresh()
        viewModel.enableLaunchAtLogin()
        viewModel.disableLaunchAtLogin()
        XCTAssertEqual(launchAtLoginService.enableCount, 1)
        XCTAssertEqual(launchAtLoginService.disableCount, 1)
        XCTAssertEqual(viewModel.state.launchAtLoginStatus, .notFound)
    }

    func testCoordinatorRefreshForSettingsPresentationRefreshesBothChildren() {
        let store = RecordingSettingsStore(snapshot: .defaults)
        let launchAtLoginService = FakeLaunchAtLoginService(status: .notRegistered)
        let targetTracker = AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools")
        let appViewModel = AppSettingsViewModel(
            settingsStore: store,
            launchAtLoginService: launchAtLoginService,
            logger: ProbeLogger()
        )
        let dockViewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: targetTracker,
            logger: ProbeLogger()
        )
        let coordinator = SettingsViewModel(
            appSettings: appViewModel,
            dockWindowQuickLookSettings: dockViewModel
        )

        launchAtLoginService.status = .requiresApproval
        targetTracker.updateLatestHoveredDockApp(
            AppTarget(bundleIdentifier: "com.example.Editor", displayName: "Example Editor")
        )
        coordinator.refreshForSettingsPresentation()

        XCTAssertEqual(appViewModel.state.launchAtLoginStatus, .requiresApproval)
        XCTAssertEqual(
            dockViewModel.state.currentExclusionTarget,
            AppTarget(bundleIdentifier: "com.example.Editor", displayName: "Example Editor")
        )
    }

    func testCoordinatorPublishesWhenAppSettingsChange() async {
        let store = RecordingSettingsStore(snapshot: .defaults)
        let appViewModel = AppSettingsViewModel(
            settingsStore: store,
            launchAtLoginService: FakeLaunchAtLoginService(),
            logger: ProbeLogger()
        )
        let dockViewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
            logger: ProbeLogger()
        )
        let coordinator = SettingsViewModel(
            appSettings: appViewModel,
            dockWindowQuickLookSettings: dockViewModel
        )
        let published = expectation(description: "coordinator publishes app child changes")
        published.assertForOverFulfill = false
        let cancellable = coordinator.objectWillChange.sink { _ in
            published.fulfill()
        }

        appViewModel.setDisplayLanguage(.simplifiedChinese)

        await fulfillment(of: [published], timeout: 1)
        XCTAssertEqual(coordinator.displayLanguage, .simplifiedChinese)
        withExtendedLifetime(cancellable) {}
    }

    func testCoordinatorPublishesWhenDockSettingsChange() async {
        let store = RecordingSettingsStore(snapshot: .defaults)
        let appViewModel = AppSettingsViewModel(
            settingsStore: store,
            launchAtLoginService: FakeLaunchAtLoginService(),
            logger: ProbeLogger()
        )
        let dockViewModel = DockWindowQuickLookSettingsViewModel(
            settingsStore: store,
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
            logger: ProbeLogger()
        )
        let coordinator = SettingsViewModel(
            appSettings: appViewModel,
            dockWindowQuickLookSettings: dockViewModel
        )
        let published = expectation(description: "coordinator publishes dock child changes")
        published.assertForOverFulfill = false
        let cancellable = coordinator.objectWillChange.sink { _ in
            published.fulfill()
        }

        dockViewModel.toggleDockWindowQuickLook()

        await fulfillment(of: [published], timeout: 1)
        XCTAssertFalse(dockViewModel.state.isDockWindowQuickLookEnabled)
        withExtendedLifetime(cancellable) {}
    }

    private func makeTemporaryDefaults() -> (UserDefaults, String) {
        let suiteName = "SettingsViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

private enum LaunchAtLoginTestError: Error {
    case failed
}

@MainActor
private final class RecordingSettingsStore: DockHoverPreviewSettingsStore {
    private var observers: [UUID: @MainActor (DockHoverPreviewSettings) -> Void] = [:]
    private(set) var snapshot: DockHoverPreviewSettings
    private(set) var writtenSnapshots: [DockHoverPreviewSettings] = []

    init(snapshot: DockHoverPreviewSettings) {
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
        writtenSnapshots.append(snapshot)
        observers.values.forEach { $0(snapshot) }
    }

    func replaceSnapshot(_ snapshot: DockHoverPreviewSettings) {
        self.snapshot = snapshot
        observers.values.forEach { $0(snapshot) }
    }
}

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginStatus
    var enableError: Error?
    var disableError: Error?
    private(set) var enableCount = 0
    private(set) var disableCount = 0
    private(set) var openSettingsCount = 0

    init(status: LaunchAtLoginStatus = .notRegistered) {
        self.status = status
    }

    func enable() throws {
        enableCount += 1
        if let enableError {
            throw enableError
        }
    }

    func disable() throws {
        disableCount += 1
        if let disableError {
            throw disableError
        }
    }

    func openSettings() {
        openSettingsCount += 1
    }
}

@MainActor
private final class FakeAppNameResolver: AppNameResolving {
    let displayNames: [String: String]

    init(displayNames: [String: String] = [:]) {
        self.displayNames = displayNames
    }

    func displayName(forBundleIdentifier bundleIdentifier: String) -> String? {
        displayNames[bundleIdentifier]
    }
}

@MainActor
private final class FakeExcludedAppSelectionPresenter: ExcludedAppSelectionPresenting {
    var selection: ExcludedAppSelection?
    private(set) var presentedTitles: [String] = []

    init(selection: ExcludedAppSelection?) {
        self.selection = selection
    }

    func selectAppToExclude(panelTitle: String) -> ExcludedAppSelection? {
        presentedTitles.append(panelTitle)
        return selection
    }
}

private extension DockHoverPreviewSettings {
    static func viewModelSettings(
        enabled: Bool,
        hoverDelayMilliseconds: Int,
        maxCardCount: Int,
        retention: PanelRetentionMode,
        excludedApps: Set<String>,
        language: DisplayLanguage
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
