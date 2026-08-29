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

struct FinderTemplateImportFailure: Equatable {
    let fileName: String
    let reason: String
}

struct FinderTemplateImportResult: Equatable {
    let importedItemIDs: [String]
    let failures: [FinderTemplateImportFailure]

    var importedCount: Int { importedItemIDs.count }
    var hasFailures: Bool { !failures.isEmpty }
}

@MainActor
final class FinderExtensionSettingsViewModel: ObservableObject {
    @Published private(set) var state: FinderExtensionSettingsViewState
    @Published private(set) var lastSaveError: String?
    @Published private(set) var lastImportResult: FinderTemplateImportResult?

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
        lastImportResult = nil
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

    /// Updates only custom extensions. Built-in extensions are deliberately immutable.
    @discardableResult
    func updateFileExtension(_ fileExtension: String, for itemID: String) -> Bool {
        guard let item = state.catalog.item(withID: itemID), item.source == .custom,
              let normalized = FinderNewFileCatalogItem.normalizedFileExtension(fileExtension)
        else { return false }
        return mutateItem(withID: itemID) {
            $0.fileExtension = normalized
            $0.iconHint = FinderNewFileIconHint(fileExtension: normalized)
        }
    }

    /// Imports ordinary files, retaining successful copies when another file fails.
    @discardableResult
    func importTemplates(from urls: [URL], textProvider: AppTextProvider? = nil) -> FinderTemplateImportResult {
        let templateDirectory = state.catalog.templateDirectoryURL
        var ordered = state.items
        var importedIDs: [String] = []
        var failures: [FinderTemplateImportFailure] = []
        var copiedReferences: [String] = []
        var importedFileNames: [String] = []

        do {
            try FileManager.default.createDirectory(at: templateDirectory, withIntermediateDirectories: true)
        } catch {
            let result = FinderTemplateImportResult(
                importedItemIDs: [],
                failures: urls.map { FinderTemplateImportFailure(fileName: $0.lastPathComponent, reason: error.localizedDescription) }
            )
            lastImportResult = result
            return result
        }

        for url in urls {
            let fileName = url.lastPathComponent
            guard url.isFileURL, isRegularFile(url) else {
                failures.append(FinderTemplateImportFailure(fileName: fileName, reason: localizedImportReason(.finderNewFileImportRegularOnly, textProvider: textProvider)))
                continue
            }
            guard let fileExtension = FinderNewFileCatalogItem.normalizedFileExtension(url.pathExtension) else {
                failures.append(FinderTemplateImportFailure(fileName: fileName, reason: localizedImportReason(.finderNewFileImportInvalidExtension, textProvider: textProvider)))
                continue
            }
            let displayName = url.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !displayName.isEmpty, displayName.range(of: #"[/\0]"#, options: .regularExpression) == nil else {
                failures.append(FinderTemplateImportFailure(fileName: fileName, reason: localizedImportReason(.finderNewFileImportInvalidName, textProvider: textProvider)))
                continue
            }

            let id = "custom.\(UUID().uuidString.lowercased())"
            let relativePath = "\(id).\(fileExtension)"
            let destination = templateDirectory.appendingPathComponent(relativePath, isDirectory: false)
            do {
                try FileManager.default.copyItem(at: url, to: destination)
                copiedReferences.append(relativePath)
                let item = FinderNewFileCatalogItem(
                    id: id,
                    source: .custom,
                    displayName: displayName,
                    fileExtension: fileExtension,
                    isEnabled: true,
                    sortOrder: ordered.count,
                    templateReference: FinderNewFileTemplateReference(relativePath: relativePath)
                )
                ordered.append(item)
                importedIDs.append(id)
                importedFileNames.append(fileName)
            } catch {
                failures.append(FinderTemplateImportFailure(fileName: fileName, reason: error.localizedDescription))
            }
        }

        if !importedIDs.isEmpty && !persist(orderedItems: ordered) {
            // The previous catalog remains authoritative; remove copies which no entry owns.
            for reference in copiedReferences {
                try? FileManager.default.removeItem(at: templateDirectory.appendingPathComponent(reference))
            }
            failures.append(contentsOf: importedFileNames.map {
                FinderTemplateImportFailure(fileName: $0, reason: lastSaveError ?? localizedImportReason(.finderNewFileImportSaveFailed, textProvider: textProvider))
            })
            importedIDs.removeAll()
        }

        let result = FinderTemplateImportResult(importedItemIDs: importedIDs, failures: failures)
        lastImportResult = result
        return result
    }

    @discardableResult
    func deleteCustomItem(withID itemID: String, confirmed: Bool) -> Bool {
        guard confirmed, let item = state.catalog.item(withID: itemID), item.source == .custom else { return false }
        var ordered = state.items
        ordered.removeAll { $0.id == itemID }
        let templateURL = item.templateReference.map {
            state.catalog.templateDirectoryURL.appendingPathComponent($0.relativePath)
        }
        var stagedURL: URL?
        if let templateURL {
            do {
                if FileManager.default.fileExists(atPath: templateURL.path) {
                    let staging = templateURL.deletingLastPathComponent().appendingPathComponent(".deleting-\(UUID().uuidString)")
                    try FileManager.default.moveItem(at: templateURL, to: staging)
                    stagedURL = staging
                }
            } catch {
                lastSaveError = error.localizedDescription
                return false
            }
        }
        guard persist(orderedItems: ordered) else {
            if let stagedURL, let templateURL {
                try? FileManager.default.moveItem(at: stagedURL, to: templateURL)
            }
            return false
        }
        if let stagedURL { try? FileManager.default.removeItem(at: stagedURL) }
        return true
    }

    @discardableResult
    func restoreDefaults(confirmed: Bool) -> Bool {
        guard confirmed else { return false }
        let templateDirectory = state.catalog.templateDirectoryURL
        let customReferences = state.items.compactMap { item -> String? in
            guard item.source == .custom else { return nil }
            return item.templateReference?.relativePath
        }
        guard persist(orderedItems: FinderNewFileCatalog.defaultCatalog(templateDirectoryURL: templateDirectory).items) else { return false }
        for reference in customReferences {
            try? FileManager.default.removeItem(at: templateDirectory.appendingPathComponent(reference))
        }
        // Remove orphaned copies created by this feature while leaving unrelated files alone.
        if let entries = try? FileManager.default.contentsOfDirectory(at: templateDirectory, includingPropertiesForKeys: [.isDirectoryKey]) {
            for entry in entries where entry.lastPathComponent.hasPrefix("custom.") {
                try? FileManager.default.removeItem(at: entry)
            }
        }
        return true
    }

    private func isRegularFile(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else { return false }
        guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink != true else { return false }
        return true
    }

    private func localizedImportReason(_ key: LocalizedTextKey, textProvider: AppTextProvider?) -> String {
        if let textProvider { return textProvider.string(key) }
        let language: DisplayLanguage = FinderNewFileLanguage.isSimplifiedChinese() ? .simplifiedChinese : .english
        return AppTextProvider(language: language).string(key)
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
