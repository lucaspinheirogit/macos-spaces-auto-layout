import Foundation

enum AppIdentity {
    /// The app's bundle identifier. Used for the Application Support folder and the logging subsystem.
    nonisolated static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "macos-spaces-auto-layout"
}
