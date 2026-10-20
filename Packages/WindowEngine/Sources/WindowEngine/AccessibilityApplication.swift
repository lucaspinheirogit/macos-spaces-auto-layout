import AppKit
import ApplicationServices

/// Another app's Accessibility root element.
@MainActor
public struct AccessibilityApplication {
    /// How long one Accessibility call may wait for the app to answer. The default is about 6 s, and every call
    /// blocks the main actor, so a hung app would freeze the caller past every placement timeout.
    static let messagingTimeoutSeconds: Float = 1

    public let runningApplication: NSRunningApplication
    let element: AXUIElement

    public init(_ runningApplication: NSRunningApplication) {
        self.runningApplication = runningApplication
        element = AXUIElementCreateApplication(runningApplication.processIdentifier)
        _ = AXUIElementSetMessagingTimeout(element, Self.messagingTimeoutSeconds)
    }

    /// The windows Accessibility can see. Usually only those on the current Space.
    public var windows: [AccessibilityWindow] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
            let elements = value as? [AXUIElement]
        else { return [] }
        return elements.map(AccessibilityWindow.init(element:))
    }

    /// The app's main window if it's a standard window, otherwise its first standard window.
    public var mainOrFirstStandardWindow: AccessibilityWindow? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXMainWindowAttribute as CFString, &value) == .success,
            let raw = value, CFGetTypeID(raw) == AXUIElementGetTypeID()
        {
            let main = AccessibilityWindow(element: raw as! AXUIElement)
            if main.isStandard { return main }
        }
        return windows.first(where: \.isStandard)
    }
}
