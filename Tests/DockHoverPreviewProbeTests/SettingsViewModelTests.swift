import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testInitialSnapshotMapsToUIState() {
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

        let viewModel = SettingsViewModel(
            settingsStore: store,
            launchAtLoginService: launchAtLoginService,
            targetTracker: targetTracker,
            appNameResolver: appNameResolver,
            logger: ProbeLogger()
        )

        XCTAssertFalse(viewModel.state.isDockWindowQuickLookEnabled)
        XCTAssertEqual(viewModel.state.hoverDelayMilliseconds, 400)
        XCTAssertEqual(viewModel.state.hoverDelaySliderIndex, 2)
        XCTAssertEqual(viewModel.state.panelRetentionMode, .forgiving)
        XCTAssertEqual(viewModel.state.panelRetentionSliderIndex, 2)
        XCTAssertEqual(viewModel.state.maxCardCount, 12)
        XCTAssertEqual(viewModel.state.maxCardSliderIndex, 3)
        XCTAssertEqual(viewModel.state.displayLanguage, .simplifiedChinese)
        XCTAssertEqual(
            viewModel.state.excludedApps.map(\.title),
            ["Example Editor (com.example.Editor)", "com.example.Unknown"]
        )
        XCTAssertEqual(viewModel.state.currentExclusionTarget?.bundleIdentifier, "com.example.Editor")
        XCTAssertTrue(viewModel.state.isCurrentExclusionTargetExcluded)
        XCTAssertEqual(viewModel.state.launchAtLoginStatus, .requiresApproval)
        XCTAssertFalse(viewModel.state.canEnableLaunchAtLogin)
        XCTAssertFalse(viewModel.state.canDisableLaunchAtLogin)
        XCTAssertTrue(viewModel.state.canOpenLaunchAtLoginSettings)
    }

    func testStoreObserverRefreshesMappedState() {
        let store = RecordingSettingsStore(snapshot: .defaults)
        let viewModel = SettingsViewModel(
            settingsStore: store,
            launchAtLoginService: FakeLaunchAtLoginService(),
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

        XCTAssertFalse(viewModel.state.isDockWindowQuickLookEnabled)
        XCTAssertEqual(viewModel.state.hoverDelayMilliseconds, 150)
        XCTAssertEqual(viewModel.state.hoverDelaySliderIndex, 0)
        XCTAssertEqual(viewModel.state.panelRetentionMode, .tight)
        XCTAssertEqual(viewModel.state.panelRetentionSliderIndex, 0)
        XCTAssertEqual(viewModel.state.maxCardCount, 3)
        XCTAssertEqual(viewModel.state.maxCardSliderIndex, 0)
        XCTAssertEqual(viewModel.state.displayLanguage, .simplifiedChinese)
        XCTAssertEqual(viewModel.state.excludedApps.map(\.bundleIdentifier), ["com.example.One"])
    }

    func testNonPresetUserDefaultsValuesFallBackBeforeMappingToUIState() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(999, forKey: SettingsKey.hoverDelayMilliseconds.rawValue)
        defaults.set(7, forKey: SettingsKey.maxCardCount.rawValue)

        let logger = ProbeLogger()
        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: logger)
        let viewModel = SettingsViewModel(
            settingsStore: store,
            launchAtLoginService: FakeLaunchAtLoginService(),
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
        let viewModel = SettingsViewModel(
            settingsStore: store,
            launchAtLoginService: FakeLaunchAtLoginService(),
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

    func testSettingIntentsWriteOnlySettingsStore() {
        let store = RecordingSettingsStore(snapshot: .viewModelSettings(
            enabled: true,
            hoverDelayMilliseconds: 250,
            maxCardCount: 8,
            retention: .standard,
            excludedApps: ["com.example.One"],
            language: .english
        ))
        let viewModel = SettingsViewModel(
            settingsStore: store,
            launchAtLoginService: FakeLaunchAtLoginService(),
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
            logger: ProbeLogger()
        )

        viewModel.toggleDockWindowQuickLook()
        viewModel.setDisplayLanguage(.simplifiedChinese)

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
        let viewModel = SettingsViewModel(
            settingsStore: store,
            launchAtLoginService: FakeLaunchAtLoginService(),
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
        let viewModel = SettingsViewModel(
            settingsStore: store,
            launchAtLoginService: FakeLaunchAtLoginService(),
            targetTracker: targetTracker,
            logger: ProbeLogger()
        )

        viewModel.toggleCurrentExclusionTarget()

        XCTAssertEqual(store.writtenSnapshots, [])
        XCTAssertNil(viewModel.state.currentExclusionTarget)
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
        let viewModel = SettingsViewModel(
            settingsStore: store,
            launchAtLoginService: FakeLaunchAtLoginService(),
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
        let viewModel = SettingsViewModel(
            settingsStore: RecordingSettingsStore(snapshot: .defaults),
            launchAtLoginService: launchAtLoginService,
            targetTracker: AppTargetTracker(selfBundleIdentifier: "com.zong.zongMacTools"),
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
