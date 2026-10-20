import Foundation
import WindowEngine

/// One attempt to place one app.
public struct PlacementReport: Sendable, Equatable {
    public let app: String
    public let run: Int
    public let scenario: String
    public let fromDisplay: Int?
    public let toDisplay: Int
    public let mode: PlacementMode
    public let steps: [StepResult]

    public init(
        app: String, run: Int, scenario: String, fromDisplay: Int?, toDisplay: Int, mode: PlacementMode,
        steps: [StepResult]
    ) {
        self.app = app
        self.run = run
        self.scenario = scenario
        self.fromDisplay = fromDisplay
        self.toDisplay = toDisplay
        self.mode = mode
        self.steps = steps
    }

    public var success: Bool { !steps.isEmpty && steps.allSatisfy(\.ok) }
    public var totalMs: Int { steps.reduce(0) { $0 + $1.ms } }
    public var failedStep: String? { steps.first { !$0.ok }?.name }

    public static let csvHeader = "app,run,scenario,from_display,to_display,mode,success,failed_step,total_ms,steps"

    /// `steps` is `name:ms:ok` joined by `|`, with `:attempts` appended when a step took more than one,
    /// e.g. `app:12:1|enter-fullscreen:6424:1:2`.
    public var csvRow: String {
        let stepsField = steps.map { step in
            "\(step.name):\(step.ms):\(step.ok ? 1 : 0)" + (step.attempts > 1 ? ":\(step.attempts)" : "")
        }.joined(separator: "|")
        return [
            app, String(run), scenario, fromDisplay.map(String.init) ?? "", String(toDisplay),
            mode.rawValue, success ? "1" : "0", failedStep ?? "", String(totalMs), stepsField,
        ].map(Self.csvEscape).joined(separator: ",")
    }

    static func csvEscape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
