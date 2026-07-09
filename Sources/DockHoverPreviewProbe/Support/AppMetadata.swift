import Foundation

enum AppSigningStatus: Equatable, Sendable {
    case adHoc
    case signed(identity: String)
    case unsigned
    case unknown(String)

    var displayString: String {
        switch self {
        case .adHoc:
            "Ad-hoc signature"
        case .signed(let identity):
            "Signed: \(identity)"
        case .unsigned:
            "Unsigned"
        case .unknown(let reason):
            "Unknown: \(reason)"
        }
    }

    static func parse(codesignOutput: String) -> AppSigningStatus {
        let lines = codesignOutput
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        if lines.contains(where: { $0.localizedCaseInsensitiveContains("Signature=adhoc") }) {
            return .adHoc
        }
        if codesignOutput.localizedCaseInsensitiveContains("not signed") {
            return .unsigned
        }
        if let authority = lines.first(where: { $0.hasPrefix("Authority=") }) {
            let identity = String(authority.dropFirst("Authority=".count))
            if !identity.isEmpty {
                return .signed(identity: identity)
            }
        }
        return .unknown("unrecognized codesign output")
    }
}

struct AppMetadata: Equatable, Sendable {
    let appName: String
    let version: String
    let buildNumber: String
    let bundleIdentifier: String
    let bundlePath: String
    let executableName: String
    let signingStatus: AppSigningStatus

    init(
        appName: String,
        version: String,
        buildNumber: String,
        bundleIdentifier: String,
        bundlePath: String,
        executableName: String,
        signingStatus: AppSigningStatus
    ) {
        self.appName = appName
        self.version = version
        self.buildNumber = buildNumber
        self.bundleIdentifier = bundleIdentifier
        self.bundlePath = bundlePath
        self.executableName = executableName
        self.signingStatus = signingStatus
    }

    init(
        infoDictionary: [String: Any],
        bundleURL: URL,
        signingStatus: AppSigningStatus
    ) {
        self.appName = Self.nonEmptyString(infoDictionary["CFBundleDisplayName"])
            ?? Self.nonEmptyString(infoDictionary["CFBundleName"])
            ?? bundleURL.deletingPathExtension().lastPathComponent
        self.version = Self.nonEmptyString(infoDictionary["CFBundleShortVersionString"]) ?? "0.0.0"
        self.buildNumber = Self.nonEmptyString(infoDictionary["CFBundleVersion"]) ?? "0"
        self.bundleIdentifier = Self.nonEmptyString(infoDictionary["CFBundleIdentifier"]) ?? "unknown.bundle"
        self.bundlePath = bundleURL.path
        self.executableName = Self.nonEmptyString(infoDictionary["CFBundleExecutable"]) ?? "unknown"
        self.signingStatus = signingStatus
    }

    init(bundle: Bundle = .main, signingStatus: AppSigningStatus = .unknown("not checked")) {
        self.init(
            infoDictionary: bundle.infoDictionary ?? [:],
            bundleURL: bundle.bundleURL,
            signingStatus: signingStatus
        )
    }

    var versionDisplayString: String {
        "Version \(version) (\(buildNumber))"
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else {
            return nil
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
