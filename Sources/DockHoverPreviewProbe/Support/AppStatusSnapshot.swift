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
            statusLine(.version, metadata.version, language: language),
            statusLine(.build, metadata.buildNumber, language: language),
            statusLine(.bundleIdentifier, metadata.bundleIdentifier, language: language),
            statusLine(.bundlePath, metadata.bundlePath, language: language),
            statusLine(.executable, metadata.executableName, language: language),
            text.accessibilityStatus(granted: permissionState.accessibilityGranted),
            text.screenRecordingStatus(granted: permissionState.screenRecordingGranted),
            statusLine(.launchAtLogin, launchAtLoginStatus.statusText(language: language), language: language),
            statusLine(.signing, metadata.signingStatus.displayString(language: language), language: language),
            localizedStatusLine(
                label: text.string(.dockWindowQuickLook),
                value: enabledStatus(settingsSummary.isDockHoverPreviewEnabled, language: language),
                language: language
            ),
            localizedStatusLine(
                label: text.string(.hoverDelay),
                value: "\(settingsSummary.hoverDelayMilliseconds) ms",
                language: language
            ),
            localizedStatusLine(
                label: text.string(.panelRetention),
                value: panelRetentionText(settingsSummary.panelRetentionMode, language: language),
                language: language
            ),
            localizedStatusLine(
                label: text.string(.maxCards),
                value: "\(settingsSummary.maxCardCount)",
                language: language
            ),
            localizedStatusLine(
                label: text.string(.excludedApps),
                value: "\(settingsSummary.excludedAppCount)",
                language: language
            ),
            localizedStatusLine(
                label: text.string(.language),
                value: text.languageDisplayName(settingsSummary.displayLanguage),
                language: language
            )
        ].joined(separator: "\n")
    }
}

private enum AppStatusField {
    case version
    case build
    case bundleIdentifier
    case bundlePath
    case executable
    case launchAtLogin
    case signing
}

private func statusLine(_ field: AppStatusField, _ value: String, language: DisplayLanguage) -> String {
    localizedStatusLine(label: statusLabel(field, language: language), value: value, language: language)
}

private func localizedStatusLine(label: String, value: String, language: DisplayLanguage) -> String {
    switch language {
    case .english:
        "\(label): \(value)"
    case .simplifiedChinese:
        "\(label)\u{FF1A}\(value)"
    }
}

private func statusLabel(_ field: AppStatusField, language: DisplayLanguage) -> String {
    switch language {
    case .english:
        switch field {
        case .version:
            "Version"
        case .build:
            "Build"
        case .bundleIdentifier:
            "Bundle ID"
        case .bundlePath:
            "Bundle Path"
        case .executable:
            "Executable"
        case .launchAtLogin:
            "Launch at Login"
        case .signing:
            "Signing"
        }
    case .simplifiedChinese:
        switch field {
        case .version:
            "\u{7248}\u{672C}"
        case .build:
            "\u{6784}\u{5EFA}"
        case .bundleIdentifier:
            "\u{5305}\u{6807}\u{8BC6}\u{7B26}"
        case .bundlePath:
            "\u{5305}\u{8DEF}\u{5F84}"
        case .executable:
            "\u{53EF}\u{6267}\u{884C}\u{6587}\u{4EF6}"
        case .launchAtLogin:
            "\u{5F00}\u{673A}\u{542F}\u{52A8}"
        case .signing:
            "\u{7B7E}\u{540D}"
        }
    }
}

private func enabledStatus(_ isEnabled: Bool, language: DisplayLanguage) -> String {
    switch language {
    case .english:
        isEnabled ? "enabled" : "disabled"
    case .simplifiedChinese:
        isEnabled ? "\u{5DF2}\u{542F}\u{7528}" : "\u{5DF2}\u{505C}\u{7528}"
    }
}

private func panelRetentionText(_ mode: PanelRetentionMode, language: DisplayLanguage) -> String {
    switch language {
    case .english:
        mode.rawValue
    case .simplifiedChinese:
        AppTextProvider(language: language).panelRetentionDisplayName(mode)
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
    func statusText(language: DisplayLanguage) -> String {
        switch language {
        case .english:
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
        case .simplifiedChinese:
            switch self {
            case .enabled:
                "\u{5DF2}\u{542F}\u{7528}"
            case .notRegistered:
                "\u{672A}\u{6CE8}\u{518C}"
            case .requiresApproval:
                "\u{9700}\u{8981}\u{6279}\u{51C6}"
            case .notFound:
                "\u{672A}\u{627E}\u{5230}"
            }
        }
    }
}

private extension AppSigningStatus {
    func displayString(language: DisplayLanguage) -> String {
        switch language {
        case .english:
            displayString
        case .simplifiedChinese:
            switch self {
            case .adHoc:
                "Ad-hoc \u{7B7E}\u{540D}"
            case .signed(let identity):
                "\u{5DF2}\u{7B7E}\u{540D}\u{FF1A}\(identity)"
            case .unsigned:
                "\u{672A}\u{7B7E}\u{540D}"
            case .unknown(let reason):
                "\u{672A}\u{77E5}\u{FF1A}\(reason)"
            }
        }
    }
}
