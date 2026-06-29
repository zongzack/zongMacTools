import CoreGraphics

enum DockEdge: Equatable {
    case bottom
    case left
    case right
}

struct PreviewPanelAnchor: Equatable {
    let dockItemFrame: CGRect?
    let mouseLocation: CGPoint
    let screenFrame: CGRect
    let visibleFrame: CGRect
}
