import Testing
@testable import WindowKit

struct ReportTests {
    private func report(_ app: String = "com.apple.Safari", scenario: String = "s", steps: [StepResult]) -> PlacementReport {
        PlacementReport(app: app, run: 1, scenario: scenario, fromDisplay: 0, toDisplay: 1, mode: .fullscreen, steps: steps)
    }

    @Test func successNeedsEveryStepOk() {
        #expect(report(steps: [StepResult(name: "app", ok: true, ms: 5), StepResult(name: "move", ok: true, ms: 10)]).success)
        #expect(!report(steps: [StepResult(name: "app", ok: true, ms: 5), StepResult(name: "move", ok: false, ms: 10)]).success)
        #expect(!report(steps: []).success)
    }

    @Test func totalsAndFailedStep() {
        let r = report(steps: [
            StepResult(name: "app", ok: true, ms: 5),
            StepResult(name: "enter-fullscreen", ok: false, ms: 900),
        ])
        #expect(r.totalMs == 905)
        #expect(r.failedStep == "enter-fullscreen")
    }

    @Test func csvRowMatchesHeader() {
        let r = report(steps: [StepResult(name: "app", ok: true, ms: 5, detail: "ignored, not in CSV")])
        #expect(r.csvRow == "com.apple.Safari,1,s,0,1,fullscreen,1,,5,app:5:1")
        #expect(r.csvRow.split(separator: ",", omittingEmptySubsequences: false).count
            == PlacementReport.csvHeader.split(separator: ",").count)
    }

    @Test func csvStepsListAttemptsOnlyWhenRetried() {
        let r = report(steps: [
            StepResult(name: "move", ok: true, ms: 3),
            StepResult(name: "enter-fullscreen", ok: true, ms: 6424, attempts: 2),
        ])
        #expect(r.csvRow.hasSuffix(",move:3:1|enter-fullscreen:6424:1:2"))
    }

    @Test func csvEscapesSpecialCharacters() {
        #expect(PlacementReport.csvEscape("plain") == "plain")
        #expect(PlacementReport.csvEscape("a,b") == "\"a,b\"")
        #expect(PlacementReport.csvEscape("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }

    @Test func percentileUsesNearestRank() {
        let values = Array(1...20)
        #expect(BenchSummary.percentile(values, 0.5) == 10)
        #expect(BenchSummary.percentile(values, 0.95) == 19)
        #expect(BenchSummary.percentile([42], 0.95) == 42)
        #expect(BenchSummary.percentile([], 0.5) == nil)
    }

    @Test func summaryGroupsByAppAndScenario() {
        let ok = StepResult(name: "enter-fullscreen", ok: true, ms: 800)
        let bad = StepResult(name: "enter-fullscreen", ok: false, ms: 5000)
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
        #expect(first.p50Ms == 800)
        #expect(first.failuresByStep == ["enter-fullscreen": 1])
    }
}
