//
//  ContentView.swift
//  macos-spaces-auto-layout
//
//  Created by Lucas Pinheiro on 02/04/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = LayoutStore()

    var body: some View {
        LayoutsView(store: store)
            .background(Color(.underPageBackgroundColor))
    }
}

#Preview {
    ContentView()
}
