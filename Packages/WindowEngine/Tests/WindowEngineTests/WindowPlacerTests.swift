import CoreGraphics
import Testing

@testable import WindowEngine

/// Drives every placement step with fakes on a test clock, on a desk of two side-by-side displays.
@MainActor
struct WindowPlacerTests {
    static let left = ConnectedDisplay(
        index: 0, id: 1, uuid: "LEFT", name: "Left", isBuiltin: true, isMain: true,
        bounds: CGRect(x: 0, y: 0, width: 1000, height: 800),
        visibleBounds: CGRect(x: 0, y: 25, width: 1000, height: 775))
    static let right = ConnectedDisplay(
        index: 1, id: 2, uuid: "RIGHT", name: "Right", isBuiltin: false, isMain: false,
        bounds: CGRect(x: 1000, y: 0, width: 1000, height: 800),
        visibleBounds: CGRect(x: 1000, y: 25, width: 1000, height: 700))
    static let displays = [left, right]
    /// A normal window on the left display.
    static let normalFrame = CGRect(x: 100, y: 100, width: 600, height: 400)

    let window = FakeWindow(frame: normalFrame, displays: displays)
    let locator = FakeApplicationLocator()
    let windowList = FakeWindowList(displays: displays)
    let placer: WindowPlacer

    init() {
        locator.window = window
        windowList.window = window
        placer = WindowPlacer(
            applicationLocator: locator, windowList: windowList, poller: ConditionPoller(clock: TestClock()))
    }

    private func place(on target: ConnectedDisplay = right, _ mode: WindowPlacementMode) async throws
        -> [PlacementStepResult]
    {
        try await placer.placeStandardWindow(
            ofBundleId: "com.example.App", onDisplay: target, among: Self.displays, mode: mode)
    }

    private func makeFullscreen(on display: ConnectedDisplay) {
        window.fullScreen = true
        window.currentFrame = display.bounds
    }

    // MARK: - Successful placements

    @Test func maximizesOnTheTarget() async throws {
        let steps = try await place(.maximized)
        #expect(steps.map(\.step) == [.app, .move, .verifyMaximized])
        #expect(steps.allSatisfy { $0.succeeded })
        #expect(window.currentFrame == Self.right.visibleBounds)
        // The move has to hold for the settle time; the clock makes that exact.
        #expect(steps[1].elapsedMilliseconds == 300)
    }

    @Test func movesAFullscreenWindowToTheOtherDisplay() async throws {
        makeFullscreen(on: Self.left)
        let steps = try await place(.fullscreen)
        #expect(steps.map(\.step) == [.app, .exitFullscreen, .move, .enterFullscreen])
        #expect(steps.allSatisfy { $0.succeeded })
        #expect(window.fullScreen && window.currentFrame == Self.right.bounds)
        #expect(window.setFullScreenCalls == [false, true])
        #expect(locator.activations == 1)
    }

    @Test func skipsAWindowAlreadyFullscreenOnTheTarget() async throws {
        makeFullscreen(on: Self.right)
        let steps = try await place(.fullscreen)
        #expect(steps.map(\.step) == [.app, .alreadyDone])
        #expect(steps.allSatisfy { $0.succeeded })
        #expect(window.setFrameCalls == 0 && window.setFullScreenCalls.isEmpty)
    }

    @Test func launchesAnAppThatIsNotRunning() async throws {
        locator.isRunning = false
        let steps = try await place(.maximized)
        #expect(locator.launches == 1)
        #expect(steps.allSatisfy { $0.succeeded })
    }

    @Test func restoresAMinimizedWindowFirst() async throws {
        window.minimized = true
        let steps = try await place(.maximized)
        #expect(steps.map(\.step) == [.app, .unminimize, .move, .verifyMaximized])
        #expect(steps.allSatisfy { $0.succeeded })
        #expect(window.unminimizeCalls == 1)
    }

    // MARK: - Retries

    @Test func retriesAMoveTheAppAppliedLate() async throws {
        window.ignoredSetFrames = 1
        let steps = try await place(.maximized)
        let move = try #require(steps.first { $0.step == .move })
        #expect(move.succeeded && move.attempts == 2)
        // A full attempt timeout, then the settle time.
        #expect(move.elapsedMilliseconds == 2000 + 300)
    }

    @Test func setsTheFrameAgainWhenTheSizeWasClamped() async throws {
        window.clampedSizeOnNextSetFrame = CGSize(width: 1000, height: 500)
        let steps = try await place(.maximized)
        let verify = try #require(steps.last)
        #expect(verify.step == .verifyMaximized && verify.succeeded && verify.attempts == 2)
        #expect(window.currentFrame == Self.right.visibleBounds)
        #expect(window.setFrameCalls == 2)
    }

    @Test func retriesFullscreenWithBackoff() async throws {
        window.ignoredFullScreenEntries = 1
        let steps = try await place(.fullscreen)
        let enter = try #require(steps.last)
        #expect(enter.step == .enterFullscreen && enter.succeeded && enter.attempts == 2)
        // A full transition timeout, the first backoff pause, then the settle time.
        #expect(enter.elapsedMilliseconds == 5000 + 500 + 300)
        #expect(locator.activations == 2)
    }

    @Test func reopensAnAppWithNoWindow() async throws {
        locator.window = nil
        locator.windowCreatedOnReopen = window
        let steps = try await place(.maximized)
        #expect(steps.allSatisfy { $0.succeeded })
        #expect(steps[0].diagnosticDetail.hasPrefix("reopened; "))
        #expect(steps[0].elapsedMilliseconds == 2000)
        // Maximized placement keeps the app in the background.
        #expect(locator.reopens == [false])
    }

    @Test func reopenActivatesForFullscreen() async throws {
        locator.window = nil
        locator.windowCreatedOnReopen = window
        _ = try await place(.fullscreen)
        #expect(locator.reopens == [true])
    }

    // MARK: - Failures

    @Test func failsWhenTheAppIgnoresAXFullScreen() async throws {
        window.ignoresFullScreen = true
        let steps = try await place(.fullscreen)
        let enter = try #require(steps.last)
        #expect(enter.step == .enterFullscreen && !enter.succeeded && enter.attempts == 3)
        #expect(enter.diagnosticDetail.contains("fullscreen=false"))
        #expect(window.setFullScreenCalls == [true, true, true])
    }

    @Test func failsWhenTheAppWontLeaveFullscreen() async throws {
        makeFullscreen(on: Self.left)
        window.ignoresFullScreen = true
        let steps = try await place(.fullscreen)
        #expect(steps.map(\.step) == [.app, .exitFullscreen])
        #expect(!steps[1].succeeded && steps[1].diagnosticDetail.hasPrefix("still fullscreen"))
    }

    @Test func stopsWhenTheWindowClosesMidStep() async throws {
        window.onSetFrame = { [window] in window.isGone = true }
        let steps = try await place(.maximized)
        #expect(steps.map(\.step) == [.app, .move])
        #expect(!steps[1].succeeded)
        #expect(steps[1].diagnosticDetail.hasPrefix("window closed"))
    }

    @Test func failsWithoutAWindowEvenAfterReopening() async throws {
        locator.window = nil
        let steps = try await place(.maximized)
        #expect(steps.map(\.step) == [.app])
        #expect(!steps[0].succeeded && steps[0].diagnosticDetail.hasSuffix("no standard window"))
        #expect(steps[0].elapsedMilliseconds == 2000 + 10_000)
    }

    @Test func failsWhenTheAppIsNotInstalled() async throws {
        locator.isRunning = false
        locator.isInstalled = false
        let steps = try await place(.maximized)
        #expect(steps.map(\.step) == [.app])
        #expect(!steps[0].succeeded && steps[0].diagnosticDetail.contains("not installed"))
    }

    @Test func rejectsATargetNotInTheDisplayList() async throws {
        let unplugged = ConnectedDisplay(
            index: 1, id: 3, uuid: "GONE", name: "Gone", isBuiltin: false, isMain: false,
            bounds: Self.right.bounds, visibleBounds: Self.right.visibleBounds)
        let steps = try await place(on: unplugged, .maximized)
        #expect(steps.map(\.step) == [.targetDisplay])
        #expect(!steps[0].succeeded)
        #expect(window.setFrameCalls == 0 && locator.activations == 0)
    }

    @Test func comparesDisplaysByIdNotPosition() async throws {
        // Same index as the right display, but it's the left one: the window must end up on the left.
        let leftAtIndexOne = ConnectedDisplay(
            index: 1, id: Self.left.id, uuid: "LEFT", name: "Left", isBuiltin: true, isMain: true,
            bounds: Self.left.bounds, visibleBounds: Self.left.visibleBounds)
        window.currentFrame = CGRect(x: 1100, y: 100, width: 600, height: 400)
        let steps = try await place(on: leftAtIndexOne, .maximized)
        #expect(steps.allSatisfy { $0.succeeded })
        #expect(window.currentFrame == Self.left.visibleBounds)
    }

    @Test func recordsAFailedActivation() async throws {
        locator.activationSucceeds = false
        let steps = try await place(.fullscreen)
        let enter = try #require(steps.last)
        #expect(enter.succeeded)
        #expect(enter.diagnosticDetail.hasPrefix("activate failed ×1"))
    }

    @Test func stopsWhenCancelled() async throws {
        let placer = placer
        var reported: [PlacementStep] = []
        window.onSetFrame = { withUnsafeCurrentTask { $0?.cancel() } }
        let task = Task {
            try await placer.placeStandardWindow(
                ofBundleId: "com.example.App", onDisplay: Self.right, among: Self.displays, mode: .maximized,
                onStep: { reported.append($0.step) })
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(reported == [.app])
        #expect(window.setFrameCalls == 1)
    }

    @Test func reportsEachStepAsItFinishes() async throws {
        var reported: [PlacementStepResult] = []
        let steps = try await placer.placeStandardWindow(
            ofBundleId: "com.example.App", onDisplay: Self.right, among: Self.displays, mode: .maximized,
            onStep: { reported.append($0) })
        #expect(reported == steps)
    }
}
