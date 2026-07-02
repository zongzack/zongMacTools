import AppKit

struct AppTarget: Equatable, Sendable {
    let bundleIdentifier: String
    let displayName: String
}

@MainActor
final class AppTargetTracker {
    private let selfBundleIdentifier: String
    private var currentPreviewApp: AppTarget?
    private var latestHoveredDockApp: AppTarget?
    private var latestNonSelfActiveApp: AppTarget?
    private var observer: NSObjectProtocol?
    private var observedNotificationCenter: NotificationCenter?

    init(selfBundleIdentifier: String) {
        self.selfBundleIdentifier = selfBundleIdentifier
    }

    var exclusionTarget: AppTarget? {
        [currentPreviewApp, latestHoveredDockApp, latestNonSelfActiveApp]
            .compactMap { $0 }
            .first { isValidTarget($0) }
    }

    func updateCurrentPreviewApp(_ target: AppTarget?) {
        currentPreviewApp = target.flatMap { isValidTarget($0) ? $0 : nil }
    }

    func updateLatestHoveredDockApp(_ target: AppTarget?) {
        latestHoveredDockApp = target.flatMap { isValidTarget($0) ? $0 : nil }
    }

    func updateLatestNonSelfActiveApp(_ target: AppTarget?) {
        latestNonSelfActiveApp = target.flatMap { isValidTarget($0) ? $0 : nil }
    }

    func startWorkspaceObservation(workspace: NSWorkspace = .shared) {
        guard observer == nil else {
            return
        }

        let notificationCenter = workspace.notificationCenter
        observer = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            Task { @MainActor in
                self?.updateLatestNonSelfActiveApp(AppTarget(app: app))
            }
        }
        observedNotificationCenter = notificationCenter
    }

    func stopWorkspaceObservation(workspace: NSWorkspace = .shared) {
        if let observer {
            (observedNotificationCenter ?? workspace.notificationCenter).removeObserver(observer)
        }
        observer = nil
        observedNotificationCenter = nil
    }

    private func isValidTarget(_ target: AppTarget) -> Bool {
        !target.bundleIdentifier.isEmpty && target.bundleIdentifier != selfBundleIdentifier
    }
}

extension AppTarget {
    init?(app: NSRunningApplication) {
        guard let bundleIdentifier = app.bundleIdentifier, !bundleIdentifier.isEmpty else {
            return nil
        }
        self.bundleIdentifier = bundleIdentifier
        self.displayName = app.localizedName ?? bundleIdentifier
    }
}
