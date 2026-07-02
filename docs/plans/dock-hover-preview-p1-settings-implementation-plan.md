# Dock Hover Preview P1 Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement P1 basic settings for the Dock hover preview module while keeping the current MVP default behavior stable, quiet, and recoverable.

**Architecture:** Add a small settings layer around `UserDefaults`, then inject settings snapshots into the menu, orchestrator, preview session, and packaging paths. Keep Dock monitoring, window query, thumbnail generation, activation, and panel display boundaries intact. Verify behavior with XCTest and build scripts first; use manual checks only for TCC, Login Items, visual menu behavior, and environment variants that cannot be automated.

**Tech Stack:** Swift 6, SwiftPM, AppKit, SwiftUI, ScreenCaptureKit, ServiceManagement, XCTest, shell build scripts.

---

## Execution Guidance

Use `/goal` at the start of implementation with an objective like:

```text
Implement Dock hover preview P1 settings from docs/plans/dock-hover-preview-p1-settings-design.md with automated tests passing before manual validation.
```

Recommended execution model:

1. Use a lead/integration agent for `AppDelegate.swift`, `ProbeOrchestrator.swift`, `PreviewSessionController.swift`, and `MenuBarController.swift`. These are shared integration files; do not let multiple agents edit the same one at the same time.
2. Independent agents may prepare leaf files and tests only: settings store/text provider, app target tracker, launch-at-login service, packaging script changes, and docs updates.
3. Merge leaf work back one task at a time. After each merge, the lead agent updates required initializer call sites and runs that task's automatic gate before another task touches the same integration file.
4. If using `/goal`, treat every task below as a buildable checkpoint. A task that changes an initializer must also update `AppDelegate.swift` and the relevant test harness file in the same task, usually `PreviewSessionControllerTests.swift`, `ProbeOrchestratorPreviewTests.swift`, or `MenuBarControllerTests.swift`.

Do not run manual validation before the relevant automated checks pass. If an automated test fails, fix code or test assumptions first. Ask for human help only when the check requires macOS UI state, TCC permissions, Login Items approval, or hardware that automation cannot provide.

Current dirty-tree note before implementation: `docs/roadmap.md`, `docs/plans/`, and `Assets/` may already contain design/icon changes. Do not revert them.

## Automatic Verification Gates

Run these after every task that touches Swift code:

```bash
swift test
swift build
git diff --check
```

Run these before any manual validation:

```bash
swift test
swift build
Scripts/build_probe_app.sh
git diff --check
```

Manual validation is allowed only after the full automatic gate passes, except when investigating an automatic failure that is clearly caused by a macOS permission or packaging state.

## File Map

Create:

- `Sources/DockHoverPreviewProbe/DockHoverPreviewSettings.swift`
  Value types and validation constants: `DockHoverPreviewSettings`, `PanelRetentionMode`, `DisplayLanguage`, `PanelRetentionParameters`.

- `Sources/DockHoverPreviewProbe/SettingsStore.swift`
  `DockHoverPreviewSettingsStore` protocol, `UserDefaultsSettingsStore`, and test-friendly observer/update APIs.

- `Sources/DockHoverPreviewProbe/AppTextProvider.swift`
  Static UI text table for English and Simplified Chinese. Logs must not use this provider.

- `Sources/DockHoverPreviewProbe/AppTargetTracker.swift`
  Tracks current preview app, latest hovered Dock app, and latest non-self active app for excluded-app menu actions.

- `Sources/DockHoverPreviewProbe/HoverDelayScheduler.swift`
  Small scheduler abstraction so hover delay can be tested without sleeping.

- `Sources/DockHoverPreviewProbe/LaunchAtLoginService.swift`
  Public API wrapper around `SMAppService.mainApp`.

- `Tests/DockHoverPreviewProbeTests/SettingsStoreTests.swift`
- `Tests/DockHoverPreviewProbeTests/AppTextProviderTests.swift`
- `Tests/DockHoverPreviewProbeTests/AppTargetTrackerTests.swift`
- `Tests/DockHoverPreviewProbeTests/LaunchAtLoginServiceTests.swift`

Modify:

- `Package.swift`
  Link `ServiceManagement`.

- `Sources/DockHoverPreviewProbe/AppDelegate.swift`
  Construct and inject settings, text, target tracker, scheduler, and launch-at-login services. Update this file in the same task that introduces any new required initializer dependency; do not defer required wiring to a later task if the current task's gate runs `swift build`.

- `Sources/DockHoverPreviewProbe/MenuBarController.swift`
  Build settings menu, language menu, excluded-app menu, Launch at Login menu.

- `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`
  Use enable/delay/exclusions, cancellable scheduler, target tracker, and settings-change callbacks.

- `Sources/DockHoverPreviewProbe/PreviewSessionController.swift`
  Use max card count and retention parameters from settings; expose current app identity for exclusion hiding.

- `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`
  Remove hard-coded `prefix(8)` as the active limit. Keep only defensive cap if explicitly passed.

- `Sources/DockHoverPreviewProbe/PreviewPanelView.swift`
  Keep app names and window titles as raw system values. Add horizontal visible-card capping only if needed to keep `maxCardCount=12` from producing a panel wider than the visible frame.

- `Sources/DockHoverPreviewProbe/WindowQueryService.swift`
  Add a limit parameter so query, session, and view model do not each use independent hard-coded limits.

- `Sources/DockHoverPreviewProbe/Info.plist`
  Use `zongMacTools` as user-visible name and declare generated app icon.

- `Scripts/build_probe_app.sh` and `Scripts/run_probe_app.sh`
  Package the existing executable into a user-visible `zongMacTools.app`, generate/copy icon resources, and keep the SwiftPM executable name unchanged.

- `README.md` and verification docs after implementation is actually verified.

## Task 1: Settings Model and UserDefaults Store

**Files:**

- Create: `Sources/DockHoverPreviewProbe/DockHoverPreviewSettings.swift`
- Create: `Sources/DockHoverPreviewProbe/SettingsStore.swift`
- Create: `Tests/DockHoverPreviewProbeTests/SettingsStoreTests.swift`

- [ ] **Step 1: Write failing settings tests**

Create `Tests/DockHoverPreviewProbeTests/SettingsStoreTests.swift` with focused tests:

```swift
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsMatchMVPBehavior() {
        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: ProbeLogger())

        XCTAssertEqual(store.snapshot.isDockHoverPreviewEnabled, true)
        XCTAssertEqual(store.snapshot.hoverDelayMilliseconds, 250)
        XCTAssertEqual(store.snapshot.panelRetentionMode, .standard)
        XCTAssertEqual(store.snapshot.maxCardCount, 8)
        XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers, [])
        XCTAssertEqual(store.snapshot.displayLanguage, .english)
        XCTAssertEqual(store.snapshot.panelRetentionParameters.dockItemTolerance, 24)
        XCTAssertEqual(store.snapshot.panelRetentionParameters.panelEdgeTolerance, 6)
        XCTAssertEqual(store.snapshot.panelRetentionParameters.bridgeInset, 24)
    }

    func testInvalidValuesFallBackWithoutPersistingDefaults() {
        defaults.set("false", forKey: SettingsKey.isEnabled.rawValue)
        defaults.set(999, forKey: SettingsKey.hoverDelayMilliseconds.rawValue)
        defaults.set("loose", forKey: SettingsKey.panelRetentionMode.rawValue)
        defaults.set(11, forKey: SettingsKey.maxCardCount.rawValue)
        defaults.set("fr", forKey: SettingsKey.displayLanguage.rawValue)

        let logger = ProbeLogger()
        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: logger)

        XCTAssertEqual(store.snapshot.isDockHoverPreviewEnabled, true)
        XCTAssertEqual(store.snapshot.hoverDelayMilliseconds, 250)
        XCTAssertEqual(store.snapshot.panelRetentionMode, .standard)
        XCTAssertEqual(store.snapshot.maxCardCount, 8)
        XCTAssertEqual(store.snapshot.displayLanguage, .english)
        XCTAssertEqual(defaults.string(forKey: SettingsKey.isEnabled.rawValue), "false")
        XCTAssertEqual(defaults.integer(forKey: SettingsKey.maxCardCount.rawValue), 11)
        XCTAssertTrue(logger.snapshot().contains { $0.contains("settings.invalid") })
    }

    func testExcludedAppsAreSanitizedSortedAndCapped() {
        let valid = (0..<140).map { "com.example.app\($0)" }
        let invalid = ["", "   ", String(repeating: "x", count: 300), "bad id with spaces", "中文.bundle"]
        defaults.set((valid + invalid + ["com.example.app1"]).shuffled(), forKey: SettingsKey.excludedAppBundleIdentifiers.rawValue)

        let logger = ProbeLogger()
        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: logger)

        XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers.count, 128)
        XCTAssertTrue(store.snapshot.excludedAppBundleIdentifiers.contains("com.example.app0"))
        XCTAssertFalse(store.snapshot.excludedAppBundleIdentifiers.contains("bad id with spaces"))
        XCTAssertTrue(logger.snapshot().contains { $0.contains("excludedAppsDropped=") })
    }

    func testWritingSettingsPersistsSortedValuesAndNotifiesObservers() {
        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: ProbeLogger())
        var observed: [DockHoverPreviewSettings] = []
        let token = store.addObserver { observed.append($0) }

        store.update { settings in
            settings.isDockHoverPreviewEnabled = false
            settings.hoverDelayMilliseconds = 400
            settings.panelRetentionMode = .forgiving
            settings.maxCardCount = 12
            settings.excludedAppBundleIdentifiers = ["com.zeta.App", "com.alpha.App"]
            settings.displayLanguage = .simplifiedChinese
        }

        XCTAssertEqual(store.snapshot.isDockHoverPreviewEnabled, false)
        XCTAssertEqual(defaults.integer(forKey: SettingsKey.hoverDelayMilliseconds.rawValue), 400)
        XCTAssertEqual(defaults.stringArray(forKey: SettingsKey.excludedAppBundleIdentifiers.rawValue), ["com.alpha.App", "com.zeta.App"])
        XCTAssertEqual(observed.count, 1)

        store.removeObserver(token)
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter SettingsStoreTests
```

Expected: FAIL because `DockHoverPreviewSettings`, `SettingsKey`, and `UserDefaultsSettingsStore` do not exist.

- [ ] **Step 3: Implement settings value types**

Create `Sources/DockHoverPreviewProbe/DockHoverPreviewSettings.swift`:

```swift
import CoreGraphics
import Foundation

struct DockHoverPreviewSettings: Equatable, Sendable {
    var isDockHoverPreviewEnabled: Bool
    var hoverDelayMilliseconds: Int
    var panelRetentionMode: PanelRetentionMode
    var maxCardCount: Int
    var excludedAppBundleIdentifiers: Set<String>
    var displayLanguage: DisplayLanguage

    static let defaults = DockHoverPreviewSettings(
        isDockHoverPreviewEnabled: true,
        hoverDelayMilliseconds: 250,
        panelRetentionMode: .standard,
        maxCardCount: 8,
        excludedAppBundleIdentifiers: [],
        displayLanguage: .english
    )

    var panelRetentionParameters: PanelRetentionParameters {
        panelRetentionMode.parameters
    }
}

enum PanelRetentionMode: String, CaseIterable, Sendable {
    case tight
    case standard
    case forgiving

    var parameters: PanelRetentionParameters {
        switch self {
        case .tight:
            PanelRetentionParameters(dockItemTolerance: 12, panelEdgeTolerance: 4, bridgeInset: 12)
        case .standard:
            PanelRetentionParameters(dockItemTolerance: 24, panelEdgeTolerance: 6, bridgeInset: 24)
        case .forgiving:
            PanelRetentionParameters(dockItemTolerance: 36, panelEdgeTolerance: 8, bridgeInset: 36)
        }
    }
}

struct PanelRetentionParameters: Equatable, Sendable {
    let dockItemTolerance: CGFloat
    let panelEdgeTolerance: CGFloat
    let bridgeInset: CGFloat
}

enum DisplayLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
}

enum SettingsKey: String, CaseIterable {
    case isEnabled = "DockHoverPreview.isEnabled"
    case hoverDelayMilliseconds = "DockHoverPreview.hoverDelayMilliseconds"
    case panelRetentionMode = "DockHoverPreview.panelRetentionMode"
    case maxCardCount = "DockHoverPreview.maxCardCount"
    case excludedAppBundleIdentifiers = "DockHoverPreview.excludedAppBundleIdentifiers"
    case displayLanguage = "DockHoverPreview.displayLanguage"
}
```

- [ ] **Step 4: Implement settings store**

Create `Sources/DockHoverPreviewProbe/SettingsStore.swift`:

```swift
import Foundation

@MainActor
protocol DockHoverPreviewSettingsStore: AnyObject {
    var snapshot: DockHoverPreviewSettings { get }
    @discardableResult func addObserver(_ observer: @escaping (DockHoverPreviewSettings) -> Void) -> UUID
    func removeObserver(_ token: UUID)
    func update(_ transform: (inout DockHoverPreviewSettings) -> Void)
}

@MainActor
final class UserDefaultsSettingsStore: DockHoverPreviewSettingsStore {
    private let userDefaults: UserDefaults
    private let logger: ProbeLogger
    private var observers: [UUID: (DockHoverPreviewSettings) -> Void] = [:]
    private(set) var snapshot: DockHoverPreviewSettings

    init(userDefaults: UserDefaults = .standard, logger: ProbeLogger) {
        self.userDefaults = userDefaults
        self.logger = logger
        self.snapshot = Self.readSnapshot(from: userDefaults, logger: logger)
    }

    @discardableResult
    func addObserver(_ observer: @escaping (DockHoverPreviewSettings) -> Void) -> UUID {
        let token = UUID()
        observers[token] = observer
        return token
    }

    func removeObserver(_ token: UUID) {
        observers.removeValue(forKey: token)
    }

    func update(_ transform: (inout DockHoverPreviewSettings) -> Void) {
        var next = snapshot
        transform(&next)
        next = Self.sanitized(next, logger: logger)
        persist(next)
        snapshot = next
        logger.info("settings.changed enabled=\(next.isDockHoverPreviewEnabled) delayMS=\(next.hoverDelayMilliseconds) retention=\(next.panelRetentionMode.rawValue) maxCards=\(next.maxCardCount) excludedCount=\(next.excludedAppBundleIdentifiers.count) language=\(next.displayLanguage.rawValue)")
        observers.values.forEach { $0(next) }
    }

    private func persist(_ settings: DockHoverPreviewSettings) {
        userDefaults.set(settings.isDockHoverPreviewEnabled, forKey: SettingsKey.isEnabled.rawValue)
        userDefaults.set(settings.hoverDelayMilliseconds, forKey: SettingsKey.hoverDelayMilliseconds.rawValue)
        userDefaults.set(settings.panelRetentionMode.rawValue, forKey: SettingsKey.panelRetentionMode.rawValue)
        userDefaults.set(settings.maxCardCount, forKey: SettingsKey.maxCardCount.rawValue)
        userDefaults.set(settings.excludedAppBundleIdentifiers.sorted(), forKey: SettingsKey.excludedAppBundleIdentifiers.rawValue)
        userDefaults.set(settings.displayLanguage.rawValue, forKey: SettingsKey.displayLanguage.rawValue)
    }

    private static func readSnapshot(from defaults: UserDefaults, logger: ProbeLogger) -> DockHoverPreviewSettings {
        var settings = DockHoverPreviewSettings.defaults

        if defaults.object(forKey: SettingsKey.isEnabled.rawValue) != nil {
            if let value = defaults.object(forKey: SettingsKey.isEnabled.rawValue) as? Bool {
                settings.isDockHoverPreviewEnabled = value
            } else {
                logger.warning("settings.invalid key=\(SettingsKey.isEnabled.rawValue) valueType=\(type(of: defaults.object(forKey: SettingsKey.isEnabled.rawValue)!))")
            }
        }

        if defaults.object(forKey: SettingsKey.hoverDelayMilliseconds.rawValue) != nil {
            let value = defaults.integer(forKey: SettingsKey.hoverDelayMilliseconds.rawValue)
            settings.hoverDelayMilliseconds = [150, 250, 400].contains(value) ? value : 250
            if settings.hoverDelayMilliseconds != value {
                logger.warning("settings.invalid key=\(SettingsKey.hoverDelayMilliseconds.rawValue) value=\(value)")
            }
        }

        if let raw = defaults.string(forKey: SettingsKey.panelRetentionMode.rawValue) {
            settings.panelRetentionMode = PanelRetentionMode(rawValue: raw) ?? .standard
            if PanelRetentionMode(rawValue: raw) == nil {
                logger.warning("settings.invalid key=\(SettingsKey.panelRetentionMode.rawValue) value=\(raw)")
            }
        }

        if defaults.object(forKey: SettingsKey.maxCardCount.rawValue) != nil {
            let value = defaults.integer(forKey: SettingsKey.maxCardCount.rawValue)
            settings.maxCardCount = [3, 5, 8, 12].contains(value) ? value : 8
            if settings.maxCardCount != value {
                logger.warning("settings.invalid key=\(SettingsKey.maxCardCount.rawValue) value=\(value)")
            }
        }

        if let rawValues = defaults.stringArray(forKey: SettingsKey.excludedAppBundleIdentifiers.rawValue) {
            settings.excludedAppBundleIdentifiers = sanitizedExcludedApps(rawValues, logger: logger)
        }

        if let raw = defaults.string(forKey: SettingsKey.displayLanguage.rawValue) {
            settings.displayLanguage = DisplayLanguage(rawValue: raw) ?? .english
            if DisplayLanguage(rawValue: raw) == nil {
                logger.warning("settings.invalid key=\(SettingsKey.displayLanguage.rawValue) value=\(raw)")
            }
        }

        return settings
    }

    private static func sanitized(_ settings: DockHoverPreviewSettings, logger: ProbeLogger) -> DockHoverPreviewSettings {
        var next = settings
        if ![150, 250, 400].contains(next.hoverDelayMilliseconds) {
            logger.warning("settings.invalid key=\(SettingsKey.hoverDelayMilliseconds.rawValue) value=\(next.hoverDelayMilliseconds)")
            next.hoverDelayMilliseconds = 250
        }
        if ![3, 5, 8, 12].contains(next.maxCardCount) {
            logger.warning("settings.invalid key=\(SettingsKey.maxCardCount.rawValue) value=\(next.maxCardCount)")
            next.maxCardCount = 8
        }
        next.excludedAppBundleIdentifiers = sanitizedExcludedApps(Array(next.excludedAppBundleIdentifiers), logger: logger)
        return next
    }

    private static func sanitizedExcludedApps(_ values: [String], logger: ProbeLogger) -> Set<String> {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        let valid = values.compactMap { value -> String? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...256).contains(trimmed.count) else { return nil }
            guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
            return trimmed
        }
        let uniqueSorted = Array(Set(valid)).sorted()
        let capped = Array(uniqueSorted.prefix(128))
        let droppedCount = values.count - capped.count
        if droppedCount > 0 {
            logger.warning("settings.invalid excludedAppsDropped=\(droppedCount)")
        }
        return Set(capped)
    }
}
```

- [ ] **Step 5: Run targeted and full automatic checks**

Run:

```bash
swift test --filter SettingsStoreTests
swift test
swift build
git diff --check
```

Expected: all pass.

## Shared Test Helpers After Task 1

After Task 1 lands, add these helpers to the test files that need settings fakes. Prefer copying the helper into the first test file that needs it, then moving it to a shared test-support file only if duplication becomes noisy.

```swift
@MainActor
final class FakeSettingsStore: DockHoverPreviewSettingsStore {
    private(set) var observers: [UUID: (DockHoverPreviewSettings) -> Void] = [:]
    private(set) var updateCount = 0
    var snapshot: DockHoverPreviewSettings

    init(snapshot: DockHoverPreviewSettings = .defaults) {
        self.snapshot = snapshot
    }

    @discardableResult
    func addObserver(_ observer: @escaping (DockHoverPreviewSettings) -> Void) -> UUID {
        let token = UUID()
        observers[token] = observer
        return token
    }

    func removeObserver(_ token: UUID) {
        observers.removeValue(forKey: token)
    }

    func update(_ transform: (inout DockHoverPreviewSettings) -> Void) {
        updateCount += 1
        transform(&snapshot)
        observers.values.forEach { $0(snapshot) }
    }

    func replaceSnapshot(_ next: DockHoverPreviewSettings) {
        snapshot = next
        observers.values.forEach { $0(snapshot) }
    }
}

extension DockHoverPreviewSettings {
    static func defaultsWith(
        enabled: Bool = true,
        hoverDelayMilliseconds: Int = 250,
        maxCardCount: Int = 8,
        retention: PanelRetentionMode = .standard,
        excludedApps: Set<String> = [],
        language: DisplayLanguage = .english
    ) -> DockHoverPreviewSettings {
        var settings = DockHoverPreviewSettings.defaults
        settings.isDockHoverPreviewEnabled = enabled
        settings.hoverDelayMilliseconds = hoverDelayMilliseconds
        settings.maxCardCount = maxCardCount
        settings.panelRetentionMode = retention
        settings.excludedAppBundleIdentifiers = excludedApps
        settings.displayLanguage = language
        return settings
    }
}
```

## Task 2: App Text Provider

**Files:**

- Create: `Sources/DockHoverPreviewProbe/AppTextProvider.swift`
- Create: `Tests/DockHoverPreviewProbeTests/AppTextProviderTests.swift`

- [ ] **Step 1: Write failing text-provider tests**

Create `Tests/DockHoverPreviewProbeTests/AppTextProviderTests.swift`:

```swift
import XCTest
@testable import DockHoverPreviewProbe

final class AppTextProviderTests: XCTestCase {
    func testEnglishMenuStrings() {
        let text = AppTextProvider(language: .english)

        XCTAssertEqual(text.string(.dockHoverPreviewStatusEnabled), "Dock Hover Preview: Enabled")
        XCTAssertEqual(text.string(.enableDockHoverPreview), "Enable Dock Hover Preview")
        XCTAssertEqual(text.string(.debugShowPreviewForFrontmostApp), "Debug: Show Preview For Frontmost App")
        XCTAssertEqual(text.string(.excludeNamedApp, appName: "Google Chrome"), "Exclude Google Chrome")
        XCTAssertEqual(text.string(.moreExcludedApps, count: 108), "108 more excluded apps")
        XCTAssertEqual(text.languageDisplayName(.english), "English")
        XCTAssertEqual(text.languageDisplayName(.simplifiedChinese), "简体中文")
    }

    func testSimplifiedChineseMenuStrings() {
        let text = AppTextProvider(language: .simplifiedChinese)

        XCTAssertEqual(text.string(.dockHoverPreviewStatusEnabled), "Dock 悬停预览：已启用")
        XCTAssertEqual(text.string(.disableDockHoverPreview), "停用 Dock 悬停预览")
        XCTAssertEqual(text.string(.quit), "退出")
    }

    func testProviderDoesNotTranslateExternalValues() {
        let text = AppTextProvider(language: .simplifiedChinese)

        XCTAssertEqual(text.externalAppName("Google Chrome"), "Google Chrome")
        XCTAssertEqual(text.externalWindowTitle("Project README"), "Project README")
        XCTAssertEqual(text.bundleIdentifier("com.google.Chrome"), "com.google.Chrome")
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter AppTextProviderTests
```

Expected: FAIL because `AppTextProvider` does not exist.

- [ ] **Step 3: Implement text provider**

Create `Sources/DockHoverPreviewProbe/AppTextProvider.swift`:

```swift
import Foundation

enum LocalizedTextKey: String, CaseIterable {
    case dockHoverPreviewStatusEnabled
    case dockHoverPreviewStatusDisabled
    case enableDockHoverPreview
    case disableDockHoverPreview
    case hoverDelay
    case panelRetention
    case maxCards
    case language
    case excludedApps
    case excludeApp
    case excludeNamedApp
    case includeNamedApp
    case clearExcludedApps
    case moreExcludedApps
    case launchAtLoginEnabled
    case launchAtLoginNotRegistered
    case launchAtLoginRequiresApproval
    case launchAtLoginNotFound
    case enableLaunchAtLogin
    case disableLaunchAtLogin
    case openLoginItemsSettings
    case requestAccessibilityPrompt
    case openAccessibilitySettings
    case openScreenRecordingSettings
    case refreshPermissions
    case debugShowPreviewForFrontmostApp
    case quit
}

struct AppTextProvider: Equatable {
    let language: DisplayLanguage

    func string(_ key: LocalizedTextKey) -> String {
        switch language {
        case .english:
            english[key]!
        case .simplifiedChinese:
            simplifiedChinese[key]!
        }
    }

    func languageDisplayName(_ language: DisplayLanguage) -> String {
        switch language {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }

    func string(_ key: LocalizedTextKey, appName: String) -> String {
        string(key).replacingOccurrences(of: "%@", with: appName)
    }

    func string(_ key: LocalizedTextKey, count: Int) -> String {
        string(key).replacingOccurrences(of: "%d", with: String(count))
    }

    func externalAppName(_ value: String) -> String { value }
    func externalWindowTitle(_ value: String) -> String { value }
    func bundleIdentifier(_ value: String) -> String { value }

    private var english: [LocalizedTextKey: String] {
        [
            .dockHoverPreviewStatusEnabled: "Dock Hover Preview: Enabled",
            .dockHoverPreviewStatusDisabled: "Dock Hover Preview: Disabled",
            .enableDockHoverPreview: "Enable Dock Hover Preview",
            .disableDockHoverPreview: "Disable Dock Hover Preview",
            .hoverDelay: "Hover Delay",
            .panelRetention: "Panel Retention",
            .maxCards: "Max Cards",
            .language: "Language",
            .excludedApps: "Excluded Apps",
            .excludeApp: "Exclude App",
            .excludeNamedApp: "Exclude %@",
            .includeNamedApp: "Include %@",
            .clearExcludedApps: "Clear Excluded Apps",
            .moreExcludedApps: "%d more excluded apps",
            .launchAtLoginEnabled: "Launch at Login: Enabled",
            .launchAtLoginNotRegistered: "Launch at Login: Not Registered",
            .launchAtLoginRequiresApproval: "Launch at Login: Requires Approval",
            .launchAtLoginNotFound: "Launch at Login: Not Found",
            .enableLaunchAtLogin: "Enable Launch at Login",
            .disableLaunchAtLogin: "Disable Launch at Login",
            .openLoginItemsSettings: "Open Login Items Settings",
            .requestAccessibilityPrompt: "Request Accessibility Prompt",
            .openAccessibilitySettings: "Open Accessibility Settings",
            .openScreenRecordingSettings: "Open Screen Recording Settings",
            .refreshPermissions: "Refresh Permissions",
            .debugShowPreviewForFrontmostApp: "Debug: Show Preview For Frontmost App",
            .quit: "Quit"
        ]
    }

    private var simplifiedChinese: [LocalizedTextKey: String] {
        [
            .dockHoverPreviewStatusEnabled: "Dock 悬停预览：已启用",
            .dockHoverPreviewStatusDisabled: "Dock 悬停预览：已停用",
            .enableDockHoverPreview: "启用 Dock 悬停预览",
            .disableDockHoverPreview: "停用 Dock 悬停预览",
            .hoverDelay: "悬停延迟",
            .panelRetention: "面板保留手感",
            .maxCards: "最大卡片数",
            .language: "显示语言",
            .excludedApps: "排除的 App",
            .excludeApp: "排除 App",
            .excludeNamedApp: "排除 %@",
            .includeNamedApp: "恢复 %@",
            .clearExcludedApps: "清空排除列表",
            .moreExcludedApps: "还有 %d 个已排除 App",
            .launchAtLoginEnabled: "开机启动：已启用",
            .launchAtLoginNotRegistered: "开机启动：未注册",
            .launchAtLoginRequiresApproval: "开机启动：需要批准",
            .launchAtLoginNotFound: "开机启动：未找到",
            .enableLaunchAtLogin: "启用开机启动",
            .disableLaunchAtLogin: "停用开机启动",
            .openLoginItemsSettings: "打开登录项设置",
            .requestAccessibilityPrompt: "请求辅助功能授权提示",
            .openAccessibilitySettings: "打开辅助功能设置",
            .openScreenRecordingSettings: "打开屏幕录制设置",
            .refreshPermissions: "刷新权限状态",
            .debugShowPreviewForFrontmostApp: "调试：预览当前前台 App",
            .quit: "退出"
        ]
    }
}
```

- [ ] **Step 4: Run checks**

Run:

```bash
swift test --filter AppTextProviderTests
swift test
git diff --check
```

Expected: all pass.

## Task 3: Max Card Count Plumbing

**Files:**

- Modify: `Sources/DockHoverPreviewProbe/WindowQueryService.swift`
- Modify: `Sources/DockHoverPreviewProbe/PreviewSessionController.swift`
- Modify: `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`
- Modify: `Sources/DockHoverPreviewProbe/PreviewPanelView.swift`
- Modify: `Sources/DockHoverPreviewProbe/AppDelegate.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/WindowQueryServiceTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelViewModelTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewPanelLayoutEngineTests.swift`

- [ ] **Step 1: Write failing tests for configurable limits**

Update `WindowQueryService` protocol usage tests to expect a limit:

```swift
func testPreviewSessionUsesConfiguredMaxCardCount() async {
    let windows = (1...6).map { makeWindow(id: CGWindowID($0)) }
    let settings = FakeSettingsStore(snapshot: .defaultsWith(maxCardCount: 3))
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: windows, settingsStore: settings)

    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    XCTAssertEqual(harness.display.lastModel?.cards.count, 3)
    XCTAssertEqual(harness.queryService.requestedLimits, [3])
}

func testPanelViewModelDoesNotApplyIndependentEightCardLimit() {
    let cards = (1...12).map { makeCard(id: CGWindowID($0), title: "Window \($0)") }

    let model = PreviewPanelViewModel(appName: "Code", cards: cards, maxCardCount: 12)

    XCTAssertEqual(model.cards.count, 12)
}

func testHorizontalPanelSizeCapsVisibleWidthWhenMaxCardsIsTwelve() {
    let eightCards = PreviewPanelMetrics.panelSize(cardCount: 8, layout: .horizontal)
    let twelveCards = PreviewPanelMetrics.panelSize(cardCount: 12, layout: .horizontal)

    XCTAssertEqual(twelveCards.width, eightCards.width, accuracy: 0.001)
    XCTAssertEqual(twelveCards.height, eightCards.height, accuracy: 0.001)
}
```

Use the shared `FakeSettingsStore` and `DockHoverPreviewSettings.defaultsWith(...)` helper from the previous section.

- [ ] **Step 2: Run targeted tests and verify failure**

Run:

```bash
swift test --filter PreviewSessionControllerTests/testPreviewSessionUsesConfiguredMaxCardCount
swift test --filter PreviewPanelViewModelTests/testPanelViewModelDoesNotApplyIndependentEightCardLimit
swift test --filter PreviewPanelLayoutEngineTests/testHorizontalPanelSizeCapsVisibleWidthWhenMaxCardsIsTwelve
```

Expected: FAIL because protocols and initializers still hard-code `8`.

- [ ] **Step 3: Change window query protocol and service**

Update `Sources/DockHoverPreviewProbe/WindowQueryService.swift`:

```swift
protocol WindowQueryService: Sendable {
    func windows(for app: NSRunningApplication, limit: Int) async -> [PreviewWindow]
}
```

In `ScreenCaptureWindowQueryService.windows`, replace both `prefix(8)` calls with `prefix(limit)` and log item rows from the limited result:

```swift
let limited = Array(sorted.prefix(limit))
logger.info("windows.query app=\(app.localizedName ?? "unknown") count=\(limited.count) totalCount=\(sorted.count) limit=\(limit) elapsedMS=\(elapsedMS)")
limited.forEach { window in
    logger.info("windows.item id=\(window.cgWindowID) pid=\(window.id.pid) title=\(window.title) frame=\(window.frame) axMatched=\(window.axElement != nil)")
}
return limited
```

Update all fake services to implement:

```swift
func windows(for app: NSRunningApplication, limit: Int) async -> [PreviewWindow] {
    requestedLimits.append(limit)
    return Array(windows.prefix(limit))
}
```

- [ ] **Step 4: Change preview view model initializer**

Update `Sources/DockHoverPreviewProbe/PreviewPanelModels.swift`:

```swift
struct PreviewPanelViewModel {
    let appName: String
    private(set) var cards: [PreviewCardViewModel]

    init(appName: String, cards: [PreviewCardViewModel], maxCardCount: Int) {
        self.appName = appName
        self.cards = Array(cards.prefix(max(maxCardCount, 0)))
    }
}
```

Update call sites to pass the settings max count.

- [ ] **Step 5: Cap horizontal visible panel width**

Update `Sources/DockHoverPreviewProbe/PreviewPanelView.swift` so `maxCardCount=12` shows all cards in the horizontal scroll view without making the panel wider than the current 8-card MVP maximum:

```swift
enum PreviewPanelMetrics {
    static let maxVisibleHorizontalCards = 8
    static let maxVisibleVerticalCards = 3

    static func panelSize(cardCount: Int, layout: PreviewPanelLayout) -> CGSize {
        let safeCardCount = max(cardCount, 1)
        switch layout {
        case .horizontal:
            let visibleCardCount = min(safeCardCount, maxVisibleHorizontalCards)
            return CGSize(
                width: CGFloat(visibleCardCount) * cardWidth
                    + CGFloat(max(visibleCardCount - 1, 0)) * cardSpacing
                    + panelPadding * 2,
                height: cardHeight + panelPadding * 2
            )
        case .vertical:
            let visibleCardCount = min(safeCardCount, maxVisibleVerticalCards)
            return CGSize(
                width: cardWidth + panelPadding * 2,
                height: CGFloat(visibleCardCount) * cardHeight
                    + CGFloat(max(visibleCardCount - 1, 0)) * cardSpacing
                    + panelPadding * 2
            )
        }
    }
}
```

- [ ] **Step 6: Inject settings into preview session**

Update `PreviewSessionController` initializer:

```swift
private let settingsStore: DockHoverPreviewSettingsStore

init(
    permissionService: PermissionService,
    windowQueryService: WindowQueryService,
    thumbnailService: ThumbnailService,
    activationService: ActivationService,
    panelDisplay: PreviewPanelDisplaying,
    settingsStore: DockHoverPreviewSettingsStore,
    logger: ProbeLogger
) {
    self.permissionService = permissionService
    self.windowQueryService = windowQueryService
    self.thumbnailService = thumbnailService
    self.activationService = activationService
    self.panelDisplay = panelDisplay
    self.settingsStore = settingsStore
    self.logger = logger
}
```

In `showPreview`, read a snapshot once for the session:

```swift
let settings = settingsStore.snapshot
let windows = await windowQueryService.windows(for: app, limit: settings.maxCardCount)
...
currentModel = PreviewPanelViewModel(appName: appName, cards: cards, maxCardCount: settings.maxCardCount)
```

Update `PreviewSessionHarness` to accept `settingsStore: DockHoverPreviewSettingsStore = FakeSettingsStore()` and pass it into `PreviewSessionController`.

Update `Sources/DockHoverPreviewProbe/AppDelegate.swift` in this same task:

```swift
private var settingsStore: DockHoverPreviewSettingsStore!

// in applicationDidFinishLaunching, before PreviewSessionController construction
settingsStore = UserDefaultsSettingsStore(logger: logger)

previewSessionController = PreviewSessionController(
    permissionService: permissionService,
    windowQueryService: windowQueryService,
    thumbnailService: thumbnailService,
    activationService: activationService,
    panelDisplay: previewPanelController,
    settingsStore: settingsStore,
    logger: logger
)
```

This keeps the Task 3 `swift build` gate meaningful; do not wait until Task 9 to wire this required dependency.

- [ ] **Step 7: Run checks**

Run:

```bash
swift test --filter PreviewSessionControllerTests
swift test --filter PreviewPanelViewModelTests
swift test --filter WindowQueryServiceTests
swift test --filter PreviewPanelLayoutEngineTests/testHorizontalPanelSizeCapsVisibleWidthWhenMaxCardsIsTwelve
swift test
swift build
git diff --check
```

Expected: all pass.

## Task 4: Retention Mode Parameterization

**Files:**

- Modify: `Sources/DockHoverPreviewProbe/PreviewSessionController.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`

- [ ] **Step 1: Write failing retention tests**

Add tests that compare standard, tight, and forgiving behavior using pure geometry points:

```swift
func testStandardRetentionMatchesExistingBridgeBehavior() async {
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [makeWindow(id: 1)], settingsStore: FakeSettingsStore(snapshot: .defaultsWith(retention: .standard)))
    harness.display.panelFrameResult = CGRect(x: 600, y: 58, width: 256, height: 196)

    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    XCTAssertTrue(harness.controller.isMouseInsidePreviewRegion(CGPoint(x: 726, y: 53)))
    XCTAssertFalse(harness.controller.isMouseInsidePreviewRegion(CGPoint(x: 300, y: 53)))
}

func testTightRetentionShrinksDockTolerance() async {
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [makeWindow(id: 1)], settingsStore: FakeSettingsStore(snapshot: .defaultsWith(retention: .tight)))
    harness.display.panelFrameResult = CGRect(x: 600, y: 58, width: 256, height: 196)

    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    XCTAssertFalse(harness.controller.isMouseInsidePreviewRegion(CGPoint(x: 775, y: 40)))
}

func testForgivingRetentionExpandsDockTolerance() async {
    let harness = PreviewSessionHarness(screenRecordingGranted: true, windows: [makeWindow(id: 1)], settingsStore: FakeSettingsStore(snapshot: .defaultsWith(retention: .forgiving)))
    harness.display.panelFrameResult = CGRect(x: 600, y: 58, width: 256, height: 196)

    await harness.controller.showPreview(for: harness.app, anchor: harness.anchor)

    XCTAssertTrue(harness.controller.isMouseInsidePreviewRegion(CGPoint(x: 787, y: 40)))
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter PreviewSessionControllerTests/testTightRetentionShrinksDockTolerance
swift test --filter PreviewSessionControllerTests/testForgivingRetentionExpandsDockTolerance
```

Expected: FAIL because preview session still uses fixed constants.

- [ ] **Step 3: Replace fixed constants with parameters**

In `PreviewSessionController`, replace:

```swift
private let previewRegionTolerance: CGFloat = 24
private let panelEdgeTolerance: CGFloat = 6
```

with:

```swift
private var currentRetentionParameters = PanelRetentionMode.standard.parameters
```

In `showPreview`, after reading settings:

```swift
currentRetentionParameters = settings.panelRetentionParameters
```

In geometry methods, use:

```swift
let dockTolerance = currentRetentionParameters.dockItemTolerance
let panelTolerance = currentRetentionParameters.panelEdgeTolerance
let bridgeInset = currentRetentionParameters.bridgeInset
```

Update `bridgeFrame` so bridge width/inset uses `bridgeInset`, not the old dock tolerance.

- [ ] **Step 4: Make settings changes affect current leave polling**

Add observer wiring in `PreviewSessionController`:

```swift
private var settingsObserverToken: UUID?

func startObservingSettings() {
    settingsObserverToken = settingsStore.addObserver { [weak self] settings in
        self?.currentRetentionParameters = settings.panelRetentionParameters
    }
}

func stopObservingSettings() {
    if let settingsObserverToken {
        settingsStore.removeObserver(settingsObserverToken)
    }
    settingsObserverToken = nil
}
```

Call `startObservingSettings()` from `AppDelegate` after construction or directly from the initializer if the store is `@MainActor`. Ensure `stopObservingSettings()` is called during app termination if not using deinit.

- [ ] **Step 5: Run checks**

Run:

```bash
swift test --filter PreviewSessionControllerTests
swift test
swift build
git diff --check
```

Expected: all pass, especially existing bridge and adjacent Dock item tests.

## Task 5: Orchestrator Settings Integration and Hover Scheduler

**Files:**

- Create: `Sources/DockHoverPreviewProbe/HoverDelayScheduler.swift`
- Modify: `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`
- Modify: `Sources/DockHoverPreviewProbe/AppDelegate.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/ProbeOrchestratorPreviewTests.swift`

- [ ] **Step 1: Write failing orchestrator tests**

Add fake scheduler and settings tests:

```swift
@MainActor
private final class FakeHoverDelayScheduler: HoverDelayScheduling {
    struct Scheduled {
        let milliseconds: Int
        let action: @MainActor () -> Void
        let token: HoverDelayCancellation
    }
    private(set) var scheduled: [Scheduled] = []

    func schedule(afterMilliseconds milliseconds: Int, action: @escaping @MainActor () -> Void) -> HoverDelayCancellation {
        let token = FakeHoverDelayCancellation()
        scheduled.append(Scheduled(milliseconds: milliseconds, action: action, token: token))
        return token
    }
}

private final class FakeHoverDelayCancellation: HoverDelayCancellation {
    private(set) var isCancelled = false
    func cancel() { isCancelled = true }
}

private struct FakeFrontmostApplicationProvider: FrontmostApplicationProviding {
    let frontmostApplication: NSRunningApplication?
}
```

Tests to add:

```swift
func testFrontmostDebugPreviewIgnoresDisabledSettingButRespectsScreenRecording() async {
    let settings = FakeSettingsStore(snapshot: .defaultsWith(enabled: false))
    let harness = ProbeOrchestratorPreviewHarness(
        screenRecordingGranted: true,
        settingsStore: settings,
        frontmostApplicationProvider: FakeFrontmostApplicationProvider(frontmostApplication: NSRunningApplication.current)
    )

    harness.orchestrator.showFrontmostAppProbe()
    await Task.yield()

    XCTAssertEqual(harness.display.showCount, 0)
    XCTAssertEqual(harness.display.hideReasons, ["noWindows"])
}

func testFrontmostDebugPreviewRespectsExcludedApp() async {
    let bundleIdentifier = NSRunningApplication.current.bundleIdentifier!
    let snapshot = DockHoverPreviewSettings.defaultsWith(excludedApps: [bundleIdentifier])
    let settings = FakeSettingsStore(snapshot: snapshot)
    let harness = ProbeOrchestratorPreviewHarness(
        screenRecordingGranted: true,
        settingsStore: settings,
        frontmostApplicationProvider: FakeFrontmostApplicationProvider(frontmostApplication: NSRunningApplication.current)
    )

    harness.orchestrator.showFrontmostAppProbe()
    await Task.yield()

    XCTAssertEqual(harness.display.hideReasons, ["appExcluded"])
    XCTAssertEqual(harness.display.showCount, 0)
}

func testHoverDelayUsesSettingsSnapshot() {
    let scheduler = FakeHoverDelayScheduler()
    let settings = FakeSettingsStore(snapshot: .defaultsWith(hoverDelayMilliseconds: 400))
    let harness = ProbeOrchestratorPreviewHarness(
        screenRecordingGranted: true,
        settingsStore: settings,
        hoverScheduler: scheduler,
        frontmostApplicationProvider: FakeFrontmostApplicationProvider(frontmostApplication: NSRunningApplication.current)
    )

    harness.orchestrator.schedulePreviewAfterDelayForTesting(
        app: NSRunningApplication.current,
        bundleIdentifier: NSRunningApplication.current.bundleIdentifier!,
        dockItemFrame: CGRect(x: 0, y: 0, width: 48, height: 48)
    )

    XCTAssertEqual(scheduler.scheduled.map(\.milliseconds), [400])
}

func testDisablingSettingsCancelsPendingHoverAndHidesPreview() {
    let scheduler = FakeHoverDelayScheduler()
    let settings = FakeSettingsStore(snapshot: .defaultsWith())
    let harness = ProbeOrchestratorPreviewHarness(
        screenRecordingGranted: true,
        settingsStore: settings,
        hoverScheduler: scheduler,
        frontmostApplicationProvider: FakeFrontmostApplicationProvider(frontmostApplication: NSRunningApplication.current)
    )

    harness.orchestrator.start()
    harness.orchestrator.schedulePreviewAfterDelayForTesting(
        app: NSRunningApplication.current,
        bundleIdentifier: NSRunningApplication.current.bundleIdentifier!,
        dockItemFrame: CGRect(x: 0, y: 0, width: 48, height: 48)
    )
    settings.replaceSnapshot(.defaultsWith(enabled: false))

    XCTAssertTrue((scheduler.scheduled.last?.token as? FakeHoverDelayCancellation)?.isCancelled == true)
    XCTAssertEqual(harness.display.hideReasons, ["settingsDisabled"])
}

func testAddingPendingAppToExclusionsCancelsPendingHoverAndHidesPreview() {
    let scheduler = FakeHoverDelayScheduler()
    let bundleIdentifier = NSRunningApplication.current.bundleIdentifier!
    let settings = FakeSettingsStore(snapshot: .defaultsWith())
    let harness = ProbeOrchestratorPreviewHarness(
        screenRecordingGranted: true,
        settingsStore: settings,
        hoverScheduler: scheduler,
        frontmostApplicationProvider: FakeFrontmostApplicationProvider(frontmostApplication: NSRunningApplication.current)
    )

    harness.orchestrator.start()
    harness.orchestrator.schedulePreviewAfterDelayForTesting(
        app: NSRunningApplication.current,
        bundleIdentifier: bundleIdentifier,
        dockItemFrame: CGRect(x: 0, y: 0, width: 48, height: 48)
    )
    settings.replaceSnapshot(.defaultsWith(excludedApps: [bundleIdentifier]))

    XCTAssertTrue((scheduler.scheduled.last?.token as? FakeHoverDelayCancellation)?.isCancelled == true)
    XCTAssertEqual(harness.display.hideReasons, ["appExcluded"])
}

func testDelayedValidationRechecksDisabledSettingBeforeShowingPreview() {
    let settings = FakeSettingsStore(snapshot: .defaultsWith())
    let harness = ProbeOrchestratorPreviewHarness(
        screenRecordingGranted: true,
        settingsStore: settings,
        frontmostApplicationProvider: FakeFrontmostApplicationProvider(frontmostApplication: NSRunningApplication.current)
    )
    let candidate = HoverPreviewCandidate(
        app: NSRunningApplication.current,
        bundleIdentifier: NSRunningApplication.current.bundleIdentifier!,
        dockItemFrame: CGRect(x: 0, y: 0, width: 48, height: 48)
    )
    settings.replaceSnapshot(.defaultsWith(enabled: false))

    harness.orchestrator.validateDelayedHoverForTesting(candidate: candidate, resolved: candidate, mouseInside: true)

    XCTAssertEqual(harness.display.hideReasons, ["settingsDisabled"])
    XCTAssertEqual(harness.display.showCount, 0)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter ProbeOrchestratorPreviewTests
```

Expected: FAIL because orchestrator does not accept settings and scheduler yet.

- [ ] **Step 3: Add scheduler abstraction**

Create `Sources/DockHoverPreviewProbe/HoverDelayScheduler.swift`:

```swift
import Foundation

@MainActor
protocol HoverDelayCancellation: AnyObject {
    func cancel()
}

@MainActor
protocol HoverDelayScheduling: AnyObject {
    func schedule(afterMilliseconds milliseconds: Int, action: @escaping @MainActor () -> Void) -> HoverDelayCancellation
}

@MainActor
final class DispatchHoverDelayScheduler: HoverDelayScheduling {
    func schedule(afterMilliseconds milliseconds: Int, action: @escaping @MainActor () -> Void) -> HoverDelayCancellation {
        let workItem = DispatchWorkItem {
            Task { @MainActor in action() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds), execute: workItem)
        return DispatchHoverDelayCancellation(workItem: workItem)
    }
}

private final class DispatchHoverDelayCancellation: HoverDelayCancellation {
    private let workItem: DispatchWorkItem

    init(workItem: DispatchWorkItem) {
        self.workItem = workItem
    }

    func cancel() {
        workItem.cancel()
    }
}
```

- [ ] **Step 4: Add frontmost app provider**

Add this small protocol near `ProbeOrchestrator` or in `HoverDelayScheduler.swift` if keeping small support types together:

```swift
protocol FrontmostApplicationProviding {
    var frontmostApplication: NSRunningApplication? { get }
}

struct WorkspaceFrontmostApplicationProvider: FrontmostApplicationProviding {
    var frontmostApplication: NSRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }
}
```

- [ ] **Step 5: Inject settings into orchestrator**

Update `ProbeOrchestrator` initializer:

```swift
private let settingsStore: DockHoverPreviewSettingsStore
private let hoverScheduler: HoverDelayScheduling
private let frontmostApplicationProvider: FrontmostApplicationProviding
private var pendingHoverCancellation: HoverDelayCancellation?
private var pendingHoverCandidateBundleIdentifier: String?
private var settingsObserverToken: UUID?

init(
    permissionService: PermissionService,
    logger: ProbeLogger,
    previewSessionController: PreviewSessionController,
    settingsStore: DockHoverPreviewSettingsStore,
    hoverScheduler: HoverDelayScheduling = DispatchHoverDelayScheduler(),
    frontmostApplicationProvider: FrontmostApplicationProviding = WorkspaceFrontmostApplicationProvider()
) {
    self.permissionService = permissionService
    self.logger = logger
    self.previewSessionController = previewSessionController
    self.settingsStore = settingsStore
    self.hoverScheduler = hoverScheduler
    self.frontmostApplicationProvider = frontmostApplicationProvider
    self.dockHoverMonitor.delegate = self
}
```

In `showFrontmostAppProbe()`, replace direct access to `NSWorkspace.shared.frontmostApplication` with:

```swift
guard let app = frontmostApplicationProvider.frontmostApplication else {
    logger.warning("debug.frontmost.noApp")
    return
}
if let bundleIdentifier = app.bundleIdentifier,
   settingsStore.snapshot.excludedAppBundleIdentifiers.contains(bundleIdentifier) {
    previewSessionController.hide(reason: "appExcluded")
    logger.info("debug.frontmost.skipped appExcluded=true bundle=\(bundleIdentifier)")
    return
}
```

Use `settingsStore.snapshot.hoverDelayMilliseconds` instead of the old `0.25` literal inside `schedulePreviewAfterDelay(for:monitor:)`. During delayed validation, read a fresh settings snapshot and re-check `enabled` and `excludedAppBundleIdentifiers`.

Add a lightweight internal candidate so delay scheduling and delayed validation can be verified without constructing `AXUIElement` in tests:

```swift
struct HoverPreviewCandidate {
    let app: NSRunningApplication
    let bundleIdentifier: String
    let dockItemFrame: CGRect?
}

func schedulePreviewAfterDelayForTesting(app: NSRunningApplication, bundleIdentifier: String, dockItemFrame: CGRect?) {
    schedulePreviewAfterDelay(
        for: HoverPreviewCandidate(app: app, bundleIdentifier: bundleIdentifier, dockItemFrame: dockItemFrame),
        monitor: nil
    )
}

func validateDelayedHoverForTesting(candidate: HoverPreviewCandidate, resolved: HoverPreviewCandidate?, mouseInside: Bool) {
    validateDelayedHover(candidate: candidate, resolved: resolved, mouseInside: mouseInside)
}
```

Move the scheduling body out of `dockHoverMonitor(_:didHover:)` into:

```swift
private func schedulePreviewAfterDelay(for candidate: HoverPreviewCandidate, monitor: DockHoverMonitor?) {
    pendingHoverCancellation?.cancel()
    pendingHoverCandidateBundleIdentifier = nil
    let settings = settingsStore.snapshot
    guard settings.isDockHoverPreviewEnabled else {
        previewSessionController.hide(reason: "settingsDisabled")
        logger.info("dock.hoverSkipped settingsDisabled=true")
        return
    }
    guard !settings.excludedAppBundleIdentifiers.contains(candidate.bundleIdentifier) else {
        previewSessionController.hide(reason: "appExcluded")
        logger.info("dock.hoverSkipped appExcluded=true bundle=\(candidate.bundleIdentifier)")
        return
    }
    pendingHoverCandidateBundleIdentifier = candidate.bundleIdentifier
    pendingHoverCancellation = hoverScheduler.schedule(afterMilliseconds: settings.hoverDelayMilliseconds) { [weak self, weak monitor] in
        self?.validateDelayedHover(candidate: candidate, monitor: monitor)
    }
}
```

In `dockHoverMonitor(_:didHover:)`, convert the real hover model:

```swift
schedulePreviewAfterDelay(
    for: HoverPreviewCandidate(
        app: app.app,
        bundleIdentifier: app.bundleIdentifier,
        dockItemFrame: app.dockItemFrame
    ),
    monitor: monitor
)
```

Implement delayed validation as two methods so production code can resolve the current Dock state while tests can inject the resolved candidate:

```swift
private func validateDelayedHover(candidate: HoverPreviewCandidate, monitor: DockHoverMonitor?) {
    let stillHovered = monitor?.resolveCurrentHoveredDockApp()
    let resolved = stillHovered.map {
        HoverPreviewCandidate(
            app: $0.app,
            bundleIdentifier: $0.bundleIdentifier,
            dockItemFrame: $0.dockItemFrame
        )
    }
    let validationFrame = resolved?.dockItemFrame
    let mouseInside = validationFrame.map {
        GeometryHelpers.containsDockItemHover(
            NSEvent.mouseLocation,
            dockItemFrame: $0,
            screenFrame: makeAnchor(dockItemFrame: $0).screenFrame,
            tolerance: 2
        )
    } ?? false
    validateDelayedHover(candidate: candidate, resolved: resolved, mouseInside: mouseInside)
}

private func validateDelayedHover(candidate: HoverPreviewCandidate, resolved: HoverPreviewCandidate?, mouseInside: Bool) {
    pendingHoverCancellation = nil
    pendingHoverCandidateBundleIdentifier = nil

    let settings = settingsStore.snapshot
    guard settings.isDockHoverPreviewEnabled else {
        previewSessionController.hide(reason: "settingsDisabled")
        logger.info("dock.hoverDelayedSkipped settingsDisabled=true bundle=\(candidate.bundleIdentifier)")
        return
    }
    guard !settings.excludedAppBundleIdentifiers.contains(candidate.bundleIdentifier) else {
        previewSessionController.hide(reason: "appExcluded")
        logger.info("dock.hoverDelayedSkipped appExcluded=true bundle=\(candidate.bundleIdentifier)")
        return
    }

    let matches = resolved?.bundleIdentifier == candidate.bundleIdentifier
    logger.info("dock.hoverDelayed bundle=\(candidate.bundleIdentifier) matches=\(matches) mouseInside=\(mouseInside) frame=\(String(describing: resolved?.dockItemFrame))")
    guard matches, mouseInside, let resolved else {
        previewSessionController.hide(reason: "hoverValidationFailed")
        return
    }

    let anchor = makeAnchor(dockItemFrame: resolved.dockItemFrame)
    Task { @MainActor [previewSessionController] in
        await previewSessionController.showPreview(for: resolved.app, anchor: anchor)
    }
}
```

Update `Sources/DockHoverPreviewProbe/AppDelegate.swift` in this same task so the app still builds:

```swift
orchestrator = ProbeOrchestrator(
    permissionService: permissionService,
    logger: logger,
    previewSessionController: previewSessionController,
    settingsStore: settingsStore
)
```

Update `ProbeOrchestratorPreviewHarness` to accept `settingsStore`, `hoverScheduler`, and `frontmostApplicationProvider`, and pass them through to `ProbeOrchestrator`.

- [ ] **Step 6: Observe settings changes**

In `start()`:

```swift
settingsObserverToken = settingsStore.addObserver { [weak self] settings in
    guard let self else { return }
    if !settings.isDockHoverPreviewEnabled {
        self.pendingHoverCancellation?.cancel()
        self.pendingHoverCancellation = nil
        self.pendingHoverCandidateBundleIdentifier = nil
        self.previewSessionController.hide(reason: "settingsDisabled")
        return
    }
    if let bundleIdentifier = self.pendingHoverCandidateBundleIdentifier,
       settings.excludedAppBundleIdentifiers.contains(bundleIdentifier) {
        self.pendingHoverCancellation?.cancel()
        self.pendingHoverCancellation = nil
        self.pendingHoverCandidateBundleIdentifier = nil
        self.previewSessionController.hide(reason: "appExcluded")
    }
}
```

In `stop()`:

```swift
pendingHoverCancellation?.cancel()
pendingHoverCancellation = nil
pendingHoverCandidateBundleIdentifier = nil
if let settingsObserverToken {
    settingsStore.removeObserver(settingsObserverToken)
}
settingsObserverToken = nil
```

- [ ] **Step 7: Run checks**

Run:

```bash
swift test --filter ProbeOrchestratorPreviewTests
swift test
swift build
git diff --check
```

Expected: all pass. Logs must retain stable English event/reason names.

## Task 6: Excluded-App Target Tracker

**Files:**

- Create: `Sources/DockHoverPreviewProbe/AppTargetTracker.swift`
- Create: `Tests/DockHoverPreviewProbeTests/AppTargetTrackerTests.swift`
- Modify: `Sources/DockHoverPreviewProbe/ProbeOrchestrator.swift`
- Modify: `Sources/DockHoverPreviewProbe/PreviewSessionController.swift`
- Modify: `Sources/DockHoverPreviewProbe/AppDelegate.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/PreviewSessionControllerTests.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/ProbeOrchestratorPreviewTests.swift`

- [ ] **Step 1: Write failing target tracker tests**

Create `Tests/DockHoverPreviewProbeTests/AppTargetTrackerTests.swift`:

```swift
import AppKit
import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class AppTargetTrackerTests: XCTestCase {
    func testPrefersCurrentPreviewAppOverHoveredAndActiveApp() {
        let tracker = AppTargetTracker(selfBundleIdentifier: "com.zong.DockHoverPreviewProbe")
        tracker.updateLatestNonSelfActiveApp(AppTarget(bundleIdentifier: "com.apple.TextEdit", displayName: "TextEdit"))
        tracker.updateLatestHoveredDockApp(AppTarget(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"))
        tracker.updateCurrentPreviewApp(AppTarget(bundleIdentifier: "com.microsoft.VSCode", displayName: "Code"))

        XCTAssertEqual(tracker.exclusionTarget?.bundleIdentifier, "com.microsoft.VSCode")
    }

    func testIgnoresSelfAndMissingBundleIdentifier() {
        let tracker = AppTargetTracker(selfBundleIdentifier: "com.zong.DockHoverPreviewProbe")
        tracker.updateLatestNonSelfActiveApp(AppTarget(bundleIdentifier: "com.zong.DockHoverPreviewProbe", displayName: "zongMacTools"))
        tracker.updateLatestHoveredDockApp(AppTarget(bundleIdentifier: "", displayName: "Unknown"))

        XCTAssertNil(tracker.exclusionTarget)
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter AppTargetTrackerTests
```

Expected: FAIL because tracker does not exist.

- [ ] **Step 3: Implement tracker**

Create `Sources/DockHoverPreviewProbe/AppTargetTracker.swift`:

```swift
import AppKit

struct AppTarget: Equatable, Sendable {
    let bundleIdentifier: String
    let displayName: String
}

@MainActor
final class AppTargetTracker {
    private let selfBundleIdentifier: String
    private var currentPreviewApp: AppTarget?
    private var latestHoveredDockApp: AppTarget?
    private var latestNonSelfActiveApp: AppTarget?
    private var observer: NSObjectProtocol?

    init(selfBundleIdentifier: String) {
        self.selfBundleIdentifier = selfBundleIdentifier
    }

    var exclusionTarget: AppTarget? {
        [currentPreviewApp, latestHoveredDockApp, latestNonSelfActiveApp]
            .compactMap { $0 }
            .first { isValidTarget($0) }
    }

    func updateCurrentPreviewApp(_ target: AppTarget?) {
        currentPreviewApp = target.flatMap { isValidTarget($0) ? $0 : nil }
    }

    func updateLatestHoveredDockApp(_ target: AppTarget?) {
        latestHoveredDockApp = target.flatMap { isValidTarget($0) ? $0 : nil }
    }

    func updateLatestNonSelfActiveApp(_ target: AppTarget?) {
        latestNonSelfActiveApp = target.flatMap { isValidTarget($0) ? $0 : nil }
    }

    func startWorkspaceObservation(workspace: NSWorkspace = .shared) {
        observer = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor in
                self?.updateLatestNonSelfActiveApp(AppTarget(app: app))
            }
        }
    }

    func stopWorkspaceObservation(workspace: NSWorkspace = .shared) {
        if let observer {
            workspace.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    private func isValidTarget(_ target: AppTarget) -> Bool {
        !target.bundleIdentifier.isEmpty && target.bundleIdentifier != selfBundleIdentifier
    }
}

extension AppTarget {
    init?(app: NSRunningApplication) {
        guard let bundleIdentifier = app.bundleIdentifier, !bundleIdentifier.isEmpty else { return nil }
        self.bundleIdentifier = bundleIdentifier
        self.displayName = app.localizedName ?? bundleIdentifier
    }
}
```

- [ ] **Step 4: Inject tracker and wire tracker updates**

Add `targetTracker` as a required dependency in `ProbeOrchestrator` and `PreviewSessionController`, then update `AppDelegate` and test harnesses in the same task:

```swift
// ProbeOrchestrator
private let targetTracker: AppTargetTracker

init(
    permissionService: PermissionService,
    logger: ProbeLogger,
    previewSessionController: PreviewSessionController,
    settingsStore: DockHoverPreviewSettingsStore,
    targetTracker: AppTargetTracker,
    hoverScheduler: HoverDelayScheduling = DispatchHoverDelayScheduler(),
    frontmostApplicationProvider: FrontmostApplicationProviding = WorkspaceFrontmostApplicationProvider()
) {
    self.permissionService = permissionService
    self.logger = logger
    self.previewSessionController = previewSessionController
    self.settingsStore = settingsStore
    self.targetTracker = targetTracker
    self.hoverScheduler = hoverScheduler
    self.frontmostApplicationProvider = frontmostApplicationProvider
    self.dockHoverMonitor.delegate = self
}

// PreviewSessionController
private let targetTracker: AppTargetTracker

init(
    permissionService: PermissionService,
    windowQueryService: WindowQueryService,
    thumbnailService: ThumbnailService,
    activationService: ActivationService,
    panelDisplay: PreviewPanelDisplaying,
    settingsStore: DockHoverPreviewSettingsStore,
    targetTracker: AppTargetTracker,
    logger: ProbeLogger
) {
    self.permissionService = permissionService
    self.windowQueryService = windowQueryService
    self.thumbnailService = thumbnailService
    self.activationService = activationService
    self.panelDisplay = panelDisplay
    self.settingsStore = settingsStore
    self.targetTracker = targetTracker
    self.logger = logger
}
```

Update `AppDelegate` before this task's build gate:

```swift
private var targetTracker: AppTargetTracker!

targetTracker = AppTargetTracker(selfBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.zong.DockHoverPreviewProbe")
targetTracker.startWorkspaceObservation()

previewSessionController = PreviewSessionController(
    permissionService: permissionService,
    windowQueryService: windowQueryService,
    thumbnailService: thumbnailService,
    activationService: activationService,
    panelDisplay: previewPanelController,
    settingsStore: settingsStore,
    targetTracker: targetTracker,
    logger: logger
)

orchestrator = ProbeOrchestrator(
    permissionService: permissionService,
    logger: logger,
    previewSessionController: previewSessionController,
    settingsStore: settingsStore,
    targetTracker: targetTracker
)
```

In `applicationWillTerminate`, stop workspace observation in the same task that starts it:

```swift
targetTracker.stopWorkspaceObservation()
```

In `ProbeOrchestrator.dockHoverMonitor(_:didHover:)`, call:

```swift
targetTracker.updateLatestHoveredDockApp(AppTarget(bundleIdentifier: app.bundleIdentifier, displayName: app.app.localizedName ?? app.bundleIdentifier))
```

In `PreviewSessionController.showPreview`, after computing `appName`, call:

```swift
targetTracker.updateCurrentPreviewApp(AppTarget(app: app))
```

In `PreviewSessionController.hide`, clear current preview:

```swift
targetTracker.updateCurrentPreviewApp(nil)
```

- [ ] **Step 5: Run checks**

Run:

```bash
swift test --filter AppTargetTrackerTests
swift test
swift build
git diff --check
```

Expected: all pass.

## Task 7: Menu Bar Settings UI

**Files:**

- Modify: `Sources/DockHoverPreviewProbe/MenuBarController.swift`
- Create: `Sources/DockHoverPreviewProbe/LaunchAtLoginService.swift`
- Modify: `Sources/DockHoverPreviewProbe/AppDelegate.swift`
- Modify: `Tests/DockHoverPreviewProbeTests/MenuBarControllerTests.swift` if created, otherwise create it.

- [ ] **Step 1: Write failing menu tests**

Create `Tests/DockHoverPreviewProbeTests/MenuBarControllerTests.swift` with menu construction tests. If direct `NSStatusItem` installation is too UI-coupled, extract menu construction into an internal method:

```swift
func makeMenu(permissionState: PermissionState) -> NSMenu
```

Test cases:

```swift
@MainActor
final class MenuBarControllerTests: XCTestCase {
    func testMenuShowsCheckedDelayRetentionMaxCardsAndLanguage() {
        var settings = DockHoverPreviewSettings.defaults
        settings.hoverDelayMilliseconds = 400
        settings.panelRetentionMode = .forgiving
        settings.maxCardCount = 12
        settings.displayLanguage = .simplifiedChinese
        let harness = MenuHarness(settings: settings)

        let menu = harness.controller.makeMenu(permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: true))

        XCTAssertNotNil(menu.findItem(title: "400 ms", state: .on))
        XCTAssertNotNil(menu.findItem(title: "Forgiving", state: .on))
        XCTAssertNotNil(menu.findItem(title: "12", state: .on))
        XCTAssertNotNil(menu.findItem(title: "简体中文", state: .on))
    }

    func testExcludedAppTargetTitleIsExplicit() {
        let harness = MenuHarness(settings: .defaults)
        harness.targetTracker.updateLatestNonSelfActiveApp(AppTarget(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"))

        let menu = harness.controller.makeMenu(permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: true))

        XCTAssertNotNil(menu.findItem(title: "Exclude Google Chrome"))
    }

    func testLongExcludedListIsSummarized() {
        var settings = DockHoverPreviewSettings.defaults
        settings.excludedAppBundleIdentifiers = Set((0..<30).map { "com.example.app\($0)" })
        let harness = MenuHarness(settings: settings)

        let menu = harness.controller.makeMenu(permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: true))

        XCTAssertNotNil(menu.findItem(containing: "more excluded apps"))
    }

    func testDisableActionWritesSettingCancelsPendingAndHidesPreview() {
        let harness = MenuHarness(settings: .defaults)
        let menu = harness.controller.makeMenu(permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: true))

        menu.performItem(title: "Disable Dock Hover Preview")

        XCTAssertFalse(harness.settingsStore.snapshot.isDockHoverPreviewEnabled)
        XCTAssertEqual(harness.orchestrator.cancelReasons, ["settingsDisabled"])
        XCTAssertEqual(harness.orchestrator.hideReasons, ["settingsDisabled"])
    }

    func testExcludeTargetActionWritesSettingCancelsPendingAndHidesPreview() {
        let harness = MenuHarness(settings: .defaults)
        harness.targetTracker.updateLatestNonSelfActiveApp(AppTarget(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"))
        let menu = harness.controller.makeMenu(permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: true))

        menu.performItem(title: "Exclude Google Chrome")

        XCTAssertEqual(harness.settingsStore.snapshot.excludedAppBundleIdentifiers, ["com.google.Chrome"])
        XCTAssertEqual(harness.orchestrator.cancelReasons, ["appExcluded"])
        XCTAssertEqual(harness.orchestrator.hideReasons, ["appExcluded"])
    }

    func testExcludeTargetIsDisabledForSelfApp() {
        let harness = MenuHarness(settings: .defaults)
        harness.targetTracker.updateLatestNonSelfActiveApp(AppTarget(bundleIdentifier: "com.zong.DockHoverPreviewProbe", displayName: "zongMacTools"))

        let menu = harness.controller.makeMenu(permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: true))

        let item = menu.findItem(title: "Exclude App")
        XCTAssertNotNil(item)
        XCTAssertFalse(item?.isEnabled ?? true)
    }

    func testLaunchAtLoginNotFoundDisablesToggleAndKeepsOpenSettings() {
        let harness = MenuHarness(settings: .defaults, launchAtLoginStatus: .notFound)

        let menu = harness.controller.makeMenu(permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: true))

        XCTAssertNotNil(menu.findItem(title: "Launch at Login: Not Found"))
        XCTAssertFalse(menu.findItem(title: "Enable Launch at Login")?.isEnabled ?? true)
        XCTAssertFalse(menu.findItem(title: "Disable Launch at Login")?.isEnabled ?? true)
        XCTAssertTrue(menu.findItem(title: "Open Login Items Settings")?.isEnabled == true)
    }
}
```

Add helper:

```swift
@MainActor
private final class MenuHarness {
    let settingsStore: FakeSettingsStore
    let targetTracker = AppTargetTracker(selfBundleIdentifier: "com.zong.DockHoverPreviewProbe")
    let orchestrator = FakeMenuOrchestrator()
    let launchAtLoginService: FakeLaunchAtLoginService
    let controller: MenuBarController

    init(settings: DockHoverPreviewSettings, launchAtLoginStatus: LaunchAtLoginStatus = .notRegistered) {
        settingsStore = FakeSettingsStore(snapshot: settings)
        launchAtLoginService = FakeLaunchAtLoginService(status: launchAtLoginStatus)
        controller = MenuBarController(
            permissionService: FakePermissionService(accessibilityGranted: true, screenRecordingGranted: true),
            orchestrator: orchestrator,
            settingsStore: settingsStore,
            launchAtLoginService: launchAtLoginService,
            targetTracker: targetTracker,
            logger: ProbeLogger()
        )
    }
}

private final class FakePermissionService: PermissionService {
    var currentState: PermissionState

    init(accessibilityGranted: Bool, screenRecordingGranted: Bool) {
        currentState = PermissionState(
            accessibilityGranted: accessibilityGranted,
            screenRecordingGranted: screenRecordingGranted
        )
    }

    func refresh() -> PermissionState { currentState }
    func requestAccessibilityPrompt() {}
    func openAccessibilitySettings() {}
    func openScreenRecordingSettings() {}
}

@MainActor
private final class FakeMenuOrchestrator: MenuOrchestrating {
    private(set) var hideReasons: [String] = []
    private(set) var cancelReasons: [String] = []
    private(set) var debugPreviewCount = 0

    func showFrontmostAppProbe() {
        debugPreviewCount += 1
    }

    func cancelPendingHover(reason: String) {
        cancelReasons.append(reason)
    }

    func hidePreview(reason: String) {
        hideReasons.append(reason)
    }
}

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginStatus
    private(set) var enableCount = 0
    private(set) var disableCount = 0
    private(set) var openSettingsCount = 0

    init(status: LaunchAtLoginStatus) {
        self.status = status
    }

    func enable() throws { enableCount += 1 }
    func disable() throws { disableCount += 1 }
    func openSettings() { openSettingsCount += 1 }
}

private extension NSMenu {
    func findItem(title: String, state: NSControl.StateValue? = nil) -> NSMenuItem? {
        items.recursiveItems.first { item in
            item.title == title && (state == nil || item.state == state)
        }
    }

    func findItem(containing text: String) -> NSMenuItem? {
        items.recursiveItems.first { $0.title.contains(text) }
    }

    func performItem(title: String) {
        guard let item = findItem(title: title), let action = item.action else {
            XCTFail("Missing menu item \(title)")
            return
        }
        NSApplication.shared.sendAction(action, to: item.target, from: item)
    }
}

private extension Array where Element == NSMenuItem {
    var recursiveItems: [NSMenuItem] {
        flatMap { item in [item] + (item.submenu?.items.recursiveItems ?? []) }
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter MenuBarControllerTests
```

Expected: FAIL because `makeMenu` and P1 menu items do not exist.

- [ ] **Step 3: Add menu-facing protocols**

Create the fake-friendly Launch at Login API in `Sources/DockHoverPreviewProbe/LaunchAtLoginService.swift`. The system `SMAppService` implementation is added in Task 8.

```swift
enum LaunchAtLoginStatus: Equatable {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound

    var menuTextKey: LocalizedTextKey {
        switch self {
        case .enabled: .launchAtLoginEnabled
        case .notRegistered: .launchAtLoginNotRegistered
        case .requiresApproval: .launchAtLoginRequiresApproval
        case .notFound: .launchAtLoginNotFound
        }
    }

    var canEnable: Bool { self == .notRegistered }
    var canDisable: Bool { self == .enabled }
    var canOpenSettings: Bool { self == .requiresApproval || self == .notFound }
}

@MainActor
protocol LaunchAtLoginService: AnyObject {
    var status: LaunchAtLoginStatus { get }
    func enable() throws
    func disable() throws
    func openSettings()
}

@MainActor
final class UnavailableLaunchAtLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginStatus { .notFound }
    func enable() throws {}
    func disable() throws {}
    func openSettings() {}
}
```

`UnavailableLaunchAtLoginService` is a temporary buildable app implementation for Task 7 only. Task 8 replaces AppDelegate usage with `SystemLaunchAtLoginService`.

Add a narrow menu protocol in `MenuBarController.swift`:

```swift
@MainActor
protocol MenuOrchestrating: AnyObject {
    func showFrontmostAppProbe()
    func cancelPendingHover(reason: String)
    func hidePreview(reason: String)
}
```

Add menu bridge methods and conformance in `ProbeOrchestrator.swift`:

```swift
func cancelPendingHoverForMenu(reason: String) {
    pendingHoverCancellation?.cancel()
    pendingHoverCancellation = nil
    pendingHoverCandidateBundleIdentifier = nil
    logger.info("orchestrator.pendingHoverCancelled reason=\(reason)")
}

func hidePreviewForMenu(reason: String) {
    previewSessionController.hide(reason: reason)
}

extension ProbeOrchestrator: MenuOrchestrating {
    func cancelPendingHover(reason: String) {
        cancelPendingHoverForMenu(reason: reason)
    }

    func hidePreview(reason: String) {
        hidePreviewForMenu(reason: reason)
    }
}
```

- [ ] **Step 4: Update MenuBarController dependencies**

Update initializer:

```swift
init(
    permissionService: PermissionService,
    orchestrator: MenuOrchestrating,
    settingsStore: DockHoverPreviewSettingsStore,
    launchAtLoginService: LaunchAtLoginService,
    targetTracker: AppTargetTracker,
    logger: ProbeLogger
) {
    self.permissionService = permissionService
    self.orchestrator = orchestrator
    self.settingsStore = settingsStore
    self.launchAtLoginService = launchAtLoginService
    self.targetTracker = targetTracker
    self.logger = logger
}
```

Make `makeMenu(permissionState:)` internal for tests and have `rebuildMenu` call it.

When `targetTracker.exclusionTarget` is nil, render a disabled `Exclude App` item and no enabled include/exclude action. When a target exists, render `Exclude <Display Name>` or `Include <Display Name>` with the exact target name in the title.

Update `AppDelegate` in this same task so the new initializer is used before the build gate:

```swift
menuBarController = MenuBarController(
    permissionService: permissionService,
    orchestrator: orchestrator,
    settingsStore: settingsStore,
    launchAtLoginService: UnavailableLaunchAtLoginService(),
    targetTracker: targetTracker,
    logger: logger
)
```

- [ ] **Step 5: Add settings menu actions**

Use selectors that update settings:

```swift
@objc private func setHoverDelay(_ sender: NSMenuItem) {
    guard let value = sender.representedObject as? Int else { return }
    settingsStore.update { $0.hoverDelayMilliseconds = value }
    orchestrator.cancelPendingHover(reason: "settingsChanged")
    rebuildMenu()
}

@objc private func setPanelRetention(_ sender: NSMenuItem) {
    guard let rawValue = sender.representedObject as? String,
          let mode = PanelRetentionMode(rawValue: rawValue) else { return }
    settingsStore.update { $0.panelRetentionMode = mode }
    rebuildMenu()
}

@objc private func setMaxCards(_ sender: NSMenuItem) {
    guard let value = sender.representedObject as? Int else { return }
    settingsStore.update { $0.maxCardCount = value }
    rebuildMenu()
}

@objc private func setLanguage(_ sender: NSMenuItem) {
    guard let rawValue = sender.representedObject as? String,
          let language = DisplayLanguage(rawValue: rawValue) else { return }
    settingsStore.update { $0.displayLanguage = language }
    rebuildMenu()
}
```

Add enable toggle:

```swift
@objc private func toggleDockHoverPreview() {
    let enabled = settingsStore.snapshot.isDockHoverPreviewEnabled
    settingsStore.update { $0.isDockHoverPreviewEnabled = !enabled }
    if enabled {
        orchestrator.cancelPendingHover(reason: "settingsDisabled")
        orchestrator.hidePreview(reason: "settingsDisabled")
    }
    rebuildMenu()
}
```

- [ ] **Step 6: Add excluded apps actions**

Use `targetTracker.exclusionTarget`:

```swift
@objc private func excludeTargetApp() {
    guard let target = targetTracker.exclusionTarget else { return }
    settingsStore.update { $0.excludedAppBundleIdentifiers.insert(target.bundleIdentifier) }
    orchestrator.cancelPendingHover(reason: "appExcluded")
    orchestrator.hidePreview(reason: "appExcluded")
    rebuildMenu()
}

@objc private func includeTargetApp() {
    guard let target = targetTracker.exclusionTarget else { return }
    settingsStore.update { $0.excludedAppBundleIdentifiers.remove(target.bundleIdentifier) }
    rebuildMenu()
}

@objc private func removeExcludedApp(_ sender: NSMenuItem) {
    guard let bundleIdentifier = sender.representedObject as? String else { return }
    settingsStore.update { $0.excludedAppBundleIdentifiers.remove(bundleIdentifier) }
    rebuildMenu()
}

@objc private func clearExcludedApps() {
    settingsStore.update { $0.excludedAppBundleIdentifiers = [] }
    rebuildMenu()
}
```

- [ ] **Step 7: Run checks**

Run:

```bash
swift test --filter MenuBarControllerTests
swift test
swift build
git diff --check
```

Expected: all pass.

## Task 8: Launch at Login Service

**Files:**

- Modify: `Package.swift`
- Modify: `Sources/DockHoverPreviewProbe/LaunchAtLoginService.swift`
- Create: `Tests/DockHoverPreviewProbeTests/LaunchAtLoginServiceTests.swift`
- Modify: `Sources/DockHoverPreviewProbe/MenuBarController.swift`
- Modify: `Sources/DockHoverPreviewProbe/AppDelegate.swift`

- [ ] **Step 1: Write failing fake-service tests**

Create `Tests/DockHoverPreviewProbeTests/LaunchAtLoginServiceTests.swift`:

```swift
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
```

Also extend `MenuBarControllerTests` with action/error coverage. Update `FakeLaunchAtLoginService` to accept optional thrown errors:

```swift
private enum LaunchAtLoginTestError: Error {
    case failed
}

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginStatus
    var enableError: Error?
    var disableError: Error?
    private(set) var enableCount = 0
    private(set) var disableCount = 0
    private(set) var openSettingsCount = 0

    init(status: LaunchAtLoginStatus) {
        self.status = status
    }

    func enable() throws {
        enableCount += 1
        if let enableError { throw enableError }
    }

    func disable() throws {
        disableCount += 1
        if let disableError { throw disableError }
    }

    func openSettings() {
        openSettingsCount += 1
    }
}

func testEnableLaunchAtLoginActionCallsService() {
    let harness = MenuHarness(settings: .defaults, launchAtLoginStatus: .notRegistered)
    let menu = harness.controller.makeMenu(permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: true))

    menu.performItem(title: "Enable Launch at Login")

    XCTAssertEqual(harness.launchAtLoginService.enableCount, 1)
}

func testLaunchAtLoginEnableFailureDoesNotCrash() {
    let harness = MenuHarness(settings: .defaults, launchAtLoginStatus: .notRegistered)
    harness.launchAtLoginService.enableError = LaunchAtLoginTestError.failed
    let menu = harness.controller.makeMenu(permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: true))

    menu.performItem(title: "Enable Launch at Login")

    XCTAssertEqual(harness.launchAtLoginService.enableCount, 1)
}

func testRequiresApprovalOnlyOffersOpenSettings() {
    let harness = MenuHarness(settings: .defaults, launchAtLoginStatus: .requiresApproval)
    let menu = harness.controller.makeMenu(permissionState: PermissionState(accessibilityGranted: true, screenRecordingGranted: true))

    XCTAssertNotNil(menu.findItem(title: "Launch at Login: Requires Approval"))
    XCTAssertNil(menu.findItem(title: "Enable Launch at Login"))
    XCTAssertNil(menu.findItem(title: "Disable Launch at Login"))
    XCTAssertTrue(menu.findItem(title: "Open Login Items Settings")?.isEnabled == true)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter LaunchAtLoginServiceTests
```

Expected: FAIL because `SystemLaunchAtLoginService` does not exist yet.

- [ ] **Step 3: Link ServiceManagement**

Modify `Package.swift` linker settings:

```swift
.linkedFramework("ServiceManagement")
```

- [ ] **Step 4: Implement system service**

Update `Sources/DockHoverPreviewProbe/LaunchAtLoginService.swift` by adding `import ServiceManagement` and the system implementation below the existing protocol/status definitions from Task 7:

```swift
import ServiceManagement

@MainActor
final class SystemLaunchAtLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .notRegistered
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .notFound
        }
    }

    func enable() throws {
        try SMAppService.mainApp.register()
    }

    func disable() throws {
        try SMAppService.mainApp.unregister()
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
```

- [ ] **Step 5: Wire menu actions**

Add actions in `MenuBarController`:

```swift
@objc private func enableLaunchAtLogin() {
    do {
        try launchAtLoginService.enable()
    } catch {
        logger.error("launchAtLogin.enableFailed error=\(error)")
    }
    rebuildMenu()
}

@objc private func disableLaunchAtLogin() {
    do {
        try launchAtLoginService.disable()
    } catch {
        logger.error("launchAtLogin.disableFailed error=\(error)")
    }
    rebuildMenu()
}

@objc private func openLoginItemsSettings() {
    launchAtLoginService.openSettings()
}
```

Menu behavior:

- `.enabled`: show enabled status and enabled Disable action.
- `.notRegistered`: show not registered status and enabled Enable action.
- `.requiresApproval`: show requires approval status and Open Login Items Settings.
- `.notFound`: show not found status, disable Enable/Disable, show Open Login Items Settings.

Update `AppDelegate` to replace the Task 7 temporary service with the real system service:

```swift
private var launchAtLoginService: LaunchAtLoginService!

launchAtLoginService = SystemLaunchAtLoginService()
menuBarController = MenuBarController(
    permissionService: permissionService,
    orchestrator: orchestrator,
    settingsStore: settingsStore,
    launchAtLoginService: launchAtLoginService,
    targetTracker: targetTracker,
    logger: logger
)
```

- [ ] **Step 6: Run checks**

Run:

```bash
swift test --filter LaunchAtLoginServiceTests
swift test --filter MenuBarControllerTests
swift test
swift build
git diff --check
```

Expected: all pass.

## Task 9: App Delegate Wiring Audit

**Files:**

- Modify: `Sources/DockHoverPreviewProbe/AppDelegate.swift` only if the audit finds missing retention or lifecycle wiring.

- [ ] **Step 1: Audit AppDelegate construction**

By this point, earlier tasks must already have updated required initializer call sites. In `applicationDidFinishLaunching`, confirm the shared services exist as retained properties and are constructed in this order:

```swift
logger = ProbeLogger()
permissionService = SystemPermissionService(logger: logger)
settingsStore = UserDefaultsSettingsStore(logger: logger)
targetTracker = AppTargetTracker(selfBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.zong.DockHoverPreviewProbe")
targetTracker.startWorkspaceObservation()
launchAtLoginService = SystemLaunchAtLoginService()
previewPanelController = PreviewPanelController(logger: logger)
```

Confirm `settingsStore`, `targetTracker`, and `launchAtLoginService` are injected into the objects that need them:

```swift
previewSessionController = PreviewSessionController(..., settingsStore: settingsStore, targetTracker: targetTracker, logger: logger)
orchestrator = ProbeOrchestrator(..., settingsStore: settingsStore, targetTracker: targetTracker)
menuBarController = MenuBarController(..., settingsStore: settingsStore, launchAtLoginService: launchAtLoginService, targetTracker: targetTracker, logger: logger)
```

- [ ] **Step 2: Ensure lifecycle cleanup**

In `applicationWillTerminate`, stop orchestrator and workspace observation:

```swift
orchestrator.stop()
targetTracker.stopWorkspaceObservation()
logger.info("app.terminated")
```

Store `settingsStore`, `targetTracker`, and `launchAtLoginService` as properties so they are retained.

- [ ] **Step 3: Run checks**

Run:

```bash
swift test
swift build
git diff --check
```

Expected: all pass.

## Task 10: App Icon and User-Visible Name Packaging

**Files:**

- Modify: `Sources/DockHoverPreviewProbe/Info.plist`
- Modify: `Scripts/build_probe_app.sh`
- Modify: `Scripts/run_probe_app.sh`
- Use existing: `Assets/AppIcon/zong-mac-tools-logo.png`

- [ ] **Step 1: Update Info.plist**

Keep executable and bundle identifier stable for now, but change user-visible name and icon:

```xml
<key>CFBundleExecutable</key>
<string>DockHoverPreviewProbe</string>
<key>CFBundleIdentifier</key>
<string>com.zong.DockHoverPreviewProbe</string>
<key>CFBundleName</key>
<string>zongMacTools</string>
<key>CFBundleDisplayName</key>
<string>zongMacTools</string>
<key>CFBundleIconFile</key>
<string>zongMacTools</string>
```

Update usage descriptions to say `zongMacTools`.

- [ ] **Step 2: Update build script**

In `Scripts/build_probe_app.sh`, separate executable name from app bundle name:

```bash
EXECUTABLE_NAME="DockHoverPreviewProbe"
APP_BUNDLE_NAME="zongMacTools"
CONFIGURATION="${CONFIGURATION:-debug}"
APP_DIR="$ROOT_DIR/build/${APP_BUNDLE_NAME}.app"
```

Copy the executable:

```bash
EXECUTABLE_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)/$EXECUTABLE_NAME"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"
```

Generate `.icns` from `Assets/AppIcon/zong-mac-tools-logo.png`:

```bash
ICON_SOURCE="$ROOT_DIR/Assets/AppIcon/zong-mac-tools-logo.png"
ICONSET_DIR="$ROOT_DIR/build/zongMacTools.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/zongMacTools.icns"
rm -rf "$ICONSET_DIR"
```

Print the new app path:

```bash
echo "$APP_DIR"
```

- [ ] **Step 3: Update run script**

Make `Scripts/run_probe_app.sh` open the path printed by `Scripts/build_probe_app.sh`, not a hard-coded `DockHoverPreviewProbe.app` path:

```bash
APP_PATH="$("$ROOT_DIR/Scripts/build_probe_app.sh")"
open "$APP_PATH"
```

- [ ] **Step 4: Run automatic packaging checks**

Run:

```bash
swift build
Scripts/build_probe_app.sh
plutil -p build/zongMacTools.app/Contents/Info.plist | grep zongMacTools
test -f build/zongMacTools.app/Contents/Resources/zongMacTools.icns
codesign --verify --deep --strict build/zongMacTools.app
git diff --check
```

Expected:

- Build script prints `.../build/zongMacTools.app`.
- `Info.plist` contains `CFBundleName`, `CFBundleDisplayName`, and `CFBundleIconFile`.
- `zongMacTools.icns` exists.
- Codesign verification exits 0.

## Task 11: Docs and Verification Updates

**Files:**

- Modify: `README.md`
- Modify: `docs/architecture/dock-hover-preview-technical-design.md`
- Modify: `docs/verification/dock-hover-preview-mvp-ui-manual-checklist.md`
- Modify: `docs/verification/dock-hover-preview-probe-summary.md`
- Modify: `docs/verification/dock-hover-preview-environment-variant-verification-plan.md`

- [ ] **Step 1: Update docs only after automatic checks pass**

Before editing docs, run:

```bash
swift test
swift build
Scripts/build_probe_app.sh
git diff --check
```

Expected: all pass.

- [ ] **Step 2: Update README**

Document:

- User-visible app name: `zongMacTools`.
- Current SwiftPM executable/target remains `DockHoverPreviewProbe`.
- Build output path: `build/zongMacTools.app`.
- Menu bar item text, if still `DHP`, and the reason it remains a short module label.
- P1 settings menu.
- Screen Recording missing remains silent.
- Launch at Login uses public `ServiceManagement`.

- [ ] **Step 3: Update verification docs with actual results only**

Add P1 verification sections after the implementation has been run. Do not mark manual-only items as pass without doing them.

Required automatic evidence:

```text
swift test
swift build
Scripts/build_probe_app.sh
git diff --check
```

Manual-only evidence:

- Finder shows `zongMacTools.app` with the Z icon.
- System Settings permission rows show `zongMacTools` and the icon after re-adding permissions if TCC requires it.
- Login Items status follows `SMAppService.mainApp.status`; `.requiresApproval` opens settings and does not spam prompts.
- Menu actions visibly update checkmarks and do not leave stale panels.

- [ ] **Step 4: Run docs checks**

Run:

```bash
git diff --check
rg -n "build/DockHoverPreviewProbe\\.app|DockHoverPreviewProbe\\.app" README.md docs/verification docs/plans
```

Expected: old app bundle path appears only in archived docs or explicit historical notes. Current instructions should use `build/zongMacTools.app`.

## Final Automatic Verification

Run:

```bash
swift test
swift build
Scripts/build_probe_app.sh
git diff --check
```

Expected:

- XCTest passes.
- Swift build passes.
- App package is generated at `build/zongMacTools.app`.
- No whitespace errors.

If any command fails, do not start manual validation. Fix the failure first.

## Manual Validation Queue

Ask the human only after Final Automatic Verification passes.

Manual checks:

1. Open `build/zongMacTools.app`.
2. Grant/re-grant Accessibility and Screen Recording if macOS TCC requires it.
3. Confirm default behavior remains MVP-equivalent: enabled, 250 ms delay, standard retention, max 8 cards, no excluded apps, English UI.
4. Disable Dock hover preview and confirm Dock hover shows no panel.
5. Re-enable and confirm next hover works.
6. Check 150 ms and 400 ms delay settings.
7. Check tight/standard/forgiving retention without stale panel.
8. Check max cards 3/5/8/12 with a multi-window app.
9. Exclude target app, hover it, confirm no preview; include or clear and confirm preview returns.
10. Switch language to Simplified Chinese and back; app names, window titles, bundle ids, permission names, and logs must not be translated.
11. Toggle Launch at Login; if status becomes `requiresApproval`, open Login Items Settings and do not repeatedly prompt.
12. `killall Dock`, confirm no stuck panel and Dock observer recovers.
13. Sample ordinary bottom Dock, Dock auto-hide, left/right Dock, and Stage Manager only after core checks pass.

Multiple displays remain blocked unless the hardware is available.

## Completion Criteria

P1 is complete when:

- All automatic verification commands pass.
- Manual-only checks have documented pass/pass with note/fail/blocked results.
- `README.md` and verification docs reflect only actually verified behavior.
- Defaults preserve current MVP behavior.
- Screen Recording missing still silently suppresses preview UI.
- Stale hover cancellation remains a first-class behavior.
- No private API is introduced.
- No DockDoor GPLv3 source, structure, helper, comments, or private API wrappers are copied.
