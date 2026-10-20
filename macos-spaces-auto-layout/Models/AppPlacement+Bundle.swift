import Foundation

extension AppPlacement {
    /// Reads the name and bundle identifier from an `.app` bundle.
    /// The name prefers the localized `CFBundleDisplayName`, then `CFBundleName`, then the file name.
    /// Returns nil when the bundle has no `CFBundleIdentifier`.
    nonisolated init?(appURL: URL) {
        guard let bundle = Bundle(url: appURL), let bundleId = bundle.bundleIdentifier else { return nil }

        func value(_ key: String) -> String? {
            bundle.localizedInfoDictionary?[key] as? String ?? bundle.infoDictionary?[key] as? String
        }
        let name =
            value("CFBundleDisplayName")
            ?? value("CFBundleName")
            ?? appURL.deletingPathExtension().lastPathComponent
        self.init(bundleId: bundleId, name: name)
    }
}
