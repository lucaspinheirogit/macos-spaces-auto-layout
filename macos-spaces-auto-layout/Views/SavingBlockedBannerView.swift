import SwiftUI

/// Shown above the setups list when the store refuses to save, so the user knows edits won't stick.
struct SavingBlockedBannerView: View {
    let reason: SavingBlockedReason

    /// The list window sizes to its content, so the message needs a fixed width to wrap.
    private static let messageWidth: CGFloat = 320

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(reason.message)
                .font(.callout)
                .frame(width: Self.messageWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
