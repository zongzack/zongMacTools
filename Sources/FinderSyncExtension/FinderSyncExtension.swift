import AppKit
import FinderSync
import FinderNewFileCore

final class FinderSyncExtension: FIFinderSync {
    private let menuCoordinator = FinderMenuCoordinator(
        directoryValidator: LocalFinderDirectoryValidator(),
        title: FinderSyncExtension.localizedNewFileTitle()
    )

    override init() {
        super.init()
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        FIFinderSyncController.default().directoryURLs = [homeURL]
    }

    private static func localizedNewFileTitle() -> String {
        let languageCode = Locale.current.language.languageCode?.identifier
        return languageCode == "zh" && Locale.current.language.script?.identifier == "Hans"
            ? "新建文件"
            : "New File"
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let kind: FinderMenuKind
        switch menuKind {
        case .contextualMenuForContainer:
            kind = .contextualMenuForContainer
        case .contextualMenuForItems:
            kind = .contextualMenuForItems
        case .contextualMenuForSidebar:
            kind = .contextualMenuForSidebar
        case .toolbarItemMenu:
            kind = .toolbarItemMenu
        @unknown default:
            return nil
        }

        let controller = FIFinderSyncController.default()
        let request = FinderMenuRequest(
            kind: kind,
            targetedURL: controller.targetedURL(),
            selectedURLs: controller.selectedItemURLs()
        )
        let plan = menuCoordinator.menuPlan(for: request)
        guard !plan.isEmpty else { return nil }

        let menu = NSMenu(title: "New File")
        for itemPlan in plan {
            let item = NSMenuItem(
                title: itemPlan.title,
                action: nil,
                keyEquivalent: ""
            )
            item.identifier = NSUserInterfaceItemIdentifier(itemPlan.identifier)
            item.isEnabled = itemPlan.isEnabled
            menu.addItem(item)
        }
        return menu
    }
}

@main
enum FinderSyncExtensionMain {
    static func main() {
        let delegate = FinderSyncExtensionDelegate()
        NSApplication.shared.delegate = delegate
        NSApplication.shared.run()
    }
}

private final class FinderSyncExtensionDelegate: NSObject, NSApplicationDelegate {
    private var extensionObject: FinderSyncExtension?

    func applicationDidFinishLaunching(_ notification: Notification) {
        extensionObject = FinderSyncExtension()
    }
}
