import CoreGraphics

/// How many of the windows that a fullscreen Space hides are showing on a display.
public struct OnScreenWindowCounts: Sendable, Equatable {
    /// Menu bar status items (Control Center, menu extras). Hidden while a fullscreen Space is showing.
    public let statusItems: Int
    /// Normal windows of apps other than the one being placed. Hidden while a fullscreen Space is showing.
    public let otherAppWindows: Int
    /// Normal windows of the app being placed. None while another Space is showing.
    public let placedAppWindows: Int

    public init(statusItems: Int, otherAppWindows: Int, placedAppWindows: Int) {
        self.statusItems = statusItems
        self.otherAppWindows = otherAppWindows
        self.placedAppWindows = placedAppWindows
    }
}

/// Tells whether a fullscreen Space is really showing on a display, from the on-screen window list.
/// `AXFullScreen` flips long before the transition ends, so the placer waits for these signals instead.
public enum FullscreenSpaceSignals {
    /// The window level of menu bar status items.
    public static let statusItemLayer = Int(CGWindowLevelForKey(.statusWindow))

    /// Counts what's on screen on a display. A window counts for the display its center is on, so one overhanging
    /// from a neighbouring display isn't counted; windows 1 pt or smaller are ignored.
    public static func onScreenWindowCounts(
        in entries: [OnScreenWindowListEntry], onDisplayWithBounds displayBounds: CGRect,
        placedAppProcessIdentifier pid: pid_t, statusItemLayer: Int = FullscreenSpaceSignals.statusItemLayer
    ) -> OnScreenWindowCounts {
        var statusItems = 0
        var otherAppWindows = 0
        var placedAppWindows = 0
        for entry in entries {
            guard entry.bounds.width > 1, entry.bounds.height > 1,
                ScreenGeometry.centerIsInside(entry.bounds, bounds: displayBounds)
            else { continue }
            if entry.layer == statusItemLayer { statusItems += 1 }
            if entry.layer == 0 {
                if entry.ownerProcessIdentifier == pid { placedAppWindows += 1 } else { otherAppWindows += 1 }
            }
        }
        return OnScreenWindowCounts(
            statusItems: statusItems, otherAppWindows: otherAppWindows, placedAppWindows: placedAppWindows)
    }
}
