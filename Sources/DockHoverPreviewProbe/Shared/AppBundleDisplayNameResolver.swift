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
