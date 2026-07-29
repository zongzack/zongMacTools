import XCTest
@testable import DockHoverPreviewProbe

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testDefaultsMatchMVPBehavior() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: ProbeLogger())

        XCTAssertTrue(store.snapshot.isDockHoverPreviewEnabled)
        XCTAssertEqual(store.snapshot.hoverDelayMilliseconds, 250)
        XCTAssertEqual(store.snapshot.panelRetentionMode, .standard)
        XCTAssertEqual(store.snapshot.maxCardCount, 8)
        XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers, [])
        XCTAssertEqual(store.snapshot.displayLanguage, .english)
        XCTAssertEqual(store.snapshot.panelRetentionParameters.dockItemTolerance, 24)
        XCTAssertEqual(store.snapshot.panelRetentionParameters.panelEdgeTolerance, 6)
        XCTAssertEqual(store.snapshot.panelRetentionParameters.bridgeInset, 24)
    }

    func testDesktopWindowPeekDefaultsToEnabledAndUsesDedicatedKey() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: ProbeLogger())

        XCTAssertTrue(store.snapshot.isDesktopWindowPeekEnabled)
        XCTAssertEqual(
            SettingsKey.desktopWindowPeekEnabled.rawValue,
            "DockHoverPreview.desktopWindowPeekEnabled"
        )
    }

    func testDesktopWindowPeekInvalidTypeFallsBackToEnabled() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("false", forKey: SettingsKey.desktopWindowPeekEnabled.rawValue)

        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: ProbeLogger())

        XCTAssertTrue(store.snapshot.isDesktopWindowPeekEnabled)
    }

    func testUpdatingOtherDockSettingsPreservesDesktopWindowPeek() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: ProbeLogger())
        store.update { $0.isDesktopWindowPeekEnabled = false }

        store.updateDockWindowQuickLookSettings { $0.maxCardCount = 12 }

        XCTAssertFalse(store.snapshot.isDesktopWindowPeekEnabled)
        XCTAssertEqual(store.snapshot.maxCardCount, 12)
    }

    func testDesktopWindowPeekImmediateReadbackFailurePublishesEnabledFallback() {
        let logger = ProbeLogger()
        let persistence = RejectingDesktopPeekPersistence()
        let store = UserDefaultsSettingsStore(persistence: persistence, logger: logger)
        var observed: [DockHoverPreviewSettings] = []
        _ = store.addObserver { observed.append($0) }

        store.update { $0.isDesktopWindowPeekEnabled = false }

        XCTAssertTrue(store.snapshot.isDesktopWindowPeekEnabled)
        XCTAssertEqual(observed, [store.snapshot])
        XCTAssertTrue(logger.snapshot().contains {
            $0.contains("settings.persistFailed key=DockHoverPreview.desktopWindowPeekEnabled")
        })
    }

    func testDesktopWindowPeekWrongTypeReadbackPublishesEnabledFallback() {
        let logger = ProbeLogger()
        let persistence = WrongTypeDesktopPeekPersistence()
        let store = UserDefaultsSettingsStore(persistence: persistence, logger: logger)

        store.update { $0.isDesktopWindowPeekEnabled = false }

        XCTAssertTrue(store.snapshot.isDesktopWindowPeekEnabled)
        XCTAssertTrue(logger.snapshot().contains {
            $0.contains("settings.persistFailed key=DockHoverPreview.desktopWindowPeekEnabled")
        })
    }

    func testDesktopWindowPeekMismatchedReadbackPublishesEnabledFallback() {
        let logger = ProbeLogger()
        let persistence = InvertingDesktopPeekPersistence()
        let store = UserDefaultsSettingsStore(persistence: persistence, logger: logger)

        store.update { $0.isDesktopWindowPeekEnabled = false }

        XCTAssertTrue(store.snapshot.isDesktopWindowPeekEnabled)
        XCTAssertTrue(logger.snapshot().contains {
            $0.contains("settings.persistFailed key=DockHoverPreview.desktopWindowPeekEnabled")
        })
    }

    func testInvalidValuesFallBackWithoutPersistingDefaults() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("false", forKey: SettingsKey.isEnabled.rawValue)
        defaults.set("250", forKey: SettingsKey.hoverDelayMilliseconds.rawValue)
        defaults.set("loose", forKey: SettingsKey.panelRetentionMode.rawValue)
        defaults.set(11, forKey: SettingsKey.maxCardCount.rawValue)
        defaults.set(["com.valid.App", 42], forKey: SettingsKey.excludedAppBundleIdentifiers.rawValue)
        defaults.set("fr", forKey: SettingsKey.displayLanguage.rawValue)

        let logger = ProbeLogger()
        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: logger)

        XCTAssertTrue(store.snapshot.isDockHoverPreviewEnabled)
        XCTAssertEqual(store.snapshot.hoverDelayMilliseconds, 250)
        XCTAssertEqual(store.snapshot.panelRetentionMode, .standard)
        XCTAssertEqual(store.snapshot.maxCardCount, 8)
        XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers, [])
        XCTAssertEqual(store.snapshot.displayLanguage, .english)
        XCTAssertEqual(defaults.string(forKey: SettingsKey.isEnabled.rawValue), "false")
        XCTAssertEqual(defaults.string(forKey: SettingsKey.hoverDelayMilliseconds.rawValue), "250")
        XCTAssertEqual(defaults.string(forKey: SettingsKey.panelRetentionMode.rawValue), "loose")
        XCTAssertEqual(defaults.integer(forKey: SettingsKey.maxCardCount.rawValue), 11)
        XCTAssertEqual(defaults.string(forKey: SettingsKey.displayLanguage.rawValue), "fr")
        XCTAssertTrue(logger.snapshot().contains { $0.contains("settings.invalid") })
    }

    func testExcludedAppsAreSanitizedSortedAndCapped() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let valid = (0..<140).map { String(format: "com.example.app%03d", $0) }
        let invalid = [
            "",
            "   ",
            String(repeating: "x", count: 300),
            "bad id with spaces",
            "zhongwen.bundle.\u{4E2D}"
        ]
        defaults.set((valid + invalid + [" com.example.app001 "]).shuffled(), forKey: SettingsKey.excludedAppBundleIdentifiers.rawValue)

        let logger = ProbeLogger()
        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: logger)

        XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers.count, 128)
        XCTAssertTrue(store.snapshot.excludedAppBundleIdentifiers.contains("com.example.app000"))
        XCTAssertTrue(store.snapshot.excludedAppBundleIdentifiers.contains("com.example.app001"))
        XCTAssertFalse(store.snapshot.excludedAppBundleIdentifiers.contains("bad id with spaces"))
        XCTAssertFalse(store.snapshot.excludedAppBundleIdentifiers.contains("zhongwen.bundle.\u{4E2D}"))
        XCTAssertEqual(defaults.stringArray(forKey: SettingsKey.excludedAppBundleIdentifiers.rawValue)?.count, 146)
        XCTAssertTrue(logger.snapshot().contains { $0.contains("excludedAppsDropped=") })
    }

    func testWritingSettingsPersistsSortedValuesAndNotifiesObservers() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let logger = ProbeLogger()
        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: logger)
        var observed: [DockHoverPreviewSettings] = []
        let token = store.addObserver { observed.append($0) }

        store.update { settings in
            settings.isDockHoverPreviewEnabled = false
            settings.hoverDelayMilliseconds = 400
            settings.panelRetentionMode = .forgiving
            settings.maxCardCount = 12
            settings.excludedAppBundleIdentifiers = ["com.zeta.App", " com.alpha.App ", "bad id"]
            settings.displayLanguage = .simplifiedChinese
        }

        XCTAssertFalse(store.snapshot.isDockHoverPreviewEnabled)
        XCTAssertEqual(store.snapshot.hoverDelayMilliseconds, 400)
        XCTAssertEqual(store.snapshot.panelRetentionMode, .forgiving)
        XCTAssertEqual(store.snapshot.maxCardCount, 12)
        XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers, ["com.alpha.App", "com.zeta.App"])
        XCTAssertEqual(store.snapshot.displayLanguage, .simplifiedChinese)
        XCTAssertEqual(defaults.bool(forKey: SettingsKey.isEnabled.rawValue), false)
        XCTAssertEqual(defaults.integer(forKey: SettingsKey.hoverDelayMilliseconds.rawValue), 400)
        XCTAssertEqual(defaults.string(forKey: SettingsKey.panelRetentionMode.rawValue), "forgiving")
        XCTAssertEqual(defaults.integer(forKey: SettingsKey.maxCardCount.rawValue), 12)
        XCTAssertEqual(defaults.stringArray(forKey: SettingsKey.excludedAppBundleIdentifiers.rawValue), ["com.alpha.App", "com.zeta.App"])
        XCTAssertEqual(defaults.string(forKey: SettingsKey.displayLanguage.rawValue), "zh-Hans")
        XCTAssertEqual(observed, [store.snapshot])
        XCTAssertTrue(logger.snapshot().contains { $0.contains("settings.changed") })

        store.removeObserver(token)
        store.update { settings in
            settings.hoverDelayMilliseconds = 150
        }
        XCTAssertEqual(observed.count, 1)
    }

    func testAppSettingsStoreOnlyMutatesAppSettings() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: ProbeLogger())
        store.update { settings in
            settings.isDockHoverPreviewEnabled = false
            settings.hoverDelayMilliseconds = 400
            settings.panelRetentionMode = .forgiving
            settings.maxCardCount = 12
            settings.excludedAppBundleIdentifiers = ["com.example.Editor"]
            settings.displayLanguage = .english
        }
        let before = store.snapshot

        let appStore: AppSettingsStore = store
        appStore.updateAppSettings { settings in
            settings.displayLanguage = .simplifiedChinese
        }

        XCTAssertEqual(appStore.appSettingsSnapshot.displayLanguage, .simplifiedChinese)
        XCTAssertEqual(store.snapshot.displayLanguage, .simplifiedChinese)
        XCTAssertEqual(store.snapshot.isDockHoverPreviewEnabled, before.isDockHoverPreviewEnabled)
        XCTAssertEqual(store.snapshot.hoverDelayMilliseconds, before.hoverDelayMilliseconds)
        XCTAssertEqual(store.snapshot.panelRetentionMode, before.panelRetentionMode)
        XCTAssertEqual(store.snapshot.maxCardCount, before.maxCardCount)
        XCTAssertEqual(store.snapshot.excludedAppBundleIdentifiers, before.excludedAppBundleIdentifiers)
    }

    func testDockWindowQuickLookSettingsStorePreservesDisplayLanguage() {
        let (defaults, suiteName) = makeTemporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsSettingsStore(userDefaults: defaults, logger: ProbeLogger())
        store.update { settings in
            settings.displayLanguage = .simplifiedChinese
        }

        let dockStore: DockWindowQuickLookSettingsStore = store
        dockStore.updateDockWindowQuickLookSettings { settings in
            settings.isDockHoverPreviewEnabled = false
            settings.hoverDelayMilliseconds = 400
            settings.panelRetentionMode = .forgiving
            settings.maxCardCount = 12
            settings.excludedAppBundleIdentifiers = ["com.example.Editor"]
        }

        XCTAssertEqual(store.snapshot.displayLanguage, .simplifiedChinese)
        XCTAssertFalse(dockStore.dockWindowQuickLookSettingsSnapshot.isDockHoverPreviewEnabled)
        XCTAssertEqual(dockStore.dockWindowQuickLookSettingsSnapshot.hoverDelayMilliseconds, 400)
        XCTAssertEqual(dockStore.dockWindowQuickLookSettingsSnapshot.panelRetentionMode, .forgiving)
        XCTAssertEqual(dockStore.dockWindowQuickLookSettingsSnapshot.maxCardCount, 12)
        XCTAssertEqual(
            dockStore.dockWindowQuickLookSettingsSnapshot.excludedAppBundleIdentifiers,
            ["com.example.Editor"]
        )
        XCTAssertEqual(dockStore.dockWindowQuickLookSettingsSnapshot.displayLanguage, .simplifiedChinese)

    }

    private func makeTemporaryDefaults() -> (UserDefaults, String) {
        let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

}

private final class RejectingDesktopPeekPersistence: SettingsKeyValueStoring {
    private var values: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        guard defaultName != SettingsKey.desktopWindowPeekEnabled.rawValue else { return }
        values[defaultName] = value
    }
}

private final class WrongTypeDesktopPeekPersistence: SettingsKeyValueStoring {
    private var values: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = defaultName == SettingsKey.desktopWindowPeekEnabled.rawValue
            ? NSNumber(value: 0)
            : value
    }
}

private final class InvertingDesktopPeekPersistence: SettingsKeyValueStoring {
    private var values: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        if defaultName == SettingsKey.desktopWindowPeekEnabled.rawValue,
           let requested = value as? Bool {
            values[defaultName] = !requested
        } else {
            values[defaultName] = value
        }
    }
}
