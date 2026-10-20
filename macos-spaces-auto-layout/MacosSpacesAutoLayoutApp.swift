import SwiftUI

@main
struct MacosSpacesAutoLayoutApp: App {
    @State private var store = DeskSetupStore()

    var body: some Scene {
        Window("Setups", id: "main") {
            DeskSetupListView(store: store)
        }
        .windowResizability(.contentSize)
    }
}
