import Foundation

public enum FinderNewFileCatalogStoreError: Error, Equatable, LocalizedError, Sendable {
    case invalidCatalog

    public var errorDescription: String? {
        switch self {
        case .invalidCatalog:
            "文件目录配置无效，未写入。"
        }
    }
}

/// Storage seam shared by the settings app (writer) and Finder extension (reader).
public protocol FinderNewFileCatalogStoring: FinderNewFileCatalogProviding {
    func saveCatalog(_ catalog: FinderNewFileCatalog) throws
}

public struct JSONFinderNewFileCatalogStore: FinderNewFileCatalogStoring {
    public static let currentVersion = 1

    private let catalogURL: URL
    private let templateDirectoryURL: URL
    private let disk: any FinderNewFileCatalogDiskAccess

    public init(
        catalogURL: URL = FinderNewFileCatalogPaths.defaultCatalogURL(),
        templateDirectoryURL: URL = FinderNewFileCatalogPaths.defaultTemplateDirectoryURL()
    ) {
        self.init(
            catalogURL: catalogURL,
            templateDirectoryURL: templateDirectoryURL,
            disk: LocalFinderNewFileCatalogDiskAccess()
        )
    }

    init(
        catalogURL: URL,
        templateDirectoryURL: URL,
        disk: any FinderNewFileCatalogDiskAccess
    ) {
        self.catalogURL = catalogURL
        self.templateDirectoryURL = templateDirectoryURL
        self.disk = disk
    }

    public func loadCatalog() -> FinderNewFileCatalog {
        guard disk.fileExists(at: catalogURL),
              let data = try? disk.readData(at: catalogURL)
        else {
            return fallbackCatalog()
        }
        let decoder = JSONDecoder()
        guard let document = try? decoder.decode(StorageDocument.self, from: data),
              document.version == Self.currentVersion
        else {
            return fallbackCatalog()
        }
        let items = validatedItems(from: document.items)
        guard !items.isEmpty else {
            return fallbackCatalog()
        }
        // A configuration that only contains invalid custom references must not
        // leave the user with a partial menu. Restore the complete built-in set.
        let declaredCustomCount = document.items.filter { $0.source == .custom }.count
        let validCustomCount = items.filter { $0.source == .custom }.count
        if declaredCustomCount > 0, validCustomCount == 0 {
            return fallbackCatalog()
        }
        return FinderNewFileCatalog(items: items, templateDirectoryURL: templateDirectoryURL)
    }

    public func saveCatalog(_ catalog: FinderNewFileCatalog) throws {
        let items = validatedItems(from: catalog.items, templateDirectoryURL: catalog.templateDirectoryURL)
        guard !items.isEmpty, items.count == catalog.items.count else {
            throw FinderNewFileCatalogStoreError.invalidCatalog
        }

        try disk.createDirectory(at: catalogURL.deletingLastPathComponent())
        try disk.createDirectory(at: catalog.templateDirectoryURL)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(StorageDocument(version: Self.currentVersion, items: items))
        let temporaryURL = catalogURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(catalogURL.lastPathComponent).tmp.\(UUID().uuidString)", isDirectory: false)

        var shouldRemoveTemporary = true
        defer {
            if shouldRemoveTemporary {
                try? disk.removeItem(at: temporaryURL)
            }
        }

        try disk.writeData(data, to: temporaryURL)
        if disk.fileExists(at: catalogURL) {
            try disk.replaceItem(at: catalogURL, withItemAt: temporaryURL)
        } else {
            try disk.moveItem(at: temporaryURL, to: catalogURL)
        }
        shouldRemoveTemporary = false
    }

    private func fallbackCatalog() -> FinderNewFileCatalog {
        FinderNewFileCatalog.defaultCatalog(templateDirectoryURL: templateDirectoryURL)
    }

    private func validatedItems(
        from items: [FinderNewFileCatalogItem],
        templateDirectoryURL: URL? = nil
    ) -> [FinderNewFileCatalogItem] {
        var seenIDs: Set<String> = []
        var validItems: [FinderNewFileCatalogItem] = []
        let templateDirectory = templateDirectoryURL ?? self.templateDirectoryURL
        for item in items {
            guard let validItem = validatedItem(item, templateDirectoryURL: templateDirectory),
                  seenIDs.insert(validItem.id).inserted
            else {
                continue
            }
            validItems.append(validItem)
        }
        return validItems
    }

    private func validatedItem(
        _ item: FinderNewFileCatalogItem,
        templateDirectoryURL: URL
    ) -> FinderNewFileCatalogItem? {
        guard isValidStableID(item.id),
              item.sortOrder >= 0,
              let displayName = normalizedDisplayName(item.displayName),
              let fileExtension = FinderNewFileCatalogItem.normalizedFileExtension(item.fileExtension),
              let iconExtension = FinderNewFileCatalogItem.normalizedFileExtension(item.iconHint.fileExtension),
              iconExtension == fileExtension
        else {
            return nil
        }

        switch item.source {
        case .builtIn:
            guard let format = item.builtInFormat,
                  item.id == format.stableID,
                  fileExtension == format.fileExtension,
                  item.templateReference == nil
            else {
                return nil
            }
            return FinderNewFileCatalogItem(
                id: item.id,
                source: .builtIn,
                builtInFormat: format,
                displayName: displayName,
                fileExtension: fileExtension,
                isEnabled: item.isEnabled,
                sortOrder: item.sortOrder,
                iconHint: FinderNewFileIconHint(fileExtension: fileExtension)
            )
        case .custom:
            guard item.builtInFormat == nil,
                  let reference = item.templateReference,
                  let relativePath = normalizedTemplateRelativePath(reference.relativePath)
            else {
                return nil
            }
            let templateURL = templateDirectoryURL.appendingPathComponent(relativePath, isDirectory: false)
            guard disk.regularFileExists(at: templateURL) else {
                return nil
            }
            return FinderNewFileCatalogItem(
                id: item.id,
                source: .custom,
                displayName: displayName,
                fileExtension: fileExtension,
                isEnabled: item.isEnabled,
                sortOrder: item.sortOrder,
                iconHint: FinderNewFileIconHint(fileExtension: fileExtension),
                templateReference: FinderNewFileTemplateReference(relativePath: relativePath)
            )
        }
    }

    private func normalizedDisplayName(_ value: String) -> String? {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name.range(of: #"[/\0]"#, options: .regularExpression) == nil
        else {
            return nil
        }
        return name
    }

    private func normalizedTemplateRelativePath(_ value: String) -> String? {
        let path = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              path != ".",
              path != "..",
              path.range(of: #"[/\\\0]"#, options: .regularExpression) == nil
        else {
            return nil
        }
        return path
    }

    private func isValidStableID(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil
    }
}

private struct StorageDocument: Codable {
    var version: Int
    var items: [FinderNewFileCatalogItem]
}

protocol FinderNewFileCatalogDiskAccess {
    func readData(at url: URL) throws -> Data
    func writeData(_ data: Data, to url: URL) throws
    func createDirectory(at url: URL) throws
    func fileExists(at url: URL) -> Bool
    func regularFileExists(at url: URL) -> Bool
    func moveItem(at sourceURL: URL, to destinationURL: URL) throws
    func replaceItem(at originalItemURL: URL, withItemAt newItemURL: URL) throws
    func removeItem(at url: URL) throws
}

struct LocalFinderNewFileCatalogDiskAccess: FinderNewFileCatalogDiskAccess {
    func readData(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func writeData(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func regularFileExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && !isDirectory.boolValue
    }

    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    func replaceItem(at originalItemURL: URL, withItemAt newItemURL: URL) throws {
        _ = try FileManager.default.replaceItemAt(originalItemURL, withItemAt: newItemURL)
    }

    func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
