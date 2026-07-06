import Foundation
import XCTest
@testable import DockHoverPreviewProbe

final class AppMetadataTests: XCTestCase {
    func testReadsMetadataFromInfoDictionary() {
        let metadata = AppMetadata(
            infoDictionary: [
                "CFBundleDisplayName": "zongMacTools",
                "CFBundleName": "FallbackName",
                "CFBundleShortVersionString": "0.1.0",
                "CFBundleVersion": "7",
                "CFBundleIdentifier": "com.zong.zongMacTools",
                "CFBundleExecutable": "DockHoverPreviewProbe"
            ],
            bundleURL: URL(fileURLWithPath: "/Applications/zongMacTools.app"),
            signingStatus: .adHoc
        )

        XCTAssertEqual(metadata.appName, "zongMacTools")
        XCTAssertEqual(metadata.version, "0.1.0")
        XCTAssertEqual(metadata.buildNumber, "7")
        XCTAssertEqual(metadata.bundleIdentifier, "com.zong.zongMacTools")
        XCTAssertEqual(metadata.bundlePath, "/Applications/zongMacTools.app")
        XCTAssertEqual(metadata.executableName, "DockHoverPreviewProbe")
        XCTAssertEqual(metadata.versionDisplayString, "Version 0.1.0 (7)")
        XCTAssertEqual(metadata.signingStatus.displayString, "Ad-hoc signature")
    }

    func testFallsBackWhenInfoDictionaryValuesAreMissing() {
        let metadata = AppMetadata(
            infoDictionary: [:],
            bundleURL: URL(fileURLWithPath: "/tmp/Preview.app"),
            signingStatus: .unknown("not checked")
        )

        XCTAssertEqual(metadata.appName, "Preview")
        XCTAssertEqual(metadata.version, "0.0.0")
        XCTAssertEqual(metadata.buildNumber, "0")
        XCTAssertEqual(metadata.bundleIdentifier, "unknown.bundle")
        XCTAssertEqual(metadata.executableName, "unknown")
        XCTAssertEqual(metadata.signingStatus.displayString, "Unknown: not checked")
    }

    func testParsesCodesignOutputForAdHocAndSignedIdentities() {
        XCTAssertEqual(
            AppSigningStatus.parse(codesignOutput: "Executable=/tmp/zongMacTools\nSignature=adhoc\nCDHash=ABC123"),
            .adHoc
        )
        XCTAssertEqual(
            AppSigningStatus.parse(codesignOutput: "Authority=Developer ID Application: Example Co\nAuthority=Developer ID Certification Authority"),
            .signed(identity: "Developer ID Application: Example Co")
        )
        XCTAssertEqual(
            AppSigningStatus.parse(codesignOutput: "code object is not signed at all"),
            .unsigned
        )
    }
}
