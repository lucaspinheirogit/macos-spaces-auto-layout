import AppKit
import ColorSync
import CoreGraphics

/// A connected display. Rects use global top-left coordinates.
public struct DisplayInfo: Sendable {
    public let index: Int
    public let id: CGDirectDisplayID
    /// Stable across reboots (derived from the display's EDID).
    public let uuid: String
    public let name: String
    public let isBuiltin: Bool
    public let isMain: Bool
    public let bounds: CGRect
    /// Bounds minus the menu bar and Dock.
    public let visibleBounds: CGRect
}

@MainActor
public enum Displays {
    /// Active displays, main display first, then left to right.
    public static func current() -> [DisplayInfo] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)

        let screens = NSScreen.screens
        let primaryHeight = screens.first?.frame.height ?? 0
        func screen(for id: CGDirectDisplayID) -> NSScreen? {
            screens.first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
            }
        }

        let sorted = ids.prefix(Int(count)).sorted { a, b in
            if CGDisplayIsMain(a) != CGDisplayIsMain(b) { return CGDisplayIsMain(a) != 0 }
            return CGDisplayBounds(a).minX < CGDisplayBounds(b).minX
        }
        return sorted.enumerated().map { index, id in
            let bounds = CGDisplayBounds(id)
            let screen = screen(for: id)
            let visible = screen.map { Geometry.topLeftRect(fromAppKit: $0.visibleFrame, primaryHeight: primaryHeight) } ?? bounds
            return DisplayInfo(
                index: index,
                id: id,
                uuid: uuidString(for: id),
                name: screen?.localizedName ?? "Display \(id)",
                isBuiltin: CGDisplayIsBuiltin(id) != 0,
                isMain: CGDisplayIsMain(id) != 0,
                bounds: bounds,
                visibleBounds: visible
            )
        }
    }

    /// The display a window frame is mostly on.
    public static func display(for frame: CGRect, in displays: [DisplayInfo]) -> DisplayInfo? {
        Geometry.bestMatch(for: frame, in: displays.map(\.bounds)).map { displays[$0] }
    }

    /// Mission Control's "Displays have separate Spaces". Stored inverted as `com.apple.spaces spans-displays`.
    /// Reading another app's preferences domain only works outside the App Sandbox.
    public static var separateSpacesEnabled: Bool {
        !(UserDefaults(suiteName: "com.apple.spaces")?.bool(forKey: "spans-displays") ?? false)
    }

    /// What's on screen on a display, read from `CGWindowListCopyWindowInfo` (owner PIDs, layers and bounds only,
    /// so no Screen Recording permission is needed). A window counts for the display its center is on, so one
    /// overhanging from a neighbouring display isn't counted.
    public struct OnScreen: Sendable, Equatable {
        /// Menu bar status items (Control Center, menu extras). Hidden while a fullscreen Space is showing.
        public let statusItems: Int
        /// Normal windows of apps other than the one being placed. Hidden while a fullscreen Space is showing.
        public let otherAppWindows: Int
    }

    public static func onScreen(on display: DisplayInfo, excludingPID pid: pid_t) -> OnScreen {
        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        var statusItems = 0
        var otherAppWindows = 0
        for info in infos {
            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width > 1, bounds.height > 1, Geometry.isCentered(bounds, in: display.bounds),
                  let layer = info[kCGWindowLayer as String] as? Int
            else { continue }
            let owner = info[kCGWindowOwnerPID as String] as? pid_t
            if layer == statusLevel { statusItems += 1 }
            if layer == 0, owner != pid { otherAppWindows += 1 }
        }
        return OnScreen(statusItems: statusItems, otherAppWindows: otherAppWindows)
    }

    private static func uuidString(for id: CGDirectDisplayID) -> String {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return "unknown" }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
