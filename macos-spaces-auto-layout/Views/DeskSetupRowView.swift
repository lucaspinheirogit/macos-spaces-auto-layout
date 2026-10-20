import SwiftUI

struct DeskSetupRowView: View {
    let setup: DeskSetup
    let store: DeskSetupStore
    @State private var isEditorPresented = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: setup.displayCountSymbolName)
                    .font(.system(size: 18))
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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        )
        .sheet(isPresented: $isEditorPresented) {
            DeskSetupEditorView(setup: setup, store: store)
        }
    }
}
