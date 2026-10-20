import AppKit
import BenchReport
import WindowEngine

let usage = """
    Usage: fullscreen-spike <command>

      displays                                   List displays and the separate-Spaces setting
      windows <bundleId>                         List an app's windows
      trace <bundleId> [--button]                Toggle fullscreen once and sample it every 50 ms
                                                 (--button: press the green button instead of AXFullScreen)
      place <bundleId> [--display N] [--mode fullscreen|maximized]
                                                 Place one app once and print each step
      bench [bundleId…] [--runs N]               Repeat placements and write results/<timestamp>.csv
                                                 (default: all test apps, 20 runs each)
    """

let testApps = [
    "company.thebrowser.Browser",  // Arc
    "com.todesktop.230313mzl4w4u92",  // Cursor
    "com.tinyspeck.slackmacgap",  // Slack
    "com.apple.Safari",
    "com.apple.dt.Xcode",
    "com.figma.Desktop",
    "dev.warp.Warp-Stable",
]

let pauseBetweenRuns: Duration = .seconds(1)

// MARK: - Arguments

var arguments = Array(CommandLine.arguments.dropFirst())

/// Removes `name` and its value from the arguments and returns the value, or nil if the option isn't given.
func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name) else { return nil }
    guard index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") else { fail("\(name) needs a value") }
    let value = arguments[index + 1]
    arguments.removeSubrange(index...index + 1)
    return value
}

func intOption(_ name: String, default defaultValue: Int) -> Int {
    guard let raw = option(name) else { return defaultValue }
    guard let value = Int(raw) else { fail("\(name) must be a whole number, got \"\(raw)\"") }
    return value
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func requireAccessibility() {
    guard AccessibilityPermission.isTrusted(prompt: true) else {
        fail(
            """
            Accessibility permission is missing. Grant it to your terminal app in
            System Settings → Privacy & Security → Accessibility, then run this again.
            """)
    }
}

func printStep(_ step: PlacementStepResult) {
    let name = step.step.rawValue.padding(toLength: 18, withPad: " ", startingAt: 0)
    let attempts = step.attempts > 1 ? "attempts=\(step.attempts) " : ""
    print(
        "  \(step.succeeded ? "✓" : "✗") \(name) \(String(format: "%5d", step.elapsedMilliseconds)) ms  \(attempts)\(step.diagnosticDetail)"
    )
}

// MARK: - Commands

func connectedDisplays() -> [ConnectedDisplay] {
    let displays: [ConnectedDisplay]
    do {
        displays = try ConnectedDisplays.current()
    } catch {
        fail("\(error)")
    }
    guard !displays.isEmpty else { fail("No active displays.") }
    return displays
}

func listDisplays() {
    let displays = connectedDisplays()
    for d in displays {
        let flags = [d.isMain ? "main" : nil, d.isBuiltin ? "built-in" : nil].compactMap { $0 }.joined(separator: ", ")
        print("[\(d.index)] \(d.name) (\(flags))")
        print("    uuid    \(d.uuid)")
        print(
            "    bounds  \(ScreenGeometry.debugFrameDescription(d.bounds))   visible \(ScreenGeometry.debugFrameDescription(d.visibleBounds))"
        )
    }
    print(
        "Displays have separate Spaces: \(ConnectedDisplays.separateSpacesEnabled ? "on" : "OFF (fullscreen per display won't work)")"
    )
}

func listWindows(_ bundleId: String) {
    requireAccessibility()
    guard let app = AppLauncher.runningApplication(bundleId: bundleId) else { fail("\(bundleId) is not running") }
    let displays = connectedDisplays()
    let windows = AccessibilityApplication(app).windows
    if windows.isEmpty { print("No windows visible to Accessibility (windows on other Spaces may be hidden).") }
    for (i, w) in windows.enumerated() {
        let frame = try? w.frame
        let display =
            frame.flatMap { ConnectedDisplays.display(containing: $0, in: displays) }.map { "[\($0.index)]" } ?? "?"
        let fullscreen = (try? w.isFullScreen).map(String.init) ?? "?"
        print(
            "#\(i) \"\(w.title ?? "")\" \(w.subrole ?? "?") frame=\(ScreenGeometry.debugFrameDescription(frame)) fullscreen=\(fullscreen) display=\(display)"
        )
    }
}

func displayIndex(of window: AccessibilityWindow?, in displays: [ConnectedDisplay]) -> Int? {
    (try? window?.frame).flatMap { ConnectedDisplays.display(containing: $0, in: displays)?.index }
}

func place(_ bundleId: String, displayIndex: Int, mode: WindowPlacementMode) async throws {
    requireAccessibility()
    let displays = connectedDisplays()
    guard displays.indices.contains(displayIndex) else { fail("No display \(displayIndex). Run `displays`.") }
    print("\(bundleId) → [\(displayIndex)] \(displays[displayIndex].name), \(mode.rawValue)")
    let steps = try await WindowPlacer().placeStandardWindow(
        ofBundleId: bundleId, onDisplay: displays[displayIndex], among: displays, mode: mode, onStep: printStep)
    let report = PlacementReport(
        app: bundleId, run: 1, scenario: "manual", fromDisplay: nil,
        toDisplay: displayIndex, mode: mode, steps: steps)
    print(report.success ? "OK in \(report.totalMilliseconds) ms" : "FAILED at \(report.failedStep?.rawValue ?? "?")")
}

/// Toggles fullscreen once and samples what's observable every 50 ms, to see when the transition really ends.
func trace(_ bundleId: String, useButton: Bool) async throws {
    requireAccessibility()
    guard let app = AppLauncher.runningApplication(bundleId: bundleId),
        let window = AccessibilityApplication(app).mainOrFirstStandardWindow
    else {
        fail("\(bundleId) has no standard window")
    }
    let displays = connectedDisplays()
    guard let display = (try? window.frame).flatMap({ ConnectedDisplays.display(containing: $0, in: displays) })
    else {
        fail("window is off-screen")
    }
    let target = !((try? window.isFullScreen) ?? false)
    print(
        "\(useButton ? "Pressing the fullscreen button" : "Setting AXFullScreen=\(target)") on \"\(window.title ?? "")\""
    )
    print("    ms  attr   status others  frame")
    if !app.activate() { print("activate() failed") }
    try? window.raise()
    let start = ContinuousClock.now
    do {
        if useButton { try window.pressFullScreenButton() } else { try window.setFullScreen(target) }
    } catch {
        print(error)
    }
    while ContinuousClock.now - start < .milliseconds(2500) {
        let ms = (ContinuousClock.now - start).wholeMilliseconds
        let attr = (try? window.isFullScreen).map(String.init) ?? "?"
        let screen = FullscreenSpaceSignals.onScreenWindowCounts(
            in: CoreGraphicsWindowList().onScreenWindows(), onDisplayWithBounds: display.bounds,
            excludingProcessIdentifier: app.processIdentifier)
        print(
            String(format: "%6d", ms), attr.padding(toLength: 6, withPad: " ", startingAt: 0),
            String(format: "%6d %6d ", screen.statusItems, screen.otherAppWindows),
            ScreenGeometry.debugFrameDescription(try? window.frame))
        try await Task.sleep(for: .milliseconds(50))
    }
}

/// What an app looked like before the bench, so it can be put back afterwards.
struct InitialState {
    let fullscreen: Bool
    let displayIndex: Int
    let frame: CGRect?
}

func restore(_ bundleId: String, to state: InitialState, displays: [ConnectedDisplay]) async throws {
    guard !displays.isEmpty else { return }
    let placer = WindowPlacer()
    let target = displays[min(state.displayIndex, displays.count - 1)]
    if state.fullscreen {
        _ = try await placer.placeStandardWindow(
            ofBundleId: bundleId, onDisplay: target, among: displays, mode: .fullscreen)
        return
    }
    _ = try await placer.placeStandardWindow(
        ofBundleId: bundleId, onDisplay: target, among: displays, mode: .maximized)
    if let frame = state.frame, let app = AppLauncher.runningApplication(bundleId: bundleId) {
        try? AccessibilityApplication(app).mainOrFirstStandardWindow?.setFrame(frame)
    }
}

func bench(_ bundleIds: [String], runs: Int) async throws {
    requireAccessibility()
    let displays = connectedDisplays()
    let multiDisplay = displays.count > 1
    let placer = WindowPlacer()
    var reports: [PlacementReport] = []

    print(
        "Bench: \(bundleIds.count) apps × \(runs) runs on \(displays.count) display(s). Don't touch the mouse or keyboard."
    )
    for bundleId in bundleIds {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil else {
            print("\n\(bundleId): not installed, skipped")
            continue
        }
        print("\n\(bundleId)")

        // Remember how the app looked, then put it in a known starting state (not recorded).
        let wasRunning = AppLauncher.runningApplication(bundleId: bundleId) != nil
        let before =
            wasRunning
            ? AppLauncher.runningApplication(bundleId: bundleId).flatMap {
                AccessibilityApplication($0).mainOrFirstStandardWindow
            } : nil
        let initial = before.map { window in
            InitialState(
                fullscreen: (try? window.isFullScreen) ?? false,
                displayIndex: displayIndex(of: window, in: displays) ?? 0,
                frame: try? window.frame
            )
        }
        let baselineMode: WindowPlacementMode = multiDisplay ? .fullscreen : .maximized
        let baseline = try await placer.placeStandardWindow(
            ofBundleId: bundleId, onDisplay: displays[0], among: displays, mode: baselineMode)
        if !baseline.allSatisfy(\.succeeded) { print("  ! baseline placement failed; continuing anyway") }

        for run in 1...runs {
            try await Task.sleep(for: pauseBetweenRuns)
            let window = AppLauncher.runningApplication(bundleId: bundleId).flatMap {
                AccessibilityApplication($0).mainOrFirstStandardWindow
            }
            let from = displayIndex(of: window, in: displays)
            let mode: WindowPlacementMode
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
            let steps = try await placer.placeStandardWindow(
                ofBundleId: bundleId, onDisplay: displays[to], among: displays, mode: mode)
            let report = PlacementReport(
                app: bundleId, run: run, scenario: scenario, fromDisplay: from,
                toDisplay: to, mode: mode, steps: steps)
            reports.append(report)
            let outcome =
                report.success ? "✓" : "✗ \(report.failedStep?.rawValue ?? "?"): \(steps.last?.diagnosticDetail ?? "")"
            print("  #\(run) \(scenario) \(report.totalMilliseconds) ms \(outcome)")
        }

        try await Task.sleep(for: pauseBetweenRuns)
        if let initial {
            try await restore(bundleId, to: initial, displays: displays)
        } else if wasRunning {
            // It had no window before; close the one the bench made it open.
            try? AppLauncher.runningApplication(bundleId: bundleId).flatMap {
                AccessibilityApplication($0).mainOrFirstStandardWindow
            }?.close()
        } else {
            AppLauncher.runningApplication(bundleId: bundleId)?.terminate()
        }
    }

    writeCSV(reports)
    printSummary(reports)
}

func writeCSV(_ reports: [PlacementReport]) {
    let resultsDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("results")
    let stamp = Date.now.ISO8601Format(
        .iso8601.year().month().day().dateSeparator(.dash)
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
        let failures = s.failuresByStep.sorted { $0.key.rawValue < $1.key.rawValue }.map {
            "\($0.key.rawValue)×\($0.value)"
        }.joined(separator: ", ")
        print(
            "\(s.app) | \(s.scenario) | \(rate) | \(s.p50Milliseconds.map(String.init) ?? "-") | \(s.p95Milliseconds.map(String.init) ?? "-") | \(failures.isEmpty ? "-" : failures)"
        )
    }
}

// MARK: - Main

/// Runs the command, then exits. Window-server state (the on-screen window list, Accessibility notifications)
/// only stays current while AppKit's event loop runs, so the command runs inside a normal NSApplication loop,
/// like the real app will.
func run() async throws {
    guard let command = arguments.first else { fail(usage) }
    arguments.removeFirst()

    switch command {
    case "displays":
        listDisplays()
    case "windows":
        guard let bundleId = arguments.first else { fail(usage) }
        listWindows(bundleId)
    case "trace":
        let useButton = arguments.contains("--button")
        arguments.removeAll { $0 == "--button" }
        guard let bundleId = arguments.first else { fail(usage) }
        try await trace(bundleId, useButton: useButton)
    case "place":
        let displayIndex = intOption("--display", default: 0)
        guard let mode = WindowPlacementMode(rawValue: option("--mode") ?? "fullscreen") else { fail(usage) }
        guard let bundleId = arguments.first else { fail(usage) }
        try await place(bundleId, displayIndex: displayIndex, mode: mode)
    case "bench":
        let runs = intOption("--runs", default: 20)
        guard runs > 0 else { fail("--runs must be at least 1") }
        try await bench(arguments.isEmpty ? testApps : arguments, runs: runs)
    default:
        fail(usage)
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)  // no Dock icon or menu bar
Task {
    do {
        try await run()
    } catch {
        fail("\(error)")
    }
    exit(0)
}
application.run()
