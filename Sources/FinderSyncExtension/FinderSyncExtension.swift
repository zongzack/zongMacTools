import AppKit
import Darwin
import FinderSync
import FinderNewFileCore
import UniformTypeIdentifiers

final class FinderSyncExtension: FIFinderSync {
    private let menuCoordinator: FinderNewFileCoordinator
    private var actionTargets: [FinderNewFileMenuActionTarget] = []

    override init() {
        let directoryValidator = LocalFinderDirectoryValidator()
        menuCoordinator = FinderNewFileCoordinator(
            directoryValidator: directoryValidator,
            publisher: SecureAtomicFilePublisher(),
            selector: WorkspaceFinderFileSelector(),
            errorPresenter: AlertFinderErrorPresenter()
        )
        super.init()
        if let homeDirectory = Self.realUserHomeDirectory() {
            FIFinderSyncController.default().directoryURLs = [homeDirectory]
        } else {
            FIFinderSyncController.default().directoryURLs = []
        }
    }

    private static func realUserHomeDirectory() -> URL? {
        guard let passwd = getpwuid(getuid()), let homePath = passwd.pointee.pw_dir else { return nil }
        return URL(fileURLWithPath: String(cString: homePath), isDirectory: true)
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let kind: FinderMenuKind
        switch menuKind {
        case .contextualMenuForContainer: kind = .contextualMenuForContainer
        case .contextualMenuForItems: kind = .contextualMenuForItems
        case .contextualMenuForSidebar: kind = .contextualMenuForSidebar
        case .toolbarItemMenu: kind = .toolbarItemMenu
        @unknown default: return nil
        }
        let controller = FIFinderSyncController.default()
        let target = controller.targetedURL()
        let selectedURLs = controller.selectedItemURLs()
        let request = FinderMenuRequest(kind: kind, targetedURL: target, selectedURLs: selectedURLs)
        let plans = menuCoordinator.menuPlan(for: request)
        guard !plans.isEmpty, let target else {
            actionTargets = []
            return nil
        }
        actionTargets = plans.map { plan in
            FinderNewFileMenuActionTarget(itemID: plan.identifier, directoryURL: target) { [menuCoordinator] itemID, directoryURL in
                _ = menuCoordinator.create(itemID: itemID, in: directoryURL)
            }
        }
        let menu = NSMenu(title: Self.localizedNewFileTitle())
        let submenu = NSMenu(title: Self.localizedNewFileTitle())
        for (plan, actionTarget) in zip(plans, actionTargets) {
            let item = NSMenuItem(title: plan.title, action: #selector(FinderNewFileMenuActionTarget.createFile(_:)), keyEquivalent: "")
            item.target = actionTarget
            item.identifier = NSUserInterfaceItemIdentifier(plan.identifier)
            item.isEnabled = plan.isEnabled
            if let fileExtension = plan.fileExtension {
                let type = UTType(filenameExtension: fileExtension) ?? .data
                item.image = NSWorkspace.shared.icon(for: type)
            }
            submenu.addItem(item)
        }
        let newFileItem = NSMenuItem(title: Self.localizedNewFileTitle(), action: nil, keyEquivalent: "")
        newFileItem.identifier = NSUserInterfaceItemIdentifier(FinderNewFileCoordinator.newFileIdentifier)
        newFileItem.isEnabled = true
        newFileItem.submenu = submenu
        menu.addItem(newFileItem)
        return menu
    }

    private static func localizedNewFileTitle() -> String {
        FinderNewFileLanguage.isSimplifiedChinese() ? "新建文件" : "New File"
    }
}

private struct WorkspaceFinderFileSelector: FinderFileSelecting {
    nonisolated func select(fileURL: URL) { Task { @MainActor in NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path) } }
}
private struct AlertFinderErrorPresenter: FinderErrorPresenting {
    nonisolated func present(error: FinderNewFileError) { Task { @MainActor in let alert = NSAlert(); alert.alertStyle = .warning; alert.messageText = "无法新建文件"; alert.informativeText = error.localizedDescription; alert.addButton(withTitle: "好"); alert.runModal() } }
}

private final class FinderNewFileMenuActionTarget: NSObject {
    private let itemID: String
    private let directoryURL: URL
    private let create: (String, URL) -> Void

    init(itemID: String, directoryURL: URL, create: @escaping (String, URL) -> Void) {
        self.itemID = itemID
        self.directoryURL = directoryURL
        self.create = create
    }

    @objc func createFile(_ sender: NSMenuItem) {
        create(itemID, directoryURL)
    }
}

@main
enum FinderSyncExtensionMain {
    static func main() { NSExtensionMain() }
}

// SwiftPM builds this target as an executable, so explicitly forward to the
// App Extension runtime entry point that Xcode supplies for extension targets.
@_silgen_name("NSExtensionMain")
private func NSExtensionMain()
