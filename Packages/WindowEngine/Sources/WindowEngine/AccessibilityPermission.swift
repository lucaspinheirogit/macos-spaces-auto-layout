import ApplicationServices

public enum AccessibilityPermission {
    /// Whether this process may control other apps. With `prompt`, macOS shows the permission dialog if not.
    @MainActor
    public static func isTrusted(prompt: Bool) -> Bool {
        // String value of kAXTrustedCheckOptionPrompt (the C global isn't concurrency-safe to reference).
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": prompt] as CFDictionary)
    }
}
