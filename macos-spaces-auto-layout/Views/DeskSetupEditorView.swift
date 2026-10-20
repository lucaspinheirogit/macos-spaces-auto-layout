import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DeskSetupEditorView: View {
    @Environment(\.dismiss) private var dismiss

    // Local editing copy — Cancel discards, Save commits
    @State private var model: DeskSetupEditorModel

    @State private var isAppPickerPresented = false
    /// The display whose Add App button opened the file picker.
    @State private var displayReceivingApp: DeskSetupDisplay.ID?
    @State private var alert: EditorAlert?

    private enum Layout {
        static let columnSpacing: CGFloat = 16
        static let horizontalPadding: CGFloat = 24
        /// The columns scroll past this height instead of growing the sheet off screen.
        static let maxColumnsHeight: CGFloat = 520
    }

    init(setup: DeskSetup, store: DeskSetupStore) {
        _model = State(initialValue: DeskSetupEditorModel(setup: setup, store: store))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header + display columns in the same container
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 4) {
                    TextField("Setup name", text: $model.setupBeingEdited.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                    Text(model.setupBeingEdited.displayCountLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                CappedHeightScrollView(maxHeight: Layout.maxColumnsHeight) {
                    HStack(alignment: .top, spacing: Layout.columnSpacing) {
                        ForEach(model.setupBeingEdited.displays) { display in
                            DeskSetupDisplayColumnView(
                                display: display,
                                isMain: model.isMainDisplay(display),
                                onAddApp: {
                                    displayReceivingApp = display.id
                                    isAppPickerPresented = true
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
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

                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, 20)
        }
        .fixedSize()
        .background(Color(.underPageBackgroundColor))
        .onAppear { NSApp.keyWindow?.makeFirstResponder(nil) }
        .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
        .fileImporter(
            isPresented: $isAppPickerPresented,
            allowedContentTypes: [.applicationBundle],
            onCompletion: addPickedApp
        )
        .fileDialogDefaultDirectory(URL(fileURLWithPath: "/Applications"))
        .fileDialogConfirmationLabel("Select")
        .fileDialogMessage("Choose an application to add")
        .alert(
            alert?.title ?? "",
            isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } }),
            presenting: alert
        ) { _ in
            Button("OK") {}
        } message: { alert in
            Text(alert.message)
        }
    }

    private func addPickedApp(_ result: Result<URL, any Error>) {
        guard let displayId = displayReceivingApp, case .success(let url) = result else { return }
        switch model.addApp(fromBundleAt: url, toDisplay: displayId) {
        case .added:
            break
        case .missingBundleIdentifier(let appName):
            alert = EditorAlert(
                title: "Can't add \(appName)",
                message: "This app has no bundle identifier, so it can't be recognized later.")
        case .alreadyInSetup(let appName, let displayName):
            alert = EditorAlert(
                title: "\(appName) is already in this setup",
                message: "It's on \(displayName). An app can be on only one display of a setup.")
        }
    }

    /// Closes the sheet only when the save worked, so a failed save keeps the edits on screen.
    private func save() {
        do {
            try model.save()
            dismiss()
        } catch {
            alert = EditorAlert(title: "Couldn't save the setup", message: error.localizedDescription)
        }
    }
}

private struct EditorAlert {
    let title: String
    let message: String
}

#Preview {
    DeskSetupEditorView(setup: DeskSetup.firstLaunchSetups[1], store: DeskSetupStore(storage: .temporary))
}
