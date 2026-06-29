import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
protocol DockHoverMonitorDelegate: AnyObject {
    func dockHoverMonitor(_ monitor: DockHoverMonitor, didHover app: HoveredDockApp)
    func dockHoverMonitorDidLoseHover(_ monitor: DockHoverMonitor)
}

private func dockAXObserverCallback(observer: AXObserver, element: AXUIElement, notification: CFString, refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let monitor = Unmanaged<DockHoverMonitor>.fromOpaque(refcon).takeUnretainedValue()
    DispatchQueue.main.async {
        monitor.processSelectedChildNotification()
    }
}

@MainActor
final class DockHoverMonitor: @unchecked Sendable {
    weak var delegate: DockHoverMonitorDelegate?

    private let logger: ProbeLogger
    private var observer: AXObserver?
    private var dockListElement: AXUIElement?
    private var dockPID: pid_t?
    private var healthTimer: Timer?
    private var pollTimer: Timer?
    private var lastHovered: HoveredDockApp?

    init(logger: ProbeLogger) {
        self.logger = logger
    }

    func start() {
        stop()
        subscribe()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.healthCheck()
            }
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollMouseLeave()
            }
        }
        logger.info("dock.start")
    }

    func stop() {
        let hadHover = lastHovered != nil
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        healthTimer?.invalidate()
        pollTimer?.invalidate()
        observer = nil
        dockListElement = nil
        dockPID = nil
        lastHovered = nil
        if hadHover {
            logger.info("dock.hoverLost reason=stop")
            delegate?.dockHoverMonitorDidLoseHover(self)
        }
        logger.info("dock.stop")
    }

    func processSelectedChildNotification() {
        guard let hovered = resolveCurrentHoveredDockApp() else {
            if lastHovered != nil {
                logger.info("dock.hoverLost reason=noCandidate")
                lastHovered = nil
                delegate?.dockHoverMonitorDidLoseHover(self)
            }
            return
        }
        lastHovered = hovered
        logger.info("dock.hover app=\(hovered.app.localizedName ?? "unknown") bundle=\(hovered.bundleIdentifier) pid=\(hovered.app.processIdentifier) frame=\(String(describing: hovered.dockItemFrame))")
        delegate?.dockHoverMonitor(self, didHover: hovered)
    }

    func resolveCurrentHoveredDockApp() -> HoveredDockApp? {
        guard let dockListElement else { return nil }
        guard let selected = AXHelpers.optionalAttribute(kAXSelectedChildrenAttribute as CFString, from: dockListElement, as: [AXUIElement].self)?.first else {
            return nil
        }
        let subrole = AXHelpers.stringAttribute(kAXSubroleAttribute as CFString, from: selected)
        guard subrole == "AXApplicationDockItem" else {
            logger.info("dock.selectedIgnored subrole=\(subrole ?? "nil")")
            return nil
        }
        guard let url = AXHelpers.optionalAttribute(kAXURLAttribute as CFString, from: selected, as: URL.self) else {
            logger.warning("dock.selectedMissingURL")
            return nil
        }
        guard let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else {
            logger.warning("dock.bundleResolveFailed url=\(url.path)")
            return nil
        }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            logger.info("dock.appNotRunning bundle=\(bundleIdentifier)")
            return nil
        }
        guard let rawFrame = AXHelpers.frame(of: selected) else {
            logger.warning("dock.selectedMissingFrame bundle=\(bundleIdentifier)")
            return nil
        }
        let frame = convertDockItemFrameForMouseCoordinates(rawFrame)
        let mouse = NSEvent.mouseLocation
        guard GeometryHelpers.contains(mouse, in: frame, tolerance: 2) else {
            logger.info("dock.selectedStale bundle=\(bundleIdentifier) mouse=\(mouse) frame=\(frame)")
            return nil
        }
        return HoveredDockApp(app: app, bundleIdentifier: bundleIdentifier, dockItemElement: selected, dockItemFrame: frame)
    }

    private func subscribe() {
        guard AXIsProcessTrusted() else {
            logger.warning("dock.subscribeSkipped accessibility=false")
            return
        }
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            logger.error("dock.notRunning")
            return
        }
        dockPID = dockApp.processIdentifier
        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        guard let children = AXHelpers.optionalAttribute(kAXChildrenAttribute as CFString, from: dockElement, as: [AXUIElement].self) else {
            logger.error("dock.childrenMissing")
            return
        }
        guard let list = children.first(where: { AXHelpers.stringAttribute(kAXRoleAttribute as CFString, from: $0) == kAXListRole }) else {
            logger.error("dock.listMissing")
            return
        }
        var newObserver: AXObserver?
        let createResult = AXObserverCreate(dockApp.processIdentifier, dockAXObserverCallback, &newObserver)
        guard createResult == .success, let newObserver else {
            logger.error("dock.observerCreateFailed code=\(createResult.rawValue)")
            return
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let addResult = AXObserverAddNotification(newObserver, list, kAXSelectedChildrenChangedNotification as CFString, refcon)
        guard addResult == .success else {
            logger.error("dock.notificationSubscribeFailed code=\(addResult.rawValue)")
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .commonModes)
        observer = newObserver
        dockListElement = list
        logger.info("dock.subscribed pid=\(dockApp.processIdentifier)")
    }

    private func convertDockItemFrameForMouseCoordinates(_ rawFrame: CGRect) -> CGRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { GeometryHelpers.contains(mouse, in: $0.frame, tolerance: 0) }
            ?? NSScreen.screens.first { $0.frame.intersects(rawFrame) }
            ?? NSScreen.main
        guard let screen else { return rawFrame }
        return GeometryHelpers.convertTopLeftFrameToBottomLeftFrame(rawFrame, in: screen.frame)
    }

    private func healthCheck() {
        let currentDock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        if currentDock?.processIdentifier != dockPID {
            logger.warning("dock.pidChanged old=\(String(describing: dockPID)) new=\(String(describing: currentDock?.processIdentifier))")
            stop()
            start()
            return
        }
        guard let dockListElement else {
            logger.warning("dock.healthMissingList")
            stop()
            start()
            return
        }
        var role: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(dockListElement, kAXRoleAttribute as CFString, &role)
        if result == .invalidUIElement || result == .cannotComplete {
            logger.warning("dock.healthInvalid code=\(result.rawValue)")
            stop()
            start()
        }
    }

    private func pollMouseLeave() {
        guard let lastHovered else { return }
        guard let frame = lastHovered.dockItemFrame else { return }
        if !GeometryHelpers.contains(NSEvent.mouseLocation, in: frame, tolerance: 2) {
            self.lastHovered = nil
            logger.info("dock.hoverLost reason=mouseOutside frame=\(frame)")
            delegate?.dockHoverMonitorDidLoseHover(self)
        }
    }
}
