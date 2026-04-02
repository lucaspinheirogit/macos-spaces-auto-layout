//
//  macos_spaces_auto_layoutApp.swift
//  macos-spaces-auto-layout
//
//  Created by Lucas Pinheiro on 02/04/26.
//

import SwiftUI

@main
struct macos_spaces_auto_layoutApp: App {
    var body: some Scene {
        Window("Layouts", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
