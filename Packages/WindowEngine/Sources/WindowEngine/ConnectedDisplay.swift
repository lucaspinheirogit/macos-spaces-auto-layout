import CoreGraphics

/// A connected display. Rects use global top-left coordinates.
public struct ConnectedDisplay: Sendable, Equatable {
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

    public init(
        index: Int, id: CGDirectDisplayID, uuid: String, name: String, isBuiltin: Bool, isMain: Bool, bounds: CGRect,
        visibleBounds: CGRect
    ) {
        self.index = index
        self.id = id
        self.uuid = uuid
        self.name = name
        self.isBuiltin = isBuiltin
        self.isMain = isMain
        self.bounds = bounds
        self.visibleBounds = visibleBounds
    }
}
