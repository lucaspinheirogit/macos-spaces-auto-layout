import SwiftUI

/// Shown above the setups list until the app has Accessibility access, which it needs to move other apps' windows.
struct AccessibilityBannerView: View {
    let accessibilityAccess: AccessibilityAccess

    /// The list window sizes to its content, so the message needs a fixed width to wrap.
    private static let messageWidth: CGFloat = 320

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    "To arrange windows, the app needs Accessibility access. macOS asks for it once; turn the app on in System Settings → Privacy & Security → Accessibility."
                )
                .font(.callout)
                .frame(width: Self.messageWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                Button("Open System Settings") { accessibilityAccess.requestAccess() }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
