import SwiftUI

/// The rounded, lightly shadowed window-colored background shared by setup rows and display columns.
struct CardStyle: ViewModifier {
    static let cornerRadius: CGFloat = 10
    private static let shadowOpacity = 0.06
    private static let shadowOffsetY: CGFloat = 1

    var shadowRadius: CGFloat
    /// Clips the content to the rounded shape, for cards whose content draws its own backgrounds.
    var clipsContent: Bool

    func body(content: Content) -> some View {
        let card = content.background(
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: .black.opacity(Self.shadowOpacity), radius: shadowRadius, x: 0, y: Self.shadowOffsetY)
        )
        if clipsContent {
            card.clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        } else {
            card
        }
    }
}

extension View {
    func cardStyle(shadowRadius: CGFloat = 2, clipsContent: Bool = false) -> some View {
        modifier(CardStyle(shadowRadius: shadowRadius, clipsContent: clipsContent))
    }
}
