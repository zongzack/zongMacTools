import Foundation

protocol SettingsKeyValueStoring: AnyObject {
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: SettingsKeyValueStoring {}

struct AppSettingsSnapshot: Equatable, Sendable {
    var displayLanguage: DisplayLanguage

    init(displayLanguage: DisplayLanguage) {
        self.displayLanguage = displayLanguage
    }

    init(settings: DockHoverPreviewSettings) {
        self.init(displayLanguage: settings.displayLanguage)
    }
}

struct DockWindowQuickLookSettingsSnapshot: Equatable, Sendable {
    var isDockHoverPreviewEnabled: Bool
    var isDesktopWindowPeekEnabled: Bool
    var hoverDelayMilliseconds: Int
    var panelRetentionMode: PanelRetentionMode
    var maxCardCount: Int
    var excludedAppBundleIdentifiers: Set<String>
    let displayLanguage: DisplayLanguage

    init(
        isDockHoverPreviewEnabled: Bool,
        isDesktopWindowPeekEnabled: Bool,
        hoverDelayMilliseconds: Int,
        panelRetentionMode: PanelRetentionMode,
        maxCardCount: Int,
        excludedAppBundleIdentifiers: Set<String>,
        displayLanguage: DisplayLanguage
    ) {
        self.isDockHoverPreviewEnabled = isDockHoverPreviewEnabled
        self.isDesktopWindowPeekEnabled = isDesktopWindowPeekEnabled
        self.hoverDelayMilliseconds = hoverDelayMilliseconds
        self.panelRetentionMode = panelRetentionMode
        self.maxCardCount = maxCardCount
        self.excludedAppBundleIdentifiers = excludedAppBundleIdentifiers
        self.displayLanguage = displayLanguage
    }

    init(settings: DockHoverPreviewSettings) {
        self.init(
            isDockHoverPreviewEnabled: settings.isDockHoverPreviewEnabled,
            isDesktopWindowPeekEnabled: settings.isDesktopWindowPeekEnabled,
            hoverDelayMilliseconds: settings.hoverDelayMilliseconds,
            panelRetentionMode: settings.panelRetentionMode,
            maxCardCount: settings.maxCardCount,
            excludedAppBundleIdentifiers: settings.excludedAppBundleIdentifiers,
            displayLanguage: settings.displayLanguage
        )
    }

    var panelRetentionParameters: PanelRetentionParameters {
        panelRetentionMode.parameters
    }
}

@MainActor
protocol AppSettingsStore: AnyObject {
    var appSettingsSnapshot: AppSettingsSnapshot { get }

    @discardableResult
    func addAppSettingsObserver(_ observer: @MainActor @escaping (AppSettingsSnapshot) -> Void) -> UUID
    func removeObserver(_ token: UUID)
    func updateAppSettings(transform: (inout AppSettingsSnapshot) -> Void)
}

@MainActor
protocol DockWindowQuickLookSettingsStore: AnyObject {
    var dockWindowQuickLookSettingsSnapshot: DockWindowQuickLookSettingsSnapshot { get }

    @discardableResult
    func addDockWindowQuickLookSettingsObserver(
        _ observer: @MainActor @escaping (DockWindowQuickLookSettingsSnapshot) -> Void
    ) -> UUID
    func removeObserver(_ token: UUID)
    func updateDockWindowQuickLookSettings(transform: (inout DockWindowQuickLookSettingsSnapshot) -> Void)
}

@MainActor
protocol DockHoverPreviewSettingsStore: AppSettingsStore, DockWindowQuickLookSettingsStore {
    var snapshot: DockHoverPreviewSettings { get }

    @discardableResult
    func addObserver(_ observer: @MainActor @escaping (DockHoverPreviewSettings) -> Void) -> UUID
    func removeObserver(_ token: UUID)
    func update(transform: (inout DockHoverPreviewSettings) -> Void)
}

extension DockHoverPreviewSettingsStore {
    var appSettingsSnapshot: AppSettingsSnapshot {
        AppSettingsSnapshot(settings: snapshot)
    }

    @discardableResult
    func addAppSettingsObserver(_ observer: @MainActor @escaping (AppSettingsSnapshot) -> Void) -> UUID {
        let fullObserver: @MainActor (DockHoverPreviewSettings) -> Void = { settings in
            observer(AppSettingsSnapshot(settings: settings))
        }
        return addObserver(fullObserver)
    }

    func updateAppSettings(transform: (inout AppSettingsSnapshot) -> Void) {
        var next = appSettingsSnapshot
        transform(&next)

        update { settings in
            settings.displayLanguage = next.displayLanguage
        }
    }

    var dockWindowQuickLookSettingsSnapshot: DockWindowQuickLookSettingsSnapshot {
        DockWindowQuickLookSettingsSnapshot(settings: snapshot)
    }

    @discardableResult
    func addDockWindowQuickLookSettingsObserver(
        _ observer: @MainActor @escaping (DockWindowQuickLookSettingsSnapshot) -> Void
    ) -> UUID {
        let fullObserver: @MainActor (DockHoverPreviewSettings) -> Void = { settings in
            observer(DockWindowQuickLookSettingsSnapshot(settings: settings))
        }
        return addObserver(fullObserver)
    }

    func updateDockWindowQuickLookSettings(transform: (inout DockWindowQuickLookSettingsSnapshot) -> Void) {
        var next = dockWindowQuickLookSettingsSnapshot
        transform(&next)

        update { settings in
            settings.isDockHoverPreviewEnabled = next.isDockHoverPreviewEnabled
            settings.isDesktopWindowPeekEnabled = next.isDesktopWindowPeekEnabled
            settings.hoverDelayMilliseconds = next.hoverDelayMilliseconds
            settings.panelRetentionMode = next.panelRetentionMode
            settings.maxCardCount = next.maxCardCount
            settings.excludedAppBundleIdentifiers = next.excludedAppBundleIdentifiers
        }
    }
}

@MainActor
final class UserDefaultsSettingsStore: DockHoverPreviewSettingsStore {
    private typealias Observer = @MainActor (DockHoverPreviewSettings) -> Void

    private let persistence: any SettingsKeyValueStoring
    private let logger: ProbeLogger
    private var observers: [UUID: Observer] = [:]

    private(set) var snapshot: DockHoverPreviewSettings

    convenience init(userDefaults: UserDefaults = .standard, logger: ProbeLogger) {
        self.init(persistence: userDefaults, logger: logger)
    }

    init(persistence: any SettingsKeyValueStoring, logger: ProbeLogger) {
        self.persistence = persistence
        self.logger = logger
        self.snapshot = Self.readSnapshot(from: persistence, logger: logger)
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

        let persisted = persist(next)
        snapshot = persisted
        logger.info(Self.changedLogLine(for: persisted))

        let currentObservers = Array(observers.values)
        currentObservers.forEach { $0(persisted) }
    }

    private func persist(_ settings: DockHoverPreviewSettings) -> DockHoverPreviewSettings {
        persistence.set(settings.isDockHoverPreviewEnabled, forKey: SettingsKey.isEnabled.rawValue)
        persistence.set(settings.isDesktopWindowPeekEnabled, forKey: SettingsKey.desktopWindowPeekEnabled.rawValue)
        persistence.set(settings.hoverDelayMilliseconds, forKey: SettingsKey.hoverDelayMilliseconds.rawValue)
        persistence.set(settings.panelRetentionMode.rawValue, forKey: SettingsKey.panelRetentionMode.rawValue)
        persistence.set(settings.maxCardCount, forKey: SettingsKey.maxCardCount.rawValue)
        persistence.set(Self.sortedExcludedApps(from: settings), forKey: SettingsKey.excludedAppBundleIdentifiers.rawValue)
        persistence.set(settings.displayLanguage.rawValue, forKey: SettingsKey.displayLanguage.rawValue)

        var persisted = settings
        guard let object = persistence.object(forKey: SettingsKey.desktopWindowPeekEnabled.rawValue),
              let number = object as? NSNumber,
              Self.isBooleanNumber(number),
              number.boolValue == settings.isDesktopWindowPeekEnabled
        else {
            logger.warning("settings.persistFailed key=\(SettingsKey.desktopWindowPeekEnabled.rawValue)")
            persisted.isDesktopWindowPeekEnabled = true
            return persisted
        }
        return persisted
    }

    private static func readSnapshot(
        from persistence: any SettingsKeyValueStoring,
        logger: ProbeLogger
    ) -> DockHoverPreviewSettings {
        var settings = DockHoverPreviewSettings.defaults

        if let value = readBool(for: .isEnabled, from: persistence, logger: logger) {
            settings.isDockHoverPreviewEnabled = value
        }

        if let value = readBool(for: .desktopWindowPeekEnabled, from: persistence, logger: logger) {
            settings.isDesktopWindowPeekEnabled = value
        }

        if let value = readInt(
            for: .hoverDelayMilliseconds,
            from: persistence,
            validValues: DockHoverPreviewSettings.validHoverDelayMilliseconds,
            defaultValue: DockHoverPreviewSettings.defaults.hoverDelayMilliseconds,
            logger: logger
        ) {
            settings.hoverDelayMilliseconds = value
        }

        if let value = readEnum(
            for: .panelRetentionMode,
            from: persistence,
            defaultValue: DockHoverPreviewSettings.defaults.panelRetentionMode,
            logger: logger,
            type: PanelRetentionMode.self
        ) {
            settings.panelRetentionMode = value
        }

        if let value = readInt(
            for: .maxCardCount,
            from: persistence,
            validValues: DockHoverPreviewSettings.validMaxCardCounts,
            defaultValue: DockHoverPreviewSettings.defaults.maxCardCount,
            logger: logger
        ) {
            settings.maxCardCount = value
        }

        if let values = readExcludedApps(from: persistence, logger: logger) {
            settings.excludedAppBundleIdentifiers = values
        }

        if let value = readEnum(
            for: .displayLanguage,
            from: persistence,
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
        from persistence: any SettingsKeyValueStoring,
        logger: ProbeLogger
    ) -> Bool? {
        guard let object = persistence.object(forKey: key.rawValue) else {
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
        from persistence: any SettingsKeyValueStoring,
        validValues: Set<Int>,
        defaultValue: Int,
        logger: ProbeLogger
    ) -> Int? {
        guard let object = persistence.object(forKey: key.rawValue) else {
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
        from persistence: any SettingsKeyValueStoring,
        defaultValue: Value,
        logger: ProbeLogger,
        type: Value.Type
    ) -> Value? where Value: RawRepresentable, Value.RawValue == String {
        guard let object = persistence.object(forKey: key.rawValue) else {
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

    private static func readExcludedApps(
        from persistence: any SettingsKeyValueStoring,
        logger: ProbeLogger
    ) -> Set<String>? {
        let key = SettingsKey.excludedAppBundleIdentifiers
        guard let object = persistence.object(forKey: key.rawValue) else {
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
            guard let bundleIdentifier = BundleIdentifierValidator.sanitized(value) else {
                continue
            }
            valid.insert(bundleIdentifier)
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
        "settings.changed enabled=\(settings.isDockHoverPreviewEnabled) desktopPeek=\(settings.isDesktopWindowPeekEnabled) " +
        "delayMS=\(settings.hoverDelayMilliseconds) " +
        "retention=\(settings.panelRetentionMode.rawValue) maxCards=\(settings.maxCardCount) " +
        "excludedCount=\(settings.excludedAppBundleIdentifiers.count) language=\(settings.displayLanguage.rawValue)"
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
