import Foundation

public enum FinderMenuKind: Equatable, Sendable { case contextualMenuForItems, contextualMenuForContainer, contextualMenuForSidebar, toolbarItemMenu }
public struct FinderMenuRequest: Sendable {
    public let kind: FinderMenuKind; public let targetedURL: URL?; public let selectedURLs: [URL]?
    public init(kind: FinderMenuKind, targetedURL: URL?, selectedURLs: [URL]? = nil) { self.kind = kind; self.targetedURL = targetedURL; self.selectedURLs = selectedURLs }
}

public enum FinderNewFileFormat: String, CaseIterable, Codable, Sendable {
    case txt, markdown, json, word, excel, powerpoint
    public var fileExtension: String {
        switch self {
        case .txt: "txt"
        case .markdown: "md"
        case .json: "json"
        case .word: "docx"
        case .excel: "xlsx"
        case .powerpoint: "pptx"
        }
    }
    public func menuTitle(isSimplifiedChinese: Bool) -> String {
        let name: String
        switch self {
        case .txt: name = "TXT"
        case .markdown: name = "Markdown"
        case .json: name = "JSON"
        case .word: name = "Word"
        case .excel: name = "Excel"
        case .powerpoint: name = "PowerPoint"
        }
        return isSimplifiedChinese ? name : "\(name) File"
    }
    public var defaultDisplayName: String {
        switch self {
        case .txt: "TXT"
        case .markdown: "Markdown"
        case .json: "JSON"
        case .word: "Word"
        case .excel: "Excel"
        case .powerpoint: "PowerPoint"
        }
    }
    public var stableID: String { "builtin.\(rawValue)" }
    public var isOfficeFormat: Bool { self == .word || self == .excel || self == .powerpoint }
    public var contents: Data { (try? contentData()) ?? Data() }
    public func contentData() throws -> Data {
        switch self {
        case .txt, .markdown: Data()
        case .json: Data("{}\n".utf8)
        case .word, .excel, .powerpoint: try FinderOfficeTemplateProvider.data(for: self)
        }
    }
}
public enum FinderNewFileLanguage {
    public static func isSimplifiedChinese(_ locale: Locale = .current) -> Bool {
        // System-launched processes such as Finder Sync extensions can report a
        // region-format `Locale.current` (e.g. en_US) even when the user prefers
        // Simplified Chinese. Prefer AppleLanguages to decide menu/file naming.
        if let preferred = Locale.preferredLanguages.first {
            let language = Locale(identifier: preferred).language
            if language.languageCode?.identifier == "zh" {
                return language.script?.identifier != "Hant"
            }
        }
        let language = locale.language
        return language.languageCode?.identifier == "zh" && language.script?.identifier == "Hans"
    }
}

public struct FinderMenuItemPlan: Equatable, Sendable {
    public let identifier: String; public let title: String; public let isEnabled: Bool; public let format: FinderNewFileFormat?; public let fileExtension: String?
    public init(identifier: String, title: String, isEnabled: Bool, format: FinderNewFileFormat? = nil, fileExtension: String? = nil) { self.identifier = identifier; self.title = title; self.isEnabled = isEnabled; self.format = format; self.fileExtension = fileExtension ?? format?.fileExtension }
}
public protocol FinderDirectoryValidating { func isValidDirectory(_ url: URL) -> Bool }

public struct LocalFinderDirectoryValidator: FinderDirectoryValidating {
    public init() {}
    public func isValidDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let path = url.standardizedFileURL.path
        return url.isFileURL && FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue && FileManager.default.isWritableFile(atPath: path)
    }
}

public enum FinderFilePublishError: Error, Equatable { case nameOccupied; case failed(String) }
public protocol FinderFilePublishing { func publish(data: Data, directoryURL: URL, fileName: String) throws -> URL }
public protocol FinderFileSelecting { func select(fileURL: URL) }
public protocol FinderErrorPresenting { func present(error: FinderNewFileError) }
public enum FinderNewFileError: Error, Equatable {
    case invalidDirectory, itemUnavailable(String), nameExhausted, publishFailed(String)
    public var localizedDescription: String { switch self { case .invalidDirectory: "无法在此位置创建文件：目录不存在、不可写或不受支持。"; case .itemUnavailable: "无法创建文件：文件类型已不可用。"; case .nameExhausted: "无法创建文件：候选名称已全部占用。"; case .publishFailed(let reason): "无法创建文件：\(reason)" } }
}
public struct FinderNewFileOutcome: Equatable, Sendable { public let fileURL: URL?; public let error: FinderNewFileError?; public var isSuccess: Bool { fileURL != nil && error == nil } }

public struct FinderNewFileCoordinator {
    public static let newFileIdentifier = "com.zong.zongMacTools.finder.new-file"
    private let directoryValidator: FinderDirectoryValidating; private let publisher: FinderFilePublishing; private let selector: FinderFileSelecting; private let errorPresenter: FinderErrorPresenting; private let catalogProvider: any FinderNewFileCatalogProviding; private let isSimplifiedChinese: () -> Bool
    public init(directoryValidator: FinderDirectoryValidating = LocalFinderDirectoryValidator(), publisher: FinderFilePublishing = SecureAtomicFilePublisher(), selector: FinderFileSelecting = NoopFinderFileSelector(), errorPresenter: FinderErrorPresenting = NoopFinderErrorPresenter(), catalogProvider: any FinderNewFileCatalogProviding = JSONFinderNewFileCatalogStore(), isSimplifiedChinese: @escaping () -> Bool = FinderNewFileCoordinator.defaultLanguage) { self.directoryValidator = directoryValidator; self.publisher = publisher; self.selector = selector; self.errorPresenter = errorPresenter; self.catalogProvider = catalogProvider; self.isSimplifiedChinese = isSimplifiedChinese }
    public func menuPlan(for request: FinderMenuRequest) -> [FinderMenuItemPlan] {
        guard request.kind == .contextualMenuForContainer, let url = request.targetedURL, directoryValidator.isValidDirectory(url) else { return [] }
        // Finder reports the container URL itself in `selectedItemURLs` for the
        // window-background menu, so a selection that only contains the targeted
        // directory must be treated as an empty selection. Only genuine item
        // selections (any URL other than the container) suppress the menu.
        let selected = (request.selectedURLs ?? []).filter { $0.standardizedFileURL != url.standardizedFileURL }
        guard selected.isEmpty else { return [] }
        let catalog = catalogProvider.loadCatalog()
        return catalog.enabledOrderedItems.map {
            FinderMenuItemPlan(identifier: $0.id, title: $0.menuTitle(isSimplifiedChinese: isSimplifiedChinese()), isEnabled: true, format: $0.builtInFormat, fileExtension: $0.iconHint.fileExtension)
        }
    }
    public func create(format: FinderNewFileFormat, in directoryURL: URL) -> FinderNewFileOutcome {
        let item = FinderNewFileCatalogItem.builtInItem(for: format, sortOrder: 0)
        return create(item: item, catalog: FinderNewFileCatalog(items: [item]), in: directoryURL)
    }
    public func create(itemID: String, in directoryURL: URL) -> FinderNewFileOutcome {
        let catalog = catalogProvider.loadCatalog()
        guard let item = catalog.item(withID: itemID) else {
            let error = FinderNewFileError.itemUnavailable(itemID)
            errorPresenter.present(error: error)
            return FinderNewFileOutcome(fileURL: nil, error: error)
        }
        return create(item: item, catalog: catalog, in: directoryURL)
    }
    private func create(item: FinderNewFileCatalogItem, catalog: FinderNewFileCatalog, in directoryURL: URL) -> FinderNewFileOutcome {
        guard directoryValidator.isValidDirectory(directoryURL) else { let error = FinderNewFileError.invalidDirectory; errorPresenter.present(error: error); return FinderNewFileOutcome(fileURL: nil, error: error) }
        let data: Data
        do {
            data = try item.contentData(templateDirectoryURL: catalog.templateDirectoryURL)
        } catch {
            let result = FinderNewFileError.publishFailed((error as NSError).localizedDescription)
            errorPresenter.present(error: result)
            return FinderNewFileOutcome(fileURL: nil, error: result)
        }
        let stem = item.fileNameStem(isSimplifiedChinese: isSimplifiedChinese())
        for index in 1...10_000 {
            let suffix = index == 1 ? "" : " \(index)", name = "\(stem)\(suffix).\(item.fileExtension)"
            do { let url = try publisher.publish(data: data, directoryURL: directoryURL, fileName: name); selector.select(fileURL: url); return FinderNewFileOutcome(fileURL: url, error: nil) }
            catch FinderFilePublishError.nameOccupied { continue }
            catch { let result = FinderNewFileError.publishFailed((error as NSError).localizedDescription); errorPresenter.present(error: result); return FinderNewFileOutcome(fileURL: nil, error: result) }
        }
        let error = FinderNewFileError.nameExhausted; errorPresenter.present(error: error); return FinderNewFileOutcome(fileURL: nil, error: error)
    }
    public static func defaultLanguage() -> Bool { FinderNewFileLanguage.isSimplifiedChinese() }
}
/// Compatibility seam from ticket 01. Ticket 02 uses FinderNewFileCoordinator for actions.
@available(*, deprecated, message: "Use FinderNewFileCoordinator for Finder new-file menus and actions.")
public struct FinderMenuCoordinator {
    public static let newFileIdentifier = FinderNewFileCoordinator.newFileIdentifier
    private let validator: FinderDirectoryValidating
    private let title: String
    public init(directoryValidator: FinderDirectoryValidating = LocalFinderDirectoryValidator(), title: String = "New File") { self.validator = directoryValidator; self.title = title }
    public func menuPlan(for request: FinderMenuRequest) -> [FinderMenuItemPlan] {
        guard request.kind == .contextualMenuForContainer, request.selectedURLs?.isEmpty ?? true, let url = request.targetedURL, validator.isValidDirectory(url) else { return [] }
        return [FinderMenuItemPlan(identifier: Self.newFileIdentifier, title: title, isEnabled: false)]
    }
}
public struct NoopFinderFileSelector: FinderFileSelecting { public init() {}; public func select(fileURL: URL) {} }
public struct NoopFinderErrorPresenter: FinderErrorPresenting { public init() {}; public func present(error: FinderNewFileError) {} }

#if canImport(Darwin)
import Darwin
public struct SecureAtomicFilePublisher: FinderFilePublishing {
    public init() {}
    public func publish(data: Data, directoryURL: URL, fileName: String) throws -> URL {
        let descriptor = open(directoryURL.standardizedFileURL.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW, 0); guard descriptor >= 0 else { throw FinderFilePublishError.failed(String(cString: strerror(errno))) }; defer { close(descriptor) }
        var before = stat(); guard fstat(descriptor, &before) == 0 else { throw FinderFilePublishError.failed("无法读取目录状态") }
        let temporaryName = ".zongMacTools.tmp.\(UUID().uuidString)", tempFD = openat(descriptor, temporaryName, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR); guard tempFD >= 0 else { throw FinderFilePublishError.failed(String(cString: strerror(errno))) }
        var keepTemporary = true; defer { if keepTemporary { _ = unlinkat(descriptor, temporaryName, 0) } }
        try writeAll(data, to: tempFD); guard fsync(tempFD) == 0, close(tempFD) == 0 else { throw FinderFilePublishError.failed(String(cString: strerror(errno))) }
        var after = stat(); guard fstat(descriptor, &after) == 0, before.st_dev == after.st_dev, before.st_ino == after.st_ino else { throw FinderFilePublishError.failed("目录状态已变化") }
        guard renameatx_np(descriptor, temporaryName, descriptor, fileName, UInt32(RENAME_EXCL)) == 0 else { if errno == EEXIST { throw FinderFilePublishError.nameOccupied }; throw FinderFilePublishError.failed(String(cString: strerror(errno))) }
        keepTemporary = false; return directoryURL.appendingPathComponent(fileName)
    }
    private func writeAll(_ data: Data, to descriptor: Int32) throws { try data.withUnsafeBytes { bytes in var offset = 0; while offset < bytes.count { let written = Darwin.write(descriptor, bytes.baseAddress!.advanced(by: offset), bytes.count - offset); guard written > 0 else { throw FinderFilePublishError.failed(String(cString: strerror(errno))) }; offset += written } } }
}
#else
public struct SecureAtomicFilePublisher: FinderFilePublishing { public init() {}; public func publish(data: Data, directoryURL: URL, fileName: String) throws -> URL { throw FinderFilePublishError.failed("平台不支持") } }
#endif
