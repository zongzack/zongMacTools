import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class WindowEnvironmentDescriptorTests: XCTestCase {
    func testSingleScreenMatchUsesLocalizedScreenName() {
        let description = WindowEnvironmentDescriptor.description(
            for: CGRect(x: 100, y: 100, width: 800, height: 600),
            screens: [
                WindowEnvironmentDescriptor.Screen(
                    frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                    localizedName: "Built-in Display"
                )
            ],
            textProvider: AppTextProvider(language: .english)
        )

        XCTAssertEqual(description, "Screen: Built-in Display")
    }

    func testMultipleScreensPickLargestIntersectionArea() {
        let description = WindowEnvironmentDescriptor.description(
            for: CGRect(x: 900, y: 100, width: 900, height: 600),
            screens: [
                WindowEnvironmentDescriptor.Screen(
                    frame: CGRect(x: 0, y: 0, width: 1200, height: 900),
                    localizedName: "Built-in Display"
                ),
                WindowEnvironmentDescriptor.Screen(
                    frame: CGRect(x: 1200, y: 0, width: 1200, height: 900),
                    localizedName: "Studio Display"
                )
            ],
            textProvider: AppTextProvider(language: .english)
        )

        XCTAssertEqual(description, "Screen: Studio Display")
    }

    func testUnknownWhenNoScreenIntersectsWindow() {
        let description = WindowEnvironmentDescriptor.description(
            for: CGRect(x: 2000, y: 2000, width: 500, height: 400),
            screens: [
                WindowEnvironmentDescriptor.Screen(
                    frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                    localizedName: "Built-in Display"
                )
            ],
            textProvider: AppTextProvider(language: .english)
        )

        XCTAssertEqual(description, "Screen: Unknown")
    }

    func testSimplifiedChineseScreenDescriptionUsesLocalizedPrefix() {
        let description = WindowEnvironmentDescriptor.description(
            for: CGRect(x: 100, y: 100, width: 800, height: 600),
            screens: [
                WindowEnvironmentDescriptor.Screen(
                    frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                    localizedName: "Mi Monitor"
                )
            ],
            textProvider: AppTextProvider(language: .simplifiedChinese)
        )

        XCTAssertEqual(description, "\u{5C4F}\u{5E55}\u{FF1A}Mi Monitor")
    }
}
