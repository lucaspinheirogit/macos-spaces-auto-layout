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
    public static func running(_ bundleId: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
    }

    /// Returns the running app, launching it in the background first if needed.
    public static func runningOrLaunch(_ bundleId: String) async throws -> NSRunningApplication {
        if let app = running(bundleId) { return app }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            throw AppLauncherError.notInstalled(bundleId)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        return try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}
