import Foundation

@MainActor
protocol DockHoverPreviewSettingsStore: AnyObject {
    var snapshot: DockHoverPreviewSettings { get }

    @discardableResult
    func addObserver(_ observer: @MainActor @escaping (DockHoverPreviewSettings) -> Void) -> UUID
    func removeObserver(_ token: UUID)
    func update(transform: (inout DockHoverPreviewSettings) -> Void)
}

@MainActor
final class UserDefaultsSettingsStore: DockHoverPreviewSettingsStore {
    private typealias Observer = @MainActor (DockHoverPreviewSettings) -> Void

    private let userDefaults: UserDefaults
    private let logger: ProbeLogger
    private var observers: [UUID: Observer] = [:]

    private(set) var snapshot: DockHoverPreviewSettings

    init(userDefaults: UserDefaults = .standard, logger: ProbeLogger) {
        self.userDefaults = userDefaults
        self.logger = logger
        self.snapshot = Self.readSnapshot(from: userDefaults, logger: logger)
    }

    @discardableResult
    func addObserver(_ observer: @MainActor @escaping (DockHoverPreviewSettings) -> Void) -> UUID {
        let token = UUID()
        observers[token] = observer
        return token
    }

    func removeObserver(_ token: UUID) {
        observers.removeValue(forKey: token)
    }

    func update(transform: (inout DockHoverPreviewSettings) -> Void) {
        var next = snapshot
        transform(&next)
        next = Self.sanitized(next, logger: logger)

        persist(next)
        snapshot = next
        logger.info(Self.changedLogLine(for: next))

        let currentObservers = Array(observers.values)
        currentObservers.forEach { $0(next) }
    }

    private func persist(_ settings: DockHoverPreviewSettings) {
        userDefaults.set(settings.isDockHoverPreviewEnabled, forKey: SettingsKey.isEnabled.rawValue)
        userDefaults.set(settings.hoverDelayMilliseconds, forKey: SettingsKey.hoverDelayMilliseconds.rawValue)
        userDefaults.set(settings.panelRetentionMode.rawValue, forKey: SettingsKey.panelRetentionMode.rawValue)
        userDefaults.set(settings.maxCardCount, forKey: SettingsKey.maxCardCount.rawValue)
        userDefaults.set(Self.sortedExcludedApps(from: settings), forKey: SettingsKey.excludedAppBundleIdentifiers.rawValue)
        userDefaults.set(settings.displayLanguage.rawValue, forKey: SettingsKey.displayLanguage.rawValue)
    }

    private static func readSnapshot(from userDefaults: UserDefaults, logger: ProbeLogger) -> DockHoverPreviewSettings {
        var settings = DockHoverPreviewSettings.defaults

        if let value = readBool(for: .isEnabled, from: userDefaults, logger: logger) {
            settings.isDockHoverPreviewEnabled = value
        }

        if let value = readInt(
            for: .hoverDelayMilliseconds,
            from: userDefaults,
            validValues: DockHoverPreviewSettings.validHoverDelayMilliseconds,
            defaultValue: DockHoverPreviewSettings.defaults.hoverDelayMilliseconds,
            logger: logger
        ) {
            settings.hoverDelayMilliseconds = value
        }

        if let value = readEnum(
            for: .panelRetentionMode,
            from: userDefaults,
            defaultValue: DockHoverPreviewSettings.defaults.panelRetentionMode,
            logger: logger,
            type: PanelRetentionMode.self
        ) {
            settings.panelRetentionMode = value
        }

        if let value = readInt(
            for: .maxCardCount,
            from: userDefaults,
            validValues: DockHoverPreviewSettings.validMaxCardCounts,
            defaultValue: DockHoverPreviewSettings.defaults.maxCardCount,
            logger: logger
        ) {
            settings.maxCardCount = value
        }

        if let values = readExcludedApps(from: userDefaults, logger: logger) {
            settings.excludedAppBundleIdentifiers = values
        }

        if let value = readEnum(
            for: .displayLanguage,
            from: userDefaults,
            defaultValue: DockHoverPreviewSettings.defaults.displayLanguage,
            logger: logger,
            type: DisplayLanguage.self
        ) {
            settings.displayLanguage = value
        }

        return settings
    }

    private static func sanitized(
        _ settings: DockHoverPreviewSettings,
        logger: ProbeLogger
    ) -> DockHoverPreviewSettings {
        var sanitized = settings

        if !DockHoverPreviewSettings.validHoverDelayMilliseconds.contains(sanitized.hoverDelayMilliseconds) {
            logger.warning(
                "settings.invalid key=\(SettingsKey.hoverDelayMilliseconds.rawValue) value=\(sanitized.hoverDelayMilliseconds)"
            )
            sanitized.hoverDelayMilliseconds = DockHoverPreviewSettings.defaults.hoverDelayMilliseconds
        }

        if !DockHoverPreviewSettings.validMaxCardCounts.contains(sanitized.maxCardCount) {
            logger.warning("settings.invalid key=\(SettingsKey.maxCardCount.rawValue) value=\(sanitized.maxCardCount)")
            sanitized.maxCardCount = DockHoverPreviewSettings.defaults.maxCardCount
        }

        sanitized.excludedAppBundleIdentifiers = sanitizedExcludedApps(
            Array(sanitized.excludedAppBundleIdentifiers),
            logger: logger
        )

        return sanitized
    }

    private static func readBool(
        for key: SettingsKey,
        from userDefaults: UserDefaults,
        logger: ProbeLogger
    ) -> Bool? {
        guard let object = userDefaults.object(forKey: key.rawValue) else {
            return nil
        }
        guard let number = object as? NSNumber, isBooleanNumber(number) else {
            logger.warning("settings.invalid key=\(key.rawValue) valueType=\(typeDescription(of: object))")
            return DockHoverPreviewSettings.defaults.isDockHoverPreviewEnabled
        }
        return number.boolValue
    }

    private static func readInt(
        for key: SettingsKey,
        from userDefaults: UserDefaults,
        validValues: Set<Int>,
        defaultValue: Int,
        logger: ProbeLogger
    ) -> Int? {
        guard let object = userDefaults.object(forKey: key.rawValue) else {
            return nil
        }
        guard let number = object as? NSNumber, !isBooleanNumber(number), isWholeNumber(number) else {
            logger.warning("settings.invalid key=\(key.rawValue) valueType=\(typeDescription(of: object))")
            return defaultValue
        }

        let value = number.intValue
        guard validValues.contains(value) else {
            logger.warning("settings.invalid key=\(key.rawValue) value=\(value)")
            return defaultValue
        }
        return value
    }

    private static func readEnum<Value>(
        for key: SettingsKey,
        from userDefaults: UserDefaults,
        defaultValue: Value,
        logger: ProbeLogger,
        type: Value.Type
    ) -> Value? where Value: RawRepresentable, Value.RawValue == String {
        guard let object = userDefaults.object(forKey: key.rawValue) else {
            return nil
        }
        guard let rawValue = object as? String else {
            logger.warning("settings.invalid key=\(key.rawValue) valueType=\(typeDescription(of: object))")
            return defaultValue
        }
        guard let value = Value(rawValue: rawValue) else {
            logger.warning("settings.invalid key=\(key.rawValue) value=\(rawValue)")
            return defaultValue
        }
        return value
    }

    private static func readExcludedApps(from userDefaults: UserDefaults, logger: ProbeLogger) -> Set<String>? {
        let key = SettingsKey.excludedAppBundleIdentifiers
        guard let object = userDefaults.object(forKey: key.rawValue) else {
            return nil
        }
        guard let values = object as? [String] else {
            logger.warning("settings.invalid key=\(key.rawValue) valueType=\(typeDescription(of: object))")
            return DockHoverPreviewSettings.defaults.excludedAppBundleIdentifiers
        }
        return sanitizedExcludedApps(values, logger: logger)
    }

    private static func sanitizedExcludedApps(_ values: [String], logger: ProbeLogger) -> Set<String> {
        var valid: Set<String> = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidBundleIdentifier(trimmed) else {
                continue
            }
            valid.insert(trimmed)
        }

        let sorted = valid.sorted()
        let capped = Array(sorted.prefix(128))
        let droppedCount = values.count - capped.count

        if droppedCount > 0 {
            logger.warning(
                "settings.invalid key=\(SettingsKey.excludedAppBundleIdentifiers.rawValue) excludedAppsDropped=\(droppedCount)"
            )
        }

        return Set(capped)
    }

    private static func sortedExcludedApps(from settings: DockHoverPreviewSettings) -> [String] {
        settings.excludedAppBundleIdentifiers.sorted()
    }

    private static func changedLogLine(for settings: DockHoverPreviewSettings) -> String {
        "settings.changed enabled=\(settings.isDockHoverPreviewEnabled) delayMS=\(settings.hoverDelayMilliseconds) " +
        "retention=\(settings.panelRetentionMode.rawValue) maxCards=\(settings.maxCardCount) " +
        "excludedCount=\(settings.excludedAppBundleIdentifiers.count) language=\(settings.displayLanguage.rawValue)"
    }

    private static func isValidBundleIdentifier(_ value: String) -> Bool {
        guard (1...256).contains(value.utf8.count) else {
            return false
        }

        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 45, 46, 48...57, 65...90, 95, 97...122:
                true
            default:
                false
            }
        }
    }

    private static func isBooleanNumber(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func isWholeNumber(_ number: NSNumber) -> Bool {
        let value = number.doubleValue
        return value.isFinite && value.rounded(.towardZero) == value
    }

    private static func typeDescription(of object: Any) -> String {
        String(describing: Swift.type(of: object))
    }
}
