import Foundation
import SwiftUI

@main
struct MacosSpacesAutoLayoutApp: App {
    @State private var store = DeskSetupStore(storage: MacosSpacesAutoLayoutApp.deskSetupStorage)

    var body: some Scene {
        Window("Setups", id: "main") {
            DeskSetupListView(store: store)
        }
        .windowResizability(.contentSize)
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
