import Combine
import Foundation

struct SettingsViewState: Equatable {
    let isDockWindowQuickLookEnabled: Bool
    let hoverDelayMilliseconds: Int
    let hoverDelaySliderIndex: Double
    let panelRetentionMode: PanelRetentionMode
    let panelRetentionSliderIndex: Double
    let maxCardCount: Int
    let maxCardSliderIndex: Double
    let displayLanguage: DisplayLanguage
    let excludedApps: [ExcludedAppState]
    let currentExclusionTarget: AppTarget?
    let isCurrentExclusionTargetExcluded: Bool
    let launchAtLoginStatus: LaunchAtLoginStatus

    var canEnableLaunchAtLogin: Bool {
        launchAtLoginStatus.canEnable
    }

    var canDisableLaunchAtLogin: Bool {
        launchAtLoginStatus.canDisable
    }

    var canOpenLaunchAtLoginSettings: Bool {
        launchAtLoginStatus.canOpenSettings
    }
}

struct ExcludedAppState: Equatable, Identifiable {
    let bundleIdentifier: String
    let displayName: String?
    let title: String

    var id: String {
        bundleIdentifier
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    private static let hoverDelayPresets = [150, 250, 400]
    private static let panelRetentionPresets: [PanelRetentionMode] = [.tight, .standard, .forgiving]
    private static let maxCardCountPresets = [3, 5, 8, 12]

    @Published private(set) var state: SettingsViewState

    private let settingsStore: DockHoverPreviewSettingsStore
    private let launchAtLoginService: LaunchAtLoginService
    private let targetTracker: AppTargetTracker
    private let appNameResolver: AppNameResolving
    private let logger: ProbeLogger
    private var observerToken: UUID?

    init(
        settingsStore: DockHoverPreviewSettingsStore,
        launchAtLoginService: LaunchAtLoginService,
        targetTracker: AppTargetTracker,
        appNameResolver: AppNameResolving = WorkspaceAppNameResolver(),
        logger: ProbeLogger
    ) {
        self.settingsStore = settingsStore
        self.launchAtLoginService = launchAtLoginService
        self.targetTracker = targetTracker
        self.appNameResolver = appNameResolver
        self.logger = logger
        self.state = Self.makeState(
            snapshot: settingsStore.snapshot,
            launchAtLoginStatus: launchAtLoginService.status,
            targetTracker: targetTracker,
            appNameResolver: appNameResolver
        )

        observerToken = settingsStore.addObserver { [weak self] snapshot in
            self?.refresh(snapshot: snapshot)
        }
    }

    func refresh() {
        refresh(snapshot: settingsStore.snapshot)
    }

    func refreshForSettingsPresentation() {
        targetTracker.refreshLatestNonSelfActiveApp()
        refresh(snapshot: settingsStore.snapshot)
    }

    func toggleDockWindowQuickLook() {
        settingsStore.update { settings in
            settings.isDockHoverPreviewEnabled.toggle()
        }
    }

    func setHoverDelaySliderIndex(_ sliderIndex: Double) {
        let value = Self.presetValue(
            forSliderIndex: sliderIndex,
            presets: Self.hoverDelayPresets
        )
        settingsStore.update { settings in
            settings.hoverDelayMilliseconds = value
        }
    }

    func setPanelRetentionSliderIndex(_ sliderIndex: Double) {
        let value = Self.presetValue(
            forSliderIndex: sliderIndex,
            presets: Self.panelRetentionPresets
        )
        settingsStore.update { settings in
            settings.panelRetentionMode = value
        }
    }

    func setMaxCardSliderIndex(_ sliderIndex: Double) {
        let value = Self.presetValue(
            forSliderIndex: sliderIndex,
            presets: Self.maxCardCountPresets
        )
        settingsStore.update { settings in
            settings.maxCardCount = value
        }
    }

    func setDisplayLanguage(_ language: DisplayLanguage) {
        settingsStore.update { settings in
            settings.displayLanguage = language
        }
    }

    func toggleCurrentExclusionTarget() {
        guard let target = targetTracker.exclusionTarget else {
            refresh()
            return
        }

        settingsStore.update { settings in
            if settings.excludedAppBundleIdentifiers.contains(target.bundleIdentifier) {
                settings.excludedAppBundleIdentifiers.remove(target.bundleIdentifier)
            } else {
                settings.excludedAppBundleIdentifiers.insert(target.bundleIdentifier)
            }
        }
    }

    func removeExcludedApp(bundleIdentifier: String) {
        guard state.excludedApps.contains(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return
        }

        settingsStore.update { settings in
            settings.excludedAppBundleIdentifiers.remove(bundleIdentifier)
        }
    }

    func clearExcludedApps() {
        guard !state.excludedApps.isEmpty else {
            return
        }

        settingsStore.update { settings in
            settings.excludedAppBundleIdentifiers.removeAll()
        }
    }

    func enableLaunchAtLogin() {
        guard launchAtLoginService.status.canEnable else {
            refresh()
            return
        }

        do {
            try launchAtLoginService.enable()
        } catch {
            logger.error("launchAtLogin.enableFailed error=\(error)")
        }
        refresh()
    }

    func disableLaunchAtLogin() {
        guard launchAtLoginService.status.canDisable else {
            refresh()
            return
        }

        do {
            try launchAtLoginService.disable()
        } catch {
            logger.error("launchAtLogin.disableFailed error=\(error)")
        }
        refresh()
    }

    func openLaunchAtLoginSettings() {
        guard launchAtLoginService.status.canOpenSettings else {
            refresh()
            return
        }

        launchAtLoginService.openSettings()
        refresh()
    }

    private func refresh(snapshot: DockHoverPreviewSettings) {
        state = Self.makeState(
            snapshot: snapshot,
            launchAtLoginStatus: launchAtLoginService.status,
            targetTracker: targetTracker,
            appNameResolver: appNameResolver
        )
    }

    private static func makeState(
        snapshot: DockHoverPreviewSettings,
        launchAtLoginStatus: LaunchAtLoginStatus,
        targetTracker: AppTargetTracker,
        appNameResolver: AppNameResolving
    ) -> SettingsViewState {
        let hoverDelay = sanitizedHoverDelay(snapshot.hoverDelayMilliseconds)
        let panelRetentionMode = snapshot.panelRetentionMode
        let maxCardCount = sanitizedMaxCardCount(snapshot.maxCardCount)
        let target = targetTracker.exclusionTarget
        let text = AppTextProvider(language: snapshot.displayLanguage)
        let excludedApps = snapshot.excludedAppBundleIdentifiers
            .sorted()
            .map { bundleIdentifier in
                let displayName = appNameResolver.displayName(forBundleIdentifier: bundleIdentifier)
                return ExcludedAppState(
                    bundleIdentifier: bundleIdentifier,
                    displayName: displayName,
                    title: text.excludedAppListTitle(appName: displayName, bundleIdentifier: bundleIdentifier)
                )
            }

        return SettingsViewState(
            isDockWindowQuickLookEnabled: snapshot.isDockHoverPreviewEnabled,
            hoverDelayMilliseconds: hoverDelay,
            hoverDelaySliderIndex: sliderIndex(for: hoverDelay, presets: hoverDelayPresets),
            panelRetentionMode: panelRetentionMode,
            panelRetentionSliderIndex: sliderIndex(for: panelRetentionMode, presets: panelRetentionPresets),
            maxCardCount: maxCardCount,
            maxCardSliderIndex: sliderIndex(for: maxCardCount, presets: maxCardCountPresets),
            displayLanguage: snapshot.displayLanguage,
            excludedApps: excludedApps,
            currentExclusionTarget: target,
            isCurrentExclusionTargetExcluded: target.map {
                snapshot.excludedAppBundleIdentifiers.contains($0.bundleIdentifier)
            } ?? false,
            launchAtLoginStatus: launchAtLoginStatus
        )
    }

    private static func sanitizedHoverDelay(_ value: Int) -> Int {
        hoverDelayPresets.contains(value)
            ? value
            : DockHoverPreviewSettings.defaults.hoverDelayMilliseconds
    }

    private static func sanitizedMaxCardCount(_ value: Int) -> Int {
        maxCardCountPresets.contains(value)
            ? value
            : DockHoverPreviewSettings.defaults.maxCardCount
    }

    private static func sliderIndex<Value: Equatable>(for value: Value, presets: [Value]) -> Double {
        Double(presets.firstIndex(of: value) ?? 0)
    }

    private static func presetValue<Value>(forSliderIndex sliderIndex: Double, presets: [Value]) -> Value {
        let roundedIndex = sliderIndex.isFinite ? Int(sliderIndex.rounded()) : 0
        let clampedIndex = min(max(roundedIndex, 0), presets.count - 1)
        return presets[clampedIndex]
    }
}
