import Foundation
import XCTest

final class PackagingTests: XCTestCase {
    func testInfoPlistUsesZongMacToolsDisplayNameAndIcon() throws {
        let plist = try infoPlist()

        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "DockHoverPreviewProbe")
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "com.zong.DockHoverPreviewProbe")
        XCTAssertEqual(plist["CFBundleName"] as? String, "zongMacTools")
        XCTAssertEqual(plist["CFBundleDisplayName"] as? String, "zongMacTools")
        XCTAssertEqual(plist["CFBundleIconFile"] as? String, "zongMacTools")
        XCTAssertTrue((plist["NSAppleEventsUsageDescription"] as? String)?.contains("zongMacTools") ?? false)
        XCTAssertTrue((plist["NSScreenCaptureUsageDescription"] as? String)?.contains("zongMacTools") ?? false)
    }

    func testBuildScriptSeparatesExecutableFromBundleNameAndGeneratesIcon() throws {
        let source = try scriptSource("build_probe_app.sh")

        XCTAssertTrue(source.contains("EXECUTABLE_NAME=\"DockHoverPreviewProbe\""))
        XCTAssertTrue(source.contains("APP_BUNDLE_NAME=\"zongMacTools\""))
        XCTAssertTrue(source.contains("APP_DIR=\"$ROOT_DIR/build/${APP_BUNDLE_NAME}.app\""))
        XCTAssertTrue(source.contains("ICON_SOURCE=\"$ROOT_DIR/Assets/AppIcon/zong-mac-tools-logo.png\""))
        XCTAssertTrue(source.contains("iconutil -c icns \"$ICONSET_DIR\" -o \"$RESOURCES_DIR/zongMacTools.icns\""))
        XCTAssertTrue(source.contains("cp \"$ICON_SOURCE\" \"$RESOURCES_DIR/zong-mac-tools-logo.png\""))
        XCTAssertTrue(source.contains("cp \"$EXECUTABLE_PATH\" \"$MACOS_DIR/$EXECUTABLE_NAME\""))
        XCTAssertTrue(source.contains("echo \"$APP_DIR\""))
    }

    func testRunScriptOpensBuildScriptOutput() throws {
        let source = try scriptSource("run_probe_app.sh")

        XCTAssertTrue(source.contains("APP_PATH=\"$(\"$ROOT_DIR/Scripts/build_probe_app.sh\")\""))
        XCTAssertTrue(source.contains("open \"$APP_PATH\""))
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

    private func scriptSource(_ name: String) throws -> String {
        let url = packageRoot()
            .appendingPathComponent("Scripts")
            .appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
