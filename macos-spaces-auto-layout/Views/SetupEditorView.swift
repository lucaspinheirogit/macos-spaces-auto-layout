//
//  SetupEditorView.swift
//  macos-spaces-auto-layout
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SetupEditorView: View {
    let store: SetupStore
    @Environment(\.dismiss) private var dismiss

    // Local editing copy — Cancel discards, Save commits
    @State private var draft: Setup

    init(setup: Setup, store: SetupStore) {
        self.store = store
        _draft = State(initialValue: setup)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header + display columns in the same container
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 4) {
                    TextField("Setup name", text: $draft.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                    Text(displayCountLabel(draft.displays.count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                HStack(alignment: .top, spacing: 16) {
                    ForEach($draft.displays) { $display in
                        DisplayColumnView(display: $display, isMain: display.id == draft.displays.first?.id)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)

            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    store.update(draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .fixedSize()
        .background(Color(.underPageBackgroundColor))
        .onAppear { NSApp.keyWindow?.makeFirstResponder(nil) }
        .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
    }
}

struct DisplayColumnView: View {
    @Binding var display: SetupDisplay
    let isMain: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            HStack {
                Image(systemName: "desktopcomputer")
                    .foregroundStyle(Color.accentColor)
                Text(display.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if isMain {
                    Text("MAIN")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // App list
            VStack(spacing: 0) {
                ForEach(display.apps) { app in
                    AppRowView(app: app)
                    if app.id != display.apps.last?.id {
                        Divider().padding(.leading, 36)
                    }
                }
            }

            // Add App button
            Button {
                pickApp { app in
                    if let app { display.apps.append(app) }
                }
            } label: {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("Add App")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .background(Color(.windowBackgroundColor).opacity(0.5))
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(minWidth: 200)
    }

    private func pickApp(completion: @escaping (AppPlacement?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Select"
        panel.message = "Choose an application to add"

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }
            completion(AppPlacement(appURL: url))
        }
    }
}

struct AppRowView: View {
    let app: AppPlacement

    private var appIcon: NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 20, height: 20)
            Text(app.name)
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    SetupEditorView(setup: Setup.defaults[1], store: SetupStore(storage: .preview))
}
