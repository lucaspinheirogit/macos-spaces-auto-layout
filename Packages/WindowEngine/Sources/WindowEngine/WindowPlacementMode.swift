/// How a window ends up on its display.
public enum WindowPlacementMode: String, Sendable, CaseIterable {
    /// Native fullscreen, in its own Space on the display.
    case fullscreen
    /// Fills the display's visible area (below the menu bar, beside the Dock).
    case maximized
}
