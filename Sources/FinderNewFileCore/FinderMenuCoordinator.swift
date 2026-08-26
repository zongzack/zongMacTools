import Foundation

public enum FinderMenuKind: Equatable, Sendable {
    case contextualMenuForItems
    case contextualMenuForContainer
    case contextualMenuForSidebar
    case toolbarItemMenu
}

public struct FinderMenuRequest: Sendable {
    public let kind: FinderMenuKind
    public let targetedURL: URL?
    public let selectedURLs: [URL]?

    public init(kind: FinderMenuKind, targetedURL: URL?, selectedURLs: [URL]? = nil) {
        self.kind = kind
        self.targetedURL = targetedURL
        self.selectedURLs = selectedURLs
    }
}

public struct FinderMenuItemPlan: Equatable, Sendable {
    public let identifier: String
    public let title: String
    public let isEnabled: Bool

    public init(identifier: String, title: String, isEnabled: Bool) {
        self.identifier = identifier
        self.title = title
        self.isEnabled = isEnabled
    }
}

public protocol FinderDirectoryValidating {
    func isValidDirectory(_ url: URL) -> Bool
}

public struct LocalFinderDirectoryValidator: FinderDirectoryValidating {
    public init() {}

    public func isValidDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let path = url.standardizedFileURL.path
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
            && FileManager.default.isWritableFile(atPath: path)
    }
}

public struct FinderMenuCoordinator {
    public static let newFileIdentifier = "com.zong.zongMacTools.finder.new-file"

    private let directoryValidator: FinderDirectoryValidating
    private let title: String

    public init(
        directoryValidator: FinderDirectoryValidating = LocalFinderDirectoryValidator(),
        title: String = "New File"
    ) {
        self.directoryValidator = directoryValidator
        self.title = title
    }

    public func menuPlan(for request: FinderMenuRequest) -> [FinderMenuItemPlan] {
        guard request.kind == .contextualMenuForContainer,
              request.selectedURLs?.isEmpty ?? true,
              let targetedURL = request.targetedURL,
              directoryValidator.isValidDirectory(targetedURL)
        else {
            return []
        }

        return [FinderMenuItemPlan(
            identifier: Self.newFileIdentifier,
            title: title,
            isEnabled: false
        )]
    }
}
