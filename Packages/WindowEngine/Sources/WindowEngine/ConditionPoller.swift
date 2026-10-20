/// Polls a condition until it holds or a timeout passes. Used instead of fixed delays, because how long a window
/// takes to move or change Space varies by app.
public enum ConditionPoller {
    public static let pollInterval: Duration = .milliseconds(50)

    /// Checks `condition` every poll interval until it has been true for `holdingFor` (default: once) or `timeout`
    /// passes.
    @MainActor
    public static func waitUntil(timeout: Duration, holdingFor: Duration = .zero, _ condition: () -> Bool) async
        -> Bool
    {
        let deadline = ContinuousClock.now + timeout
        var trueSince: ContinuousClock.Instant?
        while true {
            if condition() {
                let since = trueSince ?? .now
                trueSince = since
                if ContinuousClock.now - since >= holdingFor { return true }
            } else {
                trueSince = nil
            }
            if ContinuousClock.now >= deadline { return false }
            try? await Task.sleep(for: pollInterval)
        }
    }

    /// Waits until the window's frame hasn't changed for `stableFor` (i.e. its animation has finished).
    @MainActor
    public static func waitForStableFrame(
        of window: AccessibilityWindow, stableFor: Duration = .milliseconds(300), timeout: Duration
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        var last = window.frame
        var stableSince = ContinuousClock.now
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: pollInterval)
            let current = window.frame
            if current != last {
                last = current
                stableSince = .now
            } else if ContinuousClock.now - stableSince >= stableFor {
                return true
            }
        }
        return false
    }
}
