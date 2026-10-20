import Foundation
import Observation

/// The editor sheet's state: a copy of one setup. Changes stay here until `save()`; closing without saving discards them.
@Observable
final class DeskSetupEditorModel {
    var setupBeingEdited: DeskSetup

    @ObservationIgnored private let store: DeskSetupStore

    init(setup: DeskSetup, store: DeskSetupStore) {
        setupBeingEdited = setup
        self.store = store
    }

    /// What happened when the user picked an app bundle.
    enum AddAppOutcome: Equatable {
        case added(AppPlacement)
        /// The bundle has no `CFBundleIdentifier`, so the app couldn't be recognized later.
        case missingBundleIdentifier(appName: String)
        /// An app is in a setup at most once. Holds the display that already has it.
        case alreadyInSetup(appName: String, displayName: String)
    }

    /// The first display is the main one.
    func isMainDisplay(_ display: DeskSetupDisplay) -> Bool {
        display.id == setupBeingEdited.displays.first?.id
    }

    /// Appends the app at `bundleURL` to the display, unless it has no bundle id or is already in the setup.
    func addApp(fromBundleAt bundleURL: URL, toDisplay displayId: DeskSetupDisplay.ID) -> AddAppOutcome {
        guard let index = setupBeingEdited.displays.firstIndex(where: { $0.id == displayId }) else {
            preconditionFailure("Display \(displayId) isn't in the setup being edited")
        }
        guard let app = AppPlacement(appURL: bundleURL) else {
            return .missingBundleIdentifier(appName: bundleURL.deletingPathExtension().lastPathComponent)
        }
        if let display = setupBeingEdited.display(containingBundleId: app.bundleId) {
            return .alreadyInSetup(appName: app.name, displayName: display.name)
        }
        setupBeingEdited.displays[index].apps.append(app)
        return .added(app)
    }

    /// Saves the edited copy through the store. On failure the store is unchanged and the edits are kept here.
    func save() throws(DeskSetupStoreError) {
        try store.update(setupBeingEdited)
    }
}
