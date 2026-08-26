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

    func testFinderSyncInfoPlistProvidesSystemManagementMetadata() throws {
        let url = packageRoot()
            .appendingPathComponent("Sources")
            .appendingPathComponent("FinderSyncExtension")
            .appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: url)
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let plist = try XCTUnwrap(object as? [String: Any])

        XCTAssertEqual(plist["CFBundleDisplayName"] as? String, "zongMacTools")
        let extensionDictionary = try XCTUnwrap(plist["NSExtension"] as? [String: Any])
        XCTAssertNotNil(extensionDictionary["NSExtensionAttributes"] as? [String: Any])
        XCTAssertEqual(extensionDictionary["NSExtensionPointIdentifier"] as? String, "com.apple.FinderSync")
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

    func testAuthoritativeBuildRecordsNestedSigningOrderWithoutDeepSigning() throws {
        let source = try scriptSource(named: "build_probe_app.sh")

        XCTAssertTrue(source.contains("SIGNING_TRACE_PATH"))
        XCTAssertTrue(source.contains("1 extension-sign start"))
        XCTAssertTrue(source.contains("2 extension-sign success"))
        XCTAssertTrue(source.contains("3 app-sign start"))
        XCTAssertTrue(source.contains("4 app-sign success"))
        XCTAssertNil(source.range(of: #"codesign[^\n]*--deep"#, options: .regularExpression), "authoritative build must not use codesign --deep")

        let extensionSuccess = try XCTUnwrap(source.range(of: "2 extension-sign success"))
        let appStart = try XCTUnwrap(source.range(of: "3 app-sign start"))
        XCTAssertLessThan(
            source.distance(from: source.startIndex, to: extensionSuccess.lowerBound),
            source.distance(from: source.startIndex, to: appStart.lowerBound),
            "outer app signing must start only after extension signing succeeds"
        )
    }

    func testBundleVerifierSeparatelyChecksSignaturesEntitlementsAndSingleExtension() throws {
        let source = try scriptSource(named: "verify_app_bundle.sh")

        XCTAssertTrue(source.contains("expected exactly one embedded extension"))
        XCTAssertTrue(source.contains("expected exactly one appex in the complete bundle"))
        XCTAssertTrue(source.contains("codesign --verify --strict \"$EXTENSION_PATH\""))
        XCTAssertTrue(source.contains("codesign --verify --strict \"$APP_PATH\""))
        XCTAssertTrue(source.contains("com.apple.security.app-sandbox"))
        XCTAssertTrue(source.contains("missing signing order trace"))
        XCTAssertTrue(source.contains("artifact app-cdhash"))
        XCTAssertTrue(source.contains("artifact extension-cdhash"))
        XCTAssertTrue(source.contains("find \"$APP_PATH/Contents\" -type f -perm -111 -print0"))
        XCTAssertTrue(source.contains("xmllint --noout --nonet"))
        XCTAssertTrue(source.contains("Sheet1"))
        XCTAssertTrue(source.contains("normalized_arches"))
        XCTAssertTrue(source.contains("unzip -tqq"))
        XCTAssertNil(source.range(of: #"codesign[^\n]*--deep"#, options: .regularExpression), "bundle verification must not hide nested signing failures behind --deep")
    }

    func testReleasePackagingVerifiesTheExtractedArchive() throws {
        let source = try scriptSource(named: "package_release_app.sh")

        XCTAssertTrue(source.contains("ditto -x -k \"$ZIP_PATH\""))
        XCTAssertTrue(source.contains("verify_app_bundle.sh\" \"$ARCHIVE_VERIFY_DIR/${APP_NAME}.app\""))
        XCTAssertTrue(source.contains("mktemp -d"))
    }

    func testIconSourceExists() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageRoot().appendingPathComponent("Assets/AppIcon/zong-mac-tools-logo.png").path))
    }

    func testGitHubDraftReleaseWorkflowMatchesPackagingContract() throws {
        let source = try String(contentsOf: githubDraftReleaseWorkflowURL(), encoding: .utf8)
        let onBlock = try yamlTopLevelBlock(named: "on", in: source)
        let tagTriggerPattern = #"(?ms)^on:[ \t]*(?:#.*)?\r?\n(?:^[ \t]*(?:#.*)?\r?\n)*^([ \t]+)(?:push|\"push\"|'push')[ \t]*:[ \t]*(?:#.*)?\r?\n(?:^[ \t]*(?:#.*)?\r?\n)*^\1([ \t]+)(?:tags|\"tags\"|'tags')[ \t]*:[ \t]*(?:#.*)?\r?\n(?:^[ \t]*(?:#.*)?\r?\n)*^\1\2[ \t]+-[ \t]*(?:\"v\*\"|'v\*'|v\*)[ \t]*(?:#.*)?\r?\n?(?:^[ \t]*(?:#.*)?\r?\n)*\z"#

        XCTAssertNotNil(
            onBlock.range(of: tagTriggerPattern, options: .regularExpression),
            "Workflow must contain only the push tags v* trigger"
        )

        let permissionsBlock = try yamlTopLevelBlock(named: "permissions", in: source)
        let contentsWriteOnlyPattern = #"(?ms)^permissions:[ \t]*(?:#.*)?\r?\n(?:^[ \t]*(?:#.*)?\r?\n)*^[ \t]+contents:[ \t]+write[ \t]*(?:#.*)?\r?\n?(?:^[ \t]*(?:#.*)?\r?\n)*\z"#
        XCTAssertNotNil(
            permissionsBlock.range(of: contentsWriteOnlyPattern, options: .regularExpression),
            "Workflow permissions must grant only contents: write"
        )

        let concurrencyBlock = try yamlTopLevelBlock(named: "concurrency", in: source)
        XCTAssertTrue(
            concurrencyBlock.contains("group: github-draft-release-" + "$" + "{{ github.ref_name }}"),
            "Concurrency must be scoped to the release tag"
        )
        XCTAssertTrue(
            concurrencyBlock.contains("cancel-in-progress: false"),
            "Concurrency must preserve in-progress releases"
        )

        let jobsBlock = try yamlTopLevelBlock(named: "jobs", in: source)
        let releaseJob = try yamlJobBlock(named: "release", in: jobsBlock)
        XCTAssertTrue(releaseJob.contains("runs-on: macos-14"), "Release job must run on macos-14")

        let checkoutStepPattern = #"(?ms)^([ \t]*)-[ \t]+uses:[ \t]+actions/checkout@v4[ \t]*(?:#.*)?\r?\n(?:(?!^\1-[ \t]+).)*(?=^\1-[ \t]+|\z)"#
        let checkoutStepRange = try XCTUnwrap(
            releaseJob.range(of: checkoutStepPattern, options: .regularExpression),
            "Workflow must check out tagged source"
        )
        let checkoutStep = String(releaseJob[checkoutStepRange])
        XCTAssertTrue(checkoutStep.contains("uses: actions/checkout@v4"), "Checkout step must use actions/checkout@v4")
        XCTAssertTrue(checkoutStep.contains("fetch-depth: 0"), "Checkout step must fetch full history")

        let validateTagVersionStep = try yamlStepBlock(named: "Validate tag version", in: releaseJob)
        for expected in [
            "CFBundleShortVersionString",
            "CFBundleVersion",
            "test \"$TAG\" == \"v${VERSION}\"",
            "echo \"VERSION=$VERSION\" >> \"$GITHUB_ENV\"",
            "echo \"BUILD_NUMBER=$BUILD_NUMBER\" >> \"$GITHUB_ENV\""
        ] {
            XCTAssertTrue(validateTagVersionStep.contains(expected), "Validate tag version step must contain: \(expected)")
        }

        let runTestsStep = try yamlStepBlock(named: "Run tests", in: releaseJob)
        XCTAssertTrue(runTestsStep.contains("swift test"), "Run tests step must execute swift test")

        let runTestsStepRange = try XCTUnwrap(
            releaseJob.range(
                of: #"(?m)^[ \t]*-[ \t]+name:[ \t]*(?:\"Run tests\"|'Run tests'|Run tests)[ \t]*(?:#.*)?\r?$"#,
                options: .regularExpression
            ),
            "Workflow must include the Run tests step"
        )
        let packageStepRange = try XCTUnwrap(
            releaseJob.range(
                of: #"(?m)^[ \t]*-[ \t]+name:[ \t]*(?:\"Package public beta\"|'Package public beta'|Package public beta)[ \t]*(?:#.*)?\r?$"#,
                options: .regularExpression
            ),
            "Workflow must include the Package public beta step"
        )
        XCTAssertLessThan(
            releaseJob.distance(from: releaseJob.startIndex, to: runTestsStepRange.lowerBound),
            releaseJob.distance(from: releaseJob.startIndex, to: packageStepRange.lowerBound),
            "Run tests must occur before Package public beta"
        )

        let packageStep = try yamlStepBlock(named: "Package public beta", in: releaseJob)
        let emptyNotaryProfilePattern = #"(?m)^[ \t]*NOTARYTOOL_PROFILE[ \t]*:[ \t]*(?:\"\"|'')[ \t]*(?:#.*)?$"#
        XCTAssertNotNil(
            packageStep.range(of: emptyNotaryProfilePattern, options: .regularExpression),
            "Package step must explicitly disable notarization"
        )
        XCTAssertTrue(
            packageStep.contains("Scripts/package_release_app.sh"),
            "Package step must run the release packaging script"
        )

        let verifyReleaseAssetsStep = try yamlStepBlock(named: "Verify release assets", in: releaseJob)
        for expected in [
            "test -f \"$ZIP_PATH\"",
            "test -f \"$DIST_DIR/SHA256SUMS.txt\"",
            "test -f \"$DIST_DIR/release-metadata.txt\"",
            "test -f \"$DIST_DIR/README-install.txt\"",
            "test -f \"$DIST_DIR/CHANGELOG.md\"",
            "shasum -a 256 -c SHA256SUMS.txt",
            "echo \"DIST_DIR=$DIST_DIR\" >> \"$GITHUB_ENV\"",
            "echo \"ZIP_PATH=$ZIP_PATH\" >> \"$GITHUB_ENV\""
        ] {
            XCTAssertTrue(verifyReleaseAssetsStep.contains(expected), "Verify release assets step must contain: \(expected)")
        }

        let releaseStep = try yamlStepBlock(named: "Create Draft Release", in: releaseJob)
        let githubTokenPattern = #"(?m)^[ \t]*GH_TOKEN[ \t]*:[ \t]*(?:\"\$\{\{[ \t]*github\.token[ \t]*\}\}\"|'\$\{\{[ \t]*github\.token[ \t]*\}\}'|\$\{\{[ \t]*github\.token[ \t]*\}\})[ \t]*(?:#.*)?$"#
        XCTAssertNotNil(
            releaseStep.range(of: githubTokenPattern, options: .regularExpression),
            "Release step must authenticate gh with github.token"
        )

        let releaseViewGuardPattern = #"(?ms)^[ \t]*if[ \t]+gh release view \"\$TAG\"[^\r\n]*\r?\n.*?^[ \t]*fi[ \t]*$"#
        let releaseViewGuardRange = try XCTUnwrap(
            releaseStep.range(of: releaseViewGuardPattern, options: .regularExpression),
            "Workflow must guard against an existing release"
        )
        let releaseViewGuard = String(releaseStep[releaseViewGuardRange])

        XCTAssertNotNil(
            releaseViewGuard.range(of: #"\bexit[ \t]+1\b"#, options: .regularExpression),
            "Existing-release guard must fail the workflow"
        )

        let releaseCreatePattern = #"(?m)^[ \t]*gh[ \t]+release[ \t]+create[ \t]+\"\$TAG\"(?:(?:[^\r\n]*\\[ \t]*\r?\n)(?:[ \t]*[^\r\n]*\\[ \t]*\r?\n)*[ \t]*[^\r\n]*|[^\r\n]*)$"#
        let releaseCreateRange = try XCTUnwrap(
            releaseStep.range(of: releaseCreatePattern, options: .regularExpression),
            "Workflow must create the release with its title"
        )
        let releaseCreateBlock = String(releaseStep[releaseCreateRange])

        for expected in ["--draft", "--generate-notes", "--title \"zongMacTools $TAG\""] {
            XCTAssertTrue(releaseCreateBlock.contains(expected), "Release creation must contain: \(expected)")
        }
        let terminalReleaseTitlePattern = #"(?m)^[ \t]*--title[ \t]+\"zongMacTools \$TAG\"[ \t]*\z"#
        XCTAssertNotNil(
            releaseCreateBlock.range(of: terminalReleaseTitlePattern, options: .regularExpression),
            "Release title must be the terminal command argument"
        )

        let assetArgumentLines = releaseCreateBlock
            .split(whereSeparator: \.isNewline)
            .dropFirst()
            .compactMap { releaseCreateArgument(from: String($0)) }

        let expectedAssets: Set<String> = [
            "$ZIP_PATH",
            "$DIST_DIR/SHA256SUMS.txt",
            "$DIST_DIR/release-metadata.txt",
            "$DIST_DIR/README-install.txt",
            "$DIST_DIR/CHANGELOG.md"
        ]
        XCTAssertEqual(
            assetArgumentLines.count,
            expectedAssets.count,
            "Release creation must upload exactly five asset arguments"
        )
        XCTAssertEqual(
            Set(assetArgumentLines),
            expectedAssets,
            "Release creation must upload each expected asset exactly once, with no extras"
        )
    }

    func testGitHubDraftReleaseWorkflowSelectsSwiftSixToolchain() throws {
        let source = try String(contentsOf: githubDraftReleaseWorkflowURL(), encoding: .utf8)
        let jobsBlock = try yamlTopLevelBlock(named: "jobs", in: source)
        let releaseJob = try yamlJobBlock(named: "release", in: jobsBlock)

        XCTAssertTrue(
            releaseJob.contains("DEVELOPER_DIR: /Applications/Xcode_16.2.app/Contents/Developer"),
            "Release job must select Xcode 16.2 so SwiftPM supports swift-tools-version 6.0"
        )

        let showToolchainStep = try yamlStepBlock(named: "Show toolchain", in: releaseJob)
        XCTAssertTrue(showToolchainStep.contains("xcodebuild -version"), "Toolchain step must report the selected Xcode")
        XCTAssertTrue(showToolchainStep.contains("swift --version"), "Toolchain step must report the selected Swift version")

        let toolchainStepRange = try XCTUnwrap(
            releaseJob.range(
                of: #"(?m)^[ \t]*-[ \t]+name:[ \t]*(?:\"Show toolchain\"|'Show toolchain'|Show toolchain)[ \t]*(?:#.*)?\r?$"#,
                options: .regularExpression
            ),
            "Workflow must include the Show toolchain step"
        )
        let runTestsStepRange = try XCTUnwrap(
            releaseJob.range(
                of: #"(?m)^[ \t]*-[ \t]+name:[ \t]*(?:\"Run tests\"|'Run tests'|Run tests)[ \t]*(?:#.*)?\r?$"#,
                options: .regularExpression
            ),
            "Workflow must include the Run tests step"
        )
        XCTAssertLessThan(
            releaseJob.distance(from: releaseJob.startIndex, to: toolchainStepRange.lowerBound),
            releaseJob.distance(from: releaseJob.startIndex, to: runTestsStepRange.lowerBound),
            "Toolchain version must be reported before running tests"
        )
    }

    private func yamlTopLevelBlock(named name: String, in source: String) throws -> String {
        let lines = source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let headerPrefix = "\(name):"
        let headerIndex = try XCTUnwrap(
            lines.firstIndex { line in
                !line.hasPrefix(" ") && !line.hasPrefix("\t") && line.hasPrefix(headerPrefix)
            },
            "Workflow must include the top-level \(name) block"
        )
        var blockEnd = lines.endIndex
        for index in lines.index(after: headerIndex)..<lines.endIndex {
            let line = lines[index]
            if !line.isEmpty && !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                blockEnd = index
                break
            }
        }
        return lines[headerIndex..<blockEnd].map(String.init).joined(separator: "\n")
    }

    private func yamlJobBlock(named name: String, in source: String) throws -> String {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let jobHeaderPattern = #"(?m)^([ \t]+)\#(escapedName):[ \t]*(?:#.*)?$"#
        let jobHeaderRegex = try NSRegularExpression(pattern: jobHeaderPattern)
        let searchRange = NSRange(source.startIndex..., in: source)
        let jobHeader = try XCTUnwrap(
            jobHeaderRegex.firstMatch(in: source, range: searchRange),
            "Workflow must include the \(name) job"
        )
        let jobHeaderRange = try XCTUnwrap(
            Range(jobHeader.range, in: source),
            "Workflow must include the \(name) job header"
        )
        let jobIndentRange = try XCTUnwrap(
            Range(jobHeader.range(at: 1), in: source),
            "Workflow must indent the \(name) job"
        )
        let jobIndent = String(source[jobIndentRange])
        let siblingJobPattern = #"(?m)^\#(NSRegularExpression.escapedPattern(for: jobIndent))[A-Za-z0-9_-]+:[ \t]*(?:#.*)?$"#
        let followingJobRange = source.range(
            of: siblingJobPattern,
            options: .regularExpression,
            range: jobHeaderRange.upperBound..<source.endIndex
        )
        let jobEnd = followingJobRange?.lowerBound ?? source.endIndex
        return String(source[jobHeaderRange.lowerBound..<jobEnd])
    }

    private func yamlStepBlock(named name: String, in source: String) throws -> String {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = #"(?ms)^([ \t]*)-[ \t]+name:[ \t]*(?:\"\#(escapedName)\"|'\#(escapedName)'|\#(escapedName))[ \t]*(?:#.*)?\r?\n(?:(?!^\1-[ \t]+).)*(?=^\1-[ \t]+|\z)"#
        let range = try XCTUnwrap(
            source.range(of: pattern, options: .regularExpression),
            "Workflow must include a step named: \(name)"
        )
        return String(source[range])
    }

    private func releaseCreateArgument(from commandArgumentLine: String) -> String? {
        var argument = commandArgumentLine.trimmingCharacters(in: .whitespaces)
        if argument.hasSuffix("\\") {
            argument.removeLast()
            argument = argument.trimmingCharacters(in: .whitespaces)
        }

        guard !argument.isEmpty, !argument.hasPrefix("--") else {
            return nil
        }

        if let quote = argument.first,
           argument.count >= 2,
           (quote == "\"" || quote == "'"),
           argument.last == quote {
            argument.removeFirst()
            argument.removeLast()
        }

        return argument
    }

    private func githubDraftReleaseWorkflowURL() -> URL {
        packageRoot()
            .appendingPathComponent(".github")
            .appendingPathComponent("workflows")
            .appendingPathComponent("github-draft-release.yml")
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

    private func scriptSource(named name: String) throws -> String {
        try String(
            contentsOf: packageRoot()
                .appendingPathComponent("Scripts")
                .appendingPathComponent(name),
            encoding: .utf8
        )
    }
}
