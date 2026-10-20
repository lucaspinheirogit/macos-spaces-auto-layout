import AppKit
import WindowKit

let usage = """
    Usage: fullscreen-spike <command>

      displays                                   List displays and the separate-Spaces setting
      windows <bundleId>                         List an app's windows
      place <bundleId> [--display N] [--mode fullscreen|maximized]
                                                 Place one app once and print each step
      bench [bundleId…] [--runs N]               Repeat placements and write results/<timestamp>.csv
                                                 (default: all test apps, 20 runs each)
    """

let testApps = [
    "company.thebrowser.Browser",       // Arc
    "com.todesktop.230313mzl4w4u92",    // Cursor
    "com.tinyspeck.slackmacgap",        // Slack
    "com.apple.Safari",
    "com.apple.dt.Xcode",
    "com.figma.Desktop",
    "dev.warp.Warp-Stable",
]

let pauseBetweenRuns: Duration = .seconds(1)

// MARK: - Arguments

var arguments = Array(CommandLine.arguments.dropFirst())

func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    let value = arguments[index + 1]
    arguments.removeSubrange(index...index + 1)
    return value
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func requireAccessibility() {
    guard Accessibility.isTrusted(prompt: true) else {
        fail("""
            Accessibility permission is missing. Grant it to your terminal app in
            System Settings → Privacy & Security → Accessibility, then run this again.
            """)
    }
}

func describe(_ frame: CGRect?) -> String {
    guard let f = frame else { return "?" }
    return "\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height))"
}

func printStep(_ step: StepResult) {
    let name = step.name.padding(toLength: 18, withPad: " ", startingAt: 0)
    print("  \(step.ok ? "✓" : "✗") \(name) \(String(format: "%5d", step.ms)) ms  \(step.detail)")
}

// MARK: - Commands

func listDisplays() {
    let displays = Displays.current()
    for d in displays {
        let flags = [d.isMain ? "main" : nil, d.isBuiltin ? "built-in" : nil].compactMap { $0 }.joined(separator: ", ")
        print("[\(d.index)] \(d.name) (\(flags))")
        print("    uuid    \(d.uuid)")
        print("    bounds  \(describe(d.bounds))   visible \(describe(d.visibleBounds))")
    }
    print("Displays have separate Spaces: \(Displays.separateSpacesEnabled ? "on" : "OFF (fullscreen per display won't work)")")
}

func listWindows(_ bundleId: String) {
    requireAccessibility()
    guard let app = AppLauncher.running(bundleId) else { fail("\(bundleId) is not running") }
    let displays = Displays.current()
    let windows = AXApp(app).windows
    if windows.isEmpty { print("No windows visible to Accessibility (windows on other Spaces may be hidden).") }
    for (i, w) in windows.enumerated() {
        let display = w.frame.flatMap { Displays.display(for: $0, in: displays) }.map { "[\($0.index)]" } ?? "?"
        print("#\(i) \"\(w.title ?? "")\" \(w.subrole ?? "?") frame=\(describe(w.frame)) fullscreen=\(w.isFullScreen.map(String.init) ?? "?") display=\(display)")
    }
}

func displayIndex(of window: AXWindow?, in displays: [DisplayInfo]) -> Int? {
    window?.frame.flatMap { Displays.display(for: $0, in: displays)?.index }
}

func place(_ bundleId: String, displayIndex: Int, mode: PlacementMode) async {
    requireAccessibility()
    let displays = Displays.current()
    guard displays.indices.contains(displayIndex) else { fail("No display \(displayIndex). Run `displays`.") }
    print("\(bundleId) → [\(displayIndex)] \(displays[displayIndex].name), \(mode.rawValue)")
    let steps = await Placement().place(bundleId, on: displays[displayIndex], among: displays, mode: mode, onStep: printStep)
    let report = PlacementReport(app: bundleId, run: 1, scenario: "manual", fromDisplay: nil,
                                 toDisplay: displayIndex, mode: mode, steps: steps)
    print(report.success ? "OK in \(report.totalMs) ms" : "FAILED at \(report.failedStep ?? "?")")
}

/// What an app looked like before the bench, so it can be put back afterwards.
struct InitialState {
    let fullscreen: Bool
    let displayIndex: Int
    let frame: CGRect?
}

func restore(_ bundleId: String, to state: InitialState, displays: [DisplayInfo]) async {
    let placement = Placement()
    let target = displays[min(state.displayIndex, displays.count - 1)]
    if state.fullscreen {
        _ = await placement.place(bundleId, on: target, among: displays, mode: .fullscreen)
        return
    }
    _ = await placement.place(bundleId, on: target, among: displays, mode: .maximized)
    if let frame = state.frame, let app = AppLauncher.running(bundleId) {
        AXApp(app).standardWindow?.setFrame(frame)
    }
}

func bench(_ bundleIds: [String], runs: Int) async {
    requireAccessibility()
    let displays = Displays.current()
    let multiDisplay = displays.count > 1
    let placement = Placement()
    var reports: [PlacementReport] = []

    print("Bench: \(bundleIds.count) apps × \(runs) runs on \(displays.count) display(s). Don't touch the mouse or keyboard.")
    for bundleId in bundleIds {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil else {
            print("\n\(bundleId): not installed, skipped")
            continue
        }
        print("\n\(bundleId)")

        // Remember how the app looked, then put it in a known starting state (not recorded).
        let wasRunning = AppLauncher.running(bundleId) != nil
        let before = wasRunning ? AppLauncher.running(bundleId).flatMap { AXApp($0).standardWindow } : nil
        let initial = InitialState(
            fullscreen: before?.isFullScreen ?? false,
            displayIndex: displayIndex(of: before, in: displays) ?? 0,
            frame: before?.frame
        )
        let baselineMode: PlacementMode = multiDisplay ? .fullscreen : .maximized
        let baseline = await placement.place(bundleId, on: displays[0], among: displays, mode: baselineMode)
        if !baseline.allSatisfy(\.ok) { print("  ! baseline placement failed; continuing anyway") }

        for run in 1...runs {
            try? await Task.sleep(for: pauseBetweenRuns)
            let window = AppLauncher.running(bundleId).flatMap { AXApp($0).standardWindow }
            let from = displayIndex(of: window, in: displays)
            let mode: PlacementMode
            let to: Int
            let scenario: String
            if multiDisplay {
                mode = .fullscreen
                to = ((from ?? 0) + 1) % displays.count
                scenario = "fullscreen-move"
            } else {
                mode = run.isMultiple(of: 2) ? .maximized : .fullscreen
                to = 0
                scenario = mode == .fullscreen ? "normal-to-fullscreen" : "fullscreen-to-maximized"
            }
            let steps = await placement.place(bundleId, on: displays[to], among: displays, mode: mode)
            let report = PlacementReport(app: bundleId, run: run, scenario: scenario, fromDisplay: from,
                                         toDisplay: to, mode: mode, steps: steps)
            reports.append(report)
            let outcome = report.success ? "✓" : "✗ \(report.failedStep ?? "?"): \(steps.last?.detail ?? "")"
            print("  #\(run) \(scenario) \(report.totalMs) ms \(outcome)")
        }

        try? await Task.sleep(for: pauseBetweenRuns)
        if wasRunning {
            await restore(bundleId, to: initial, displays: displays)
        } else {
            AppLauncher.running(bundleId)?.terminate()
        }
    }

    writeCSV(reports)
    printSummary(reports)
}

func writeCSV(_ reports: [PlacementReport]) {
    let resultsDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("results")
    let stamp = Date.now.ISO8601Format(.iso8601.year().month().day().dateSeparator(.dash)
        .time(includingFractionalSeconds: false).timeSeparator(.omitted).timeZone(separator: .omitted))
    let url = resultsDir.appendingPathComponent("bench-\(stamp).csv")
    let csv = ([PlacementReport.csvHeader] + reports.map(\.csvRow)).joined(separator: "\n") + "\n"
    do {
        try FileManager.default.createDirectory(at: resultsDir, withIntermediateDirectories: true)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        print("\nWrote \(url.path)")
    } catch {
        print("\nCould not write results: \(error)")
    }
}

func printSummary(_ reports: [PlacementReport]) {
    print("\napp | scenario | success | p50 ms | p95 ms | failures")
    print("--- | --- | --- | --- | --- | ---")
    for s in BenchSummary.make(from: reports) {
        let rate = String(format: "%d/%d (%.0f%%)", s.successes, s.runs, s.successRate * 100)
        let failures = s.failuresByStep.sorted { $0.key < $1.key }.map { "\($0.key)×\($0.value)" }.joined(separator: ", ")
        print("\(s.app) | \(s.scenario) | \(rate) | \(s.p50Ms.map(String.init) ?? "-") | \(s.p95Ms.map(String.init) ?? "-") | \(failures.isEmpty ? "-" : failures)")
    }
}

// MARK: - Main

guard let command = arguments.first else { fail(usage) }
arguments.removeFirst()

switch command {
case "displays":
    listDisplays()
case "windows":
    guard let bundleId = arguments.first else { fail(usage) }
    listWindows(bundleId)
case "place":
    let displayIndex = option("--display").flatMap(Int.init) ?? 0
    guard let mode = PlacementMode(rawValue: option("--mode") ?? "fullscreen") else { fail(usage) }
    guard let bundleId = arguments.first else { fail(usage) }
    await place(bundleId, displayIndex: displayIndex, mode: mode)
case "bench":
    let runs = option("--runs").flatMap(Int.init) ?? 20
    guard runs > 0 else { fail("--runs must be at least 1") }
    await bench(arguments.isEmpty ? testApps : arguments, runs: runs)
default:
    fail(usage)
}
