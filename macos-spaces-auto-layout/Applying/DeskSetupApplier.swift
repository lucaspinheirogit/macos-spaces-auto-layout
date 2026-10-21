import Foundation
import OSLog
import Observation
import WindowEngine

/// Applies a setup on demand. For now only one-display setups: their apps go fullscreen on the main display, in
/// setup order, and every other fullscreen app there moves behind them (see `FullscreenSpaceSequencer`).
@Observable
final class DeskSetupApplier {
    enum State: Equatable {
        case idle
        /// `progress` is nil until the first app starts.
        case applying(setupName: String, progress: FullscreenSpaceProgress?)
        case finished(setupName: String, outcome: Outcome)
    }

    enum Outcome: Equatable {
        /// Every app ended up fullscreen. Holds how many.
        case arranged(appCount: Int)
        /// These apps (setup names, or bundle ids for other apps) didn't.
        case someAppsFailed(appNames: [String])
        case needsAccessibility
        /// Only one-display setups can be applied until displays are matched to setups.
        case needsSingleDisplay
        case noApps
        case noConnectedDisplay
        case cancelled
    }

    private(set) var state = State.idle

    var isApplying: Bool {
        if case .applying = state { true } else { false }
    }

    @ObservationIgnored private let sequencer: FullscreenSpaceSequencer
    @ObservationIgnored private let displayProvider: any DisplayProvider
    @ObservationIgnored private let accessibilityAccess: AccessibilityAccess
    @ObservationIgnored private let logger = Logger(
        subsystem: AppIdentity.bundleIdentifier, category: "DeskSetupApplier")

    init(
        accessibilityAccess: AccessibilityAccess,
        sequencer: FullscreenSpaceSequencer = FullscreenSpaceSequencer(),
        displayProvider: any DisplayProvider = ConnectedDisplayProvider()
    ) {
        self.accessibilityAccess = accessibilityAccess
        self.sequencer = sequencer
        self.displayProvider = displayProvider
    }

    /// Whether `apply(_:)` can run this setup at all.
    static func canApply(_ setup: DeskSetup) -> Bool {
        setup.displays.count == 1 && !setup.displays[0].apps.isEmpty
    }

    /// Applies the setup and records the outcome in `state`. Does nothing while another apply is running.
    func apply(_ setup: DeskSetup) async {
        guard !isApplying else { return }
        state = .applying(setupName: setup.name, progress: nil)
        let outcome = await outcome(ofApplying: setup)
        state = .finished(setupName: setup.name, outcome: outcome)
    }

    private func outcome(ofApplying setup: DeskSetup) async -> Outcome {
        accessibilityAccess.refresh()
        guard accessibilityAccess.isGranted else { return .needsAccessibility }
        guard setup.displays.count == 1 else { return .needsSingleDisplay }
        let apps = setup.displays[0].apps
        guard !apps.isEmpty else { return .noApps }
        let displays: [ConnectedDisplay]
        do {
            displays = try displayProvider.connectedDisplays()
        } catch {
            logger.error("Couldn't list displays: \(String(describing: error), privacy: .public)")
            return .noConnectedDisplay
        }
        guard let main = displays.first else { return .noConnectedDisplay }

        let results: [FullscreenSpaceAppResult]
        do {
            results = try await sequencer.arrange(
                setupBundleIds: apps.map(\.bundleId), onDisplay: main, among: displays,
                onAppStarted: { [weak self] progress in
                    self?.state = .applying(setupName: setup.name, progress: progress)
                })
        } catch {
            // Only cancellation gets here.
            return .cancelled
        }
        let failed = results.filter { !$0.succeeded }.map { result in
            apps.first { $0.bundleId == result.bundleId }?.name ?? result.bundleId
        }
        for result in results where !result.succeeded {
            let steps = result.placements.flatMap { $0 }.map { "\($0.step.rawValue)=\($0.succeeded)" }
            logger.error(
                "\(result.bundleId, privacy: .public) wasn't arranged: \(steps.joined(separator: " "), privacy: .public)"
            )
        }
        return failed.isEmpty ? .arranged(appCount: results.count) : .someAppsFailed(appNames: failed)
    }
}
