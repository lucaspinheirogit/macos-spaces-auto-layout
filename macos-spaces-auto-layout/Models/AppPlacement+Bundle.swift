//
//  AppPlacement+Bundle.swift
//  macos-spaces-auto-layout
//

import Foundation

extension AppPlacement {
    /// Reads the name and bundle identifier from an `.app` bundle's Info.plist.
    /// Returns nil when the bundle has no `CFBundleIdentifier`.
    nonisolated init?(appURL: URL) {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard
            let data = try? Data(contentsOf: plistURL),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let bundleId = plist["CFBundleIdentifier"] as? String
        else { return nil }

        let name = plist["CFBundleDisplayName"] as? String
            ?? plist["CFBundleName"] as? String
            ?? appURL.deletingPathExtension().lastPathComponent
        self.init(bundleId: bundleId, name: name)
    }
}
