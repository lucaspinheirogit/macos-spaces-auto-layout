import Foundation

/// The contents of `setups.json`: `{ "schemaVersion": 1, "setups": [...] }`.
///
/// Version 0 is the legacy format, a bare array of setups. It's still read, and saved back as the current version.
nonisolated struct DeskSetupFile: Codable, Equatable, Sendable {
    /// The version this build writes. Bump it, with a migration and a fixture, when the format changes incompatibly.
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var setups: [DeskSetup]

    init(schemaVersion: Int = currentSchemaVersion, setups: [DeskSetup]) {
        self.schemaVersion = schemaVersion
        self.setups = setups
    }

    /// Thrown when a file from a newer app version can't be decoded by this one.
    struct NewerSchemaVersionError: Error, Equatable {
        let schemaVersion: Int
    }

    private struct SchemaVersionProbe: Decodable {
        var schemaVersion: Int
    }

    /// Decodes either format. Unknown keys are ignored.
    /// Throws `DecodingError` when the data is neither format, and `NewerSchemaVersionError`
    /// when a newer file doesn't decode with this version's types.
    static func decode(from data: Data) throws -> DeskSetupFile {
        let decoder = JSONDecoder()
        guard let probe = try? decoder.decode(SchemaVersionProbe.self, from: data) else {
            return DeskSetupFile(schemaVersion: 0, setups: try decoder.decode([DeskSetup].self, from: data))
        }
        guard probe.schemaVersion > currentSchemaVersion else {
            return try decoder.decode(DeskSetupFile.self, from: data)
        }
        do {
            return try decoder.decode(DeskSetupFile.self, from: data)
        } catch {
            throw NewerSchemaVersionError(schemaVersion: probe.schemaVersion)
        }
    }

    /// Pretty-printed with sorted keys, so the file diffs cleanly.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Gives a fresh id to every setup, display and app whose id was already used earlier in the file,
    /// so lookups by id and SwiftUI lists stay correct. Returns how many ids were replaced.
    mutating func repairDuplicateIds() -> Int {
        var seen = Set<UUID>()
        var repaired = 0
        func uniqueId(_ id: UUID) -> UUID {
            if seen.insert(id).inserted { return id }
            repaired += 1
            let fresh = UUID()
            seen.insert(fresh)
            return fresh
        }
        for setupIndex in setups.indices {
            setups[setupIndex].id = uniqueId(setups[setupIndex].id)
            for displayIndex in setups[setupIndex].displays.indices {
                var display = setups[setupIndex].displays[displayIndex]
                display.id = uniqueId(display.id)
                for appIndex in display.apps.indices {
                    display.apps[appIndex].id = uniqueId(display.apps[appIndex].id)
                }
                setups[setupIndex].displays[displayIndex] = display
            }
        }
        return repaired
    }
}
