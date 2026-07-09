import ApplicationServices
import CoreGraphics

enum AXReadError: Error, CustomStringConvertible {
    case copyFailed(attribute: String, code: AXError)
    case typeMismatch(attribute: String)

    var description: String {
        switch self {
        case let .copyFailed(attribute, code):
            return "AX copy failed attribute=\(attribute) code=\(code.rawValue)"
        case let .typeMismatch(attribute):
            return "AX type mismatch attribute=\(attribute)"
        }
    }
}

enum AXHelpers {
    static func copyAttribute<T>(_ attribute: CFString, from element: AXUIElement, as type: T.Type) throws -> T {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            throw AXReadError.copyFailed(attribute: attribute as String, code: result)
        }
        guard let typed = value as? T else {
            throw AXReadError.typeMismatch(attribute: attribute as String)
        }
        return typed
    }

    static func optionalAttribute<T>(_ attribute: CFString, from element: AXUIElement, as type: T.Type) -> T? {
        try? copyAttribute(attribute, from: element, as: type)
    }

    static func stringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        optionalAttribute(attribute, from: element, as: String.self)
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        guard
            let positionValue = optionalAttribute(kAXPositionAttribute as CFString, from: element, as: AXValue.self),
            let sizeValue = optionalAttribute(kAXSizeAttribute as CFString, from: element, as: AXValue.self)
        else {
            return nil
        }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &point), AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: point, size: size)
    }
}
