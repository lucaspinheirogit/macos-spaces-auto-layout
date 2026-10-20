import AppKit

public enum AppLauncherError: Error, CustomStringConvertible {
    case notInstalled(String)

    public var description: String {
        switch self {
        case .notInstalled(let bundleId): "\(bundleId) is not installed"
        }
    }
}

@MainActor
public enum AppLauncher {
    /// A running instance of the app. An instance that is quitting can still be listed for a moment, so it's skipped.
    public static func runningApplication(bundleId: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first { !$0.isTerminated }
    }

    /// Returns the running app, launching it in the background first if needed.
    public static func runningOrLaunch(_ bundleId: String) async throws -> NSRunningApplication {
        if let app = runningApplication(bundleId: bundleId) { return app }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        return try await NSWorkspace.shared.openApplication(at: url(of: bundleId), configuration: configuration)
    }

    /// Opens a running app again, like clicking its Dock icon. Most apps respond to this
    /// "reopen" by creating a window when they have none. With `activates` false the app stays in the background.
    public static func reopen(_ bundleId: String, activates: Bool) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        _ = try await NSWorkspace.shared.openApplication(at: url(of: bundleId), configuration: configuration)
    }

    private static func url(of bundleId: String) throws -> URL {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            throw AppLauncherError.notInstalled(bundleId)
        }
        return url
    }
}
