import AppKit
import Observation
import WindowEngine

/// Whether the app may control other apps' windows. macOS doesn't announce changes to the permission, so it's checked
/// once a second; granting or revoking it in System Settings shows up without a relaunch.
@Observable
final class AccessibilityAccess {
    private(set) var isGranted: Bool

    @ObservationIgnored private let isTrusted: () -> Bool
    @ObservationIgnored private var monitoring: Task<Void, Never>?

    static let checkInterval: Duration = .seconds(1)
    /// The Privacy & Security → Accessibility pane.
    static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    init(isTrusted: @escaping () -> Bool = { AccessibilityPermission.isTrusted(prompt: false) }) {
        self.isTrusted = isTrusted
        isGranted = isTrusted()
    }

    /// Reads the permission again.
    func refresh() {
        let granted = isTrusted()
        if granted != isGranted { isGranted = granted }
    }

    /// Checks the permission every `checkInterval` until `stopMonitoring()`.
    func startMonitoring() {
        guard monitoring == nil else { return }
        monitoring = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.checkInterval)
                } catch {
                    return
                }
                self?.refresh()
            }
        }
    }

    func stopMonitoring() {
        monitoring?.cancel()
        monitoring = nil
    }

    /// Shows macOS's permission prompt, which adds the app to the list in System Settings, then opens that pane.
    func requestAccess() {
        _ = AccessibilityPermission.isTrusted(prompt: true)
        NSWorkspace.shared.open(Self.settingsURL)
    }
}
