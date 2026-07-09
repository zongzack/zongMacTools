import AppKit
import CoreGraphics

struct WindowEnvironmentDescriptor {
    struct Screen: Equatable, Sendable {
        let frame: CGRect
        let localizedName: String?
    }

    static func currentScreens() -> [Screen] {
        NSScreen.screens.map {
            Screen(frame: $0.frame, localizedName: $0.localizedName)
        }
    }

    static func description(
        for windowFrame: CGRect,
        screens: [NSScreen],
        textProvider: AppTextProvider
    ) -> String {
        description(
            for: windowFrame,
            screens: screens.map { Screen(frame: $0.frame, localizedName: $0.localizedName) },
            textProvider: textProvider
        )
    }

    static func description(
        for windowFrame: CGRect,
        screens: [Screen],
        textProvider: AppTextProvider
    ) -> String {
        guard windowFrame.width > 0, windowFrame.height > 0 else {
            return textProvider.string(.screenUnknown)
        }

        let bestMatch = screens
            .map { screen in
                (screen: screen, area: intersectionArea(windowFrame, screen.frame))
            }
            .filter { $0.area > 0 }
            .max { lhs, rhs in lhs.area < rhs.area }

        guard
            let screen = bestMatch?.screen,
            let name = screen.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty
        else {
            return textProvider.string(.screenUnknown)
        }

        return textProvider.screenDescription(name)
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, !intersection.isEmpty else {
            return 0
        }
        return intersection.width * intersection.height
    }
}
