import AppKit
import Foundation
import UniformTypeIdentifiers

struct ExcludedAppSelection: Equatable, Sendable {
    let bundleIdentifier: String
    let displayName: String?
}

@MainActor
protocol ExcludedAppSelectionPresenting: AnyObject {
    func selectAppToExclude(panelTitle: String) -> ExcludedAppSelection?
}

@MainActor
protocol ExcludedAppOpenPanelProviding: AnyObject {
    var title: String? { get set }
    var canChooseFiles: Bool { get set }
    var canChooseDirectories: Bool { get set }
    var allowsMultipleSelection: Bool { get set }
    var canCreateDirectories: Bool { get set }
    var resolvesAliases: Bool { get set }
    var allowedContentTypes: [UTType] { get set }
    var url: URL? { get }

    func runModal() -> NSApplication.ModalResponse
}

@MainActor
final class AppKitExcludedAppOpenPanel: ExcludedAppOpenPanelProviding {
    private let panel: NSOpenPanel

    init(panel: NSOpenPanel = NSOpenPanel()) {
        self.panel = panel
    }

    var title: String? {
        get { panel.title }
        set { panel.title = newValue }
    }

    var canChooseFiles: Bool {
        get { panel.canChooseFiles }
        set { panel.canChooseFiles = newValue }
    }

    var canChooseDirectories: Bool {
        get { panel.canChooseDirectories }
        set { panel.canChooseDirectories = newValue }
    }

    var allowsMultipleSelection: Bool {
        get { panel.allowsMultipleSelection }
        set { panel.allowsMultipleSelection = newValue }
    }

    var canCreateDirectories: Bool {
        get { panel.canCreateDirectories }
        set { panel.canCreateDirectories = newValue }
    }

    var resolvesAliases: Bool {
        get { panel.resolvesAliases }
        set { panel.resolvesAliases = newValue }
    }

    var allowedContentTypes: [UTType] {
        get { panel.allowedContentTypes }
        set { panel.allowedContentTypes = newValue }
    }

    var url: URL? {
        panel.url
    }

    func runModal() -> NSApplication.ModalResponse {
        panel.runModal()
    }
}

@MainActor
final class AppKitExcludedAppSelectionPresenter: ExcludedAppSelectionPresenting {
    private let openPanelFactory: @MainActor () -> any ExcludedAppOpenPanelProviding

    init(
        openPanelFactory: @escaping @MainActor () -> any ExcludedAppOpenPanelProviding = {
            AppKitExcludedAppOpenPanel()
        }
    ) {
        self.openPanelFactory = openPanelFactory
    }

    func selectAppToExclude(panelTitle: String) -> ExcludedAppSelection? {
        let panel = openPanelFactory()
        configure(panel, title: panelTitle)

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        return Self.resolvedSelection(at: url)
    }

    static func resolvedSelection(at url: URL) -> ExcludedAppSelection {
        let bundle = Bundle(url: url)
        return ExcludedAppSelection(
            bundleIdentifier: bundle?.bundleIdentifier ?? "",
            displayName: AppBundleDisplayNameResolver.displayName(for: bundle, at: url)
        )
    }

    private func configure(_ panel: any ExcludedAppOpenPanelProviding, title: String) {
        panel.title = title
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = [.applicationBundle]
    }

}
