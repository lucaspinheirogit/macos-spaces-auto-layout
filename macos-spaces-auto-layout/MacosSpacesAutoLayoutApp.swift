import Foundation
import SwiftUI

@main
struct MacosSpacesAutoLayoutApp: App {
    static let setupsWindowId = "main"

    @State private var store = DeskSetupStore(storage: MacosSpacesAutoLayoutApp.deskSetupStorage)
    @State private var accessibilityAccess: AccessibilityAccess
    @State private var applier: DeskSetupApplier

    init() {
        let access = AccessibilityAccess()
        if !Self.isRunningUnderXCTest { access.startMonitoring() }
        _accessibilityAccess = State(initialValue: access)
        _applier = State(initialValue: DeskSetupApplier(accessibilityAccess: access))
    }

    var body: some Scene {
        Window("Setups", id: Self.setupsWindowId) {
            DeskSetupListView(store: store, accessibilityAccess: accessibilityAccess)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Spaces Auto Layout", systemImage: "rectangle.3.group") {
            MenuBarContentView(store: store, applier: applier, accessibilityAccess: accessibilityAccess)
        }
    }

    /// The app is the unit tests' host, so it launches for every test run. Under XCTest it uses a temporary
    /// file, so a test run never reads, moves aside or overwrites the real `setups.json`.
    nonisolated static var deskSetupStorage: DeskSetupFileStorage {
        isRunningUnderXCTest ? .temporary : .default
    }

    nonisolated static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
