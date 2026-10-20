import AppKit

/// Puts an app's window on a display, maximized or in native fullscreen, checking every step.
/// Stops at the first step whose check fails.
@MainActor
public struct Placement {
    public var windowTimeout: Duration = .seconds(10)
    public var fullscreenTimeout: Duration = .seconds(5)
    public var moveTimeout: Duration = .seconds(2)
    public var moveAttempts = 3
    public var fullscreenBackoff: [Duration] = [.milliseconds(500), .seconds(1), .seconds(2)]

    public init() {}

    /// - Parameter onStep: called as each step finishes, for live output.
    public func place(
        _ bundleId: String,
        on target: DisplayInfo,
        among displays: [DisplayInfo],
        mode: PlacementMode,
        onStep: (StepResult) -> Void = { _ in }
    ) async -> [StepResult] {
        var steps: [StepResult] = []
        func record(_ name: String, since start: ContinuousClock.Instant, ok: Bool, _ detail: String = "") -> Bool {
            let step = StepResult(name: name, ok: ok, ms: (ContinuousClock.now - start).milliseconds, detail: detail)
            steps.append(step)
            onStep(step)
            return ok
        }
        func isOnTarget(_ window: AXWindow) -> Bool {
            window.frame.flatMap { Displays.display(for: $0, in: displays)?.index } == target.index
        }

        // 1. Find (or launch) the app and its window.
        var start = ContinuousClock.now
        let app: NSRunningApplication
        do {
            app = try await AppLauncher.runningOrLaunch(bundleId)
        } catch {
            _ = record("app", since: start, ok: false, "\(error)")
            return steps
        }
        var found: AXWindow?
        _ = await Wait.until(timeout: windowTimeout) {
            found = AXApp(app).standardWindow
            return found != nil
        }
        guard record("app", since: start, ok: found != nil, found == nil ? "no standard window" : found?.title ?? ""),
              let window = found
        else { return steps }

        // 2. Nothing to do if it's already fullscreen on the target.
        if mode == .fullscreen, window.isFullScreen == true, isOnTarget(window) {
            _ = record("already-done", since: .now, ok: true)
            return steps
        }

        // 3. Leave fullscreen first: a fullscreen window can't be moved.
        if window.isFullScreen == true {
            start = .now
            let error = window.setFullScreen(false)
            let exited = await Wait.until(timeout: fullscreenTimeout) { window.isFullScreen == false }
            let settled = exited ? await Wait.forStableFrame(window, timeout: fullscreenTimeout) : false
            guard record("exit-fullscreen", since: start, ok: exited && settled,
                         exited ? (settled ? "" : "frame still changing") : "still fullscreen (AXError \(error.rawValue))")
            else { return steps }
        }

        // 4. Move onto the target's visible area.
        start = .now
        var moved = false
        var attempts = 0
        while !moved && attempts < moveAttempts {
            attempts += 1
            window.setFrame(target.visibleBounds)
            moved = await Wait.until(timeout: moveTimeout) { isOnTarget(window) }
        }
        guard record("move", since: start, ok: moved, "attempts=\(attempts) frame=\(describe(window.frame))")
        else { return steps }

        // 5a. Maximized: the frame should match the visible area.
        if mode == .maximized {
            start = .now
            let filled = await Wait.until(timeout: moveTimeout) {
                window.frame.map { Geometry.approximatelyEqual($0, target.visibleBounds) } ?? false
            }
            _ = record("verify-maximized", since: start, ok: filled, "frame=\(describe(window.frame))")
            return steps
        }

        // 5b. Fullscreen: bring it forward, then enter fullscreen, retrying with backoff.
        start = .now
        var entered = false
        attempts = 0
        while !entered && attempts < fullscreenBackoff.count {
            if attempts > 0 { try? await Task.sleep(for: fullscreenBackoff[attempts - 1]) }
            attempts += 1
            app.activate()
            window.raise()
            window.setFullScreen(true)
            entered = await Wait.until(timeout: fullscreenTimeout) {
                window.isFullScreen == true && isOnTarget(window)
                    && (window.frame.map { Geometry.fillsDisplay($0, bounds: target.bounds) } ?? false)
            }
        }
        _ = record("enter-fullscreen", since: start, ok: entered,
                   "attempts=\(attempts) fullscreen=\(window.isFullScreen.map(String.init) ?? "?") frame=\(describe(window.frame))")
        return steps
    }

    private func describe(_ frame: CGRect?) -> String {
        guard let f = frame else { return "?" }
        return "\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height))"
    }
}
