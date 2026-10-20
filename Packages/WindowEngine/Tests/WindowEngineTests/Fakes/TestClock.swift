import Synchronization

/// A clock whose sleeps return at once after moving time forward to the deadline, so waits run instantly and
/// their timings are exact. Sleeping still throws `CancellationError` in a cancelled task.
final class TestClock: Clock {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (a: Instant, b: Instant) -> Bool { a.offset < b.offset }
    }

    private let current = Mutex(Instant(offset: .zero))

    var now: Instant { current.withLock { $0 } }
    var minimumResolution: Duration { .zero }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try Task.checkCancellation()
        current.withLock { now in
            if now < deadline { now = deadline }
        }
    }
}
