import AppKit
import ColorSync
import CoreGraphics

/// CoreGraphics couldn't list the active displays.
public struct DisplayListError: Error, Equatable, Sendable, CustomStringConvertible {
    public let code: CGError

    public var description: String { "CGGetActiveDisplayList failed (CGError \(code.rawValue))" }
}

@MainActor
public enum ConnectedDisplays {
    /// Active displays: the main display first, then left to right, then top to bottom.
    public static func current() throws(DisplayListError) -> [ConnectedDisplay] {
        var count: UInt32 = 0
        var error = CGGetActiveDisplayList(0, nil, &count)
        guard error == .success else { throw DisplayListError(code: error) }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        error = CGGetActiveDisplayList(count, &ids, &count)
        guard error == .success else { throw DisplayListError(code: error) }

        let screens = NSScreen.screens
        // The main display has the menu bar and the origin of the global coordinate space.
        let primaryHeight = CGDisplayBounds(CGMainDisplayID()).height
        func screen(for id: CGDirectDisplayID) -> NSScreen? {
            screens.first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
            }
        }

        let sorted = ids.prefix(Int(count)).sorted { a, b in
            if CGDisplayIsMain(a) != CGDisplayIsMain(b) { return CGDisplayIsMain(a) != 0 }
            let boundsA = CGDisplayBounds(a)
            let boundsB = CGDisplayBounds(b)
            return (boundsA.minX, boundsA.minY, a) < (boundsB.minX, boundsB.minY, b)
        }
        return sorted.enumerated().map { index, id in
            let bounds = CGDisplayBounds(id)
            let screen = screen(for: id)
            let visible =
                screen.map {
                    ScreenGeometry.globalTopLeftRect(
                        fromAppKitRect: $0.visibleFrame, primaryDisplayHeight: primaryHeight)
                } ?? bounds
            return ConnectedDisplay(
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
    public static func display(containing frame: CGRect, in displays: [ConnectedDisplay]) -> ConnectedDisplay? {
        ScreenGeometry.indexOfLargestOverlap(with: frame, in: displays.map(\.bounds)).map { displays[$0] }
    }

    /// Mission Control's "Displays have separate Spaces". Stored inverted as `com.apple.spaces spans-displays`.
    /// Reading another app's preferences domain only works outside the App Sandbox.
    public static var separateSpacesEnabled: Bool {
        !(UserDefaults(suiteName: "com.apple.spaces")?.bool(forKey: "spans-displays") ?? false)
    }

    private static func uuidString(for id: CGDirectDisplayID) -> String {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return "unknown" }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
