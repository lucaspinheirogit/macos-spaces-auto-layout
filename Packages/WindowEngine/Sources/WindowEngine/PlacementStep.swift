/// The steps of a placement, in the order they run. The raw values appear in the CLI output and the bench CSV.
public enum PlacementStep: String, Sendable, CaseIterable {
    /// Find or launch the app, and wait for a standard window.
    case app
    /// Fullscreen mode: the window is already fullscreen on the target, so nothing else runs.
    case alreadyDone = "already-done"
    case exitFullscreen = "exit-fullscreen"
    case move
    case verifyMaximized = "verify-maximized"
    case enterFullscreen = "enter-fullscreen"
}
