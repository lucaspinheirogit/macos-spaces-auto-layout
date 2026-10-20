import AppKit

/// Finds, launches and brings forward the app `WindowPlacer` is placing, and finds its window.
/// `WorkspaceApplicationLocator` is the real one; tests use fakes.
@MainActor
public protocol ApplicationLocator {
    /// The process of a running (not terminated) instance of the app, or nil if none is running.
    func runningProcessIdentifier(bundleId: String) -> pid_t?
    /// Launches the app without bringing it forward, and returns its process.
    func launchInBackground(bundleId: String) async throws -> pid_t
    /// Opens a running app again, like clicking its Dock icon, so an app with no window creates one.
    func reopen(bundleId: String, activates: Bool) async throws
    /// Brings the app forward. Returns false if macOS refused.
    func activate(processIdentifier: pid_t) -> Bool
    /// The app's main window if it's a standard window, otherwise its first standard window.
    func mainOrFirstStandardWindow(processIdentifier: pid_t) -> (any ControllableWindow)?
}

/// The real `ApplicationLocator`: `NSWorkspace` and `NSRunningApplication` for the app, Accessibility for its window.
@MainActor
public struct WorkspaceApplicationLocator: ApplicationLocator {
    public init() {}

    public func runningProcessIdentifier(bundleId: String) -> pid_t? {
        AppLauncher.runningApplication(bundleId: bundleId)?.processIdentifier
    }

    public func launchInBackground(bundleId: String) async throws -> pid_t {
        try await AppLauncher.launchInBackground(bundleId).processIdentifier
    }

    public func reopen(bundleId: String, activates: Bool) async throws {
        try await AppLauncher.reopen(bundleId, activates: activates)
    }

    public func activate(processIdentifier: pid_t) -> Bool {
        NSRunningApplication(processIdentifier: processIdentifier)?.activate() ?? false
    }

    public func mainOrFirstStandardWindow(processIdentifier: pid_t) -> (any ControllableWindow)? {
        NSRunningApplication(processIdentifier: processIdentifier).flatMap {
            AccessibilityApplication($0).mainOrFirstStandardWindow
        }
    }
}
