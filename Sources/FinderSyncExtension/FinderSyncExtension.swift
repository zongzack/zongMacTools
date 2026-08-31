import AppKit
import Darwin
import FinderSync
import FinderNewFileCore
import UniformTypeIdentifiers

final class FinderSyncExtension: FIFinderSync {
    private let menuCoordinator: FinderNewFileCoordinator
    // Finder may rebuild menu items before dispatching the action. Keep the
    // plans for the latest menu so the extension can recover the stable item
    // ID even when Finder drops NSMenuItem metadata during that rebuild.
    private var actionPlans: [FinderMenuActionPlan] = []

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
            actionPlans = []
            return nil
        }
        actionPlans = plans.map { FinderMenuActionPlan(itemID: $0.identifier, title: $0.title, directoryURL: target) }
        let menu = NSMenu(title: Self.localizedNewFileTitle())
        let submenu = NSMenu(title: Self.localizedNewFileTitle())
        for plan in plans {
            let item = NSMenuItem(title: plan.title, action: #selector(FinderSyncExtension.createFile(_:)), keyEquivalent: "")
            // Finder Sync actions must be received by the extension object.
            // A detached NSObject target can be discarded when Finder
            // reconstructs the contextual menu before presenting it.
            item.target = self
            item.identifier = NSUserInterfaceItemIdentifier(plan.identifier)
            item.representedObject = plan.identifier
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

    @objc func createFile(_ sender: NSMenuItem) {
        guard let actionPlan = actionPlan(for: sender) else { return }
        _ = menuCoordinator.create(itemID: actionPlan.itemID, in: actionPlan.directoryURL)
    }

    private func actionPlan(for sender: NSMenuItem) -> FinderMenuActionPlan? {
        if let itemID = sender.representedObject as? String,
           let plan = actionPlans.first(where: { $0.itemID == itemID }) {
            return plan
        }
        if let itemID = sender.identifier?.rawValue,
           let plan = actionPlans.first(where: { $0.itemID == itemID }) {
            return plan
        }
        if let menu = sender.menu {
            let index = menu.index(of: sender)
            if index >= 0, index < actionPlans.count {
                return actionPlans[index]
            }
        }
        return actionPlans.first(where: { $0.title == sender.title })
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

private struct FinderMenuActionPlan {
    let itemID: String
    let title: String
    let directoryURL: URL
}

@main
enum FinderSyncExtensionMain {
    static func main() { NSExtensionMain() }
}

// SwiftPM builds this target as an executable, so explicitly forward to the
// App Extension runtime entry point that Xcode supplies for extension targets.
@_silgen_name("NSExtensionMain")
private func NSExtensionMain()
