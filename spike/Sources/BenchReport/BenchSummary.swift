import Foundation
import WindowEngine

/// Per-app, per-scenario aggregate of bench runs.
public struct BenchSummary: Sendable, Equatable {
    public let app: String
    public let scenario: String
    public let runs: Int
    public let successes: Int
    public let p50Milliseconds: Int?
    public let p95Milliseconds: Int?
    public let failuresByStep: [PlacementStep: Int]

    public var successRate: Double { runs == 0 ? 0 : Double(successes) / Double(runs) }

    public static func make(from reports: [PlacementReport]) -> [BenchSummary] {
        let groups = Dictionary(grouping: reports) { "\($0.app)\u{0}\($0.scenario)" }
        return groups.values.map { group in
            let successful = group.filter(\.success).map(\.totalMilliseconds).sorted()
            var failures: [PlacementStep: Int] = [:]
            for report in group { if let step = report.failedStep { failures[step, default: 0] += 1 } }
            return BenchSummary(
                app: group[0].app,
                scenario: group[0].scenario,
                runs: group.count,
                successes: successful.count,
                p50Milliseconds: percentile(successful, 0.5),
                p95Milliseconds: percentile(successful, 0.95),
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
