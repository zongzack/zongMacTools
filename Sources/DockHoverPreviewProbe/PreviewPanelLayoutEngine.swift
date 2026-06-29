import CoreGraphics

enum PreviewPanelLayoutEngine {
    private static let spacing: CGFloat = 10

    static func frame(for panelSize: CGSize, anchor: PreviewPanelAnchor) -> CGRect {
        let edge = inferDockEdge(anchor: anchor)
        let proposedOrigin: CGPoint
        if let dockFrame = anchor.dockItemFrame {
            switch edge {
            case .bottom:
                proposedOrigin = CGPoint(x: dockFrame.midX - panelSize.width / 2, y: dockFrame.maxY + spacing)
            case .left:
                proposedOrigin = CGPoint(x: dockFrame.maxX + spacing, y: dockFrame.midY - panelSize.height / 2)
            case .right:
                proposedOrigin = CGPoint(x: dockFrame.minX - spacing - panelSize.width, y: dockFrame.midY - panelSize.height / 2)
            }
        } else {
            proposedOrigin = CGPoint(x: anchor.mouseLocation.x - panelSize.width / 2, y: anchor.mouseLocation.y + spacing)
        }

        return CGRect(origin: clamp(origin: proposedOrigin, panelSize: panelSize, visibleFrame: anchor.visibleFrame), size: panelSize)
    }

    static func inferDockEdge(anchor: PreviewPanelAnchor) -> DockEdge {
        guard let frame = anchor.dockItemFrame else { return .bottom }
        let edgeBand: CGFloat = 80
        if frame.minY <= anchor.screenFrame.minY + edgeBand { return .bottom }
        if frame.minX <= anchor.screenFrame.minX + edgeBand { return .left }
        if frame.maxX >= anchor.screenFrame.maxX - edgeBand { return .right }
        return .bottom
    }

    private static func clamp(origin: CGPoint, panelSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        let maxXOrigin = visibleFrame.maxX - panelSize.width
        let x = maxXOrigin < visibleFrame.minX
            ? visibleFrame.minX
            : min(max(origin.x, visibleFrame.minX), maxXOrigin)
        let maxYOrigin = visibleFrame.maxY - panelSize.height
        let y = maxYOrigin < visibleFrame.minY
            ? visibleFrame.minY
            : min(max(origin.y, visibleFrame.minY), maxYOrigin)

        return CGPoint(
            x: x,
            y: y
        )
    }
}
