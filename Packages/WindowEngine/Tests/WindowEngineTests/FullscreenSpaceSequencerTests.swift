import CoreGraphics
import Testing

@testable import WindowEngine

/// Runs the sequencer against a fake placer that keeps the display's Spaces in order, the way macOS does.
@MainActor
struct FullscreenSpaceSequencerTests {
    static let display = ConnectedDisplay(
        index: 0, id: 1, uuid: "BUILTIN", name: "Built-in", isBuiltin: true, isMain: true,
        bounds: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleBounds: CGRect(x: 0, y: 33, width: 1512, height: 949))

    let placer = FakeStandardWindowPlacer()
    let sequencer: FullscreenSpaceSequencer

    init() {
        sequencer = FullscreenSpaceSequencer(
            placer: placer, fullscreenAppLocator: FakeFullscreenAppLocator(placer: placer))
    }

    private func arrange(_ setup: [String]) async throws -> [FullscreenSpaceAppResult] {
        try await sequencer.arrange(setupBundleIds: setup, onDisplay: Self.display, among: [Self.display])
    }

    @Test func putsTheSetupsAppsFirstInSetupOrder() async throws {
        let results = try await arrange(["a", "b", "c"])
        #expect(placer.spaces == ["a", "b", "c"])
        #expect(results.map(\.bundleId) == ["a", "b", "c"])
        #expect(results.allSatisfy { $0.succeeded && $0.isInSetup })
    }

    @Test func movesOtherFullscreenAppsBehindTheSetupsApps() async throws {
        placer.spaces = ["x", "y"]
        let results = try await arrange(["a", "b"])
        #expect(Array(placer.spaces.prefix(2)) == ["a", "b"])
        #expect(Set(placer.spaces.suffix(2)) == ["x", "y"])
        #expect(results.filter { !$0.isInSetup }.allSatisfy { $0.succeeded })
    }

    @Test func reordersSetupAppsThatAreAlreadyFullscreen() async throws {
        placer.spaces = ["b", "x", "a"]
        let results = try await arrange(["a", "b"])
        #expect(placer.spaces == ["a", "b", "x"])
        // Each setup app: enter (already done), leave, enter again.
        #expect(results[0].placements.count == 3)
        #expect(placer.calls.filter { $0.bundleId == "a" }.map(\.mode) == [.fullscreen, .maximized, .fullscreen])
    }

    @Test func doesNotTouchAnythingWhenThereIsNothingElse() async throws {
        let results = try await arrange([])
        #expect(results.isEmpty && placer.calls.isEmpty)
    }

    @Test func placesADuplicateSetupAppOnce() async throws {
        _ = try await arrange(["a", "b", "a"])
        #expect(placer.spaces == ["a", "b"])
        #expect(placer.calls.filter { $0.bundleId == "a" }.count == 1)
    }

    @Test func carriesOnAfterAnAppFails() async throws {
        placer.failingBundleIds = ["b"]
        let results = try await arrange(["a", "b", "c"])
        #expect(placer.spaces == ["a", "c"])
        #expect(results.map(\.succeeded) == [true, false, true])
    }

    @Test func doesNotEnterAgainWhenLeavingFails() async throws {
        placer.spaces = ["x"]
        placer.failingBundleIds = ["x"]
        let results = try await arrange(["a"])
        let other = try #require(results.last)
        #expect(!other.succeeded && other.placements.count == 1)
        #expect(placer.spaces == ["x", "a"])
    }

    @Test func reportsProgressBeforeEachApp() async throws {
        placer.spaces = ["x"]
        var progress: [FullscreenSpaceProgress] = []
        _ = try await sequencer.arrange(
            setupBundleIds: ["a", "b"], onDisplay: Self.display, among: [Self.display],
            onAppStarted: { progress.append($0) })
        #expect(progress.map(\.bundleId) == ["a", "b", "x"])
        #expect(progress.map(\.index) == [0, 1, 2] && progress.allSatisfy { $0.total == 3 })
        #expect(progress.map(\.isInSetup) == [true, true, false])
    }

    @Test func stopsWhenCancelled() async throws {
        let sequencer = sequencer
        placer.onPlace = { [placer] in
            if placer.calls.count == 1 { withUnsafeCurrentTask { $0?.cancel() } }
        }
        let task = Task {
            try await sequencer.arrange(
                setupBundleIds: ["a", "b", "c"], onDisplay: Self.display, among: [Self.display])
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(placer.calls.map(\.bundleId) == ["a"])
    }
}
