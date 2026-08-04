# Localized Excluded App Names Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make saved exclusion rules display the installed app's localized macOS name, such as `豆包`, with robust metadata and filename fallbacks.

**Architecture:** A shared Foundation helper will select the first non-empty localized, unlocalized, or filename candidate. `WorkspaceAppNameResolver` will inject application-URL lookup for deterministic tests and delegate selection to the helper. Manual app selection will call the same helper.

**Tech Stack:** Swift 6, SwiftPM, XCTest, Foundation, AppKit.

---

## File Structure

- Create: `Sources/DockHoverPreviewProbe/Shared/AppBundleDisplayNameResolver.swift` - resolves app names from a bundle and `.app` URL.
- Modify: `Sources/DockHoverPreviewProbe/App/MenuBarController.swift:14-33` - injects app-URL lookup and calls the shared resolver.
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ExcludedAppSelectionPresenter.swift:104-134` - removes its duplicated display-name code.
- Modify: `Tests/DockHoverPreviewProbeTests/ExcludedAppSelectionPresenterTests.swift:8-93` - adds a localized temporary-bundle regression test.

### Task 1: Write the Localized Saved-Rule Regression Test

**Files:**
- Modify: `Tests/DockHoverPreviewProbeTests/ExcludedAppSelectionPresenterTests.swift:8-93`

- [ ] **Step 1: Extend the app-bundle fixture with an optional localized display name**

Add a `localizedDisplayName: String? = nil` argument to `makeTemporaryAppBundle`. Add `"CFBundleDevelopmentRegion": "en"` to the existing `info` dictionary. When the optional name is present, create `Contents/Resources/en.lproj` and write this property list to `InfoPlist.strings`:

```swift
let localizedInfo = ["CFBundleDisplayName": localizedDisplayName]
let localizedData = try PropertyListSerialization.data(
    fromPropertyList: localizedInfo,
    format: .xml,
    options: 0
)
try localizedData.write(to: localizationURL.appendingPathComponent("InfoPlist.strings"))
```

- [ ] **Step 2: Add the regression test before `testOpenPanelCancelReturnsNilSelection`**

```swift
func testWorkspaceResolverPrefersLocalizedDisplayNameForExcludedApp() throws {
    let appURL = try makeTemporaryAppBundle(
        bundleIdentifier: "com.bot.neotix.doubao",
        displayName: "Doubao",
        localizedDisplayName: "豆包"
    )
    defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }
    let resolver = WorkspaceAppNameResolver(applicationURLProvider: { _ in appURL })

    XCTAssertEqual(
        resolver.displayName(forBundleIdentifier: "com.bot.neotix.doubao"),
        "豆包"
    )
}
```

- [ ] **Step 3: Verify the test is red**

Run:

```bash
swift test --filter ExcludedAppSelectionPresenterTests/testWorkspaceResolverPrefersLocalizedDisplayNameForExcludedApp
```

Expected: compilation stops because `WorkspaceAppNameResolver` has no `applicationURLProvider` initializer. This missing seam is intentional: it makes the saved-rule lookup testable against a controlled `.app` bundle rather than whatever happens to be installed locally.

### Task 2: Implement the Shared Resolver and Green the Test

**Files:**
- Create: `Sources/DockHoverPreviewProbe/Shared/AppBundleDisplayNameResolver.swift`
- Modify: `Sources/DockHoverPreviewProbe/App/MenuBarController.swift:14-33`
- Modify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ExcludedAppSelectionPresenter.swift:104-134`

- [ ] **Step 1: Add the shared resolver**

Create `Sources/DockHoverPreviewProbe/Shared/AppBundleDisplayNameResolver.swift`:

```swift
import Foundation

enum AppBundleDisplayNameResolver {
    static func displayName(for bundle: Bundle?, at appURL: URL) -> String? {
        let candidates = [
            bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String,
            bundle?.localizedInfoDictionary?["CFBundleName"] as? String,
            bundle?.infoDictionary?["CFBundleDisplayName"] as? String,
            bundle?.infoDictionary?["CFBundleName"] as? String,
            appURL.deletingPathExtension().lastPathComponent
        ]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
```

- [ ] **Step 2: Make workspace resolution injectable and delegate to the helper**

Replace the body of `WorkspaceAppNameResolver` with:

```swift
@MainActor
final class WorkspaceAppNameResolver: AppNameResolving {
    private let applicationURLProvider: @MainActor (String) -> URL?

    init(
        applicationURLProvider: @escaping @MainActor (String) -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }
    ) {
        self.applicationURLProvider = applicationURLProvider
    }

    func displayName(forBundleIdentifier bundleIdentifier: String) -> String? {
        guard let url = applicationURLProvider(bundleIdentifier) else {
            return nil
        }
        return AppBundleDisplayNameResolver.displayName(for: Bundle(url: url), at: url)
    }
}
```

- [ ] **Step 3: Make manual selection use the same helper**

Keep its bundle-id behavior, but replace `displayName(from:url:)` and delete that private function:

```swift
static func resolvedSelection(at url: URL) -> ExcludedAppSelection {
    let bundle = Bundle(url: url)
    return ExcludedAppSelection(
        bundleIdentifier: bundle?.bundleIdentifier ?? "",
        displayName: AppBundleDisplayNameResolver.displayName(for: bundle, at: url)
    )
}
```

- [ ] **Step 4: Verify the focused suite is green**

Run:

```bash
swift test --filter ExcludedAppSelectionPresenterTests
```

Expected: all `ExcludedAppSelectionPresenterTests` pass, including the `豆包` saved-rule assertion and the existing manual-selection, cancellation, and open-panel tests.

- [ ] **Step 5: Commit only the implementation files**

Run:

```bash
git add Sources/DockHoverPreviewProbe/Shared/AppBundleDisplayNameResolver.swift Sources/DockHoverPreviewProbe/App/MenuBarController.swift Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ExcludedAppSelectionPresenter.swift Tests/DockHoverPreviewProbeTests/ExcludedAppSelectionPresenterTests.swift
git commit -m "fix: localize excluded app names"
```

Expected: the commit excludes the pre-existing Desktop Peek modifications.

### Task 3: Verify the Integrated Change

**Files:**
- Verify: `Sources/DockHoverPreviewProbe/Shared/AppBundleDisplayNameResolver.swift`
- Verify: `Sources/DockHoverPreviewProbe/App/MenuBarController.swift`
- Verify: `Sources/DockHoverPreviewProbe/Tools/DockWindowQuickLook/ExcludedAppSelectionPresenter.swift`
- Verify: `Tests/DockHoverPreviewProbeTests/ExcludedAppSelectionPresenterTests.swift`

- [ ] **Step 1: Run all automated tests**

Run:

```bash
swift test
```

Expected: zero XCTest failures.

- [ ] **Step 2: Build the target**

Run:

```bash
swift build
```

Expected: exit status 0 and `Build complete!`.

- [ ] **Step 3: Check whitespace and staging isolation**

Run each command separately:

```bash
git diff --check
```

```bash
git diff --cached --check
```

```bash
git status --short
```

Expected: both checks exit 0, and the pre-existing Desktop Peek files remain unstaged.
