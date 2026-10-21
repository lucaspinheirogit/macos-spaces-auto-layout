import CoreGraphics
import Foundation
import Testing
import WindowEngine

@testable import macos_spaces_auto_layout

@MainActor
final class DeskSetupApplierTests {
    static let builtin = ConnectedDisplay(
        index: 0, id: 1, uuid: "BUILTIN", name: "Built-in", isBuiltin: true, isMain: true,
        bounds: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleBounds: CGRect(x: 0, y: 33, width: 1512, height: 949))

    private let placer = RecordingWindowPlacer()
    private let otherFullscreenApps = FixedFullscreenAppLocator()
    private let displays = FixedDisplayProvider(displays: [builtin])
    private var isTrusted = true
    private lazy var access = AccessibilityAccess(isTrusted: { [unowned self] in isTrusted })
    private lazy var applier = DeskSetupApplier(
        accessibilityAccess: access,
        sequencer: FullscreenSpaceSequencer(placer: placer, fullscreenAppLocator: otherFullscreenApps),
        displayProvider: displays)

    private static func setup(displays apps: [[String]]) -> DeskSetup {
        DeskSetup(
            name: "Desk",
            displays: apps.enumerated().map { index, bundleIds in
                DeskSetupDisplay(
                    name: "Display \(index + 1)",
                    apps: bundleIds.map { AppPlacement(bundleId: $0, name: "App \($0)") })
            })
    }

    @Test func arrangesTheSetupsAppsInOrderOnTheMainDisplay() async {
        await applier.apply(Self.setup(displays: [["a", "b"]]))
        #expect(placer.calls.map(\.bundleId) == ["a", "b"])
        #expect(placer.calls.allSatisfy { $0.mode == .fullscreen && $0.display == Self.builtin.id })
        #expect(applier.state == .finished(setupName: "Desk", outcome: .arranged(appCount: 2)))
    }

    @Test func movesOtherFullscreenAppsToo() async {
        otherFullscreenApps.bundleIds = ["x"]
        await applier.apply(Self.setup(displays: [["a"]]))
        #expect(placer.calls.map(\.bundleId) == ["a", "x", "x"])
        #expect(applier.state == .finished(setupName: "Desk", outcome: .arranged(appCount: 2)))
    }

    @Test func namesTheAppsThatFailed() async {
        otherFullscreenApps.bundleIds = ["x"]
        placer.failingBundleIds = ["b", "x"]
        await applier.apply(Self.setup(displays: [["a", "b"]]))
        #expect(applier.state == .finished(setupName: "Desk", outcome: .someAppsFailed(appNames: ["App b", "x"])))
    }

    @Test func refusesWithoutAccessibilityAccess() async {
        isTrusted = false
        await applier.apply(Self.setup(displays: [["a"]]))
        #expect(placer.calls.isEmpty)
        #expect(applier.state == .finished(setupName: "Desk", outcome: .needsAccessibility))
    }

    @Test func refusesASetupWithSeveralDisplays() async {
        await applier.apply(Self.setup(displays: [["a"], ["b"]]))
        #expect(placer.calls.isEmpty)
        #expect(applier.state == .finished(setupName: "Desk", outcome: .needsSingleDisplay))
        #expect(!DeskSetupApplier.canApply(Self.setup(displays: [["a"], ["b"]])))
    }

    @Test func refusesASetupWithoutApps() async {
        otherFullscreenApps.bundleIds = ["x"]
        await applier.apply(Self.setup(displays: [[]]))
        #expect(placer.calls.isEmpty)
        #expect(applier.state == .finished(setupName: "Desk", outcome: .noApps))
        #expect(!DeskSetupApplier.canApply(Self.setup(displays: [[]])))
    }

    @Test func reportsAMissingDisplay() async {
        displays.displays = []
        await applier.apply(Self.setup(displays: [["a"]]))
        #expect(applier.state == .finished(setupName: "Desk", outcome: .noConnectedDisplay))
    }

    @Test func showsProgressWhileApplyingAndIgnoresASecondApply() async {
        var seen: [DeskSetupApplier.State] = []
        let applier = applier
        placer.onPlace = { [placer] in
            seen.append(applier.state)
            if placer.calls.isEmpty {
                // A second apply while the first is running does nothing.
                Task { await applier.apply(Self.setup(displays: [["z"]])) }
            }
        }
        await applier.apply(Self.setup(displays: [["a", "b"]]))
        #expect(!placer.calls.contains { $0.bundleId == "z" })
        guard case .applying(_, let progress?) = seen.last else {
            Issue.record("Expected progress, got \(String(describing: seen.last))")
            return
        }
        #expect(progress.bundleId == "b" && progress.index == 1 && progress.total == 2)
        #expect(!applier.isApplying)
    }

    @Test func startsIdle() {
        #expect(applier.state == .idle && !applier.isApplying)
    }
}

/// Records placements and enters fullscreen for every app except the failing ones.
@MainActor
private final class RecordingWindowPlacer: StandardWindowPlacing {
    var failingBundleIds: Set<String> = []
    var onPlace: (() -> Void)?
    private(set) var calls: [(bundleId: String, mode: WindowPlacementMode, display: CGDirectDisplayID)] = []

    func placeStandardWindow(
        ofBundleId bundleId: String, onDisplay target: ConnectedDisplay, among displays: [ConnectedDisplay],
        mode: WindowPlacementMode, onStep: (PlacementStepResult) -> Void
    ) async throws -> [PlacementStepResult] {
        onPlace?()
        // Suspends like a real placement, so other main-actor work can run in the middle of an apply.
        await Task.yield()
        calls.append((bundleId, mode, target.id))
        let last: PlacementStep = mode == .fullscreen ? .enterFullscreen : .verifyMaximized
        return [.app, last].map {
            PlacementStepResult(
                step: $0, succeeded: $0 == .app || !failingBundleIds.contains(bundleId), elapsedMilliseconds: 0,
                attempts: 1, diagnosticDetail: "")
        }
    }
}

@MainActor
private final class FixedFullscreenAppLocator: FullscreenAppLocator {
    var bundleIds: [String] = []

    func bundleIdsOfAppsInFullscreen(on display: ConnectedDisplay) -> [String] {
        bundleIds
    }
}

@MainActor
private final class FixedDisplayProvider: DisplayProvider {
    var displays: [ConnectedDisplay]

    init(displays: [ConnectedDisplay]) {
        self.displays = displays
    }

    func connectedDisplays() throws -> [ConnectedDisplay] {
        displays
    }
}
