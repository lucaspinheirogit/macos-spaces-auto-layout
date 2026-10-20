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
        let folder = Bundle.main.bundleIdentifier ?? "macos-spaces-auto-layout"
        return SetupFileStorage(fileURL: support.appendingPathComponent(folder).appendingPathComponent("setups.json"))
    }

    #if DEBUG
    /// A throwaway file for SwiftUI previews, so they never touch the real data.
    static var preview: SetupFileStorage {
        SetupFileStorage(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("setups-preview-\(UUID().uuidString).json"))
    }
    #endif

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
}
