import Foundation

public enum FinderOfficeTemplateError: Error, Equatable, Sendable {
    case missingResource(String)
    case unreadableResource(String)
}

/// Loads the small OOXML packages shipped with the Finder extension. No Office
/// application or user-level template installation is involved in creation.
public enum FinderOfficeTemplateProvider {
    public static func data(for format: FinderNewFileFormat) throws -> Data {
        let resourceName: String
        switch format {
        case .word: resourceName = "BlankWord"
        case .excel: resourceName = "BlankExcel"
        case .powerpoint: resourceName = "BlankPowerPoint"
        case .txt, .markdown, .json:
            throw FinderOfficeTemplateError.missingResource(format.rawValue)
        }

        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "zip") else {
            throw FinderOfficeTemplateError.missingResource(resourceName)
        }
        do {
            return try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw FinderOfficeTemplateError.unreadableResource(resourceName)
        }
    }

}
