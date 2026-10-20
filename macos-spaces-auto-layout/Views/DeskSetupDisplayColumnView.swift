import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DeskSetupDisplayColumnView: View {
    @Binding var display: DeskSetupDisplay
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
                    AppPlacementRowView(app: app)
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
            guard let app = AppPlacement(appURL: url) else {
                showMissingBundleIdAlert(for: url)
                completion(nil)
                return
            }
            completion(app)
        }
    }

    private func showMissingBundleIdAlert(for url: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Can't add \(url.deletingPathExtension().lastPathComponent)"
        alert.informativeText = "This app has no bundle identifier, so it can't be recognized later."
        alert.runModal()
    }
}
