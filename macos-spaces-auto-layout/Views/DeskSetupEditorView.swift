import AppKit
import SwiftUI

struct DeskSetupEditorView: View {
    let store: DeskSetupStore
    @Environment(\.dismiss) private var dismiss

    // Local editing copy — Cancel discards, Save commits
    @State private var setupBeingEdited: DeskSetup

    init(setup: DeskSetup, store: DeskSetupStore) {
        self.store = store
        _setupBeingEdited = State(initialValue: setup)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header + display columns in the same container
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 4) {
                    TextField("Setup name", text: $setupBeingEdited.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                    Text(setupBeingEdited.displayCountLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                HStack(alignment: .top, spacing: 16) {
                    ForEach($setupBeingEdited.displays) { $display in
                        DeskSetupDisplayColumnView(
                            display: $display, isMain: display.id == setupBeingEdited.displays.first?.id)
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
                    store.update(setupBeingEdited)
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

#Preview {
    DeskSetupEditorView(setup: DeskSetup.firstLaunchSetups[1], store: DeskSetupStore(storage: .preview))
}
