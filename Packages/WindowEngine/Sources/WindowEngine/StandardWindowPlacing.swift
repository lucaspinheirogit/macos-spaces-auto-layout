/// Places one app's standard window. `WindowPlacer` is the real one; tests use fakes.
@MainActor
public protocol StandardWindowPlacing {
    func placeStandardWindow(
        ofBundleId bundleId: String,
        onDisplay target: ConnectedDisplay,
        among displays: [ConnectedDisplay],
        mode: WindowPlacementMode,
        onStep: (PlacementStepResult) -> Void
    ) async throws -> [PlacementStepResult]
}

extension WindowPlacer: StandardWindowPlacing {}
