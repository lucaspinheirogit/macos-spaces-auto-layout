import Foundation
import Testing

@testable import macos_spaces_auto_layout

@MainActor
final class DeskSetupEditorModelTests {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    private var storage: DeskSetupFileStorage {
        DeskSetupFileStorage(fileURL: directory.appendingPathComponent("setups.json"))
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    /// A model editing the "Dual Display" first-launch setup.
    private func makeModel(store: DeskSetupStore) -> DeskSetupEditorModel {
        DeskSetupEditorModel(setup: store.setups[1], store: store)
    }

    private func makeSafari() throws -> URL {
        try makeAppBundle(
            in: directory, named: "Safari", plist: ["CFBundleIdentifier": "com.apple.Safari", "CFBundleName": "Safari"])
    }

    @Test func firstDisplayIsMain() {
        let model = makeModel(store: DeskSetupStore(storage: storage))
        let displays = model.setupBeingEdited.displays
        #expect(model.isMainDisplay(displays[0]))
        #expect(!model.isMainDisplay(displays[1]))
    }

    @Test func addsAppToTheChosenDisplay() throws {
        let model = makeModel(store: DeskSetupStore(storage: storage))
        let secondDisplay = model.setupBeingEdited.displays[1]

        let outcome = model.addApp(fromBundleAt: try makeSafari(), toDisplay: secondDisplay.id)

        guard case .added(let app) = outcome else {
            Issue.record("Expected .added, got \(outcome)")
            return
        }
        #expect(app.bundleId == "com.apple.Safari")
        #expect(model.setupBeingEdited.displays[0].apps.isEmpty)
        #expect(model.setupBeingEdited.displays[1].apps == [app])
    }

    @Test func rejectsBundleWithoutIdentifier() throws {
        let model = makeModel(store: DeskSetupStore(storage: storage))
        let url = try makeAppBundle(in: directory, named: "Nameless", plist: ["CFBundleName": "Nameless"])

        let outcome = model.addApp(fromBundleAt: url, toDisplay: model.setupBeingEdited.displays[0].id)

        #expect(outcome == .missingBundleIdentifier(appName: "Nameless"))
        #expect(model.setupBeingEdited.displays.allSatisfy { $0.apps.isEmpty })
    }

    @Test func rejectsAppAlreadyInTheSetup() throws {
        let model = makeModel(store: DeskSetupStore(storage: storage))
        let displays = model.setupBeingEdited.displays
        let safari = try makeSafari()
        _ = model.addApp(fromBundleAt: safari, toDisplay: displays[0].id)

        #expect(
            model.addApp(fromBundleAt: safari, toDisplay: displays[1].id)
                == .alreadyInSetup(appName: "Safari", displayName: "Display 1"))
        #expect(
            model.addApp(fromBundleAt: safari, toDisplay: displays[0].id)
                == .alreadyInSetup(appName: "Safari", displayName: "Display 1"))
        #expect(model.setupBeingEdited.displays.map(\.apps.count) == [1, 0])
    }

    @Test func editsStayLocalUntilSaved() throws {
        let store = DeskSetupStore(storage: storage)
        let model = makeModel(store: store)
        model.setupBeingEdited.name = "Office"
        _ = model.addApp(fromBundleAt: try makeSafari(), toDisplay: model.setupBeingEdited.displays[0].id)

        // Cancelling just drops the model.
        #expect(store.setups == DeskSetup.firstLaunchSetups)
        #expect(!FileManager.default.fileExists(atPath: storage.fileURL.path))
    }

    @Test func saveWritesThroughTheStore() throws {
        let store = DeskSetupStore(storage: storage)
        let model = makeModel(store: store)
        model.setupBeingEdited.name = "Office"
        _ = model.addApp(fromBundleAt: try makeSafari(), toDisplay: model.setupBeingEdited.displays[0].id)

        try model.save()

        #expect(store.setups[1] == model.setupBeingEdited)
        #expect(DeskSetupStore(storage: storage).setups[1] == model.setupBeingEdited)
    }

    @Test func failedSaveKeepsTheEdits() throws {
        // A directory at the file's path blocks saving.
        try FileManager.default.createDirectory(at: storage.fileURL, withIntermediateDirectories: true)
        let store = DeskSetupStore(storage: storage)
        let model = makeModel(store: store)
        model.setupBeingEdited.name = "Office"

        #expect(throws: DeskSetupStoreError.self) { try model.save() }
        #expect(model.setupBeingEdited.name == "Office")
        #expect(store.setups == DeskSetup.firstLaunchSetups)
    }
}
