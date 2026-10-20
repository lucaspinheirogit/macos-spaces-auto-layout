/// The steps of a placement, in the order they run. The raw values appear in the CLI output and the bench CSV.
public enum PlacementStep: String, Sendable, CaseIterable {
    /// Recorded only when it fails: the target display isn't in the display list.
    case targetDisplay = "target-display"
    /// Find or launch the app, and wait for a standard window.
    case app
    /// Recorded only when the window was minimized.
    case unminimize
    /// Fullscreen mode: the window is already fullscreen on the target, so nothing else runs.
    case alreadyDone = "already-done"
    case exitFullscreen = "exit-fullscreen"
    case move
    case verifyMaximized = "verify-maximized"
    case enterFullscreen = "enter-fullscreen"
}
