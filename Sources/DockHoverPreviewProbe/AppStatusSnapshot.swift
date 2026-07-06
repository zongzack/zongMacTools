import Foundation

struct AppSettingsSummary: Equatable, Sendable {
    let isDockHoverPreviewEnabled: Bool
    let hoverDelayMilliseconds: Int
    let panelRetentionMode: PanelRetentionMode
    let maxCardCount: Int
    let excludedAppCount: Int
    let displayLanguage: DisplayLanguage

    init(settings: DockHoverPreviewSettings) {
        self.isDockHoverPreviewEnabled = settings.isDockHoverPreviewEnabled
        self.hoverDelayMilliseconds = settings.hoverDelayMilliseconds
        self.panelRetentionMode = settings.panelRetentionMode
        self.maxCardCount = settings.maxCardCount
        self.excludedAppCount = settings.excludedAppBundleIdentifiers.count
        self.displayLanguage = settings.displayLanguage
    }
}

struct AppStatusSnapshot: Equatable, Sendable {
    let metadata: AppMetadata
    let permissionState: PermissionState
    let launchAtLoginStatus: LaunchAtLoginStatus
    let settingsSummary: AppSettingsSummary
    let generatedAt: Date

    init(
        metadata: AppMetadata,
        permissionState: PermissionState,
        launchAtLoginStatus: LaunchAtLoginStatus,
        settings: DockHoverPreviewSettings,
        generatedAt: Date = Date()
    ) {
        self.metadata = metadata
        self.permissionState = permissionState
        self.launchAtLoginStatus = launchAtLoginStatus
        self.settingsSummary = AppSettingsSummary(settings: settings)
        self.generatedAt = generatedAt
    }

    var appName: String { metadata.appName }
    var version: String { metadata.version }
    var buildNumber: String { metadata.buildNumber }
    var bundleIdentifier: String { metadata.bundleIdentifier }
    var bundlePath: String { metadata.bundlePath }
    var signingSummary: String { metadata.signingStatus.displayString }

    func copyStatusText(language requestedLanguage: DisplayLanguage? = nil) -> String {
        let language = requestedLanguage ?? settingsSummary.displayLanguage
        let text = AppTextProvider(language: language)

        return [
            "\(metadata.appName)",
            "Version: \(metadata.version)",
            "Build: \(metadata.buildNumber)",
            "Bundle ID: \(metadata.bundleIdentifier)",
            "Bundle Path: \(metadata.bundlePath)",
            "Executable: \(metadata.executableName)",
            text.accessibilityStatus(granted: permissionState.accessibilityGranted),
            text.screenRecordingStatus(granted: permissionState.screenRecordingGranted),
            "Launch at Login: \(launchAtLoginStatus.statusText)",
            "Signing: \(metadata.signingStatus.displayString)",
            "Dock Hover Preview: \(settingsSummary.isDockHoverPreviewEnabled ? "enabled" : "disabled")",
            "Hover Delay: \(settingsSummary.hoverDelayMilliseconds) ms",
            "Panel Retention: \(settingsSummary.panelRetentionMode.rawValue)",
            "Max Cards: \(settingsSummary.maxCardCount)",
            "Excluded Apps: \(settingsSummary.excludedAppCount)",
            "Display Language: \(settingsSummary.displayLanguage.rawValue)"
        ].joined(separator: "\n")
    }
}

@MainActor
protocol AppStatusProviding: AnyObject {
    func snapshot() -> AppStatusSnapshot
}

@MainActor
final class LiveAppStatusProvider: AppStatusProviding {
    private let permissionService: PermissionService
    private let launchAtLoginService: LaunchAtLoginService
    private let settingsStore: DockHoverPreviewSettingsStore
    private let metadataProvider: () -> AppMetadata

    init(
        permissionService: PermissionService,
        launchAtLoginService: LaunchAtLoginService,
        settingsStore: DockHoverPreviewSettingsStore,
        metadataProvider: @escaping () -> AppMetadata = { AppMetadata() }
    ) {
        self.permissionService = permissionService
        self.launchAtLoginService = launchAtLoginService
        self.settingsStore = settingsStore
        self.metadataProvider = metadataProvider
    }

    func snapshot() -> AppStatusSnapshot {
        AppStatusSnapshot(
            metadata: metadataProvider(),
            permissionState: permissionService.currentState,
            launchAtLoginStatus: launchAtLoginService.status,
            settings: settingsStore.snapshot
        )
    }
}

@MainActor
final class CachedAppMetadataProvider {
    private var cachedMetadata: AppMetadata

    init(bundle: Bundle = .main) {
        let baseMetadata = AppMetadata(bundle: bundle, signingStatus: .unknown("checking"))
        self.cachedMetadata = baseMetadata

        Task.detached {
            let result = ProcessDiagnosticCommandRunner().run(
                URL(fileURLWithPath: "/usr/bin/codesign"),
                arguments: ["-dv", "--verbose=4", baseMetadata.bundlePath]
            )
            let signingStatus = AppSigningStatus.parse(codesignOutput: result.output)
            let metadata = AppMetadata(
                appName: baseMetadata.appName,
                version: baseMetadata.version,
                buildNumber: baseMetadata.buildNumber,
                bundleIdentifier: baseMetadata.bundleIdentifier,
                bundlePath: baseMetadata.bundlePath,
                executableName: baseMetadata.executableName,
                signingStatus: signingStatus
            )
            await MainActor.run {
                self.cachedMetadata = metadata
            }
        }
    }

    func currentMetadata() -> AppMetadata {
        cachedMetadata
    }
}

private extension LaunchAtLoginStatus {
    var statusText: String {
        switch self {
        case .enabled:
            "enabled"
        case .notRegistered:
            "not registered"
        case .requiresApproval:
            "requires approval"
        case .notFound:
            "not found"
        }
    }
}
