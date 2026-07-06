import ServiceManagement

enum LaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound

    var menuTextKey: LocalizedTextKey {
        switch self {
        case .enabled:
            .launchAtLoginEnabled
        case .notRegistered:
            .launchAtLoginNotRegistered
        case .requiresApproval:
            .launchAtLoginRequiresApproval
        case .notFound:
            .launchAtLoginNotFound
        }
    }

    var canEnable: Bool {
        self == .notRegistered
    }

    var canDisable: Bool {
        self == .enabled
    }

    var canOpenSettings: Bool {
        self == .requiresApproval || self == .notFound
    }
}

@MainActor
protocol LaunchAtLoginService: AnyObject {
    var status: LaunchAtLoginStatus { get }
    func enable() throws
    func disable() throws
    func openSettings()
}

@MainActor
final class UnavailableLaunchAtLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginStatus { .notFound }

    func enable() throws {}
    func disable() throws {}
    func openSettings() {}
}

@MainActor
final class SystemLaunchAtLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .notRegistered
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .notFound
        }
    }

    func enable() throws {
        try SMAppService.mainApp.register()
    }

    func disable() throws {
        try SMAppService.mainApp.unregister()
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
