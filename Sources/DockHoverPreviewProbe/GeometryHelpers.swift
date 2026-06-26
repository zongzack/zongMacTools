import CoreGraphics

enum GeometryHelpers {
    static func contains(_ point: CGPoint, in rect: CGRect, tolerance: CGFloat) -> Bool {
        rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
    }

    static func convertTopLeftFrameToBottomLeftFrame(_ frame: CGRect, in displayFrame: CGRect) -> CGRect {
        CGRect(
            x: frame.origin.x,
            y: displayFrame.maxY - (frame.origin.y - displayFrame.minY) - frame.height,
            width: frame.width,
            height: frame.height
        )
    }

    static func frameMatchScore(scFrame: CGRect, axFrame: CGRect) -> Double {
        guard scFrame.width > 0, scFrame.height > 0, axFrame.width > 0, axFrame.height > 0 else {
            return 0
        }
        let intersection = scFrame.intersection(axFrame)
        guard !intersection.isNull, !intersection.isEmpty else {
            return 0
        }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = scFrame.width * scFrame.height + axFrame.width * axFrame.height - intersectionArea
        guard unionArea > 0 else {
            return 0
        }
        return Double(intersectionArea / unionArea)
    }
}
