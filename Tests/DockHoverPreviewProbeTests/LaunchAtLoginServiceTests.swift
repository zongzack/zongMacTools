import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class LaunchAtLoginServiceTests: XCTestCase {
    func testSystemServiceCanBeConstructed() {
        _ = SystemLaunchAtLoginService()
    }

    func testStatusTitles() {
        XCTAssertEqual(LaunchAtLoginStatus.enabled.menuTextKey, .launchAtLoginEnabled)
        XCTAssertEqual(LaunchAtLoginStatus.notRegistered.menuTextKey, .launchAtLoginNotRegistered)
        XCTAssertEqual(LaunchAtLoginStatus.requiresApproval.menuTextKey, .launchAtLoginRequiresApproval)
        XCTAssertEqual(LaunchAtLoginStatus.notFound.menuTextKey, .launchAtLoginNotFound)
    }

    func testNotFoundDisablesToggleActions() {
        XCTAssertFalse(LaunchAtLoginStatus.notFound.canEnable)
        XCTAssertFalse(LaunchAtLoginStatus.notFound.canDisable)
        XCTAssertTrue(LaunchAtLoginStatus.notFound.canOpenSettings)
    }
}
