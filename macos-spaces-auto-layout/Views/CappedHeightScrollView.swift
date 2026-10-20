import SwiftUI

/// A vertical scroll view as tall as its content, up to `maxHeight`, then it scrolls.
/// Works inside `.fixedSize()` windows and sheets, where a plain `ScrollView` has no height to fill.
struct CappedHeightScrollView<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder let content: Content

    /// Room around the content so card shadows aren't clipped by the scroll view's edges.
    private static var shadowInset: CGFloat { 4 }

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView(.vertical) {
            content
                .padding(Self.shadowInset)
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    contentHeight = $0
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(contentHeight, maxHeight))
        .padding(-Self.shadowInset)
    }
}
