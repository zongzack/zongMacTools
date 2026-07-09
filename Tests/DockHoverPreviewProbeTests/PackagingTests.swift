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

    func testBuildScriptSupportsStableSigningWithAdHocFallback() throws {
        let source = try scriptSource("build_probe_app.sh")

        XCTAssertTrue(source.contains("CODE_SIGN_IDENTITY=\"${CODE_SIGN_IDENTITY:--}\""))
        XCTAssertTrue(source.contains("CODE_SIGN_OPTIONS=()"))
        XCTAssertTrue(source.contains("--options runtime"))
        XCTAssertTrue(source.contains("--timestamp"))
        XCTAssertTrue(source.contains("codesign --force --sign \"$CODE_SIGN_IDENTITY\" \"$APP_DIR\""))
        XCTAssertTrue(source.contains("codesign --force --sign \"$CODE_SIGN_IDENTITY\""))
        XCTAssertTrue(source.contains("codesign --verify --deep --strict \"$APP_DIR\""))
        XCTAssertTrue(source.contains("ad-hoc"))
        XCTAssertTrue(source.contains("TCC"))
        XCTAssertTrue(source.contains("echo \"$APP_DIR\""))
    }

    func testVerifyAppBundleScriptChecksIdentityAndSignature() throws {
        let source = try scriptSource("verify_app_bundle.sh")

        XCTAssertTrue(source.contains("APP_PATH=\"${1:-$ROOT_DIR/build/zongMacTools.app}\""))
        XCTAssertTrue(source.contains("CFBundleExecutable"))
        XCTAssertTrue(source.contains("com.zong.zongMacTools"))
        XCTAssertTrue(source.contains("DockHoverPreviewProbe"))
        XCTAssertTrue(source.contains("zongMacTools.icns"))
        XCTAssertTrue(source.contains("codesign --verify --deep --strict"))
        XCTAssertTrue(source.contains("codesign -dv --verbose=4"))
        XCTAssertTrue(source.contains("ad-hoc"))
        XCTAssertTrue(source.contains("TCC"))
    }

    func testReleasePackagingScriptWritesOnlyIgnoredDistArtifacts() throws {
        let source = try scriptSource("package_release_app.sh")
        let gitignore = try String(contentsOf: packageRoot().appendingPathComponent(".gitignore"), encoding: .utf8)

        XCTAssertTrue(source.contains("CONFIGURATION=\"${CONFIGURATION:-release}\""))
        XCTAssertTrue(source.contains("Scripts/build_probe_app.sh"))
        XCTAssertTrue(source.contains("Scripts/verify_app_bundle.sh"))
        XCTAssertTrue(source.contains("dist/zongMacTools-${VERSION}-${BUILD_NUMBER}"))
        XCTAssertTrue(source.contains("SHA256SUMS.txt"))
        XCTAssertTrue(source.contains("release-metadata.txt"))
        XCTAssertTrue(source.contains("NOTARYTOOL_PROFILE"))
        XCTAssertTrue(source.contains("notarizationStatus="))
        XCTAssertFalse(source.contains("notarizationProfile=${NOTARYTOOL_PROFILE"))
        XCTAssertTrue(gitignore.contains("dist/"))
    }

    func testRuntimeDiagnosticsUseZongMacToolsIdentity() throws {
        let appDelegateSource = try sourceFile("App/AppDelegate.swift")
        let loggerSource = try sourceFile("Shared/ProbeLogger.swift")

        XCTAssertTrue(appDelegateSource.contains("Bundle.main.bundleIdentifier ?? \"com.zong.zongMacTools\""))
        XCTAssertFalse(appDelegateSource.contains("bundleIdentifier=com.zong.DockHoverPreviewProbe"))
        XCTAssertTrue(loggerSource.contains("Logger(subsystem: \"com.zong.zongMacTools\", category: \"probe\")"))
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

    private func sourceFile(_ name: String) throws -> String {
        let url = packageRoot()
            .appendingPathComponent("Sources")
            .appendingPathComponent("DockHoverPreviewProbe")
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
