import Testing

@testable import WindowEngine

/// Runs on a test clock: waits finish instantly, and the times they report are exact.
@MainActor
struct ConditionPollerTests {
    let poller = ConditionPoller(clock: TestClock())

    private struct ReadFailed: Error {}

    @Test func returnsAsSoonAsConditionHolds() async throws {
        #expect(try await poller.waitUntil(timeout: .seconds(1)) { true })
        #expect(poller.now == .zero)
    }

    @Test func timesOutWhenConditionNeverHolds() async throws {
        #expect(!(try await poller.waitUntil(timeout: .milliseconds(120)) { false }))
        // Polls at 0, 50, 100 and 150 ms; the last one is past the deadline.
        #expect(poller.now == .milliseconds(150))
    }

    @Test func holdingForRestartsWhenConditionFlickers() async throws {
        // true, false, then true from the third poll (100 ms) on: the 200 ms must count from there.
        var polls = 0
        let held = try await poller.waitUntil(timeout: .seconds(2), holdingFor: .milliseconds(200)) {
            polls += 1
            return polls != 2
        }
        #expect(held)
        #expect(poller.now == .milliseconds(300))
    }

    @Test func failsWhenConditionCannotHoldLongEnoughBeforeTimeout() async throws {
        #expect(!(try await poller.waitUntil(timeout: .milliseconds(150), holdingFor: .seconds(1)) { true }))
    }

    @Test func usesThePollInterval() async throws {
        let poller = ConditionPoller(clock: TestClock(), pollInterval: .milliseconds(10))
        var polls = 0
        _ = try await poller.waitUntil(timeout: .milliseconds(100)) {
            polls += 1
            return false
        }
        #expect(polls == 11)
    }

    @Test func rethrowsTheConditionsError() async {
        await #expect(throws: ReadFailed.self) {
            try await poller.waitUntil(timeout: .seconds(1)) { throw ReadFailed() }
        }
    }

    @Test func throwsWhenCancelled() async {
        let poller = poller
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await poller.waitUntil(timeout: .seconds(1)) { false }
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        // It stopped at the first sleep instead of polling until the timeout.
        #expect(poller.now == .zero)
    }

    @Test func stableValueHoldsOnceUnchanged() async throws {
        var reads = 0
        let stable = try await poller.waitForStableValue(stableFor: .milliseconds(300), timeout: .seconds(2)) {
            reads += 1
            return min(reads, 3)  // changes twice, then stays
        }
        #expect(stable)
        // The value last changed at 100 ms.
        #expect(poller.now == .milliseconds(400))
    }

    @Test func missingValueIsNeverStable() async throws {
        let stable = try await poller.waitForStableValue(stableFor: .milliseconds(300), timeout: .seconds(1)) {
            Int?.none
        }
        #expect(!stable)
    }

    @Test func wholeMillisecondsRoundsDown() {
        #expect(Duration.milliseconds(1500).wholeMilliseconds == 1500)
        #expect(Duration.microseconds(2999).wholeMilliseconds == 2)
        #expect(Duration.zero.wholeMilliseconds == 0)
    }
}
