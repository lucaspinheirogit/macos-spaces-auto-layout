import SwiftUI

struct DeskSetupRowView: View {
    let setup: DeskSetup
    let store: DeskSetupStore
    @State private var isEditorPresented = false

    private enum Layout {
        static let iconTileSize: CGFloat = 40
        static let iconTileCornerRadius: CGFloat = 8
        static let iconTileOpacity = 0.15
        static let iconPointSize: CGFloat = 18
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.iconTileCornerRadius)
                    .fill(Color(.systemGray).opacity(Layout.iconTileOpacity))
                    .frame(width: Layout.iconTileSize, height: Layout.iconTileSize)
                Image(systemName: setup.displayCountSymbolName)
                    .font(.system(size: Layout.iconPointSize))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(setup.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(setup.displayCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Edit") {
                isEditorPresented = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .cardStyle()
        .sheet(isPresented: $isEditorPresented) {
            DeskSetupEditorView(setup: setup, store: store)
        }
    }
}
