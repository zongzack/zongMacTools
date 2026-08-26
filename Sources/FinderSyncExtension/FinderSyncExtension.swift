import AppKit
import Darwin
import FinderSync
import FinderNewFileCore

final class FinderSyncExtension: FIFinderSync {
    private let menuCoordinator: FinderNewFileCoordinator

    override init() {
        menuCoordinator = FinderNewFileCoordinator(
            directoryValidator: LocalFinderDirectoryValidator(),
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
        let request = FinderMenuRequest(kind: kind, targetedURL: target, selectedURLs: controller.selectedItemURLs())
        let plans = menuCoordinator.menuPlan(for: request)
        guard !plans.isEmpty, let target else { return nil }
        let menu = NSMenu(title: Self.localizedNewFileTitle())
        for plan in plans {
            guard let format = plan.format else {
                menu.addItem(.separator())
                continue
            }
            let item = NSMenuItem(title: plan.title, action: #selector(createFile(_:)), keyEquivalent: "")
            item.target = self
            item.identifier = NSUserInterfaceItemIdentifier(plan.identifier)
            item.representedObject = FinderActionPayload(directoryURL: target, format: format)
            item.image = NSWorkspace.shared.icon(forFileType: format.fileExtension)
            menu.addItem(item)
        }
        return menu
    }

    @objc private func createFile(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? FinderActionPayload else { return }
        _ = menuCoordinator.create(format: payload.format, in: payload.directoryURL)
    }

    private static func localizedNewFileTitle() -> String {
        FinderNewFileLanguage.isSimplifiedChinese() ? "新建文件" : "New File"
    }
}

private final class FinderActionPayload: NSObject {
    let directoryURL: URL
    let format: FinderNewFileFormat
    init(directoryURL: URL, format: FinderNewFileFormat) { self.directoryURL = directoryURL; self.format = format }
}

private struct WorkspaceFinderFileSelector: FinderFileSelecting {
    nonisolated func select(fileURL: URL) { Task { @MainActor in NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path) } }
}
private struct AlertFinderErrorPresenter: FinderErrorPresenting {
    nonisolated func present(error: FinderNewFileError) { Task { @MainActor in let alert = NSAlert(); alert.alertStyle = .warning; alert.messageText = "无法新建文件"; alert.informativeText = error.localizedDescription; alert.addButton(withTitle: "好"); alert.runModal() } }
}

@main
enum FinderSyncExtensionMain {
    static func main() { let delegate = FinderSyncExtensionDelegate(); NSApplication.shared.delegate = delegate; NSApplication.shared.run() }
}
private final class FinderSyncExtensionDelegate: NSObject, NSApplicationDelegate {
    private var extensionObject: FinderSyncExtension?
    func applicationDidFinishLaunching(_ notification: Notification) { extensionObject = FinderSyncExtension() }
}
