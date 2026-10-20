import CoreGraphics
import Foundation

/// What's on screen on a display, read from `CGWindowListCopyWindowInfo` (owner PIDs, layers and bounds only,
/// so no Screen Recording permission is needed). A window counts for the display its center is on, so one
/// overhanging from a neighbouring display isn't counted.
public struct OnScreenWindowCounts: Sendable, Equatable {
    /// Menu bar status items (Control Center, menu extras). Hidden while a fullscreen Space is showing.
    public let statusItems: Int
    /// Normal windows of apps other than the one being placed. Hidden while a fullscreen Space is showing.
    public let otherAppWindows: Int
}

@MainActor
public enum FullscreenSpaceSignals {
    public static func onScreenWindowCounts(on display: ConnectedDisplay, excludingPID pid: pid_t)
        -> OnScreenWindowCounts
    {
        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        let infos =
            CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        var statusItems = 0
        var otherAppWindows = 0
        for info in infos {
            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDict),
                bounds.width > 1, bounds.height > 1, ScreenGeometry.centerIsInside(bounds, bounds: display.bounds),
                let layer = info[kCGWindowLayer as String] as? Int
            else { continue }
            let owner = info[kCGWindowOwnerPID as String] as? pid_t
            if layer == statusLevel { statusItems += 1 }
            if layer == 0, owner != pid { otherAppWindows += 1 }
        }
        return OnScreenWindowCounts(statusItems: statusItems, otherAppWindows: otherAppWindows)
    }
}
