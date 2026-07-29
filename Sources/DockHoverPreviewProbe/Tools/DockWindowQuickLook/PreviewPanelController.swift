import AppKit
import SwiftUI

@MainActor
protocol PreviewPanelDisplaying: AnyObject {
    var onRequestHide: ((String, UInt64) -> Void)? { get set }

    func show(
        model: PreviewPanelViewModel,
        anchor: PreviewPanelAnchor,
        sessionEpoch: UInt64,
        onAction: @escaping (PreviewPanelAction) -> Void
    )
    func update(model: PreviewPanelViewModel)
    func hide(reason: String)
    func hideImmediately(reason: String)
    func isMouseInsidePanel(_ point: CGPoint) -> Bool
    func panelFrame() -> CGRect?
}

@MainActor
protocol MotionPreferenceProviding {
    var accessibilityDisplayShouldReduceMotion: Bool { get }
}

enum PreviewPanelAnimationMode: Equatable {
    case standard
    case reducedMotion

    var usesScaleOrOffset: Bool {
        self == .standard
    }
}

@MainActor
protocol PanelAnimationControlling: AnyObject {
    func cancelAnimations(for panel: NSPanel)
    func animateShow(
        panel: NSPanel,
        mode: PreviewPanelAnimationMode,
        completion: @escaping @MainActor @Sendable () -> Bool
    )
    func animateHide(
        panel: NSPanel,
        mode: PreviewPanelAnimationMode,
        completion: @escaping @MainActor @Sendable () -> Bool
    )
}

@MainActor
final class PreviewPanelController: PreviewPanelDisplaying, PreviewCardHoverIntentRouting {
    var onRequestHide: ((String, UInt64) -> Void)?

    private let logger: ProbeLogger
    private let motionPreferences: MotionPreferenceProviding
    private let animator: PanelAnimationControlling
    private var panel: NSPanel?
    private var hostingController: NSHostingController<PreviewPanelView>?
    private var currentOnAction: ((PreviewPanelAction) -> Void)?
    private var currentAnchor: PreviewPanelAnchor?
    private var logicalPanelFrame: CGRect?
    private var presentationGeneration = 0
    private var eventMonitorOwner: PreviewPanelEventMonitorOwner?
    private var currentSessionEpoch: UInt64?
    private var hoverSequence: UInt64 = 0

    init(
        logger: ProbeLogger,
        motionPreferences: MotionPreferenceProviding = SystemMotionPreferenceProvider(),
        animator: PanelAnimationControlling = NSPanelAnimationController()
    ) {
        self.logger = logger
        self.motionPreferences = motionPreferences
        self.animator = animator
    }

    func show(
        model: PreviewPanelViewModel,
        anchor: PreviewPanelAnchor,
        sessionEpoch: UInt64,
        onAction: @escaping (PreviewPanelAction) -> Void
    ) {
        currentOnAction = onAction
        currentAnchor = anchor
        currentSessionEpoch = sessionEpoch
        hoverSequence = 0
        installEventMonitor(for: sessionEpoch)

        let panel = ensurePanel()
        let frame = render(
            model: model,
            anchor: anchor,
            sessionEpoch: sessionEpoch,
            in: panel,
            onAction: onAction
        )
        logicalPanelFrame = frame
        presentationGeneration += 1
        let generation = presentationGeneration
        let mode = animationMode()
        animator.cancelAnimations(for: panel)
        panel.ignoresMouseEvents = false
        panel.orderFrontRegardless()
        animator.animateShow(panel: panel, mode: mode) { [weak self] in
            guard
                let self,
                self.presentationGeneration == generation,
                self.panel === panel
            else {
                return false
            }
            panel.alphaValue = 1
            panel.contentView?.layer?.setAffineTransform(.identity)
            return true
        }
        logger.info("preview.panel.show app=\(model.appName) count=\(model.cards.count) frame=\(frame)")
    }

    func update(model: PreviewPanelViewModel) {
        guard let currentAnchor, let panel, let currentOnAction, let currentSessionEpoch else { return }
        let frame = render(
            model: model,
            anchor: currentAnchor,
            sessionEpoch: currentSessionEpoch,
            in: panel,
            onAction: currentOnAction
        )
        logicalPanelFrame = frame
        logger.info("preview.panel.update app=\(model.appName) count=\(model.cards.count)")
    }

    func hide(reason: String) {
        guard let panel else { return }
        let generation = invalidatePresentationState()
        let mode = animationMode()
        animator.cancelAnimations(for: panel)
        panel.ignoresMouseEvents = true
        animator.animateHide(panel: panel, mode: mode) { [weak self, weak panel] in
            guard
                let self,
                let panel,
                self.presentationGeneration == generation,
                self.panel === panel
            else {
                return false
            }
            panel.orderOut(nil)
            panel.alphaValue = 1
            panel.contentView?.layer?.setAffineTransform(.identity)
            return true
        }
        logger.info("preview.panel.hide reason=\(reason)")
    }

    func hideImmediately(reason: String) {
        guard let panel else { return }
        _ = invalidatePresentationState()
        animator.cancelAnimations(for: panel)
        panel.ignoresMouseEvents = true
        panel.orderOut(nil)
        panel.alphaValue = 1
        panel.contentView?.layer?.setAffineTransform(.identity)
        logger.info("preview.panel.hideImmediately reason=\(reason)")
    }

    func isMouseInsidePanel(_ point: CGPoint) -> Bool {
        guard let frame = logicalPanelFrame else { return false }
        return GeometryHelpers.contains(point, in: frame, tolerance: 2)
    }

    func panelFrame() -> CGRect? {
        logicalPanelFrame
    }

    func routeHoverIntent(
        windowID: PreviewWindowID,
        isInside: Bool,
        sessionEpoch: UInt64
    ) {
        guard currentSessionEpoch == sessionEpoch else {
            logger.info("preview.panel.staleHover epoch=\(sessionEpoch) current=\(currentSessionEpoch.map(String.init) ?? "nil")")
            return
        }
        guard let currentOnAction else { return }
        precondition(hoverSequence < UInt64.max, "Hover sequence overflow")
        hoverSequence += 1
        if isInside {
            currentOnAction(.hoverEntered(windowID, sessionEpoch: sessionEpoch, sequence: hoverSequence))
        } else {
            currentOnAction(.hoverExited(windowID, sessionEpoch: sessionEpoch, sequence: hoverSequence))
        }
    }

    func inspection() -> PreviewPanelInspection {
        PreviewPanelInspection(panel: panel)
    }

    private func render(
        model: PreviewPanelViewModel,
        anchor: PreviewPanelAnchor,
        sessionEpoch: UInt64,
        in panel: NSPanel,
        onAction: @escaping (PreviewPanelAction) -> Void
    ) -> CGRect {
        let layout = PreviewPanelLayoutEngine.panelLayout(for: anchor)
        let view = PreviewPanelView(
            model: model,
            layout: layout,
            sessionEpoch: sessionEpoch,
            hoverIntentRouter: self,
            onAction: onAction
        )

        if let hostingController {
            hostingController.rootView = view
        } else {
            let controller = NSHostingController(rootView: view)
            hostingController = controller
            panel.contentViewController = controller
        }

        panel.contentViewController?.view.layoutSubtreeIfNeeded()
        let panelSize = PreviewPanelMetrics.panelSize(cardCount: model.cards.count, layout: layout)
        let frame = PreviewPanelLayoutEngine.frame(for: panelSize, anchor: anchor)
        panel.setFrame(frame, display: true)
        return frame
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let panel = WindowPeekNonKeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 256, height: 180),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = WindowPeekPanelLevels.preview
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        self.panel = panel
        return panel
    }

    private func animationMode() -> PreviewPanelAnimationMode {
        motionPreferences.accessibilityDisplayShouldReduceMotion ? .reducedMotion : .standard
    }

    private func invalidatePresentationState() -> Int {
        logicalPanelFrame = nil
        currentAnchor = nil
        currentOnAction = nil
        currentSessionEpoch = nil
        hoverSequence = 0
        eventMonitorOwner = nil
        presentationGeneration += 1
        return presentationGeneration
    }

    private func installEventMonitor(for sessionEpoch: UInt64) {
        let relay = PreviewPanelEscapeIntentRelay(
            sessionEpoch: sessionEpoch,
            controller: self
        )
        eventMonitorOwner = PreviewPanelEventMonitorOwner { [relay] reason in
            relay.emit(reason: reason)
        }
    }

    fileprivate func routeEscapeIntent(reason: String, sessionEpoch: UInt64) {
        onRequestHide?(reason, sessionEpoch)
    }
}

@MainActor
struct PreviewPanelInspection {
    let panel: NSPanel?
}

@MainActor
final class PreviewPanelEscapeIntentRelay {
    private let sessionEpoch: UInt64
    private weak var controller: PreviewPanelController?

    init(sessionEpoch: UInt64, controller: PreviewPanelController) {
        self.sessionEpoch = sessionEpoch
        self.controller = controller
    }

    func emit(reason: String) {
        controller?.routeEscapeIntent(reason: reason, sessionEpoch: sessionEpoch)
    }
}

@MainActor
struct SystemMotionPreferenceProvider: MotionPreferenceProviding {
    var accessibilityDisplayShouldReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

@MainActor
private final class NSPanelAnimationController: PanelAnimationControlling {
    private let showDuration: TimeInterval = 0.14
    private let hideDuration: TimeInterval = 0.10
    private let transformAnimationKey = "dockHoverPreviewPanelTransform"

    func cancelAnimations(for panel: NSPanel) {
        panel.contentView?.layer?.removeAnimation(forKey: transformAnimationKey)
        panel.contentView?.layer?.setAffineTransform(.identity)
        panel.alphaValue = 1
    }

    func animateShow(
        panel: NSPanel,
        mode: PreviewPanelAnimationMode,
        completion: @escaping @MainActor @Sendable () -> Bool
    ) {
        guard mode == .standard else {
            panel.alphaValue = 1
            panel.contentView?.layer?.setAffineTransform(.identity)
            _ = completion()
            return
        }

        panel.contentView?.wantsLayer = true
        panel.alphaValue = 0
        panel.contentView?.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.98, y: 0.98))
        animateTransform(
            on: panel,
            from: CATransform3DMakeScale(0.98, 0.98, 1),
            to: CATransform3DIdentity,
            duration: showDuration
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = showDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        } completionHandler: {
            MainActor.assumeIsolated {
                _ = completion()
            }
        }
    }

    func animateHide(
        panel: NSPanel,
        mode: PreviewPanelAnimationMode,
        completion: @escaping @MainActor @Sendable () -> Bool
    ) {
        guard mode == .standard else {
            panel.alphaValue = 1
            panel.contentView?.layer?.setAffineTransform(.identity)
            _ = completion()
            return
        }

        panel.contentView?.wantsLayer = true
        panel.alphaValue = 1
        panel.contentView?.layer?.setAffineTransform(.identity)
        animateTransform(
            on: panel,
            from: CATransform3DIdentity,
            to: CATransform3DMakeScale(0.985, 0.985, 1),
            duration: hideDuration
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = hideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                _ = completion()
            }
        }
    }

    private func animateTransform(
        on panel: NSPanel,
        from: CATransform3D,
        to: CATransform3D,
        duration: TimeInterval
    ) {
        guard let layer = panel.contentView?.layer else { return }
        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: transformAnimationKey)
        layer.transform = to
    }
}

private final class PreviewPanelEventMonitorOwner {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private let onRequestHide: @MainActor @Sendable (String) -> Void

    init(onRequestHide: @MainActor @escaping @Sendable (String) -> Void) {
        self.onRequestHide = onRequestHide
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [onRequestHide] event in
            guard event.keyCode == 53 else { return event }
            precondition(Thread.isMainThread)
            MainActor.assumeIsolated {
                onRequestHide("escape")
            }
            return nil
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [onRequestHide] event in
            guard event.keyCode == 53 else { return }
            precondition(Thread.isMainThread)
            MainActor.assumeIsolated {
                onRequestHide("escape")
            }
        }
    }

    deinit {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
    }
}
