import Testing

@testable import WindowKit

@MainActor
struct WaitTests {
    @Test func returnsAsSoonAsConditionHolds() async {
        #expect(await Wait.until(timeout: .seconds(1)) { true })
    }

    @Test func timesOutWhenConditionNeverHolds() async {
        let start = ContinuousClock.now
        #expect(!(await Wait.until(timeout: .milliseconds(120)) { false }))
        #expect(ContinuousClock.now - start >= .milliseconds(120))
    }

    @Test func stableForRestartsWhenConditionFlickers() async {
        // true, false, then true from the third poll (~100 ms) on: the 200 ms must count from there.
        var polls = 0
        let start = ContinuousClock.now
        let held = await Wait.until(timeout: .seconds(2), stableFor: .milliseconds(200)) {
            polls += 1
            return polls != 2
        }
        #expect(held)
        #expect(ContinuousClock.now - start >= .milliseconds(300))
    }

    @Test func failsWhenConditionCannotHoldLongEnoughBeforeTimeout() async {
        #expect(!(await Wait.until(timeout: .milliseconds(150), stableFor: .seconds(1)) { true }))
    }

    @Test func durationMillisecondsRoundsDown() {
        #expect(Duration.milliseconds(1500).milliseconds == 1500)
        #expect(Duration.microseconds(2999).milliseconds == 2)
        #expect(Duration.zero.milliseconds == 0)
    }
}
