import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppPlacementRowView: View {
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
