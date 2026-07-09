import Foundation

enum BundleIdentifierValidator {
    static func sanitized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValid(trimmed) else {
            return nil
        }
        return trimmed
    }

    static func isValid(_ value: String) -> Bool {
        guard (1...256).contains(value.utf8.count) else {
            return false
        }

        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 45, 46, 48...57, 65...90, 95, 97...122:
                true
            default:
                false
            }
        }
    }
}
