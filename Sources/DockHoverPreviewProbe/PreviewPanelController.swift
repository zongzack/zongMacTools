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
final class PreviewPanelController: PreviewPanelDisplaying {
    var onRequestHide: ((String) -> Void)?

    private let logger: ProbeLogger
    private var panel: NSPanel?
    private var hostingController: NSHostingController<PreviewPanelView>?
    private var currentOnSelect: ((PreviewWindowID) -> Void)?
    private var currentAnchor: PreviewPanelAnchor?
    private var eventMonitorOwner: PreviewPanelEventMonitorOwner?

    init(logger: ProbeLogger) {
        self.logger = logger
    }

    func show(model: PreviewPanelViewModel, anchor: PreviewPanelAnchor, onSelect: @escaping (PreviewWindowID) -> Void) {
        currentOnSelect = onSelect
        currentAnchor = anchor

        let panel = ensurePanel()
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
        panel.orderFrontRegardless()
        logger.info("preview.panel.show app=\(model.appName) count=\(model.cards.count) frame=\(frame)")
    }

    func update(model: PreviewPanelViewModel) {
        guard let currentAnchor else { return }
        let onSelect = currentOnSelect ?? { _ in }
        show(model: model, anchor: currentAnchor, onSelect: onSelect)
        logger.info("preview.panel.update app=\(model.appName) count=\(model.cards.count)")
    }

    func hide(reason: String) {
        guard let panel else { return }
        panel.orderOut(nil)
        currentAnchor = nil
        currentOnSelect = nil
        logger.info("preview.panel.hide reason=\(reason)")
    }

    func isMouseInsidePanel(_ point: CGPoint) -> Bool {
        guard let panel, panel.isVisible else { return false }
        return GeometryHelpers.contains(point, in: panel.frame, tolerance: 2)
    }

    func panelFrame() -> CGRect? {
        guard let panel, panel.isVisible else { return nil }
        return panel.frame
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
