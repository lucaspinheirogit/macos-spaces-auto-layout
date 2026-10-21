import SwiftUI

struct DeskSetupListView: View {
    let store: DeskSetupStore
    let accessibilityAccess: AccessibilityAccess

    private enum Layout {
        static let padding: CGFloat = 20
        static let rowSpacing: CGFloat = 8
        /// The list scrolls past this height instead of growing the window.
        static let maxRowsHeight: CGFloat = 560
    }

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

            if !accessibilityAccess.isGranted {
                AccessibilityBannerView(accessibilityAccess: accessibilityAccess)
            }

            if let reason = store.savingBlockedReason {
                SavingBlockedBannerView(reason: reason)
            }

            CappedHeightScrollView(maxHeight: Layout.maxRowsHeight) {
                VStack(spacing: Layout.rowSpacing) {
                    ForEach(store.setups) { setup in
                        DeskSetupRowView(setup: setup, store: store)
                    }
                }
            }
        }
        .padding(Layout.padding)
        .fixedSize()
        .background(Color(.underPageBackgroundColor))
    }
}

#Preview {
    DeskSetupListView(store: DeskSetupStore(storage: .temporary), accessibilityAccess: AccessibilityAccess())
}
