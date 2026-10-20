//
//  MacosSpacesAutoLayoutApp.swift
//  macos-spaces-auto-layout
//

import SwiftUI

@main
struct MacosSpacesAutoLayoutApp: App {
    @State private var store = SetupStore()

    var body: some Scene {
        Window("Setups", id: "main") {
            SetupsListView(store: store)
        }
        .windowResizability(.contentSize)
    }
}
