import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class WindowEnvironmentDescriptorTests: XCTestCase {
    func testSingleCaptureScreenMatchUsesLocalizedScreenName() {
        let description = WindowEnvironmentDescriptor.description(
            forCaptureFrame: CGRect(x: 100, y: 100, width: 800, height: 600),
            screens: [
                makeScreen(
                    identifier: 1,
                    localizedName: "Built-in Display",
                    captureFrame: CGRect(x: 0, y: 0, width: 1512, height: 982)
                )
            ],
            textProvider: AppTextProvider(language: .english)
        )

        XCTAssertEqual(description, "Screen: Built-in Display")
    }

    func testCaptureScreensPickLargestIntersectionArea() {
        let description = WindowEnvironmentDescriptor.description(
            forCaptureFrame: CGRect(x: 900, y: 100, width: 900, height: 600),
            screens: [
                makeScreen(
                    identifier: 1,
                    localizedName: "Built-in Display",
                    captureFrame: CGRect(x: 0, y: 0, width: 1200, height: 900),
                    appKitFrame: CGRect(x: 1200, y: 0, width: 1200, height: 900)
                ),
                makeScreen(
                    identifier: 2,
                    localizedName: "Studio Display",
                    captureFrame: CGRect(x: 1200, y: 0, width: 1200, height: 900),
                    appKitFrame: CGRect(x: 0, y: 0, width: 1200, height: 900)
                )
            ],
            textProvider: AppTextProvider(language: .english)
        )

        XCTAssertEqual(description, "Screen: Studio Display")
    }

    func testUnknownWhenNoScreenIntersectsWindow() {
        let description = WindowEnvironmentDescriptor.description(
            forCaptureFrame: CGRect(x: 2000, y: 2000, width: 500, height: 400),
            screens: [
                makeScreen(
                    identifier: 1,
                    localizedName: "Built-in Display",
                    captureFrame: CGRect(x: 0, y: 0, width: 1512, height: 982)
                )
            ],
            textProvider: AppTextProvider(language: .english)
        )

        XCTAssertEqual(description, "Screen: Unknown")
    }

    func testSimplifiedChineseScreenDescriptionUsesLocalizedPrefix() {
        let description = WindowEnvironmentDescriptor.description(
            forCaptureFrame: CGRect(x: 100, y: 100, width: 800, height: 600),
            screens: [
                makeScreen(
                    identifier: 1,
                    localizedName: "Mi Monitor",
                    captureFrame: CGRect(x: 0, y: 0, width: 1512, height: 982)
                )
            ],
            textProvider: AppTextProvider(language: .simplifiedChinese)
        )

        XCTAssertEqual(description, "\u{5C4F}\u{5E55}\u{FF1A}Mi Monitor")
    }
}

private func makeScreen(
    identifier: UInt32,
    localizedName: String?,
    captureFrame: CGRect,
    appKitFrame: CGRect? = nil
) -> WindowPeekScreen {
    WindowPeekScreen(
        identifier: identifier,
        localizedName: localizedName,
        captureFrame: captureFrame,
        appKitFrame: appKitFrame ?? captureFrame,
        backingScaleFactor: 1
    )
}
