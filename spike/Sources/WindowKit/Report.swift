import Foundation

public enum PlacementMode: String, Sendable, CaseIterable {
    case fullscreen, maximized
}

public struct StepResult: Sendable, Equatable {
    public let name: String
    public let ok: Bool
    public let ms: Int
    public let detail: String

    public init(name: String, ok: Bool, ms: Int, detail: String = "") {
        self.name = name
        self.ok = ok
        self.ms = ms
        self.detail = detail
    }
}

/// One attempt to place one app.
public struct PlacementReport: Sendable, Equatable {
    public let app: String
    public let run: Int
    public let scenario: String
    public let fromDisplay: Int?
    public let toDisplay: Int
    public let mode: PlacementMode
    public let steps: [StepResult]

    public init(app: String, run: Int, scenario: String, fromDisplay: Int?, toDisplay: Int, mode: PlacementMode, steps: [StepResult]) {
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

    /// `steps` is `name:ms:ok` joined by `|`, e.g. `app:12:1|enter-fullscreen:810:1`.
    public var csvRow: String {
        let stepsField = steps.map { "\($0.name):\($0.ms):\($0.ok ? 1 : 0)" }.joined(separator: "|")
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

/// Per-app, per-scenario aggregate of bench runs.
public struct BenchSummary: Sendable, Equatable {
    public let app: String
    public let scenario: String
    public let runs: Int
    public let successes: Int
    public let p50Ms: Int?
    public let p95Ms: Int?
    public let failuresByStep: [String: Int]

    public var successRate: Double { runs == 0 ? 0 : Double(successes) / Double(runs) }

    public static func make(from reports: [PlacementReport]) -> [BenchSummary] {
        let groups = Dictionary(grouping: reports) { "\($0.app)\u{0}\($0.scenario)" }
        return groups.values.map { group in
            let successful = group.filter(\.success).map(\.totalMs).sorted()
            var failures: [String: Int] = [:]
            for report in group { if let step = report.failedStep { failures[step, default: 0] += 1 } }
            return BenchSummary(
                app: group[0].app,
                scenario: group[0].scenario,
                runs: group.count,
                successes: successful.count,
                p50Ms: percentile(successful, 0.5),
                p95Ms: percentile(successful, 0.95),
                failuresByStep: failures
            )
        }
        .sorted { ($0.app, $0.scenario) < ($1.app, $1.scenario) }
    }

    /// Nearest-rank percentile of sorted values.
    static func percentile(_ sorted: [Int], _ p: Double) -> Int? {
        guard !sorted.isEmpty else { return nil }
        let rank = Int((p * Double(sorted.count)).rounded(.up))
        return sorted[min(max(rank, 1), sorted.count) - 1]
    }
}
