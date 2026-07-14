# GitHub Draft Release Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a GitHub Actions workflow that validates a pushed version tag, builds the macOS public-beta artifact, and creates a GitHub Draft Release with only the intended assets.

**Architecture:** A single tag-triggered workflow on `macos-14` owns the release lifecycle. `PackagingTests` reads the workflow as text to lock in the repository's release contract, while the workflow reuses `Scripts/package_release_app.sh` for all package construction and lets `gh` create the Draft through the built-in `GITHUB_TOKEN`.

**Tech Stack:** GitHub Actions YAML, GitHub CLI, Bash, Swift XCTest, SwiftPM.

---

### Task 1: Add the release-workflow contract test

**Files:**
- Modify: `Tests/DockHoverPreviewProbeTests/PackagingTests.swift`
- Created in Task 2: `.github/workflows/github-draft-release.yml`

- [x] **Step 1: Write the failing test**

Add the following test and helper before `infoPlist()`:

```swift
func testGitHubDraftReleaseWorkflowMatchesPackagingContract() throws {
    let source = try String(contentsOf: githubDraftReleaseWorkflowURL(), encoding: .utf8)

    for expected in [
        "push:\n    tags:\n      - \"v*\"",
        "contents: write",
        "macos-14",
        "swift test",
        "Scripts/package_release_app.sh",
        "CFBundleShortVersionString",
        "test \"$TAG\" == \"v${VERSION}\"",
        "NOTARYTOOL_PROFILE: \"\"",
        "shasum -a 256 -c SHA256SUMS.txt",
        "gh release create \"$TAG\"",
        "--draft",
        "--generate-notes",
        "SHA256SUMS.txt",
        "release-metadata.txt",
        "README-install.txt",
        "CHANGELOG.md"
    ] {
        XCTAssertTrue(source.contains(expected), "Workflow must contain: \(expected)")
    }
}

private func githubDraftReleaseWorkflowURL() -> URL {
    packageRoot()
        .appendingPathComponent(".github")
        .appendingPathComponent("workflows")
        .appendingPathComponent("github-draft-release.yml")
}
```

- [x] **Step 2: Run the focused test to verify it fails**

Run: `swift test --filter PackagingTests/testGitHubDraftReleaseWorkflowMatchesPackagingContract`

Expected: FAIL because `.github/workflows/github-draft-release.yml` does not exist.

### Task 2: Create the tag-triggered Draft Release workflow

**Files:**
- Create: `.github/workflows/github-draft-release.yml`
- Test: `Tests/DockHoverPreviewProbeTests/PackagingTests.swift`

- [x] **Step 1: Create the workflow**

Create the following workflow:

```yaml
name: Create GitHub Draft Release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

concurrency:
  group: github-draft-release-${{ github.ref_name }}
  cancel-in-progress: false

jobs:
  release:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Validate tag version
        env:
          TAG: ${{ github.ref_name }}
          INFO_PLIST: Sources/DockHoverPreviewProbe/Info.plist
        run: |
          VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
          BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
          test "$TAG" == "v${VERSION}"
          echo "VERSION=$VERSION" >> "$GITHUB_ENV"
          echo "BUILD_NUMBER=$BUILD_NUMBER" >> "$GITHUB_ENV"

      - name: Run tests
        run: swift test

      - name: Package public beta
        env:
          NOTARYTOOL_PROFILE: ""
        run: Scripts/package_release_app.sh

      - name: Verify release assets
        run: |
          DIST_DIR="dist/zongMacTools-${VERSION}-${BUILD_NUMBER}"
          ZIP_PATH="$DIST_DIR/zongMacTools-${VERSION}-${BUILD_NUMBER}.zip"
          test -f "$ZIP_PATH"
          test -f "$DIST_DIR/SHA256SUMS.txt"
          test -f "$DIST_DIR/release-metadata.txt"
          test -f "$DIST_DIR/README-install.txt"
          test -f "$DIST_DIR/CHANGELOG.md"
          (
            cd "$DIST_DIR"
            shasum -a 256 -c SHA256SUMS.txt
          )
          echo "DIST_DIR=$DIST_DIR" >> "$GITHUB_ENV"
          echo "ZIP_PATH=$ZIP_PATH" >> "$GITHUB_ENV"

      - name: Create Draft Release
        env:
          GH_TOKEN: ${{ github.token }}
          TAG: ${{ github.ref_name }}
        run: |
          if gh release view "$TAG"; then
            exit 1
          fi
          gh release create "$TAG" \
            "$ZIP_PATH" \
            "$DIST_DIR/SHA256SUMS.txt" \
            "$DIST_DIR/release-metadata.txt" \
            "$DIST_DIR/README-install.txt" \
            "$DIST_DIR/CHANGELOG.md" \
            --draft \
            --generate-notes \
            --title "zongMacTools $TAG"
```

- [x] **Step 2: Run the focused test to verify it passes**

Run: `swift test --filter PackagingTests/testGitHubDraftReleaseWorkflowMatchesPackagingContract`

Expected: PASS.

### Task 3: Document the GitHub release command and verification boundary

**Files:**
- Modify: `README.md`
- Modify: `docs/releases/CHANGELOG.md`

- [x] **Step 1: Add README instructions below the public-beta packaging command**

Add a `### GitHub Draft Release` subsection explaining that the version tag must match `CFBundleShortVersionString`, then provide:

```bash
git tag v0.1.0
git push origin v0.1.0
```

State that the Action runs `Run tests`, packages the ad-hoc public beta, validates the SHA-256 checksum, creates a private Draft, and uploads only the ZIP, checksum, metadata, installation guide, and changelog. State that the maintainer must download and inspect the Draft assets before publishing and, when publishing, mark it as a prerelease if appropriate; the workflow makes no signing or notarization changes.

- [x] **Step 2: Add an Unreleased changelog entry**

Add one bullet stating that GitHub Actions now creates a Draft Release from a matching `v<version>` tag after tests, package verification, and SHA-256 validation.

- [x] **Step 3: Run the full verification suite**

Run: `swift test && swift build && git diff --check`

Expected: all XCTest cases pass, SwiftPM build succeeds, and no whitespace errors are reported.

- [x] **Step 4: Review the staged change and commit**

Run:

```bash
git add .github/workflows/github-draft-release.yml \
  Tests/DockHoverPreviewProbeTests/PackagingTests.swift \
  README.md \
  docs/releases/CHANGELOG.md \
  docs/superpowers/plans/2026-07-14-github-draft-release-automation.md
git diff --cached --check
git diff --cached --stat
git commit -m "ci: add GitHub draft release workflow"
```

Expected: only the workflow, its test, release documentation, and this implementation plan are committed.
