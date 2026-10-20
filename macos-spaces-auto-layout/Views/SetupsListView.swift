import SwiftUI

struct SetupsListView: View {
    let store: SetupStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Setups")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Configure which apps go on each display of your desk setups.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(store.setups) { setup in
                    SetupRowView(setup: setup, store: store)
                }
            }
        }
        .padding(20)
        .fixedSize()
        .background(Color(.underPageBackgroundColor))
    }
}

struct SetupRowView: View {
    let setup: Setup
    let store: SetupStore
    @State private var showEditor = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: setup.symbolName)
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
                showEditor = true
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
        .sheet(isPresented: $showEditor) {
            SetupEditorView(setup: setup, store: store)
        }
    }
}

#Preview {
    SetupsListView(store: SetupStore(storage: .preview))
}
