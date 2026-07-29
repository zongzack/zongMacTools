import CoreGraphics

enum WindowScreenSelection {
    static func largestIntersectionIndex(windowFrame: CGRect, screenFrames: [CGRect]) -> Int? {
        var matches: [(index: Int, area: CGFloat)] = []
        for index in screenFrames.indices {
            let intersection = windowFrame.intersection(screenFrames[index])
            let area = intersection.isNull || intersection.isEmpty
                ? CGFloat.zero
                : intersection.width * intersection.height
            guard area > 0 else { continue }
            matches.append((index, area))
        }
        return matches.max { lhs, rhs in lhs.area < rhs.area }?.index
    }
}

struct WindowEnvironmentDescriptor {
    static func description(
        forCaptureFrame captureFrame: CGRect,
        screens: [WindowPeekScreen],
        textProvider: AppTextProvider
    ) -> String {
        guard let index = WindowScreenSelection.largestIntersectionIndex(
            windowFrame: captureFrame,
            screenFrames: screens.map(\.captureFrame)
        ),
        let name = screens[index].localizedName?.trimmingCharacters(in: .whitespacesAndNewlines),
        !name.isEmpty
        else {
            return textProvider.string(.screenUnknown)
        }
        return textProvider.screenDescription(name)
    }
}
