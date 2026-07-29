import CoreGraphics

enum WindowPeekImageQuality: Int, Sendable {
    case coarse
    case highResolution
}

enum WindowPeekCaptureResult {
    case image(CGImage)
    case unavailable
    case permissionDenied
    case failed
}

struct WindowPeekPixelSize: Equatable, Sendable {
    let width: Int
    let height: Int
}

struct WindowPeekCaptureConfiguration: Equatable, Sendable {
    let pixelSize: WindowPeekPixelSize
    let showsCursor: Bool
    let ignoresSingleWindowShadow: Bool
}

struct WindowPeekScreen: Equatable, Sendable {
    let identifier: UInt32
    let localizedName: String?
    let captureFrame: CGRect
    let appKitFrame: CGRect
    let backingScaleFactor: CGFloat
}

struct WindowPeekLayout: Equatable, Sendable {
    let screen: WindowPeekScreen
    let dimmingFrame: CGRect
    let mirrorFrame: CGRect
    let windowCaptureFrame: CGRect
    let windowAppKitFrame: CGRect
    let pointCropRect: CGRect
}

enum WindowPeekStopReason: String, Sendable {
    case hoverExited
    case sessionReplaced
    case sessionHidden
    case primarySelection
    case contextMenu
    case settingsDisabled
    case targetUnavailable
    case targetWindowDestroyed
    case permissionDenied
    case activeSpaceChanged
    case screenParametersChanged
    case applicationTerminated
    case appTermination
}

struct WindowPeekCaptureRequestToken: Equatable, Sendable {
    let sessionEpoch: UInt64
    let peekGeneration: UInt64
    let windowID: PreviewWindowID
}
