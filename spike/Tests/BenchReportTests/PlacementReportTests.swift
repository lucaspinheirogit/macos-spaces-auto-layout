import Testing
import WindowEngine

@testable import BenchReport

func report(_ app: String = "com.apple.Safari", scenario: String = "s", steps: [PlacementStepResult])
    -> PlacementReport
{
    PlacementReport(
        app: app, run: 1, scenario: scenario, fromDisplay: 0, toDisplay: 1, mode: .fullscreen, steps: steps)
}

func result(_ step: PlacementStep, _ succeeded: Bool, _ milliseconds: Int, attempts: Int = 1, detail: String = "")
    -> PlacementStepResult
{
    PlacementStepResult(
        step: step, succeeded: succeeded, elapsedMilliseconds: milliseconds, attempts: attempts,
        diagnosticDetail: detail)
}

struct PlacementReportTests {
    @Test func successNeedsEveryStepToSucceed() {
        #expect(report(steps: [result(.app, true, 5), result(.move, true, 10)]).success)
        #expect(!report(steps: [result(.app, true, 5), result(.move, false, 10)]).success)
        #expect(!report(steps: []).success)
    }

    @Test func totalsAndFailedStep() {
        let r = report(steps: [result(.app, true, 5), result(.enterFullscreen, false, 900)])
        #expect(r.totalMilliseconds == 905)
        #expect(r.failedStep == .enterFullscreen)
    }

    @Test func csvRowMatchesHeader() {
        let r = report(steps: [result(.app, true, 5, detail: "ignored, not in CSV")])
        #expect(r.csvRow == "com.apple.Safari,1,s,0,1,fullscreen,1,,5,app:5:1")
        #expect(
            r.csvRow.split(separator: ",", omittingEmptySubsequences: false).count
                == PlacementReport.csvHeader.split(separator: ",").count)
    }

    @Test func csvStepsListAttemptsOnlyWhenRetried() {
        let r = report(steps: [result(.move, true, 3), result(.enterFullscreen, true, 6424, attempts: 2)])
        #expect(r.csvRow.hasSuffix(",move:3:1|enter-fullscreen:6424:1:2"))
    }

    @Test func stepNamesMatchTheExistingCSVFiles() {
        #expect(
            PlacementStep.allCases.map(\.rawValue) == [
                "app", "already-done", "exit-fullscreen", "move", "verify-maximized", "enter-fullscreen",
            ])
    }

    @Test func csvEscapesSpecialCharacters() {
        #expect(PlacementReport.csvEscape("plain") == "plain")
        #expect(PlacementReport.csvEscape("a,b") == "\"a,b\"")
        #expect(PlacementReport.csvEscape("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }
}
