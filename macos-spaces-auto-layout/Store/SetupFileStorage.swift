//
//  SetupFileStorage.swift
//  macos-spaces-auto-layout
//

import Foundation

/// Reads and writes setups as JSON at a fixed file URL.
nonisolated struct SetupFileStorage: Sendable {
    let fileURL: URL

    /// `~/Library/Application Support/<bundle id>/setups.json`
    static var `default`: SetupFileStorage {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return SetupFileStorage(fileURL: support
            .appendingPathComponent(AppIdentity.bundleIdentifier)
            .appendingPathComponent("setups.json"))
    }

    /// A throwaway file for SwiftUI previews, so they never touch the real data.
    static var preview: SetupFileStorage {
        SetupFileStorage(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("setups-preview-\(UUID().uuidString).json"))
    }

    /// Returns nil when no file has been saved yet.
    func load() throws -> [Setup]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([Setup].self, from: data)
    }

    func save(_ setups: [Setup]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(setups)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    /// Renames an unreadable file to `setups.corrupt-<timestamp>.json` so the next save can't overwrite it.
    /// Returns the new location.
    func moveAsideUnreadableFile(now: Date = .now) throws -> URL {
        let timestamp = now.ISO8601Format(.iso8601.year().month().day().dateSeparator(.dash)
            .time(includingFractionalSeconds: false).timeSeparator(.omitted).timeZone(separator: .omitted))
        let name = fileURL.deletingPathExtension().lastPathComponent
        let backupURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("\(name).corrupt-\(timestamp).\(fileURL.pathExtension)")
        try FileManager.default.moveItem(at: fileURL, to: backupURL)
        return backupURL
    }
}
