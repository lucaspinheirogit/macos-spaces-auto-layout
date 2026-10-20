import AppKit

/// Puts an app's window on a display, maximized or in native fullscreen, checking every step.
/// Stops at the first step whose check fails.
@MainActor
public struct Placement {
    /// How long to wait for an existing window before reopening the app.
    public var noWindowGrace: Duration = .seconds(2)
    public var windowTimeout: Duration = .seconds(10)
    public var fullscreenTimeout: Duration = .seconds(5)
    public var moveTimeout: Duration = .seconds(2)
    public var maximizeTimeout: Duration = .milliseconds(500)
    /// How long the desktop (menu bar status items) may take to come back after leaving fullscreen.
    public var desktopTimeout: Duration = .seconds(2)
    /// A "done" signal must hold this long before a step counts as finished.
    public var settleTime: Duration = .milliseconds(300)
    public var moveAttempts = 3
    /// Pause before each fullscreen retry; one more attempt than there are pauses.
    public var fullscreenBackoff: [Duration] = [.milliseconds(500), .seconds(1)]

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
        func record(_ name: String, since start: ContinuousClock.Instant, ok: Bool, attempts: Int = 1, _ detail: String = "") -> Bool {
            let step = StepResult(name: name, ok: ok, ms: (ContinuousClock.now - start).milliseconds, attempts: attempts, detail: detail)
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
        func findWindow(timeout: Duration) async -> Bool {
            await Wait.until(timeout: timeout) {
                found = AXApp(app).standardWindow
                return found != nil
            }
        }
        // Apps launched in the background, or with all windows closed, often have no window:
        // reopen them (like a Dock click) so they create one.
        var reopened = false
        if !(await findWindow(timeout: noWindowGrace)) {
            reopened = true
            try? await AppLauncher.reopen(bundleId)
            _ = await findWindow(timeout: windowTimeout)
        }
        let appDetail = found == nil ? "no standard window" : "\(reopened ? "reopened; " : "")\(found?.title ?? "")"
        guard record("app", since: start, ok: found != nil, appDetail), let window = found
        else { return steps }

        // 2. Nothing to do if it's already fullscreen on the target.
        if mode == .fullscreen, window.isFullScreen == true, isOnTarget(window) {
            _ = record("already-done", since: .now, ok: true)
            return steps
        }

        // 3. Leave fullscreen first: a fullscreen window can't be moved.
        if window.isFullScreen == true {
            start = .now
            let source = window.frame.flatMap { Displays.display(for: $0, in: displays) } ?? target
            let error = window.setFullScreen(false)
            let exited = await Wait.until(timeout: fullscreenTimeout) { window.isFullScreen == false }
            // The attribute flips at once; the desktop is back when the menu bar status items reappear.
            // With an always-hidden menu bar they never do, so fall back to the frame settling.
            let desktopBack = exited ? await Wait.until(timeout: desktopTimeout, stableFor: settleTime) {
                Displays.onScreen(on: source, excludingPID: app.processIdentifier).statusItems > 0
            } : false
            let settled = exited ? await Wait.forStableFrame(window, stableFor: settleTime, timeout: fullscreenTimeout) : false
            let exitDetail = !exited ? "still fullscreen (AXError \(error.rawValue))"
                : !settled ? "frame still changing"
                : desktopBack ? "" : "status items never reappeared (menu bar hidden?)"
            guard record("exit-fullscreen", since: start, ok: exited && settled, exitDetail)
            else { return steps }
        }

        // 4. Move onto the target's visible area.
        start = .now
        var moved = false
        var attempts = 0
        while !moved && attempts < moveAttempts {
            attempts += 1
            window.setFrame(target.visibleBounds)
            // The frame we set reads back at once, but right after leaving fullscreen, entering it again that soon
            // lands on the old display. Waiting for the frame to hold fixes that (see finding 8 in the spike results).
            moved = await Wait.until(timeout: moveTimeout, stableFor: settleTime) { isOnTarget(window) }
        }
        guard record("move", since: start, ok: moved, attempts: attempts, "frame=\(Geometry.describe(window.frame))")
        else { return steps }

        // 5a. Maximized: the frame should match the visible area. macOS clamps a size to what fits at the
        // window's position *at that moment*; if the app applied the move late, the size got clamped, so
        // set the frame again.
        if mode == .maximized {
            start = .now
            var filled = false
            attempts = 0
            while !filled && attempts < moveAttempts {
                if attempts > 0 { window.setFrame(target.visibleBounds) }
                attempts += 1
                filled = await Wait.until(timeout: maximizeTimeout) {
                    window.frame.map { Geometry.approximatelyEqual($0, target.visibleBounds) } ?? false
                }
            }
            _ = record("verify-maximized", since: start, ok: filled, attempts: attempts, "frame=\(Geometry.describe(window.frame))")
            return steps
        }

        // 5b. Fullscreen: bring it forward, then enter fullscreen, retrying with backoff. A retry brings the app
        // forward again (another app's fullscreen Space can hide the signals) and only sets the attribute again
        // if it didn't stick: setting true on a window that already reads true does nothing.
        start = .now
        var entered = false
        attempts = 0
        while !entered && attempts <= fullscreenBackoff.count {
            if attempts > 0 { try? await Task.sleep(for: fullscreenBackoff[attempts - 1]) }
            attempts += 1
            app.activate()
            window.raise()
            if window.isFullScreen != true { window.setFullScreen(true) }
            // The attribute flips at once; the fullscreen Space is really showing once the menu bar status items
            // and other apps' windows are gone from the target display, steadily.
            entered = await Wait.until(timeout: fullscreenTimeout, stableFor: settleTime) {
                guard window.isFullScreen == true, isOnTarget(window),
                      window.frame.map({ Geometry.fillsDisplay($0, bounds: target.bounds) }) ?? false
                else { return false }
                let screen = Displays.onScreen(on: target, excludingPID: app.processIdentifier)
                return screen.statusItems == 0 && screen.otherAppWindows == 0
            }
        }
        _ = record("enter-fullscreen", since: start, ok: entered, attempts: attempts,
                   "fullscreen=\(window.isFullScreen.map(String.init) ?? "?") frame=\(Geometry.describe(window.frame))")
        return steps
    }
}
