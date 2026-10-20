import AppKit

/// Puts an app's window on a display, maximized or in native fullscreen, checking every step.
/// Stops at the first step whose check fails, or as soon as the window is gone.
@MainActor
public struct WindowPlacer {
    /// How long to wait for an existing window before reopening the app.
    public var existingWindowTimeout: Duration = .seconds(2)
    /// How long to wait for a window after reopening the app.
    public var reopenedWindowTimeout: Duration = .seconds(10)
    /// How long a minimized window may take to come back from the Dock.
    public var unminimizeTimeout: Duration = .seconds(2)
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

    /// Places the app's main (or first) standard window on `target`, which must be one of `displays`.
    /// - Parameter onStep: called as each step finishes, for live output.
    /// - Returns: the steps that ran. The placement succeeded if every step did.
    /// - Throws: `CancellationError` if the task is cancelled. Every other failure is a failed step.
    public func placeStandardWindow(
        ofBundleId bundleId: String,
        onDisplay target: ConnectedDisplay,
        among displays: [ConnectedDisplay],
        mode: WindowPlacementMode,
        onStep: (PlacementStepResult) -> Void = { _ in }
    ) async throws -> [PlacementStepResult] {
        var steps: [PlacementStepResult] = []
        var currentStep = PlacementStep.targetDisplay
        var start = ContinuousClock.now
        func record(_ succeeded: Bool, attempts: Int = 1, _ detail: String = "") -> Bool {
            let result = PlacementStepResult(
                step: currentStep, succeeded: succeeded,
                elapsedMilliseconds: (ContinuousClock.now - start).wholeMilliseconds, attempts: attempts,
                diagnosticDetail: detail)
            steps.append(result)
            onStep(result)
            return succeeded
        }
        func begin(_ step: PlacementStep) {
            currentStep = step
            start = .now
        }

        guard displays.contains(where: { $0.id == target.id }) else {
            _ = record(false, "display \(target.id) is not in the display list")
            return steps
        }

        do {
            // 1. Find (or launch) the app and its window.
            begin(.app)
            let app: NSRunningApplication
            do {
                app = try await AppLauncher.runningOrLaunch(bundleId)
            } catch {
                _ = record(false, "\(error)")
                return steps
            }
            var found: AccessibilityWindow?
            func findWindow(timeout: Duration) async throws -> Bool {
                try await ConditionPoller.waitUntil(timeout: timeout) {
                    found = AccessibilityApplication(app).mainOrFirstStandardWindow
                    return found != nil
                }
            }
            // Apps launched in the background, or with all windows closed, often have no window:
            // reopen them (like a Dock click) so they create one. Only fullscreen brings the app forward anyway.
            var reopenDetail = ""
            if !(try await findWindow(timeout: existingWindowTimeout)) {
                do {
                    try await AppLauncher.reopen(bundleId, activates: mode == .fullscreen)
                    reopenDetail = "reopened; "
                } catch {
                    reopenDetail = "reopen failed: \(error); "
                }
                _ = try await findWindow(timeout: reopenedWindowTimeout)
            }
            guard let window = found else {
                _ = record(false, reopenDetail + "no standard window")
                return steps
            }
            _ = record(true, reopenDetail + (window.title ?? ""))

            func frame() throws(AccessibilityError) -> CGRect? { try readUnlessGone { try window.frame } }
            func isFullScreen() throws(AccessibilityError) -> Bool? { try readUnlessGone { try window.isFullScreen } }
            func isOnTarget() throws(AccessibilityError) -> Bool {
                try frame().flatMap { ConnectedDisplays.display(containing: $0, in: displays)?.id } == target.id
            }
            func frameDetail() throws(AccessibilityError) -> String {
                "frame=\(ScreenGeometry.debugFrameDescription(try frame()))"
            }

            // 2. A minimized window can't be moved or made fullscreen.
            if try readUnlessGone({ try window.isMinimized }) == true {
                begin(.unminimize)
                let error = try failureUnlessGone { try window.unminimize() }
                let restored = try await ConditionPoller.waitUntil(timeout: unminimizeTimeout) {
                    try readUnlessGone { try window.isMinimized } == false
                }
                guard record(restored, restored ? "" : "still minimized (\(error.map(String.init) ?? "no error"))")
                else { return steps }
            }

            // 3. Nothing to do if it's already fullscreen on the target.
            begin(.alreadyDone)
            if mode == .fullscreen, try isFullScreen() == true, try isOnTarget() {
                _ = record(true)
                return steps
            }

            // 4. Leave fullscreen first: a fullscreen window can't be moved.
            if try isFullScreen() == true {
                begin(.exitFullscreen)
                let source = try frame().flatMap { ConnectedDisplays.display(containing: $0, in: displays) } ?? target
                let error = try failureUnlessGone { try window.setFullScreen(false) }
                let exited = try await ConditionPoller.waitUntil(timeout: fullscreenTransitionTimeout) {
                    try isFullScreen() == false
                }
                // The attribute flips at once; the desktop is back when the menu bar status items reappear.
                // With an always-hidden menu bar they never do, so fall back to the frame settling.
                let desktopBack =
                    exited
                    ? try await ConditionPoller.waitUntil(timeout: desktopReturnTimeout, holdingFor: settleTime) {
                        FullscreenSpaceSignals.onScreenWindowCounts(on: source, excludingPID: app.processIdentifier)
                            .statusItems > 0
                    } : false
                let settled =
                    exited
                    ? try await ConditionPoller.waitForStableValue(
                        stableFor: settleTime, timeout: fullscreenTransitionTimeout, frame) : false
                let exitDetail =
                    !exited
                    ? "still fullscreen (\(error.map(String.init) ?? "no error"))"
                    : !settled
                        ? "frame still changing"
                        : desktopBack ? "" : "status items never reappeared (menu bar hidden?)"
                guard record(exited && settled, exitDetail) else { return steps }
            }

            // 5. Move onto the target's visible area.
            begin(.move)
            var moved = false
            var attempts = 0
            while !moved && attempts < maximumFrameAttempts {
                attempts += 1
                _ = try failureUnlessGone { try window.setFrame(target.visibleBounds) }
                // The frame we set reads back at once, but right after leaving fullscreen, entering it again that
                // soon lands on the old display. Waiting for the frame to hold fixes that (see finding 8 in the
                // spike results).
                moved = try await ConditionPoller.waitUntil(timeout: moveAttemptTimeout, holdingFor: settleTime) {
                    try isOnTarget()
                }
            }
            guard record(moved, attempts: attempts, try frameDetail()) else { return steps }

            // 6a. Maximized: the frame should match the visible area. macOS clamps a size to what fits at the
            // window's position *at that moment*; if the app applied the move late, the size got clamped, so
            // set the frame again.
            if mode == .maximized {
                begin(.verifyMaximized)
                var filled = false
                attempts = 0
                while !filled && attempts < maximumFrameAttempts {
                    if attempts > 0 { _ = try failureUnlessGone { try window.setFrame(target.visibleBounds) } }
                    attempts += 1
                    filled = try await ConditionPoller.waitUntil(timeout: maximizeAttemptTimeout) {
                        try frame().map { ScreenGeometry.approximatelyEqual($0, target.visibleBounds) } ?? false
                    }
                }
                _ = record(filled, attempts: attempts, try frameDetail())
                return steps
            }

            // 6b. Fullscreen: bring it forward, then enter fullscreen, retrying with backoff. A retry brings the app
            // forward again (another app's fullscreen Space can hide the signals) and only sets the attribute again
            // if it didn't stick: setting true on a window that already reads true does nothing.
            begin(.enterFullscreen)
            var entered = false
            var activationFailures = 0
            attempts = 0
            while !entered && attempts <= fullscreenRetryBackoff.count {
                if attempts > 0 { try await Task.sleep(for: fullscreenRetryBackoff[attempts - 1]) }
                attempts += 1
                if !app.activate() { activationFailures += 1 }
                _ = try failureUnlessGone { try window.raise() }
                if try isFullScreen() != true { _ = try failureUnlessGone { try window.setFullScreen(true) } }
                // The attribute flips at once; the fullscreen Space is really showing once the menu bar status items
                // and other apps' windows are gone from the target display, steadily.
                entered = try await ConditionPoller.waitUntil(
                    timeout: fullscreenTransitionTimeout, holdingFor: settleTime
                ) {
                    guard try isFullScreen() == true, try isOnTarget(),
                        try frame().map({ ScreenGeometry.isFullscreenFrame($0, displayBounds: target.bounds) }) ?? false
                    else { return false }
                    let counts = FullscreenSpaceSignals.onScreenWindowCounts(
                        on: target, excludingPID: app.processIdentifier)
                    return counts.statusItems == 0 && counts.otherAppWindows == 0
                }
            }
            let activationDetail = activationFailures > 0 ? "activate failed ×\(activationFailures) " : ""
            _ = record(
                entered, attempts: attempts,
                activationDetail + "fullscreen=\(try isFullScreen().map(String.init) ?? "?") \(try frameDetail())")
            return steps
        } catch let error as AccessibilityError {
            // Only a gone window gets here; other Accessibility failures count as "not yet".
            _ = record(false, "window closed (\(error))")
            return steps
        }
    }

    /// The value, or nil when the read failed for a reason worth retrying (the app is busy, the attribute has no
    /// value yet). Rethrows when the window is gone.
    private func readUnlessGone<Value>(_ read: () throws -> Value) throws(AccessibilityError) -> Value? {
        do {
            return try read()
        } catch let error as AccessibilityError where error.isInvalidElement {
            throw error
        } catch {
            return nil
        }
    }

    /// Runs an action and returns its error, or nil if it worked. Rethrows when the window is gone.
    private func failureUnlessGone(_ action: () throws -> Void) throws(AccessibilityError) -> AccessibilityError? {
        do {
            try action()
            return nil
        } catch let error as AccessibilityError {
            if error.isInvalidElement { throw error }
            return error
        } catch {
            return nil
        }
    }
}
