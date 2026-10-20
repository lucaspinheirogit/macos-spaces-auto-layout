import SwiftUI

struct DeskSetupListView: View {
    let store: DeskSetupStore

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
                    DeskSetupRowView(setup: setup, store: store)
                }
            }
        }
        .padding(20)
        .fixedSize()
        .background(Color(.underPageBackgroundColor))
    }
}

#Preview {
    DeskSetupListView(store: DeskSetupStore(storage: .preview))
}
