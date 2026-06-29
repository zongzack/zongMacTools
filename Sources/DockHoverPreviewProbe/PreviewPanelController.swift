import AppKit
import SwiftUI

@MainActor
protocol PreviewPanelDisplaying: AnyObject {
    func show(model: PreviewPanelViewModel, anchor: PreviewPanelAnchor, onSelect: @escaping (PreviewWindowID) -> Void)
    func update(model: PreviewPanelViewModel)
    func hide(reason: String)
    func isMouseInsidePanel(_ point: CGPoint) -> Bool
}

@MainActor
final class PreviewPanelController: PreviewPanelDisplaying {
    private let logger: ProbeLogger
    private var panel: NSPanel?
    private var hostingController: NSHostingController<PreviewPanelView>?
    private var currentOnSelect: ((PreviewWindowID) -> Void)?
    private var currentAnchor: PreviewPanelAnchor?

    init(logger: ProbeLogger) {
        self.logger = logger
    }

    func show(model: PreviewPanelViewModel, anchor: PreviewPanelAnchor, onSelect: @escaping (PreviewWindowID) -> Void) {
        currentOnSelect = onSelect
        currentAnchor = anchor

        let panel = ensurePanel()
        let view = PreviewPanelView(model: model) { [weak self] id in
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
        let fittingSize = panel.contentViewController?.view.fittingSize ?? NSSize(width: 256, height: 180)
        let frame = PreviewPanelLayoutEngine.frame(for: fittingSize, anchor: anchor)
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
        self.panel = panel
        return panel
    }
}
