import CoreGraphics
import Foundation

/// One window from the window server's on-screen list: only the fields that need no Screen Recording permission.
public struct OnScreenWindowListEntry: Sendable, Equatable {
    public let ownerProcessIdentifier: pid_t?
    /// The window level: 0 for normal windows, `FullscreenSpaceSignals.statusItemLayer` for menu bar status items.
    public let layer: Int
    /// In global top-left coordinates.
    public let bounds: CGRect

    public init(ownerProcessIdentifier: pid_t?, layer: Int, bounds: CGRect) {
        self.ownerProcessIdentifier = ownerProcessIdentifier
        self.layer = layer
        self.bounds = bounds
    }
}

/// Reads the on-screen window list. `CoreGraphicsWindowList` is the real one; tests use fakes.
@MainActor
public protocol OnScreenWindowListProvider {
    func onScreenWindows() -> [OnScreenWindowListEntry]
}

/// The real `OnScreenWindowListProvider`, backed by `CGWindowListCopyWindowInfo`. The list only stays current while
/// AppKit's event loop runs.
@MainActor
public struct CoreGraphicsWindowList: OnScreenWindowListProvider {
    public init() {}

    public func onScreenWindows() -> [OnScreenWindowListEntry] {
        let infos =
            CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        return infos.compactMap { info in
            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDict),
                let layer = info[kCGWindowLayer as String] as? Int
            else { return nil }
            return OnScreenWindowListEntry(
                ownerProcessIdentifier: info[kCGWindowOwnerPID as String] as? pid_t, layer: layer, bounds: bounds)
        }
    }
}
