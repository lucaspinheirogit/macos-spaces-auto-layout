//
//  SetupStoreTests.swift
//  macos-spaces-auto-layoutTests
//

import Foundation
import Testing
@testable import macos_spaces_auto_layout

@MainActor
struct SetupStoreTests {
    private let storage = SetupFileStorage(fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("setups.json"))

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

    @Test func fallsBackToDefaultsWhenFileIsCorrupt() throws {
        try FileManager.default.createDirectory(
            at: storage.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: storage.fileURL)

        let store = SetupStore(storage: storage)
        #expect(store.setups == Setup.defaults)
    }
}
