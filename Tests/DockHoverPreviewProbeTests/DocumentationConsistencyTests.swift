import XCTest

final class DocumentationConsistencyTests: XCTestCase {
    func testCurrentDocsUseZongMacToolsBundlePath() throws {
        for path in currentDocumentationPaths {
            let source = try contents(of: path)

            XCTAssertFalse(source.contains("build/DockHoverPreviewProbe.app"), "\(path) should use build/zongMacTools.app for current instructions.")
            XCTAssertFalse(source.contains("open build/DockHoverPreviewProbe.app"), "\(path) should not instruct opening the old bundle path.")
        }
    }

    func testReadmeDocumentsP1PackagingAndSettings() throws {
        let readme = try contents(of: "README.md")

        XCTAssertTrue(readme.contains("build/zongMacTools.app"))
        XCTAssertTrue(readme.contains("SwiftPM executable"))
        XCTAssertTrue(readme.contains("DockHoverPreviewProbe"))
        XCTAssertTrue(readme.contains("菜单栏 template logo"))
        XCTAssertFalse(readme.contains("菜单栏会显示 `DHP`"))
        XCTAssertTrue(readme.contains("P1"))
        XCTAssertTrue(readme.contains("Launch at Login"))
        XCTAssertTrue(readme.contains("ServiceManagement"))
        XCTAssertTrue(readme.contains("Screen Recording 权限缺失时静默抑制预览 UI"))
    }

    func testVerificationDocsRecordAutomaticEvidenceWithoutManualPassClaims() throws {
        let checklist = try contents(of: "docs/verification/dock-hover-preview-mvp-ui-manual-checklist.md")
        let summary = try contents(of: "docs/verification/dock-hover-preview-probe-summary.md")

        for evidence in ["swift test", "swift build", "Scripts/build_probe_app.sh", "git diff --check"] {
            XCTAssertTrue(checklist.contains(evidence), "Checklist should record automatic evidence for \(evidence).")
            XCTAssertTrue(summary.contains(evidence), "Summary should record automatic evidence for \(evidence).")
        }
        XCTAssertTrue(checklist.contains("P1 手动验证队列"))
        XCTAssertTrue(summary.contains("P1 manual validation"))
        XCTAssertFalse(checklist.contains("Finder shows `zongMacTools.app` with the Z icon：通过"))
        XCTAssertFalse(summary.contains("Launch at Login：通过"))
    }

    private var currentDocumentationPaths: [String] {
        [
            "README.md",
            "docs/architecture/dock-hover-preview-technical-design.md",
            "docs/verification/dock-hover-preview-mvp-ui-manual-checklist.md",
            "docs/verification/dock-hover-preview-probe-summary.md",
            "docs/verification/dock-hover-preview-environment-variant-verification-plan.md",
            "docs/plans/dock-hover-preview-p1-settings-design.md"
        ]
    }

    private func contents(of relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
