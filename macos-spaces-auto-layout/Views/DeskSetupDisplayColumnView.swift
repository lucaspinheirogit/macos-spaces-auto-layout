import SwiftUI

/// One display in the editor: its name, its apps, and an Add App button.
struct DeskSetupDisplayColumnView: View {
    let display: DeskSetupDisplay
    let isMain: Bool
    /// Called by the Add App button. The editor owns the file picker.
    let onAddApp: () -> Void

    private enum Layout {
        static let minWidth: CGFloat = 200
        static let headerPadding: CGFloat = 12
        /// Lines up the dividers between app rows with the app names, past the icons.
        static let appDividerIndent: CGFloat = 36
        static let addButtonIconSize: CGFloat = 12
        static let addButtonBackgroundOpacity = 0.5
        static let shadowRadius: CGFloat = 3
    }

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
            .padding(.horizontal, Layout.headerPadding)
            .padding(.vertical, 10)

            Divider()

            // App list
            VStack(spacing: 0) {
                ForEach(display.apps) { app in
                    AppPlacementRowView(app: app)
                    if app.id != display.apps.last?.id {
                        Divider().padding(.leading, Layout.appDividerIndent)
                    }
                }
            }

            // Add App button
            Button(action: onAddApp) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: Layout.addButtonIconSize, weight: .medium))
                    Text("Add App")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .background(Color(.windowBackgroundColor).opacity(Layout.addButtonBackgroundOpacity))
        }
        .cardStyle(shadowRadius: Layout.shadowRadius, clipsContent: true)
        .frame(minWidth: Layout.minWidth)
    }
}
