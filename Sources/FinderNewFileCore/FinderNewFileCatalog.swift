import Foundation

#if canImport(Darwin)
import Darwin
#endif

public struct FinderNewFileTemplateReference: Codable, Equatable, Sendable {
    public var relativePath: String

    public init(relativePath: String) {
        self.relativePath = relativePath
    }
}

public struct FinderNewFileIconHint: Codable, Equatable, Sendable {
    public var fileExtension: String

    public init(fileExtension: String) {
        self.fileExtension = FinderNewFileCatalogItem.normalizedFileExtension(fileExtension) ?? fileExtension
    }
}

public struct FinderNewFileCatalogItem: Codable, Equatable, Identifiable, Sendable {
    public enum Source: String, Codable, Equatable, Sendable {
        case builtIn
        case custom
    }

    public var id: String
    public var source: Source
    public var builtInFormat: FinderNewFileFormat?
    public var displayName: String
    public var fileExtension: String
    public var isEnabled: Bool
    public var sortOrder: Int
    public var iconHint: FinderNewFileIconHint
    public var templateReference: FinderNewFileTemplateReference?

    public init(
        id: String,
        source: Source,
        builtInFormat: FinderNewFileFormat? = nil,
        displayName: String,
        fileExtension: String,
        isEnabled: Bool,
        sortOrder: Int,
        iconHint: FinderNewFileIconHint? = nil,
        templateReference: FinderNewFileTemplateReference? = nil
    ) {
        let normalizedExtension = Self.normalizedFileExtension(fileExtension) ?? fileExtension
        self.id = id
        self.source = source
        self.builtInFormat = builtInFormat
        self.displayName = displayName
        self.fileExtension = normalizedExtension
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.iconHint = iconHint ?? FinderNewFileIconHint(fileExtension: normalizedExtension)
        self.templateReference = templateReference
    }

    public static func builtInItem(for format: FinderNewFileFormat, sortOrder: Int) -> FinderNewFileCatalogItem {
        FinderNewFileCatalogItem(
            id: format.stableID,
            source: .builtIn,
            builtInFormat: format,
            displayName: format.defaultDisplayName,
            fileExtension: format.fileExtension,
            isEnabled: true,
            sortOrder: sortOrder
        )
    }

    public func menuTitle(isSimplifiedChinese: Bool) -> String {
        guard source == .builtIn,
              let builtInFormat,
              displayName == builtInFormat.defaultDisplayName
        else {
            return displayName
        }
        return builtInFormat.menuTitle(isSimplifiedChinese: isSimplifiedChinese)
    }

    public func fileNameStem(isSimplifiedChinese: Bool) -> String {
        switch source {
        case .builtIn:
            isSimplifiedChinese ? "新建文稿" : "New Document"
        case .custom:
            displayName
        }
    }

    public func contentData(templateDirectoryURL: URL) throws -> Data {
        switch source {
        case .builtIn:
            guard let builtInFormat else {
                throw FinderNewFileTemplateError.missingBuiltInFormat(id)
            }
            return try builtInFormat.contentData()
        case .custom:
            guard let templateReference else {
                throw FinderNewFileTemplateError.missingTemplateReference(id)
            }
            let templateURL = templateDirectoryURL.appendingPathComponent(templateReference.relativePath, isDirectory: false)
            do {
                return try Data(contentsOf: templateURL, options: [.mappedIfSafe])
            } catch {
                throw FinderNewFileTemplateError.unreadableTemplateCopy(templateReference.relativePath)
            }
        }
    }

    public static func normalizedFileExtension(_ value: String) -> String? {
        var candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.hasPrefix(".") {
            candidate.removeFirst()
        }
        candidate = candidate.lowercased(with: Locale(identifier: "en_US_POSIX"))
        guard !candidate.isEmpty,
              candidate.range(of: #"[./\\:\0\s]"#, options: .regularExpression) == nil
        else {
            return nil
        }
        return candidate
    }
}

public struct FinderNewFileCatalog: Equatable, Sendable {
    public var items: [FinderNewFileCatalogItem]
    public var templateDirectoryURL: URL

    public init(
        items: [FinderNewFileCatalogItem],
        templateDirectoryURL: URL = FinderNewFileCatalogPaths.defaultTemplateDirectoryURL()
    ) {
        self.items = items
        self.templateDirectoryURL = templateDirectoryURL
    }

    public static func defaultCatalog(
        templateDirectoryURL: URL = FinderNewFileCatalogPaths.defaultTemplateDirectoryURL()
    ) -> FinderNewFileCatalog {
        FinderNewFileCatalog(
            items: FinderNewFileFormat.allCases.enumerated().map { index, format in
                FinderNewFileCatalogItem.builtInItem(for: format, sortOrder: index)
            },
            templateDirectoryURL: templateDirectoryURL
        )
    }

    public var orderedItems: [FinderNewFileCatalogItem] {
        items.sorted {
            if $0.sortOrder != $1.sortOrder {
                return $0.sortOrder < $1.sortOrder
            }
            return $0.id < $1.id
        }
    }

    public var enabledOrderedItems: [FinderNewFileCatalogItem] {
        orderedItems.filter(\.isEnabled)
    }

    public func item(withID id: String) -> FinderNewFileCatalogItem? {
        items.first { $0.id == id }
    }
}

public protocol FinderNewFileCatalogProviding {
    func loadCatalog() -> FinderNewFileCatalog
}

public enum FinderNewFileCatalogPaths {
    public static let applicationSupportFolderName = "com.zong.zongMacTools"
    public static let catalogFolderName = "FinderNewFile"
    public static let catalogFileName = "catalog.json"
    public static let templatesFolderName = "Templates"

    public static func defaultCatalogURL() -> URL {
        defaultDirectoryURL().appendingPathComponent(catalogFileName, isDirectory: false)
    }

    public static func defaultTemplateDirectoryURL() -> URL {
        defaultDirectoryURL().appendingPathComponent(templatesFolderName, isDirectory: true)
    }

    public static func defaultDirectoryURL() -> URL {
        defaultApplicationSupportURL()
            .appendingPathComponent(applicationSupportFolderName, isDirectory: true)
            .appendingPathComponent(catalogFolderName, isDirectory: true)
    }

    public static func defaultApplicationSupportURL() -> URL {
        if let realHome = realUserHomeDirectory() {
            return realHome
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        }
        if let userSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return userSupport
        }
        let fallbackHome = ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"
        return URL(fileURLWithPath: fallbackHome, isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
    }

    private static func realUserHomeDirectory() -> URL? {
        #if canImport(Darwin)
        guard let passwd = getpwuid(getuid()), let homePath = passwd.pointee.pw_dir else {
            return nil
        }
        return URL(fileURLWithPath: String(cString: homePath), isDirectory: true)
        #else
        return nil
        #endif
    }
}

public enum FinderNewFileTemplateError: Error, Equatable, LocalizedError, Sendable {
    case missingBuiltInFormat(String)
    case missingTemplateReference(String)
    case unreadableTemplateCopy(String)

    public var errorDescription: String? {
        switch self {
        case .missingBuiltInFormat:
            "内置文件类型配置无效。"
        case .missingTemplateReference:
            "自定义模板引用缺失。"
        case .unreadableTemplateCopy:
            "自定义模板副本无法读取。"
        }
    }
}
