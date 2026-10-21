@testable import WindowEngine

/// Places apps on one display and keeps that display's list of fullscreen Spaces the way macOS does: entering
/// fullscreen adds a Space at the end, leaving removes it.
@MainActor
final class FakeStandardWindowPlacer: StandardWindowPlacing {
    /// The fullscreen Spaces after the Desktop, by bundle id.
    var spaces: [String] = []
    /// Apps whose placements fail at `enter-fullscreen` (or `exit-fullscreen` when leaving).
    var failingBundleIds: Set<String> = []
    /// Runs before each placement, e.g. to cancel the task.
    var onPlace: (() -> Void)?

    private(set) var calls: [(bundleId: String, mode: WindowPlacementMode)] = []

    func placeStandardWindow(
        ofBundleId bundleId: String,
        onDisplay target: ConnectedDisplay,
        among displays: [ConnectedDisplay],
        mode: WindowPlacementMode,
        onStep: (PlacementStepResult) -> Void
    ) async throws -> [PlacementStepResult] {
        onPlace?()
        try Task.checkCancellation()
        calls.append((bundleId, mode))
        let fails = failingBundleIds.contains(bundleId)
        let isFullscreen = spaces.contains(bundleId)
        var steps: [(PlacementStep, Bool)] = [(.app, true)]
        switch mode {
        case .fullscreen where isFullscreen:
            steps.append((.alreadyDone, true))
        case .fullscreen:
            steps += [(.move, true), (.enterFullscreen, !fails)]
            if !fails { spaces.append(bundleId) }
        case .maximized:
            if isFullscreen {
                steps.append((.exitFullscreen, !fails))
                if fails { break }
                spaces.removeAll { $0 == bundleId }
            }
            steps += [(.move, true), (.verifyMaximized, true)]
        }
        let results = steps.map {
            PlacementStepResult(
                step: $0.0, succeeded: $0.1, elapsedMilliseconds: 0, attempts: 1, diagnosticDetail: "")
        }
        for result in results { onStep(result) }
        return results
    }
}

/// Reports the apps that are fullscreen in a `FakeStandardWindowPlacer`, front to back as configured.
@MainActor
final class FakeFullscreenAppLocator: FullscreenAppLocator {
    let placer: FakeStandardWindowPlacer

    init(placer: FakeStandardWindowPlacer) {
        self.placer = placer
    }

    func bundleIdsOfAppsInFullscreen(on display: ConnectedDisplay) -> [String] {
        placer.spaces.reversed()
    }
}
