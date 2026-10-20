import Foundation

/// Reads and writes `setups.json` (a `DeskSetupFile`) at a fixed file URL.
nonisolated struct DeskSetupFileStorage: Sendable {
    let fileURL: URL

    /// `~/Library/Application Support/<bundle id>/setups.json`
    static var `default`: DeskSetupFileStorage {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return DeskSetupFileStorage(
            fileURL:
                support
                .appendingPathComponent(AppIdentity.bundleIdentifier)
                .appendingPathComponent("setups.json"))
    }

    /// A throwaway file for SwiftUI previews and the test host, so they never touch the real data.
    static var temporary: DeskSetupFileStorage {
        DeskSetupFileStorage(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("setups-temporary-\(UUID().uuidString).json"))
    }

    /// Returns nil when no file has been saved yet.
    /// Throws `DecodingError` when the file's contents are unreadable, and any other error
    /// (a directory at the path, no permission) when the file itself can't be read.
    func load() throws -> DeskSetupFile? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try DeskSetupFile.decode(from: data)
    }

    /// Writes the setups atomically as the current schema version.
    func save(_ setups: [DeskSetup]) throws {
        let data = try DeskSetupFile(setups: setups).encoded()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    /// Renames an unreadable file to `setups.corrupt-<timestamp>.json` so the next save can't overwrite it.
    /// If that name is taken, adds `-2`, `-3`, … before the extension. Returns the new location.
    func moveAsideUnreadableFile(now: Date = .now) throws -> URL {
        let timestamp = now.ISO8601Format(
            .iso8601.year().month().day().dateSeparator(.dash)
                .time(includingFractionalSeconds: false).timeSeparator(.omitted).timeZone(separator: .omitted))
        let name = fileURL.deletingPathExtension().lastPathComponent
        let folder = fileURL.deletingLastPathComponent()
        var backupURL = folder.appendingPathComponent("\(name).corrupt-\(timestamp).\(fileURL.pathExtension)")
        var suffix = 2
        while FileManager.default.fileExists(atPath: backupURL.path) {
            backupURL = folder.appendingPathComponent("\(name).corrupt-\(timestamp)-\(suffix).\(fileURL.pathExtension)")
            suffix += 1
        }
        try FileManager.default.moveItem(at: fileURL, to: backupURL)
        return backupURL
    }
}
