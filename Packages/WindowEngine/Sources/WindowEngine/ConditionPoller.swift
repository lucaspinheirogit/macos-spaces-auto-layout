/// Polls a condition until it holds or a timeout passes. Used instead of fixed delays, because how long a window
/// takes to move or change Space varies by app.
///
/// Time comes from an injected clock, so tests can run on a clock that advances instantly. Waits throw
/// `CancellationError` as soon as the task is cancelled, and rethrow what the condition throws.
public struct ConditionPoller: Sendable {
    public static let defaultPollInterval: Duration = .milliseconds(50)

    public let pollInterval: Duration
    private let elapsed: @Sendable () -> Duration
    private let sleepFor: @Sendable (Duration) async throws -> Void

    public init(clock: some Clock<Duration> = ContinuousClock(), pollInterval: Duration = defaultPollInterval) {
        self.pollInterval = pollInterval
        let origin = clock.now
        elapsed = { origin.duration(to: clock.now) }
        sleepFor = { try await clock.sleep(for: $0) }
    }

    /// Time on the poller's clock since the poller was made.
    public var now: Duration { elapsed() }

    /// Sleeps on the poller's clock.
    public func sleep(for duration: Duration) async throws {
        try await sleepFor(duration)
    }

    /// Checks `condition` every poll interval until it has been true for `holdingFor` (default: once) or `timeout`
    /// passes.
    @MainActor
    public func waitUntil(
        timeout: Duration, holdingFor: Duration = .zero, _ condition: () throws -> Bool
    ) async throws -> Bool {
        let deadline = now + timeout
        var trueSince: Duration?
        while true {
            if try condition() {
                let since = trueSince ?? now
                trueSince = since
                if now - since >= holdingFor { return true }
            } else {
                trueSince = nil
            }
            if now >= deadline { return false }
            try await sleep(for: pollInterval)
        }
    }

    /// Waits until `read` has returned the same value for `stableFor` (e.g. a window's frame once its animation has
    /// finished). A nil value is never stable: it means the value couldn't be read.
    @MainActor
    public func waitForStableValue<Value: Equatable>(
        stableFor: Duration, timeout: Duration, _ read: () throws -> Value?
    ) async throws -> Bool {
        let deadline = now + timeout
        var last = try read()
        var stableSince = now
        while now < deadline {
            try await sleep(for: pollInterval)
            let current = try read()
            if current == nil || current != last {
                last = current
                stableSince = now
            } else if now - stableSince >= stableFor {
                return true
            }
        }
        return false
    }
}
