import Testing
import WindowEngine

@testable import BenchReport

struct BenchSummaryTests {
    @Test func percentileUsesNearestRank() {
        let values = Array(1...20)
        #expect(BenchSummary.percentile(values, 0.5) == 10)
        #expect(BenchSummary.percentile(values, 0.95) == 19)
        #expect(BenchSummary.percentile([42], 0.95) == 42)
        #expect(BenchSummary.percentile([], 0.5) == nil)
    }

    @Test func summaryGroupsByAppAndScenario() {
        let ok = result(.enterFullscreen, true, 800)
        let bad = result(.enterFullscreen, false, 5000)
        let summaries = BenchSummary.make(from: [
            report(scenario: "a", steps: [ok]),
            report(scenario: "a", steps: [bad]),
            report(scenario: "b", steps: [ok]),
            report("com.apple.dt.Xcode", scenario: "a", steps: [ok]),
        ])
        #expect(summaries.map(\.scenario) == ["a", "b", "a"])
        let first = summaries[0]
        #expect(first.app == "com.apple.Safari")
        #expect(first.runs == 2 && first.successes == 1)
        #expect(first.successRate == 0.5)
        #expect(first.p50Milliseconds == 800)
        #expect(first.failuresByStep == [.enterFullscreen: 1])
    }
}
