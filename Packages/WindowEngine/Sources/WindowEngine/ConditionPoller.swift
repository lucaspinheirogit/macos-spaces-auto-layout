/// Polls a condition until it holds or a timeout passes. Used instead of fixed delays, because how long a window
/// takes to move or change Space varies by app.
///
/// Waits throw `CancellationError` as soon as the task is cancelled, and rethrow what the condition throws.
public enum ConditionPoller {
    public static let pollInterval: Duration = .milliseconds(50)

    /// Checks `condition` every poll interval until it has been true for `holdingFor` (default: once) or `timeout`
    /// passes.
    @MainActor
    public static func waitUntil(
        timeout: Duration, holdingFor: Duration = .zero, _ condition: () throws -> Bool
    ) async throws -> Bool {
        let deadline = ContinuousClock.now + timeout
        var trueSince: ContinuousClock.Instant?
        while true {
            if try condition() {
                let since = trueSince ?? .now
                trueSince = since
                if ContinuousClock.now - since >= holdingFor { return true }
            } else {
                trueSince = nil
            }
            if ContinuousClock.now >= deadline { return false }
            try await Task.sleep(for: pollInterval)
        }
    }

    /// Waits until `read` has returned the same value for `stableFor` (e.g. a window's frame once its animation has
    /// finished). A nil value is never stable: it means the value couldn't be read.
    @MainActor
    public static func waitForStableValue<Value: Equatable>(
        stableFor: Duration, timeout: Duration, _ read: () throws -> Value?
    ) async throws -> Bool {
        let deadline = ContinuousClock.now + timeout
        var last = try read()
        var stableSince = ContinuousClock.now
        while ContinuousClock.now < deadline {
            try await Task.sleep(for: pollInterval)
            let current = try read()
            if current == nil || current != last {
                last = current
                stableSince = .now
            } else if ContinuousClock.now - stableSince >= stableFor {
                return true
            }
        }
        return false
    }
}
