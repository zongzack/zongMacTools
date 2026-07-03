import SwiftUI
import XCTest
@testable import DockHoverPreviewProbe

final class PreviewPanelVisualStyleTests: XCTestCase {
    func testPanelBorderAndPlaceholderSurfaceAreVisibleInLightAndDark() {
        let light = PreviewPanelVisualStyle.tokens(for: .light)
        let dark = PreviewPanelVisualStyle.tokens(for: .dark)

        XCTAssertGreaterThan(light.panelBorderOpacity, 0)
        XCTAssertGreaterThan(dark.panelBorderOpacity, 0)
        XCTAssertGreaterThan(light.placeholderSurfaceOpacity, 0)
        XCTAssertGreaterThan(dark.placeholderSurfaceOpacity, 0)
    }

    func testDarkShadowIsNoStrongerThanLightShadow() {
        let light = PreviewPanelVisualStyle.tokens(for: .light)
        let dark = PreviewPanelVisualStyle.tokens(for: .dark)

        XCTAssertGreaterThan(light.panelShadowOpacity, 0)
        XCTAssertGreaterThan(dark.panelShadowOpacity, 0)
        XCTAssertLessThanOrEqual(dark.panelShadowOpacity, light.panelShadowOpacity)
    }

    func testHoverStatesAreDistinguishableInLightAndDark() {
        for scheme in [ColorScheme.light, .dark] {
            let tokens = PreviewPanelVisualStyle.tokens(for: scheme)

            XCTAssertGreaterThan(tokens.cardHoverBorderOpacity, tokens.cardBorderOpacity)
            XCTAssertGreaterThan(tokens.cardHoverBackgroundOpacity, tokens.cardBackgroundOpacity)
        }
    }
}
