import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit

struct PermissionState: Equatable, Sendable {
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool
}

struct HoveredDockApp: Equatable {
    let app: NSRunningApplication
    let bundleIdentifier: String
    let dockItemElement: AXUIElement
    let dockItemFrame: CGRect?
}

struct PreviewWindowID: Hashable, Sendable {
    let pid: pid_t
    let windowID: CGWindowID
}

enum ThumbnailSource: @unchecked Sendable {
    case screenCaptureKit(SCWindow)
    case coreGraphics(CGWindowID)
}

struct PreviewWindow: Identifiable, @unchecked Sendable {
    let id: PreviewWindowID
    let cgWindowID: CGWindowID
    let app: NSRunningApplication
    let title: String
    let frame: CGRect
    let scWindow: SCWindow?
    let axElement: AXUIElement?
    let appIcon: NSImage
    let thumbnailSource: ThumbnailSource?
}

struct ThumbnailCacheKey: Hashable, Sendable {
    let id: PreviewWindowID
    let width: Int
    let height: Int
    let title: String

    init(id: PreviewWindowID, frame: CGRect, title: String) {
        self.id = id
        self.width = Int(frame.width.rounded())
        self.height = Int(frame.height.rounded())
        self.title = title
    }
}

struct ActivationProbeResult: Sendable {
    let windowID: CGWindowID
    let title: String
    let hadAXElement: Bool
    let raiseSucceeded: Bool
    let appActivateRequestSucceeded: Bool
}
