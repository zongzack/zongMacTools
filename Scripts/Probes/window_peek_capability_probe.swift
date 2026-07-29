import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit
import SwiftUI

@main
struct WindowPeekCapabilityProbeApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = ProbeApplicationDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
private final class ProbeApplicationDelegate: NSObject, NSApplicationDelegate {
    private var runtime: ProbeRuntime?

    func applicationDidFinishLaunching(_ notification: Notification) {
        runtime = ProbeRuntime()
        runtime?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtime?.stop()
    }
}

@MainActor
private final class ProbeRuntime: NSObject {
    private let cardsModel = ProbeCardsModel()
    private let broker = ProbeCaptureBroker()
    private var dimmingPanel: ProbeNonKeyPanel?
    private var mirrorPanel: ProbeNonKeyPanel?
    private var cardsPanel: ProbeNonKeyPanel?
    private var monitorTimer: Timer?
    private var sessionEpoch: UInt64 = 0
    private var hoverSequence: UInt64 = 0
    private var selectedWindow: SCWindow?
    private var selectedAXWindow: AXUIElement?
    private var observedAXWindow: AXUIElement?
    private var observer: AXObserver?
    private var observerSource: CFRunLoopSource?
    private var escapeMonitor: Any?
    private var selfDestroyedTestWindow: NSWindow?
    private var waitingForSelfDestroyedNotification = false
    private var fullScreenHostWindow: NSWindow?
    private var fullScreenHostDelegate: ProbeFullScreenHostDelegate?
    private var activeSpaceObserver: NSObjectProtocol?
    private var screenParametersObserver: NSObjectProtocol?

    private var defersCaptureContext: Bool {
        ProcessInfo.processInfo.environment["WINDOW_PEEK_PROBE_DEFER_CAPTURE_CONTEXT"] == "1"
            || (Bundle.main.bundleIdentifier?.hasPrefix("com.zong.windowPeekCapabilityProbe") == true)
    }

    private var runsInteractionAutomation: Bool {
        ProcessInfo.processInfo.environment["WINDOW_PEEK_PROBE_AUTOMATE_INTERACTION"] == "1"
    }

    private var runsFullScreenExperiment: Bool {
        ProcessInfo.processInfo.environment["WINDOW_PEEK_PROBE_FULLSCREEN_EXPERIMENT"] == "1"
    }

    private var runsFullScreenAutoTeardown: Bool {
        ProcessInfo.processInfo.environment["WINDOW_PEEK_PROBE_FULLSCREEN_AUTO_TEARDOWN"] == "1"
    }

    func start() {
        beginSession()
        configurePanels()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.logPanelState(reason: "periodic")
            }
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.hidePanels(reason: "escape")
            return nil
        }
        installTeardownObservers()
        if defersCaptureContext {
            log("captureContext.deferred reason=environment")
        } else {
            Task { @MainActor [weak self] in
                await self?.loadPublicAPIContext()
            }
        }
        if runsInteractionAutomation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.runInteractionAutomation()
            }
        }
        if runsFullScreenExperiment {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.runFullScreenExperiment()
            }
        }
    }

    func stop() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        removeTeardownObservers()
        clearDestroyedObserver()
        fullScreenHostWindow?.orderOut(nil)
        fullScreenHostWindow = nil
        fullScreenHostDelegate = nil
        [cardsPanel, mirrorPanel, dimmingPanel].forEach { $0?.orderOut(nil) }
    }

    private func beginSession() {
        sessionEpoch &+= 1
        hoverSequence = 0
        cardsModel.tick = 0
        log("session.begin epoch=\(sessionEpoch) sequence=0 tick=0")
    }

    private func configurePanels() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.frame ?? NSRect(x: 80, y: 80, width: 1200, height: 800)

        let dimming = makePanel(frame: screenFrame, level: .floating - 2, ignoresMouseEvents: true)
        dimming.contentView = NSView(frame: dimming.contentRect(forFrameRect: dimming.frame))
        dimming.contentView?.wantsLayer = true
        dimming.contentView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.22).cgColor

        let mirrorFrame = NSRect(
            x: screenFrame.midX - 260,
            y: screenFrame.midY - 170,
            width: 520,
            height: 340
        )
        let mirror = makePanel(frame: mirrorFrame, level: .floating - 1, ignoresMouseEvents: true)
        let mirrorView = NSView(frame: mirror.contentRect(forFrameRect: mirror.frame))
        mirrorView.wantsLayer = true
        mirrorView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.76).cgColor
        mirrorView.layer?.borderColor = NSColor.white.withAlphaComponent(0.35).cgColor
        mirrorView.layer?.borderWidth = 1
        mirror.contentView = mirrorView

        let cardsSize = NSSize(width: 744, height: 214)
        let cardsFrame = NSRect(
            x: screenFrame.midX - cardsSize.width / 2,
            y: screenFrame.maxY - cardsSize.height - 64,
            width: cardsSize.width,
            height: cardsSize.height
        )
        let cards = makePanel(frame: cardsFrame, level: .floating, ignoresMouseEvents: false)
        let rootView = ProbeCardsView(
            model: cardsModel,
            onHover: { [weak self] cardID, isInside in
                self?.recordHover(cardID: cardID, isInside: isInside)
            },
            onContextMenuWillOpen: { [weak self] cardID in
                self?.recordContextMenuWillOpen(cardID: cardID)
            },
            onRunCaptureQueue: { [weak self] in
                self?.runCaptureQueueExperiment()
            },
            onRunCancellationExperiment: { [weak self] in
                self?.runCancellationExperiment()
            },
            onRestartSession: { [weak self] in
                self?.beginSession()
            },
            onLoadCaptureContext: { [weak self] in
                Task { @MainActor in
                    await self?.loadPublicAPIContext()
                }
            },
            onRunSelfDestroyedTest: { [weak self] in
                self?.runSelfDestroyedNotificationExperiment()
            }
        )
        cards.contentView = NSHostingView(rootView: rootView)

        dimmingPanel = dimming
        mirrorPanel = mirror
        cardsPanel = cards

        dimming.orderFront(nil)
        mirror.orderFront(nil)
        cards.orderFrontRegardless()
        logPanelState(reason: "initialOrder")
    }

    private func hidePanels(reason: String) {
        [cardsPanel, mirrorPanel, dimmingPanel].forEach { $0?.orderOut(nil) }
        logPanelState(reason: "hidden.\(reason)")
    }

    private func showPanels(reason: String) {
        dimmingPanel?.orderFront(nil)
        mirrorPanel?.orderFront(nil)
        cardsPanel?.orderFrontRegardless()
        logPanelState(reason: "shown.\(reason)")
    }

    private func installTeardownObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        activeSpaceObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hidePanels(reason: "activeSpaceChanged")
            }
        }
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hidePanels(reason: "screenParametersChanged")
            }
        }
    }

    private func removeTeardownObservers() {
        if let activeSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeSpaceObserver)
            self.activeSpaceObserver = nil
        }
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
            self.screenParametersObserver = nil
        }
    }

    private func runFullScreenExperiment() {
        guard fullScreenHostWindow == nil else {
            log("fullScreen.experiment ignored reason=hostAlreadyExists")
            return
        }
        let screenFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 120, y: 120, width: 960, height: 640)
        let host = NSWindow(
            contentRect: NSRect(
                x: screenFrame.midX - 240,
                y: screenFrame.midY - 160,
                width: 480,
                height: 320
            ),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        host.title = "Window Peek Probe Full-Screen Host"
        host.isReleasedWhenClosed = false
        host.collectionBehavior = [.fullScreenPrimary]
        host.contentView?.wantsLayer = true
        host.contentView?.layer?.backgroundColor = NSColor.systemTeal.withAlphaComponent(0.68).cgColor

        let delegate = ProbeFullScreenHostDelegate { [weak self] window in
            guard let self else { return }
            self.log(
                "fullScreen.entered styleMaskFullScreen=\(window.styleMask.contains(.fullScreen)) " +
                    "hostKey=\(window.isKeyWindow) hostMain=\(window.isMainWindow)"
            )
            self.showPanels(reason: "fullScreenEntered")
            if self.runsFullScreenAutoTeardown {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.sendEscapeForExperiment()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.exitFullScreenExperiment()
                }
            }
        }
        host.delegate = delegate
        fullScreenHostWindow = host
        fullScreenHostDelegate = delegate
        NSApp.activate(ignoringOtherApps: true)
        host.makeKeyAndOrderFront(nil)
        log("fullScreen.requested hostWindow=\(host.windowNumber)")
        host.toggleFullScreen(nil)
    }

    private func sendEscapeForExperiment() {
        guard let host = fullScreenHostWindow,
              let event = NSEvent.keyEvent(
                  with: .keyDown,
                  location: .zero,
                  modifierFlags: [],
                  timestamp: ProcessInfo.processInfo.systemUptime,
                  windowNumber: host.windowNumber,
                  context: nil,
                  characters: "\u{1B}",
                  charactersIgnoringModifiers: "\u{1B}",
                  isARepeat: false,
                  keyCode: 53
              )
        else {
            log("escape.automation unavailable reason=eventCreationFailed")
            return
        }
        log("escape.automation sendEvent keyCode=53")
        NSApp.sendEvent(event)
        logPanelState(reason: "escape.automation.afterSendEvent")
    }

    private func exitFullScreenExperiment() {
        guard let host = fullScreenHostWindow, host.styleMask.contains(.fullScreen) else {
            log("fullScreen.exit unavailable reason=hostNotFullScreen")
            return
        }
        log("fullScreen.exit requested")
        host.toggleFullScreen(nil)
    }

    private func runInteractionAutomation() {
        guard let cardsPanel, let screen = NSScreen.main ?? NSScreen.screens.first else {
            log("hover.automation unavailable reason=missingPanelOrScreen")
            return
        }
        guard AXIsProcessTrusted() else {
            log("hover.automation unavailable reason=accessibilityNotTrusted")
            return
        }

        let panelFrame = cardsPanel.frame
        let cardY = panelFrame.maxY - 14 - 69
        let cardPoints = (0 ..< 3).map { index in
            CGPoint(x: panelFrame.minX + 14 + 116 + CGFloat(index) * 244, y: cardY)
        }
        let outsidePoint = CGPoint(x: panelFrame.minX - 20, y: cardY)
        let originalPoint = NSEvent.mouseLocation
        let points = cardPoints + [outsidePoint, originalPoint]

        log("hover.automation started count=\(points.count)")
        Task { @MainActor [weak self] in
            for point in points {
                self?.postMouseMoved(appKitPoint: point, screen: screen)
                try? await Task.sleep(for: .milliseconds(450))
            }
            self?.log("hover.automation finished")
            self?.runSelfDestroyedNotificationExperiment()
        }
    }

    private func postMouseMoved(appKitPoint: CGPoint, screen: NSScreen) {
        let quartzPoint = CGPoint(
            x: appKitPoint.x,
            y: screen.frame.maxY - appKitPoint.y + screen.frame.minY
        )
        guard let source = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(
                  mouseEventSource: source,
                  mouseType: .mouseMoved,
                  mouseCursorPosition: quartzPoint,
                  mouseButton: .left
              )
        else {
            log("hover.automation unavailable reason=eventCreationFailed")
            return
        }
        event.post(tap: .cghidEventTap)
        log("hover.automation moved appKit=\(appKitPoint) quartz=\(quartzPoint)")
    }

    private func makePanel(
        frame: NSRect,
        level: NSWindow.Level,
        ignoresMouseEvents: Bool
    ) -> ProbeNonKeyPanel {
        let panel = ProbeNonKeyPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = level
        panel.ignoresMouseEvents = ignoresMouseEvents
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        return panel
    }

    private func recordHover(cardID: Int, isInside: Bool) {
        hoverSequence &+= 1
        log(
            "hover event=\(isInside ? "enter" : "exit") card=\(cardID) " +
                "epoch=\(sessionEpoch) sequence=\(hoverSequence) tick=\(cardsModel.tick)"
        )
    }

    private func recordContextMenuWillOpen(cardID: Int) {
        log("contextMenuWillOpen card=\(cardID) epoch=\(sessionEpoch) sequence=\(hoverSequence)")
    }

    private func runCaptureQueueExperiment() {
        guard let selectedWindow else {
            log("broker.experiment unavailable reason=noSCWindow")
            return
        }
        broker.submit(origin: .thumbnail, window: selectedWindow)
        broker.submit(origin: .desktopPeek, window: selectedWindow)
        broker.submit(origin: .desktopPeek, window: selectedWindow)
    }

    private func runCancellationExperiment() {
        guard let selectedWindow else {
            log("cancel.experiment unavailable reason=noSCWindow")
            return
        }
        let start = CFAbsoluteTimeGetCurrent()
        log("cancel.requestStarted time=\(start)")
        let task = Task { @MainActor [weak self] in
            let result = await self?.capture(window: selectedWindow)
            self?.log("cancel.captureReturned time=\(CFAbsoluteTimeGetCurrent()) result=\(result ?? "runtimeReleased")")
            self?.broker.submit(origin: .desktopPeek, window: selectedWindow)
            self?.log("cancel.nextRequestStarted time=\(CFAbsoluteTimeGetCurrent())")
        }
        DispatchQueue.main.async { [weak self] in
            self?.log("cancel.taskCancel time=\(CFAbsoluteTimeGetCurrent())")
            task.cancel()
        }
    }

    private func runAutomatedCaptureExperiments() {
        log("autorun.captureExperiments started")
        runCaptureQueueExperiment()
        waitForBrokerThenRunCancellation(remainingAttempts: 20)
    }

    private func waitForBrokerThenRunCancellation(remainingAttempts: Int) {
        guard remainingAttempts > 0 else {
            log("autorun.cancelExperiment blocked reason=brokerStillBusy")
            return
        }
        guard broker.isIdle else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.waitForBrokerThenRunCancellation(remainingAttempts: remainingAttempts - 1)
            }
            return
        }
        runCancellationExperiment()
    }

    private func capture(window: SCWindow) async -> String {
        let configuration = SCStreamConfiguration()
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.width = max(1, Int(window.frame.width.rounded(.up)))
        configuration.height = max(1, Int(window.frame.height.rounded(.up)))

        do {
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            return "success width=\(image.width) height=\(image.height)"
        } catch {
            return "error=\(error)"
        }
    }

    private func loadPublicAPIContext() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            )
            let appKitDisplays: [UInt32: NSScreen] = Dictionary(
                uniqueKeysWithValues: NSScreen.screens.compactMap { screen -> (UInt32, NSScreen)? in
                guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                    return nil
                }
                return (number.uint32Value, screen)
            })

            for display in content.displays {
                let appKit = appKitDisplays[display.displayID]
                let bounds = CGDisplayBounds(display.displayID)
                log(
                    "screen displayID=\(display.displayID) scFrame=\(display.frame) " +
                        "appKitFrame=\(appKit.map { String(describing: $0.frame) } ?? "missing") " +
                        "scale=\(appKit?.backingScaleFactor ?? 0) cgDisplayBoundsDiagnostic=\(bounds)"
                )
            }

            guard let window = content.windows.first(where: { candidate in
                candidate.isOnScreen && candidate.windowLayer == 0 && candidate.frame.width > 100 && candidate.frame.height > 100
            }) else {
                log("window.sample unavailable reason=noEligibleSCWindow")
                return
            }
            selectedWindow = window
            log(
                "window.sample scFrame=\(window.frame) id=\(window.windowID) " +
                    "pid=\(window.owningApplication?.processID ?? 0) title=\(window.title ?? "untitled")"
            )
            let axWindow = matchingAXWindow(for: window)
            selectedAXWindow = axWindow
            log("window.sample axFrame=\(axFrame(of: axWindow).map(String.init(describing:)) ?? "unavailable")")
            installDestroyedObserver(for: axWindow, pid: window.owningApplication?.processID)
            if ProcessInfo.processInfo.environment["WINDOW_PEEK_PROBE_AUTORUN"] == "1" {
                runAutomatedCaptureExperiments()
            }
        } catch {
            log("shareableContent.failed error=\(error)")
        }
    }

    private func matchingAXWindow(for window: SCWindow) -> AXUIElement? {
        guard let pid = window.owningApplication?.processID, AXIsProcessTrusted() else { return nil }
        let application = AXUIElementCreateApplication(pid)
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &rawValue) == .success,
              let windows = rawValue as? [AXUIElement]
        else {
            return nil
        }
        return windows.min { lhs, rhs in
            frameDistance(axFrame(of: lhs), from: window.frame) < frameDistance(axFrame(of: rhs), from: window.frame)
        }
    }

    private func axFrame(of element: AXUIElement?) -> CGRect? {
        guard let element else { return nil }
        guard let positionAXValue = axAttribute(kAXPositionAttribute as CFString, from: element, as: AXValue.self),
              let sizeAXValue = axAttribute(kAXSizeAttribute as CFString, from: element, as: AXValue.self)
        else {
            return nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAXValue, .cgPoint, &position),
              AXValueGetValue(sizeAXValue, .cgSize, &size)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func axAttribute<T>(_ attribute: CFString, from element: AXUIElement, as type: T.Type) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? T
    }

    private func frameDistance(_ candidate: CGRect?, from reference: CGRect) -> CGFloat {
        guard let candidate, !candidate.isNull, !candidate.isEmpty else { return .greatestFiniteMagnitude }
        return abs(candidate.minX - reference.minX)
            + abs(candidate.minY - reference.minY)
            + abs(candidate.width - reference.width)
            + abs(candidate.height - reference.height)
    }

    private func runSelfDestroyedNotificationExperiment() {
        guard AXIsProcessTrusted() else {
            log("ax.selfDestroyed unavailable reason=accessibilityNotTrusted")
            return
        }
        clearDestroyedObserver()
        let title = "Window Peek Probe AX Destroyed Test"
        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 260, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        selfDestroyedTestWindow = window
        window.orderFront(nil)

        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            guard let element = self.ownAXWindow(titled: title) else {
                self.log("ax.selfDestroyed unavailable reason=noOwnAXWindow")
                window.close()
                self.selfDestroyedTestWindow = nil
                return
            }
            self.waitingForSelfDestroyedNotification = true
            self.installDestroyedObserver(for: element, pid: ProcessInfo.processInfo.processIdentifier)
            self.log("ax.selfDestroyed closingTestWindow=true")
            window.close()
            self.selfDestroyedTestWindow = nil
        }
    }

    private func ownAXWindow(titled title: String) -> AXUIElement? {
        let application = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &rawValue) == .success,
              let windows = rawValue as? [AXUIElement]
        else {
            return nil
        }
        return windows.first { element in
            axAttribute(kAXTitleAttribute as CFString, from: element, as: String.self) == title
        }
    }

    private func installDestroyedObserver(for element: AXUIElement?, pid: pid_t?) {
        clearDestroyedObserver()
        guard let element, let pid else {
            log("ax.destroyedSubscription unavailable reason=noAXWindow")
            return
        }

        var newObserver: AXObserver?
        let createResult = AXObserverCreate(pid, probeAXObserverCallback, &newObserver)
        log("ax.observerCreate pid=\(pid) result=\(createResult.rawValue)")
        guard createResult == .success, let newObserver else { return }

        let addResult = AXObserverAddNotification(
            newObserver,
            element,
            kAXUIElementDestroyedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
        log("ax.observerAddDestroyed result=\(addResult.rawValue)")
        guard addResult == .success else { return }

        let source = AXObserverGetRunLoopSource(newObserver)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        observedAXWindow = element
        observer = newObserver
        observerSource = source
        log("ax.observerInstalled mainRunLoop=true")
    }

    private func clearDestroyedObserver() {
        if let observer, let observedAXWindow {
            let removeResult = AXObserverRemoveNotification(
                observer,
                observedAXWindow,
                kAXUIElementDestroyedNotification as CFString
            )
            log("ax.observerRemoveDestroyed result=\(removeResult.rawValue)")
        }
        if let observerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), observerSource, .commonModes)
        }
        observer = nil
        observerSource = nil
        observedAXWindow = nil
    }

    fileprivate func receivedDestroyedNotification() {
        log("ax.destroyedNotification callbackThreadMain=\(Thread.isMainThread)")
        if waitingForSelfDestroyedNotification {
            waitingForSelfDestroyedNotification = false
            log("ax.selfDestroyed callbackReceived=true")
        }
    }

    private func logPanelState(reason: String) {
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        let dockLevel = CGWindowLevelForKey(.dockWindow)
        let menuLevel = CGWindowLevelForKey(.mainMenuWindow)
        let panels = [
            ("dimming", dimmingPanel),
            ("mirror", mirrorPanel),
            ("cards", cardsPanel)
        ]
        for (name, panel) in panels {
            guard let panel else { continue }
            let windowLevel = defersCaptureContext ? nil : onScreenWindowLevel(windowNumber: panel.windowNumber)
            log(
                "panel reason=\(reason) name=\(name) level=\(panel.level.rawValue) " +
                    "visibleLevel=\(windowLevel.map(String.init) ?? "missing") " +
                    "visible=\(panel.isVisible) activeSpace=\(panel.isOnActiveSpace) " +
                    "occlusion=\(panel.occlusionState.rawValue) " +
                    "dockLevel=\(dockLevel) menuLevel=\(menuLevel) " +
                    "key=\(panel.isKeyWindow) main=\(panel.isMainWindow) " +
                    "ignoresMouse=\(panel.ignoresMouseEvents) frontmost=\(frontmost)"
            )
        }
    }

    private func onScreenWindowLevel(windowNumber: Int) -> Int? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.first { entry in
            (entry[kCGWindowNumber as String] as? NSNumber)?.intValue == windowNumber
        }?[kCGWindowLayer as String] as? Int
    }

    private func log(_ message: String) {
        print("[window-peek-probe] \(message)")
        fflush(stdout)
    }
}

private let probeAXObserverCallback: AXObserverCallback = { _, _, _, refcon in
    guard let refcon else { return }
    precondition(Thread.isMainThread)
    let runtime = Unmanaged<ProbeRuntime>.fromOpaque(refcon).takeUnretainedValue()
    MainActor.assumeIsolated {
        runtime.receivedDestroyedNotification()
    }
}

private final class ProbeNonKeyPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class ProbeFullScreenHostDelegate: NSObject, NSWindowDelegate {
    private let onDidEnterFullScreen: (NSWindow) -> Void

    init(onDidEnterFullScreen: @escaping (NSWindow) -> Void) {
        self.onDidEnterFullScreen = onDidEnterFullScreen
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        onDidEnterFullScreen(window)
    }
}

@MainActor
private final class ProbeCaptureBroker {
    enum Origin: String {
        case thumbnail
        case desktopPeek
    }

    private struct Entry {
        let origin: Origin
        let window: SCWindow
        let identifier: UInt64
    }

    private var active: Entry?
    private var pendingDesktopPeek: Entry?
    private var nextIdentifier: UInt64 = 0

    var isIdle: Bool { active == nil && pendingDesktopPeek == nil }

    func submit(origin: Origin, window: SCWindow) {
        nextIdentifier &+= 1
        let entry = Entry(origin: origin, window: window, identifier: nextIdentifier)
        if active == nil {
            launch(entry)
            return
        }

        if origin == .desktopPeek {
            if let replaced = pendingDesktopPeek {
                log("sck.broker.capture.replaced old=\(replaced.identifier) new=\(entry.identifier)")
            }
            pendingDesktopPeek = entry
            log("sck.broker.capture.pending id=\(entry.identifier) origin=desktopPeek")
        } else {
            log("sck.broker.capture.thumbnailIgnored id=\(entry.identifier) reason=physicalInFlight")
        }
    }

    private func launch(_ entry: Entry) {
        active = entry
        log("sck.broker.capture.started id=\(entry.identifier) origin=\(entry.origin.rawValue) inFlight=1")
        Task { @MainActor [weak self] in
            let result = await Self.capture(entry.window)
            guard let self else { return }
            self.log("sck.broker.capture.finished id=\(entry.identifier) origin=\(entry.origin.rawValue) result=\(result) inFlight=0")
            self.active = nil
            if let pending = self.pendingDesktopPeek {
                self.pendingDesktopPeek = nil
                self.launch(pending)
            }
        }
    }

    private static func capture(_ window: SCWindow) async -> String {
        let configuration = SCStreamConfiguration()
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.width = max(1, Int(window.frame.width.rounded(.up)))
        configuration.height = max(1, Int(window.frame.height.rounded(.up)))
        do {
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            return "success width=\(image.width) height=\(image.height)"
        } catch {
            return "error=\(error)"
        }
    }

    private func log(_ message: String) {
        print("[window-peek-probe] \(message)")
        fflush(stdout)
    }
}

@MainActor
private final class ProbeCardsModel: ObservableObject {
    @Published var tick = 0
}

private struct ProbeCardsView: View {
    @ObservedObject var model: ProbeCardsModel
    let onHover: (Int, Bool) -> Void
    let onContextMenuWillOpen: (Int) -> Void
    let onRunCaptureQueue: () -> Void
    let onRunCancellationExperiment: () -> Void
    let onRestartSession: () -> Void
    let onLoadCaptureContext: () -> Void
    let onRunSelfDestroyedTest: () -> Void

    private let colors: [Color] = [.red, .green, .blue]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    ProbeCard(
                        cardID: index + 1,
                        color: color.opacity(0.62 + Double(model.tick % 3) * 0.12),
                        tick: model.tick,
                        onHover: onHover,
                        onContextMenuWillOpen: onContextMenuWillOpen
                    )
                }
            }
            HStack(spacing: 10) {
                Button("Capture A-B-C") { onRunCaptureQueue() }
                Button("Cancel capture") { onRunCancellationExperiment() }
                Button("New session") { onRestartSession() }
                Button("Load capture") { onLoadCaptureContext() }
                Button("AX destroyed") { onRunSelfDestroyedTest() }
                Text("root tick \(model.tick)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                model.tick &+= 1
            }
        }
    }
}

private struct ProbeCard: View {
    let cardID: Int
    let color: Color
    let tick: Int
    let onHover: (Int, Bool) -> Void
    let onContextMenuWillOpen: (Int) -> Void

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .overlay(Text("Card \(cardID)").foregroundStyle(.white))
            Text("content refresh \(tick)")
                .font(.caption2)
        }
        .frame(width: 220, height: 138)
        .padding(6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .onHover { onHover(cardID, $0) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Probe card \(cardID)")
        .overlay {
            ProbeContextMenuBridge(cardID: cardID, onContextMenuWillOpen: onContextMenuWillOpen)
        }
    }
}

private struct ProbeContextMenuBridge: NSViewRepresentable {
    let cardID: Int
    let onContextMenuWillOpen: (Int) -> Void

    func makeNSView(context: Context) -> ProbeContextMenuView {
        ProbeContextMenuView(cardID: cardID, onContextMenuWillOpen: onContextMenuWillOpen)
    }

    func updateNSView(_ nsView: ProbeContextMenuView, context: Context) {
        nsView.cardID = cardID
        nsView.onContextMenuWillOpen = onContextMenuWillOpen
    }
}

private final class ProbeContextMenuView: NSView {
    var cardID: Int
    var onContextMenuWillOpen: (Int) -> Void

    init(cardID: Int, onContextMenuWillOpen: @escaping (Int) -> Void) {
        self.cardID = cardID
        self.onContextMenuWillOpen = onContextMenuWillOpen
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = window?.currentEvent ?? NSApp.currentEvent, event.type == .rightMouseDown else {
            return nil
        }
        return self
    }

    override func rightMouseDown(with event: NSEvent) {
        onContextMenuWillOpen(cardID)
        let menu = NSMenu()
        menu.addItem(withTitle: "Probe action", action: nil, keyEquivalent: "")
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}
