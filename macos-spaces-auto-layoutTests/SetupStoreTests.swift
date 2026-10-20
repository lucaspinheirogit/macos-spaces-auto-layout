import Foundation
import Testing

@testable import macos_spaces_auto_layout

@MainActor
final class SetupStoreTests {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    private var storage: SetupFileStorage { SetupFileStorage(fileURL: directory.appendingPathComponent("setups.json")) }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func seedsDefaultsWhenNoFileExists() {
        let store = SetupStore(storage: storage)
        #expect(store.setups == Setup.defaults)
    }

    @Test func updatePersistsAcrossStores() throws {
        let store = SetupStore(storage: storage)
        var setup = store.setups[1]
        setup.name = "Home desk"
        setup.displays[0].apps.append(AppPlacement(bundleId: "com.apple.Safari", name: "Safari"))
        store.update(setup)

        #expect(store.setups[1] == setup)
        let reloaded = SetupStore(storage: storage)
        #expect(reloaded.setups == store.setups)
        #expect(try storage.load() == store.setups)
    }

    @Test func ignoresUpdatesForUnknownIds() {
        let store = SetupStore(storage: storage)
        store.update(Setup(name: "Stranger", displays: []))
        #expect(store.setups == Setup.defaults)
        #expect(!FileManager.default.fileExists(atPath: storage.fileURL.path))
    }

    @Test func fallsBackToDefaultsAndKeepsCorruptFile() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: storage.fileURL)

        let store = SetupStore(storage: storage)
        #expect(store.setups == Setup.defaults)

        // The unreadable file is moved aside, so saving the defaults can't overwrite it.
        #expect(!FileManager.default.fileExists(atPath: storage.fileURL.path))
        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("setups.corrupt-") && $0.hasSuffix(".json") }
        #expect(backups.count == 1)
        let backupData = try Data(contentsOf: directory.appendingPathComponent(try #require(backups.first)))
        #expect(backupData == Data("not json".utf8))
    }

    @Test func backupNameIncludesTimestamp() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: storage.fileURL)

        let date = try Date("2026-10-20T17:30:05Z", strategy: .iso8601)
        let backupURL = try storage.moveAsideUnreadableFile(now: date)
        #expect(backupURL.lastPathComponent == "setups.corrupt-2026-10-20T173005Z.json")
    }
}
