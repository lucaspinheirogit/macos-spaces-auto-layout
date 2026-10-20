import Testing

@testable import WindowEngine

@MainActor
struct ConditionPollerTests {
    @Test func returnsAsSoonAsConditionHolds() async {
        #expect(await ConditionPoller.waitUntil(timeout: .seconds(1)) { true })
    }

    @Test func timesOutWhenConditionNeverHolds() async {
        let start = ContinuousClock.now
        #expect(!(await ConditionPoller.waitUntil(timeout: .milliseconds(120)) { false }))
        #expect(ContinuousClock.now - start >= .milliseconds(120))
    }

    @Test func stableForRestartsWhenConditionFlickers() async {
        // true, false, then true from the third poll (~100 ms) on: the 200 ms must count from there.
        var polls = 0
        let start = ContinuousClock.now
        let held = await ConditionPoller.waitUntil(timeout: .seconds(2), holdingFor: .milliseconds(200)) {
            polls += 1
            return polls != 2
        }
        #expect(held)
        #expect(ContinuousClock.now - start >= .milliseconds(300))
    }

    @Test func failsWhenConditionCannotHoldLongEnoughBeforeTimeout() async {
        #expect(!(await ConditionPoller.waitUntil(timeout: .milliseconds(150), holdingFor: .seconds(1)) { true }))
    }

    @Test func wholeMillisecondsRoundsDown() {
        #expect(Duration.milliseconds(1500).wholeMilliseconds == 1500)
        #expect(Duration.microseconds(2999).wholeMilliseconds == 2)
        #expect(Duration.zero.wholeMilliseconds == 0)
    }
}
