//
//  LayoutsView.swift
//  macos-spaces-auto-layout
//
//  Created by Lucas Pinheiro on 02/04/26.
//

import SwiftUI

struct LayoutsView: View {
    @ObservedObject var store: LayoutStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Layouts")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Select and configure your workspace monitor arrangements.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(store.layouts) { layout in
                    LayoutRowView(layout: layout, store: store)
                }
            }
        }
        .padding(20)
        .fixedSize()
    }
}

struct LayoutRowView: View {
    @ObservedObject var layout: Layout
    var store: LayoutStore
    @State private var showEditor = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: layout.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(layout.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text("\(layout.monitorCount) Monitor\(layout.monitorCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Edit") {
                showEditor = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Toggle("", isOn: Binding(
                get: { layout.isActive },
                set: { isOn in
                    if isOn { store.activate(layout) }
                    else     { store.deactivate(layout) }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        )
        .sheet(isPresented: $showEditor) {
            LayoutEditorView(layout: layout, store: store)
        }
    }
}

#Preview {
    LayoutsView(store: LayoutStore())
        .background(Color(.underPageBackgroundColor))
}
