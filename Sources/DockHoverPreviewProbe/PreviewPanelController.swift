import AppKit
import SwiftUI

@MainActor
protocol PreviewPanelDisplaying: AnyObject {
    var onRequestHide: ((String) -> Void)? { get set }

    func show(model: PreviewPanelViewModel, anchor: PreviewPanelAnchor, onSelect: @escaping (PreviewWindowID) -> Void)
    func update(model: PreviewPanelViewModel)
    func hide(reason: String)
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
final class PreviewPanelController: PreviewPanelDisplaying {
    var onRequestHide: ((String) -> Void)?

    private let logger: ProbeLogger
    private let motionPreferences: MotionPreferenceProviding
    private let animator: PanelAnimationControlling
    private var panel: NSPanel?
    private var hostingController: NSHostingController<PreviewPanelView>?
    private var currentOnSelect: ((PreviewWindowID) -> Void)?
    private var currentAnchor: PreviewPanelAnchor?
    private var logicalPanelFrame: CGRect?
    private var presentationGeneration = 0
    private var eventMonitorOwner: PreviewPanelEventMonitorOwner?

    init(
        logger: ProbeLogger,
        motionPreferences: MotionPreferenceProviding = SystemMotionPreferenceProvider(),
        animator: PanelAnimationControlling = NSPanelAnimationController()
    ) {
        self.logger = logger
        self.motionPreferences = motionPreferences
        self.animator = animator
    }

    func show(model: PreviewPanelViewModel, anchor: PreviewPanelAnchor, onSelect: @escaping (PreviewWindowID) -> Void) {
        currentOnSelect = onSelect
        currentAnchor = anchor

        let panel = ensurePanel()
        let frame = render(model: model, anchor: anchor, in: panel)
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
        guard let currentAnchor, let panel else { return }
        let frame = render(model: model, anchor: currentAnchor, in: panel)
        logicalPanelFrame = frame
        logger.info("preview.panel.update app=\(model.appName) count=\(model.cards.count)")
    }

    func hide(reason: String) {
        guard let panel else { return }
        logicalPanelFrame = nil
        currentAnchor = nil
        currentOnSelect = nil
        presentationGeneration += 1
        let generation = presentationGeneration
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

    func isMouseInsidePanel(_ point: CGPoint) -> Bool {
        guard let frame = logicalPanelFrame else { return false }
        return GeometryHelpers.contains(point, in: frame, tolerance: 2)
    }

    func panelFrame() -> CGRect? {
        logicalPanelFrame
    }

    private func render(model: PreviewPanelViewModel, anchor: PreviewPanelAnchor, in panel: NSPanel) -> CGRect {
        let layout = PreviewPanelLayoutEngine.panelLayout(for: anchor)
        let view = PreviewPanelView(model: model, layout: layout) { [weak self] id in
            self?.currentOnSelect?(id)
        }

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

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 256, height: 180),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        eventMonitorOwner = PreviewPanelEventMonitorOwner { [weak self] reason in
            self?.onRequestHide?(reason)
        }
        self.panel = panel
        return panel
    }

    private func animationMode() -> PreviewPanelAnimationMode {
        motionPreferences.accessibilityDisplayShouldReduceMotion ? .reducedMotion : .standard
    }
}

@MainActor
private struct SystemMotionPreferenceProvider: MotionPreferenceProviding {
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
            Task { @MainActor in
                onRequestHide("escape")
            }
            return nil
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [onRequestHide] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor in
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
