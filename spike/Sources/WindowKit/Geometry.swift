import CoreGraphics

/// Pure rectangle math. All rects are in global coordinates with a top-left origin
/// (the space used by the Accessibility API and `CGDisplayBounds`) unless stated otherwise.
public enum Geometry {
    /// Converts an AppKit rect (bottom-left origin, e.g. `NSScreen.visibleFrame`) to top-left coordinates.
    /// `primaryHeight` is the height of the primary display (the one with the menu bar, `NSScreen.screens[0]`).
    public static func topLeftRect(fromAppKit rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Index of the rect in `candidates` that overlaps `frame` the most, or nil if none overlap.
    public static func bestMatch(for frame: CGRect, in candidates: [CGRect]) -> Int? {
        let areas = candidates.map { area(of: frame.intersection($0)) }
        guard let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 else { return nil }
        return best
    }

    public static func approximatelyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }

    /// Whether a fullscreen window frame fills the display. Full width and bottom-aligned; the top may be
    /// inset (on notched MacBooks most apps' fullscreen windows sit below the camera housing).
    public static func fillsDisplay(_ frame: CGRect, bounds: CGRect, tolerance: CGFloat = 2, maxTopInset: CGFloat = 50) -> Bool {
        abs(frame.minX - bounds.minX) <= tolerance
            && abs(frame.width - bounds.width) <= tolerance
            && abs(frame.maxY - bounds.maxY) <= tolerance
            && frame.minY >= bounds.minY - tolerance
            && frame.minY - bounds.minY <= maxTopInset
    }

    private static func area(of rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }
}
