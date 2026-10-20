import AppKit
import ApplicationServices

public enum Accessibility {
    /// Whether this process may control other apps. With `prompt`, macOS shows the permission dialog if not.
    @MainActor
    public static func isTrusted(prompt: Bool) -> Bool {
        // String value of kAXTrustedCheckOptionPrompt (the C global isn't concurrency-safe to reference).
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": prompt] as CFDictionary)
    }
}

/// A window of another app, controlled through the Accessibility API.
@MainActor
public struct AXWindow {
    /// Not in the public headers as a kAX constant, but readable and settable on standard windows.
    static let fullScreenAttribute = "AXFullScreen"

    let element: AXUIElement

    public var title: String? { copyValue(kAXTitleAttribute) as? String }
    public var subrole: String? { copyValue(kAXSubroleAttribute) as? String }
    public var isStandard: Bool { subrole == kAXStandardWindowSubrole }

    public var isFullScreen: Bool? {
        (copyValue(Self.fullScreenAttribute) as? NSNumber)?.boolValue
    }

    @discardableResult
    public func setFullScreen(_ on: Bool) -> AXError {
        AXUIElementSetAttributeValue(element, Self.fullScreenAttribute as CFString, on as CFBoolean)
    }

    /// Frame in global top-left coordinates.
    public var frame: CGRect? {
        guard let positionValue = axValue(kAXPositionAttribute), let sizeValue = axValue(kAXSizeAttribute) else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position), AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Size, then position, then size again: macOS clamps a size that doesn't fit at the old position.
    @discardableResult
    public func setFrame(_ rect: CGRect) -> Bool {
        let first = setSize(rect.size)
        let moved = setPosition(rect.origin)
        let second = setSize(rect.size)
        return (first || second) && moved
    }

    public func raise() {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    private func setSize(_ size: CGSize) -> Bool {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value) == .success
    }

    private func setPosition(_ point: CGPoint) -> Bool {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return false }
        return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value) == .success
    }

    private func copyValue(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private func axValue(_ attribute: String) -> AXValue? {
        guard let raw = copyValue(attribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        return (raw as! AXValue)
    }
}

/// Another app's Accessibility root element.
@MainActor
public struct AXApp {
    public let app: NSRunningApplication
    let element: AXUIElement

    public init(_ app: NSRunningApplication) {
        self.app = app
        element = AXUIElementCreateApplication(app.processIdentifier)
    }

    public var windows: [AXWindow] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let elements = value as? [AXUIElement]
        else { return [] }
        return elements.map(AXWindow.init(element:))
    }

    /// The app's main window if it's a standard window, otherwise its first standard window.
    public var standardWindow: AXWindow? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXMainWindowAttribute as CFString, &value) == .success,
           let raw = value, CFGetTypeID(raw) == AXUIElementGetTypeID() {
            let main = AXWindow(element: raw as! AXUIElement)
            if main.isStandard { return main }
        }
        return windows.first(where: \.isStandard)
    }
}
