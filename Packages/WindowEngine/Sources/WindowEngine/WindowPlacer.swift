import AppKit

/// Puts an app's window on a display, maximized or in native fullscreen, checking every step.
/// Stops at the first step whose check fails.
@MainActor
public struct WindowPlacer {
    /// How long to wait for an existing window before reopening the app.
    public var existingWindowTimeout: Duration = .seconds(2)
    /// How long to wait for a window after reopening the app.
    public var reopenedWindowTimeout: Duration = .seconds(10)
    /// How long entering or leaving fullscreen may take.
    public var fullscreenTransitionTimeout: Duration = .seconds(5)
    /// How long one move attempt may take to land on the target.
    public var moveAttemptTimeout: Duration = .seconds(2)
    /// How long one maximize attempt may take to fill the visible area.
    public var maximizeAttemptTimeout: Duration = .milliseconds(500)
    /// How long the desktop (menu bar status items) may take to come back after leaving fullscreen.
    public var desktopReturnTimeout: Duration = .seconds(2)
    /// A "done" signal must hold this long before a step counts as finished.
    public var settleTime: Duration = .milliseconds(300)
    /// Attempts for the move and maximize steps.
    public var maximumFrameAttempts = 3
    /// Pause before each fullscreen retry; one more attempt than there are pauses.
    public var fullscreenRetryBackoff: [Duration] = [.milliseconds(500), .seconds(1)]

    public init() {}

    /// Places the app's main (or first) standard window on `target`.
    /// - Parameter onStep: called as each step finishes, for live output.
    public func placeStandardWindow(
        ofBundleId bundleId: String,
        onDisplay target: ConnectedDisplay,
        among displays: [ConnectedDisplay],
        mode: WindowPlacementMode,
        onStep: (PlacementStepResult) -> Void = { _ in }
    ) async -> [PlacementStepResult] {
        var steps: [PlacementStepResult] = []
        func record(
            _ step: PlacementStep, since start: ContinuousClock.Instant, succeeded: Bool, attempts: Int = 1,
            _ detail: String = ""
        ) -> Bool {
            let result = PlacementStepResult(
                step: step, succeeded: succeeded, elapsedMilliseconds: (ContinuousClock.now - start).wholeMilliseconds,
                attempts: attempts, diagnosticDetail: detail)
            steps.append(result)
            onStep(result)
            return succeeded
        }
        func isOnTarget(_ window: AccessibilityWindow) -> Bool {
            window.frame.flatMap { ConnectedDisplays.display(containing: $0, in: displays)?.index } == target.index
        }

        // 1. Find (or launch) the app and its window.
        var start = ContinuousClock.now
        let app: NSRunningApplication
        do {
            app = try await AppLauncher.runningOrLaunch(bundleId)
        } catch {
            _ = record(.app, since: start, succeeded: false, "\(error)")
            return steps
        }
        var found: AccessibilityWindow?
        func findWindow(timeout: Duration) async -> Bool {
            await ConditionPoller.waitUntil(timeout: timeout) {
                found = AccessibilityApplication(app).mainOrFirstStandardWindow
                return found != nil
            }
        }
        // Apps launched in the background, or with all windows closed, often have no window:
        // reopen them (like a Dock click) so they create one.
        var reopened = false
        if !(await findWindow(timeout: existingWindowTimeout)) {
            reopened = true
            try? await AppLauncher.reopen(bundleId)
            _ = await findWindow(timeout: reopenedWindowTimeout)
        }
        let appDetail = found == nil ? "no standard window" : "\(reopened ? "reopened; " : "")\(found?.title ?? "")"
        guard record(.app, since: start, succeeded: found != nil, appDetail), let window = found
        else { return steps }

        // 2. Nothing to do if it's already fullscreen on the target.
        if mode == .fullscreen, window.isFullScreen == true, isOnTarget(window) {
            _ = record(.alreadyDone, since: .now, succeeded: true)
            return steps
        }

        // 3. Leave fullscreen first: a fullscreen window can't be moved.
        if window.isFullScreen == true {
            start = .now
            let source = window.frame.flatMap { ConnectedDisplays.display(containing: $0, in: displays) } ?? target
            let error = window.setFullScreen(false)
            let exited = await ConditionPoller.waitUntil(timeout: fullscreenTransitionTimeout) {
                window.isFullScreen == false
            }
            // The attribute flips at once; the desktop is back when the menu bar status items reappear.
            // With an always-hidden menu bar they never do, so fall back to the frame settling.
            let desktopBack =
                exited
                ? await ConditionPoller.waitUntil(timeout: desktopReturnTimeout, holdingFor: settleTime) {
                    FullscreenSpaceSignals.onScreenWindowCounts(on: source, excludingPID: app.processIdentifier)
                        .statusItems > 0
                } : false
            let settled =
                exited
                ? await ConditionPoller.waitForStableFrame(
                    of: window, stableFor: settleTime, timeout: fullscreenTransitionTimeout) : false
            let exitDetail =
                !exited
                ? "still fullscreen (AXError \(error.rawValue))"
                : !settled
                    ? "frame still changing"
                    : desktopBack ? "" : "status items never reappeared (menu bar hidden?)"
            guard record(.exitFullscreen, since: start, succeeded: exited && settled, exitDetail)
            else { return steps }
        }

        // 4. Move onto the target's visible area.
        start = .now
        var moved = false
        var attempts = 0
        while !moved && attempts < maximumFrameAttempts {
            attempts += 1
            window.setFrame(target.visibleBounds)
            // The frame we set reads back at once, but right after leaving fullscreen, entering it again that soon
            // lands on the old display. Waiting for the frame to hold fixes that (see finding 8 in the spike results).
            moved = await ConditionPoller.waitUntil(timeout: moveAttemptTimeout, holdingFor: settleTime) {
                isOnTarget(window)
            }
        }
        guard
            record(
                .move, since: start, succeeded: moved, attempts: attempts,
                "frame=\(ScreenGeometry.debugFrameDescription(window.frame))")
        else { return steps }

        // 5a. Maximized: the frame should match the visible area. macOS clamps a size to what fits at the
        // window's position *at that moment*; if the app applied the move late, the size got clamped, so
        // set the frame again.
        if mode == .maximized {
            start = .now
            var filled = false
            attempts = 0
            while !filled && attempts < maximumFrameAttempts {
                if attempts > 0 { window.setFrame(target.visibleBounds) }
                attempts += 1
                filled = await ConditionPoller.waitUntil(timeout: maximizeAttemptTimeout) {
                    window.frame.map { ScreenGeometry.approximatelyEqual($0, target.visibleBounds) } ?? false
                }
            }
            _ = record(
                .verifyMaximized, since: start, succeeded: filled, attempts: attempts,
                "frame=\(ScreenGeometry.debugFrameDescription(window.frame))")
            return steps
        }

        // 5b. Fullscreen: bring it forward, then enter fullscreen, retrying with backoff. A retry brings the app
        // forward again (another app's fullscreen Space can hide the signals) and only sets the attribute again
        // if it didn't stick: setting true on a window that already reads true does nothing.
        start = .now
        var entered = false
        attempts = 0
        while !entered && attempts <= fullscreenRetryBackoff.count {
            if attempts > 0 { try? await Task.sleep(for: fullscreenRetryBackoff[attempts - 1]) }
            attempts += 1
            app.activate()
            window.raise()
            if window.isFullScreen != true { window.setFullScreen(true) }
            // The attribute flips at once; the fullscreen Space is really showing once the menu bar status items
            // and other apps' windows are gone from the target display, steadily.
            entered = await ConditionPoller.waitUntil(timeout: fullscreenTransitionTimeout, holdingFor: settleTime) {
                guard window.isFullScreen == true, isOnTarget(window),
                    window.frame.map({ ScreenGeometry.isFullscreenFrame($0, displayBounds: target.bounds) }) ?? false
                else { return false }
                let counts = FullscreenSpaceSignals.onScreenWindowCounts(
                    on: target, excludingPID: app.processIdentifier)
                return counts.statusItems == 0 && counts.otherAppWindows == 0
            }
        }
        _ = record(
            .enterFullscreen, since: start, succeeded: entered, attempts: attempts,
            "fullscreen=\(window.isFullScreen.map(String.init) ?? "?") "
                + "frame=\(ScreenGeometry.debugFrameDescription(window.frame))")
        return steps
    }
}
