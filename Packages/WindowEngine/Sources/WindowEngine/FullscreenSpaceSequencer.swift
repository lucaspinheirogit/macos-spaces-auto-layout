/// Puts a setup's apps into fullscreen on one display so their Spaces come first, in setup order, followed by every
/// other app that was already fullscreen there.
///
/// No public API reorders Spaces, but entering fullscreen always adds the new Space at the end of the display's list
/// (research 06). So each setup app enters fullscreen in turn, leaving and entering again if it's already fullscreen,
/// and then each other fullscreen app does the same to move behind them. Their order among themselves isn't kept.
@MainActor
public struct FullscreenSpaceSequencer {
    public let placer: any StandardWindowPlacing
    public let fullscreenAppLocator: any FullscreenAppLocator

    public init(
        placer: any StandardWindowPlacing = WindowPlacer(),
        fullscreenAppLocator: any FullscreenAppLocator = WorkspaceFullscreenAppLocator()
    ) {
        self.placer = placer
        self.fullscreenAppLocator = fullscreenAppLocator
    }

    /// Arranges the Spaces on `target`, which must be one of `displays`. An app that fails is reported and the rest
    /// carry on.
    /// - Parameter onAppStarted: called before each app, for progress.
    /// - Returns: one result per app, setup apps first.
    /// - Throws: `CancellationError` if the task is cancelled.
    public func arrange(
        setupBundleIds: [String],
        onDisplay target: ConnectedDisplay,
        among displays: [ConnectedDisplay],
        onAppStarted: (FullscreenSpaceProgress) -> Void = { _ in },
        onStep: (PlacementStepResult) -> Void = { _ in }
    ) async throws -> [FullscreenSpaceAppResult] {
        var setupApps: [String] = []
        for bundleId in setupBundleIds where !setupApps.contains(bundleId) { setupApps.append(bundleId) }
        let otherApps = fullscreenAppLocator.bundleIdsOfAppsInFullscreen(on: target).filter {
            !setupApps.contains($0)
        }
        let queue = setupApps.map { ($0, true) } + otherApps.map { ($0, false) }

        var results: [FullscreenSpaceAppResult] = []
        for (index, (bundleId, isInSetup)) in queue.enumerated() {
            try Task.checkCancellation()
            onAppStarted(
                FullscreenSpaceProgress(bundleId: bundleId, isInSetup: isInSetup, index: index, total: queue.count))
            func place(_ mode: WindowPlacementMode) async throws -> [PlacementStepResult] {
                try await placer.placeStandardWindow(
                    ofBundleId: bundleId, onDisplay: target, among: displays, mode: mode, onStep: onStep)
            }
            var placements: [[PlacementStepResult]] = []
            func leaveAndEnterAgain() async throws {
                let left = try await place(.maximized)
                placements.append(left)
                if left.allSatisfy(\.succeeded) { placements.append(try await place(.fullscreen)) }
            }
            if isInSetup {
                let entered = try await place(.fullscreen)
                placements.append(entered)
                // Already fullscreen there: its Space could be anywhere in the list.
                if entered.contains(where: { $0.step == .alreadyDone }) { try await leaveAndEnterAgain() }
            } else {
                try await leaveAndEnterAgain()
            }
            results.append(FullscreenSpaceAppResult(bundleId: bundleId, isInSetup: isInSetup, placements: placements))
        }
        return results
    }
}

/// Which app `FullscreenSpaceSequencer` is about to arrange.
public struct FullscreenSpaceProgress: Sendable, Equatable {
    public let bundleId: String
    /// False for an app that was already fullscreen and is moved behind the setup's apps.
    public let isInSetup: Bool
    /// Zero-based position in the run.
    public let index: Int
    public let total: Int

    public init(bundleId: String, isInSetup: Bool, index: Int, total: Int) {
        self.bundleId = bundleId
        self.isInSetup = isInSetup
        self.index = index
        self.total = total
    }
}

/// What happened to one app in a `FullscreenSpaceSequencer` run.
public struct FullscreenSpaceAppResult: Sendable, Equatable {
    public let bundleId: String
    public let isInSetup: Bool
    /// Each `WindowPlacer` call in order: one to enter fullscreen, or leave (maximized) then enter again.
    public let placements: [[PlacementStepResult]]

    /// Whether the app ended up fullscreen behind the ones before it: the last placement entered fullscreen.
    public var succeeded: Bool {
        guard let last = placements.last else { return false }
        return last.allSatisfy(\.succeeded) && last.contains { $0.step == .enterFullscreen }
    }
}
