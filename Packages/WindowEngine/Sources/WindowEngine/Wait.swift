public enum Wait {
    public static let pollInterval: Duration = .milliseconds(50)

    /// Checks `condition` every 50 ms until it has been true for `stableFor` (default: once) or `timeout` passes.
    @MainActor
    public static func until(timeout: Duration, stableFor: Duration = .zero, _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        var trueSince: ContinuousClock.Instant?
        while true {
            if condition() {
                let since = trueSince ?? .now
                trueSince = since
                if ContinuousClock.now - since >= stableFor { return true }
            } else {
                trueSince = nil
            }
            if ContinuousClock.now >= deadline { return false }
            try? await Task.sleep(for: pollInterval)
        }
    }

    /// Waits until the window's frame hasn't changed for `stableFor` (i.e. its animation has finished).
    @MainActor
    public static func forStableFrame(_ window: AXWindow, stableFor: Duration = .milliseconds(300), timeout: Duration)
        async -> Bool
    {
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

extension Duration {
    /// Whole milliseconds, rounded down.
    public var milliseconds: Int {
        let (seconds, attoseconds) = components
        return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
    }
}
