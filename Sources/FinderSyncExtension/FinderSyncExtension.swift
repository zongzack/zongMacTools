import AppKit
import Darwin
import FinderSync
import FinderNewFileCore

final class FinderSyncExtension: FIFinderSync {
    private let menuCoordinator: FinderNewFileCoordinator

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
        guard !plans.isEmpty, target != nil else { return nil }
        let menu = NSMenu(title: Self.localizedNewFileTitle())
        let submenu = NSMenu(title: Self.localizedNewFileTitle())
        for plan in plans {
            guard let format = plan.format else {
                submenu.addItem(.separator())
                continue
            }
            let item = NSMenuItem(title: plan.title, action: #selector(createFile(_:)), keyEquivalent: "")
            item.target = self
            item.identifier = NSUserInterfaceItemIdentifier(plan.identifier)
            item.image = NSWorkspace.shared.icon(forFileType: format.fileExtension)
            submenu.addItem(item)
        }
        let newFileItem = NSMenuItem(title: Self.localizedNewFileTitle(), action: nil, keyEquivalent: "")
        newFileItem.identifier = NSUserInterfaceItemIdentifier(FinderNewFileCoordinator.newFileIdentifier)
        newFileItem.isEnabled = true
        newFileItem.submenu = submenu
        menu.addItem(newFileItem)
        return menu
    }

    @objc private func createFile(_ sender: NSMenuItem) {
        // Finder rebuilds the menu item when presenting it, so representedObject,
        // identifier, and tag do not survive into the action. The item title and
        // targetedURL() are preserved, so recover the format from the localized
        // title and the directory from the controller.
        guard let target = FIFinderSyncController.default().targetedURL() else { return }
        let simplifiedChinese = FinderNewFileLanguage.isSimplifiedChinese()
        guard let format = FinderNewFileFormat.allCases.first(where: { $0.menuTitle(isSimplifiedChinese: simplifiedChinese) == sender.title }) else { return }
        _ = menuCoordinator.create(format: format, in: target)
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

@main
enum FinderSyncExtensionMain {
    static func main() { NSExtensionMain() }
}

// SwiftPM builds this target as an executable, so explicitly forward to the
// App Extension runtime entry point that Xcode supplies for extension targets.
@_silgen_name("NSExtensionMain")
private func NSExtensionMain()
