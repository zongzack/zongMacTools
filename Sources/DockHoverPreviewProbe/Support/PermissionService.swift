import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics

protocol PermissionService: AnyObject {
    var currentState: PermissionState { get }
    func refresh() -> PermissionState
    func requestAccessibilityPrompt()
    func openAccessibilitySettings()
    func openScreenRecordingSettings()
}

final class SystemPermissionService: PermissionService {
    private(set) var currentState: PermissionState
    private let logger: ProbeLogger

    init(logger: ProbeLogger) {
        self.logger = logger
        self.currentState = PermissionState(
            accessibilityGranted: AXIsProcessTrusted(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess()
        )
    }

    func refresh() -> PermissionState {
        currentState = PermissionState(
            accessibilityGranted: AXIsProcessTrusted(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess()
        )
        logger.info("permissions.refresh accessibility=\(currentState.accessibilityGranted) screenRecording=\(currentState.screenRecordingGranted)")
        return currentState
    }

    func requestAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        logger.info("permissions.accessibilityPrompt trusted=\(trusted)")
        _ = refresh()
    }

    func openAccessibilitySettings() {
        openSettings(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openScreenRecordingSettings() {
        openSettings(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private func openSettings(urlString: String) {
        guard let url = URL(string: urlString) else {
            logger.error("permissions.openSettings.invalidURL \(urlString)")
            return
        }
        let opened = NSWorkspace.shared.open(url)
        if opened {
            logger.info("permissions.openSettings \(urlString) opened=true")
        } else {
            logger.warning("permissions.openSettings \(urlString) opened=false")
        }
    }
}
