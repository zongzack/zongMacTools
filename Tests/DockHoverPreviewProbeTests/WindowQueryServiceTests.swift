import CoreGraphics
import XCTest
@testable import DockHoverPreviewProbe

final class WindowQueryServiceTests: XCTestCase {
    func testAXMatchDiagnosticsLogLineIncludesMatchingEvidence() {
        let diagnostics = AXMatchDiagnostics(
            axWindowCount: 4,
            minimizedCount: 1,
            threshold: 0.72,
            matched: false,
            bestScore: 0.61,
            bestFrame: CGRect(x: 10, y: 20, width: 300, height: 200)
        )

        let line = diagnostics.logLine(windowID: 42, scFrame: CGRect(x: 0, y: 0, width: 320, height: 240))

        XCTAssertTrue(line.contains("windows.axMatch id=42"))
        XCTAssertTrue(line.contains("scFrame=(0.0, 0.0, 320.0, 240.0)"))
        XCTAssertTrue(line.contains("axCount=4"))
        XCTAssertTrue(line.contains("matched=false"))
        XCTAssertTrue(line.contains("bestScore=0.610"))
        XCTAssertTrue(line.contains("bestAXFrame=(10.0, 20.0, 300.0, 200.0)"))
        XCTAssertTrue(line.contains("threshold=0.72"))
        XCTAssertTrue(line.contains("minimizedSkipped=1"))
    }
}
