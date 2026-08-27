import FinderNewFileCore
import FinderSync
import Foundation

@MainActor
protocol FinderExtensionStatusProviding: AnyObject {
    var isEnabled: Bool { get }
}

@MainActor
protocol FinderExtensionManagementPresenting: AnyObject {
    func showManagementInterface()
}

@MainActor
final class SystemFinderExtensionStatusProvider: FinderExtensionStatusProviding {
    var isEnabled: Bool { FIFinderSyncController.isExtensionEnabled }
}

@MainActor
final class SystemFinderExtensionManager: FinderExtensionManagementPresenting {
    func showManagementInterface() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}

struct FinderExtensionSettingsViewState: Equatable {
    let isEnabled: Bool

    let catalog: FinderNewFileCatalog

    var items: [FinderNewFileCatalogItem] { catalog.orderedItems }

    init(isEnabled: Bool, catalog: FinderNewFileCatalog = .defaultCatalog()) {
        self.isEnabled = isEnabled
        self.catalog = catalog
    }
}

@MainActor
final class FinderExtensionSettingsViewModel: ObservableObject {
    @Published private(set) var state: FinderExtensionSettingsViewState
    @Published private(set) var lastSaveError: String?

    private let statusProvider: FinderExtensionStatusProviding
    private let managementPresenter: FinderExtensionManagementPresenting
    private let catalogStore: any FinderNewFileCatalogStoring

    init(
        statusProvider: FinderExtensionStatusProviding = SystemFinderExtensionStatusProvider(),
        managementPresenter: FinderExtensionManagementPresenting = SystemFinderExtensionManager(),
        catalogStore: any FinderNewFileCatalogStoring = JSONFinderNewFileCatalogStore()
    ) {
        self.statusProvider = statusProvider
        self.managementPresenter = managementPresenter
        self.catalogStore = catalogStore
        self.state = FinderExtensionSettingsViewState(isEnabled: statusProvider.isEnabled, catalog: catalogStore.loadCatalog())
    }

    func refresh() {
        state = FinderExtensionSettingsViewState(isEnabled: statusProvider.isEnabled, catalog: catalogStore.loadCatalog())
        lastSaveError = nil
    }

    func openManagementInterface() {
        managementPresenter.showManagementInterface()
        refresh()
    }

    @discardableResult
    func setItemEnabled(_ enabled: Bool, for itemID: String) -> Bool {
        mutateItem(withID: itemID) { $0.isEnabled = enabled }
    }

    @discardableResult
    func updateDisplayName(_ displayName: String, for itemID: String) -> Bool {
        let normalized = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.range(of: #"[/\0]"#, options: .regularExpression) == nil else { return false }
        return mutateItem(withID: itemID) { $0.displayName = normalized }
    }

    @discardableResult
    func moveItem(withID itemID: String, beforeID targetID: String?) -> Bool {
        var ordered = state.items
        guard let sourceIndex = ordered.firstIndex(where: { $0.id == itemID }) else { return false }
        let item = ordered.remove(at: sourceIndex)
        let destination = targetID.flatMap { target in ordered.firstIndex(where: { $0.id == target }) } ?? ordered.endIndex
        ordered.insert(item, at: destination)
        return persist(orderedItems: ordered)
    }

    @discardableResult
    func moveItems(fromOffsets offsets: IndexSet, toOffset proposedOffset: Int) -> Bool {
        var ordered = state.items
        ordered.move(fromOffsets: offsets, toOffset: proposedOffset)
        return persist(orderedItems: ordered)
    }

    private func mutateItem(withID itemID: String, mutation: (inout FinderNewFileCatalogItem) -> Void) -> Bool {
        var ordered = state.items
        guard let index = ordered.firstIndex(where: { $0.id == itemID }) else { return false }
        mutation(&ordered[index])
        return persist(orderedItems: ordered)
    }

    private func persist(orderedItems: [FinderNewFileCatalogItem]) -> Bool {
        let items = orderedItems.enumerated().map { index, item in
            var copy = item
            copy.sortOrder = index
            return copy
        }
        let catalog = FinderNewFileCatalog(items: items, templateDirectoryURL: state.catalog.templateDirectoryURL)
        do {
            try catalogStore.saveCatalog(catalog)
            state = FinderExtensionSettingsViewState(isEnabled: statusProvider.isEnabled, catalog: catalog)
            lastSaveError = nil
            return true
        } catch {
            lastSaveError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }
}
