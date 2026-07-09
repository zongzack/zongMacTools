import Combine
import Foundation

struct DockWindowQuickLookSettingsViewState: Equatable {
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
final class DockWindowQuickLookSettingsViewModel: ObservableObject {
    private static let hoverDelayPresets = [150, 250, 400]
    private static let panelRetentionPresets: [PanelRetentionMode] = [.tight, .standard, .forgiving]
    private static let maxCardCountPresets = [3, 5, 8, 12]

    @Published private(set) var state: DockWindowQuickLookSettingsViewState

    private let settingsStore: DockHoverPreviewSettingsStore
    private let targetTracker: AppTargetTracker
    private let appNameResolver: AppNameResolving
    private let excludedAppSelectionPresenter: any ExcludedAppSelectionPresenting
    private let selfBundleIdentifier: String
    private let logger: ProbeLogger
    private var observerToken: UUID?

    init(
        settingsStore: DockHoverPreviewSettingsStore,
        targetTracker: AppTargetTracker,
        appNameResolver: AppNameResolving = WorkspaceAppNameResolver(),
        excludedAppSelectionPresenter: any ExcludedAppSelectionPresenting = AppKitExcludedAppSelectionPresenter(),
        selfBundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.zong.zongMacTools",
        logger: ProbeLogger
    ) {
        self.settingsStore = settingsStore
        self.targetTracker = targetTracker
        self.appNameResolver = appNameResolver
        self.excludedAppSelectionPresenter = excludedAppSelectionPresenter
        self.selfBundleIdentifier = BundleIdentifierValidator.sanitized(selfBundleIdentifier) ?? selfBundleIdentifier
        self.logger = logger
        self.state = Self.makeState(
            snapshot: settingsStore.snapshot,
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

    @discardableResult
    func addExcludedAppFromSelection() -> Bool {
        let text = AppTextProvider(language: state.displayLanguage)
        guard let selection = excludedAppSelectionPresenter.selectAppToExclude(
            panelTitle: text.string(.chooseAppToExclude)
        ) else {
            return false
        }

        return addExcludedApp(selection)
    }

    @discardableResult
    func addExcludedApp(_ selection: ExcludedAppSelection) -> Bool {
        guard let bundleIdentifier = BundleIdentifierValidator.sanitized(selection.bundleIdentifier) else {
            logger.warning("settings.excludedAppManualAddSkipped reason=invalidBundleIdentifier")
            return false
        }

        guard bundleIdentifier != selfBundleIdentifier else {
            logger.info("settings.excludedAppManualAddSkipped reason=self bundle=\(bundleIdentifier)")
            return false
        }

        guard !settingsStore.snapshot.excludedAppBundleIdentifiers.contains(bundleIdentifier) else {
            logger.info("settings.excludedAppManualAddSkipped reason=duplicate bundle=\(bundleIdentifier)")
            return false
        }

        settingsStore.update { settings in
            settings.excludedAppBundleIdentifiers.insert(bundleIdentifier)
        }
        logger.info("settings.excludedAppManualAdded bundle=\(bundleIdentifier)")
        return true
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

    private func refresh(snapshot: DockHoverPreviewSettings) {
        state = Self.makeState(
            snapshot: snapshot,
            targetTracker: targetTracker,
            appNameResolver: appNameResolver
        )
    }

    private static func makeState(
        snapshot: DockHoverPreviewSettings,
        targetTracker: AppTargetTracker,
        appNameResolver: AppNameResolving
    ) -> DockWindowQuickLookSettingsViewState {
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

        return DockWindowQuickLookSettingsViewState(
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
            } ?? false
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
