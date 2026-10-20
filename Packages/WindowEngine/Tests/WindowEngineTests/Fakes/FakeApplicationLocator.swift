import Darwin

@testable import WindowEngine

@MainActor
final class FakeApplicationLocator: ApplicationLocator {
    static let processIdentifier: pid_t = 42

    var isRunning = true
    var isInstalled = true
    /// What `mainOrFirstStandardWindow` returns.
    var window: FakeWindow?
    /// Becomes `window` when the app is reopened, like an app that creates a window on a Dock click.
    var windowCreatedOnReopen: FakeWindow?
    var activationSucceeds = true

    private(set) var launches = 0
    /// The `activates` argument of each reopen.
    private(set) var reopens: [Bool] = []
    private(set) var activations = 0

    func runningProcessIdentifier(bundleId: String) -> pid_t? {
        isRunning ? Self.processIdentifier : nil
    }

    func launchInBackground(bundleId: String) async throws -> pid_t {
        launches += 1
        guard isInstalled else { throw AppLauncherError.notInstalled(bundleId) }
        isRunning = true
        return Self.processIdentifier
    }

    func reopen(bundleId: String, activates: Bool) async throws {
        reopens.append(activates)
        if let created = windowCreatedOnReopen { window = created }
    }

    func activate(processIdentifier: pid_t) -> Bool {
        activations += 1
        return activationSucceeds
    }

    func mainOrFirstStandardWindow(processIdentifier: pid_t) -> (any ControllableWindow)? {
        window
    }
}
