import Foundation
import Testing

@testable import macos_spaces_auto_layout

@MainActor
final class DeskSetupStoreTests {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    private var storage: DeskSetupFileStorage {
        DeskSetupFileStorage(fileURL: directory.appendingPathComponent("setups.json"))
    }

    deinit {
        // Some tests make the folder read-only; restore it so it can be deleted.
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        try? FileManager.default.removeItem(at: directory)
    }

    private func writeFile(_ data: Data) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: storage.fileURL)
    }

    private func renamed(_ setup: DeskSetup, to name: String) -> DeskSetup {
        var setup = setup
        setup.name = name
        return setup
    }

    // MARK: Loading

    @Test func seedsFirstLaunchSetupsWhenNoFileExists() {
        let store = DeskSetupStore(storage: storage)
        #expect(store.setups == DeskSetup.firstLaunchSetups)
        #expect(!store.isSavingBlocked)
    }

    @Test func loadsLegacyFileAndSavesItAsCurrentVersion() throws {
        try writeFile(Fixture.data(named: "setups-v0"))
        let store = DeskSetupStore(storage: storage)
        #expect(store.setups == [Fixture.homeDesk])

        try store.update(renamed(Fixture.homeDesk, to: "Office"))
        let saved = try #require(try storage.load())
        #expect(saved == DeskSetupFile(schemaVersion: 1, setups: [renamed(Fixture.homeDesk, to: "Office")]))
    }

    @Test func fallsBackToFirstLaunchSetupsAndKeepsCorruptFile() throws {
        try writeFile(Data("not json".utf8))

        let store = DeskSetupStore(storage: storage)
        #expect(store.setups == DeskSetup.firstLaunchSetups)
        #expect(!store.isSavingBlocked)

        // The unreadable file is moved aside, so saving the first-launch setups can't overwrite it.
        #expect(!FileManager.default.fileExists(atPath: storage.fileURL.path))
        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("setups.corrupt-") && $0.hasSuffix(".json") }
        #expect(backups.count == 1)
        let backupData = try Data(contentsOf: directory.appendingPathComponent(try #require(backups.first)))
        #expect(backupData == Data("not json".utf8))
    }

    @Test func blocksSavingWhenCorruptFileCannotBeMovedAside() throws {
        try writeFile(Data("not json".utf8))
        // A read-only folder lets the file be read but not renamed.
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)

        let store = DeskSetupStore(storage: storage)
        #expect(store.setups == DeskSetup.firstLaunchSetups)
        #expect(store.savingBlockedReason == .couldNotMoveAside(path: storage.fileURL.path))
        #expect(throws: DeskSetupStoreError.savingBlocked(.couldNotMoveAside(path: storage.fileURL.path))) {
            try store.update(self.renamed(store.setups[0], to: "Changed"))
        }
        #expect(store.setups == DeskSetup.firstLaunchSetups)
        #expect(try Data(contentsOf: storage.fileURL) == Data("not json".utf8))
    }

    @Test func blocksSavingWhenPathIsADirectory() throws {
        try FileManager.default.createDirectory(at: storage.fileURL, withIntermediateDirectories: true)

        let store = DeskSetupStore(storage: storage)
        #expect(store.setups == DeskSetup.firstLaunchSetups)
        #expect(store.savingBlockedReason == .unreadableFile(path: storage.fileURL.path))
        #expect(throws: DeskSetupStoreError.savingBlocked(.unreadableFile(path: storage.fileURL.path))) {
            try store.update(self.renamed(store.setups[0], to: "Changed"))
        }

        // Nothing was moved aside or overwritten.
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: storage.fileURL.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["setups.json"])
    }

    @Test func loadsNewerVersionReadOnly() throws {
        let fixture = try Fixture.data(named: "setups-v99")
        try writeFile(fixture)

        let store = DeskSetupStore(storage: storage)
        #expect(store.setups == [Fixture.homeDesk])
        #expect(store.savingBlockedReason == .newerSchemaVersion(99))
        #expect(throws: DeskSetupStoreError.savingBlocked(.newerSchemaVersion(99))) {
            try store.update(self.renamed(Fixture.homeDesk, to: "Changed"))
        }
        #expect(store.setups == [Fixture.homeDesk])
        #expect(try Data(contentsOf: storage.fileURL) == fixture)
    }

    @Test func keepsIncompatibleNewerVersionInPlace() throws {
        let fixture = try Fixture.data(named: "setups-v99-incompatible")
        try writeFile(fixture)

        let store = DeskSetupStore(storage: storage)
        #expect(store.setups == DeskSetup.firstLaunchSetups)
        #expect(store.savingBlockedReason == .newerSchemaVersion(99))
        // Not moved aside: the file isn't corrupt, just newer.
        #expect(try Data(contentsOf: storage.fileURL) == fixture)
    }

    @Test func repairsDuplicateIdsOnLoad() throws {
        let shared = UUID()
        let file = DeskSetupFile(setups: [
            DeskSetup(id: shared, name: "A", displays: [DeskSetupDisplay(id: shared, name: "Display 1", apps: [])]),
            DeskSetup(id: shared, name: "B", displays: []),
        ])
        try writeFile(file.encoded())

        let store = DeskSetupStore(storage: storage)
        #expect(store.setups.map(\.name) == ["A", "B"])
        #expect(Set(store.setups.map(\.id)).count == 2)
        #expect(store.setups[0].displays[0].id != store.setups[0].id)

        // Updating the second setup changes only that one.
        try store.update(renamed(store.setups[1], to: "B2"))
        #expect(store.setups.map(\.name) == ["A", "B2"])
    }

    // MARK: Saving

    @Test func updatePersistsAcrossStores() throws {
        let store = DeskSetupStore(storage: storage)
        var setup = store.setups[1]
        setup.name = "Home desk"
        setup.displays[0].apps.append(AppPlacement(bundleId: "com.apple.Safari", name: "Safari"))
        try store.update(setup)

        #expect(store.setups[1] == setup)
        let reloaded = DeskSetupStore(storage: storage)
        #expect(reloaded.setups == store.setups)
        #expect(try storage.load()?.setups == store.setups)
    }

    @Test func repeatedUpdatesKeepTheLatest() throws {
        let store = DeskSetupStore(storage: storage)
        try store.update(renamed(store.setups[0], to: "First"))
        try store.update(renamed(store.setups[0], to: "Second"))
        try store.update(renamed(store.setups[2], to: "Third"))

        #expect(store.setups.map(\.name) == ["Second", "Dual Display", "Third"])
        #expect(DeskSetupStore(storage: storage).setups == store.setups)
    }

    @Test func ignoresUpdatesForUnknownIds() throws {
        let store = DeskSetupStore(storage: storage)
        try store.update(DeskSetup(name: "Stranger", displays: []))
        #expect(store.setups == DeskSetup.firstLaunchSetups)
        #expect(!FileManager.default.fileExists(atPath: storage.fileURL.path))
    }

    @Test func failedSaveRollsBackAndThrows() throws {
        // A file where the folder should be makes the write fail.
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data().write(to: directory.appendingPathComponent("blocker"))
        let storage = DeskSetupFileStorage(fileURL: directory.appendingPathComponent("blocker/setups.json"))

        let store = DeskSetupStore(storage: storage)
        let error = #expect(throws: DeskSetupStoreError.self) {
            try store.update(self.renamed(store.setups[0], to: "Changed"))
        }
        guard case .writeFailed = error else {
            Issue.record("Expected writeFailed, got \(String(describing: error))")
            return
        }
        #expect(store.setups == DeskSetup.firstLaunchSetups)
    }

    // MARK: Backups

    @Test func backupNameIncludesTimestamp() throws {
        try writeFile(Data("x".utf8))

        let date = try Date("2026-10-20T17:30:05Z", strategy: .iso8601)
        let backupURL = try storage.moveAsideUnreadableFile(now: date)
        #expect(backupURL.lastPathComponent == "setups.corrupt-2026-10-20T173005Z.json")
    }

    @Test func backupNameAvoidsExistingBackups() throws {
        let date = try Date("2026-10-20T17:30:05Z", strategy: .iso8601)
        try writeFile(Data("first".utf8))
        let first = try storage.moveAsideUnreadableFile(now: date)
        try writeFile(Data("second".utf8))
        let second = try storage.moveAsideUnreadableFile(now: date)
        try writeFile(Data("third".utf8))
        let third = try storage.moveAsideUnreadableFile(now: date)

        #expect(second.lastPathComponent == "setups.corrupt-2026-10-20T173005Z-2.json")
        #expect(third.lastPathComponent == "setups.corrupt-2026-10-20T173005Z-3.json")
        #expect(try Data(contentsOf: first) == Data("first".utf8))
        #expect(try Data(contentsOf: second) == Data("second".utf8))
    }

    // MARK: Test host

    @Test func testHostNeverUsesTheRealFile() {
        #expect(MacosSpacesAutoLayoutApp.isRunningUnderXCTest)
        #expect(MacosSpacesAutoLayoutApp.deskSetupStorage.fileURL != DeskSetupFileStorage.default.fileURL)
    }
}
