import Foundation
import XCTest

final class PackagingTests: XCTestCase {
    func testInfoPlistUsesZongMacToolsDisplayNameAndIcon() throws {
        let plist = try infoPlist()

        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "DockHoverPreviewProbe")
        let bundleIdentifier = try XCTUnwrap(plist["CFBundleIdentifier"] as? String)
        XCTAssertEqual(bundleIdentifier, "com.zong.zongMacTools")
        XCTAssertFalse(bundleIdentifier.contains("DockHoverPreviewProbe"))
        XCTAssertEqual(plist["CFBundleName"] as? String, "zongMacTools")
        XCTAssertEqual(plist["CFBundleDisplayName"] as? String, "zongMacTools")
        XCTAssertEqual(plist["CFBundleIconFile"] as? String, "zongMacTools")
        XCTAssertTrue((plist["NSAppleEventsUsageDescription"] as? String)?.contains("zongMacTools") ?? false)
        XCTAssertTrue((plist["NSScreenCaptureUsageDescription"] as? String)?.contains("zongMacTools") ?? false)
    }

    func testInfoPlistMaintainsVersionRules() throws {
        let plist = try infoPlist()

        let version = try XCTUnwrap(plist["CFBundleShortVersionString"] as? String)
        let build = try XCTUnwrap(plist["CFBundleVersion"] as? String)

        XCTAssertNotNil(version.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression))
        XCTAssertNotNil(build.range(of: #"^[1-9]\d*$"#, options: .regularExpression))
    }

    func testPackagingScriptsPassBashSyntaxValidation() throws {
        for script in [
            "build_probe_app.sh",
            "verify_app_bundle.sh",
            "package_release_app.sh",
            "run_probe_app.sh"
        ] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-n", packageRoot().appendingPathComponent("Scripts").appendingPathComponent(script).path]

            try process.run()
            process.waitUntilExit()

            XCTAssertEqual(process.terminationStatus, 0, "\(script) must pass bash syntax validation")
        }
    }

    func testIconSourceExists() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageRoot().appendingPathComponent("Assets/AppIcon/zong-mac-tools-logo.png").path))
    }

    private func infoPlist() throws -> [String: Any] {
        let url = packageRoot()
            .appendingPathComponent("Sources")
            .appendingPathComponent("DockHoverPreviewProbe")
            .appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: url)
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(object as? [String: Any])
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
