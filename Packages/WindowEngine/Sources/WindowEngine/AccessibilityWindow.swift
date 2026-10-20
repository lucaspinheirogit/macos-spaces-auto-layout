import AppKit
import ApplicationServices

/// A window of another app, controlled through the Accessibility API. Reads and setters throw an
/// `AccessibilityError`; `isInvalidElement` means the window is gone.
@MainActor
public struct AccessibilityWindow {
    /// Not in the public headers as a kAX constant, but readable and settable on standard windows.
    static let fullScreenAttribute = "AXFullScreen"

    let element: AXUIElement

    init(element: AXUIElement) {
        self.element = element
        _ = AXUIElementSetMessagingTimeout(element, AccessibilityApplication.messagingTimeoutSeconds)
    }

    public var title: String? { try? copyValue(kAXTitleAttribute) as? String }
    public var subrole: String? { try? copyValue(kAXSubroleAttribute) as? String }
    public var isStandard: Bool { subrole == kAXStandardWindowSubrole }

    public var isFullScreen: Bool {
        get throws(AccessibilityError) { try copyBool(Self.fullScreenAttribute) }
    }

    public var isMinimized: Bool {
        get throws(AccessibilityError) { try copyBool(kAXMinimizedAttribute) }
    }

    /// Frame in global top-left coordinates.
    public var frame: CGRect {
        get throws(AccessibilityError) {
            let positionValue = try copyAXValue(kAXPositionAttribute)
            let sizeValue = try copyAXValue(kAXSizeAttribute)
            var position = CGPoint.zero
            var size = CGSize.zero
            guard AXValueGetValue(positionValue, .cgPoint, &position), AXValueGetValue(sizeValue, .cgSize, &size)
            else { throw AccessibilityError(.noValue) }
            return CGRect(origin: position, size: size)
        }
    }

    public func setFullScreen(_ fullScreen: Bool) throws(AccessibilityError) {
        try setValue(fullScreen as CFBoolean, for: Self.fullScreenAttribute)
    }

    /// Restores a minimized window from the Dock.
    public func unminimize() throws(AccessibilityError) {
        try setValue(false as CFBoolean, for: kAXMinimizedAttribute)
    }

    /// Size, then position, then size again: macOS clamps a size that doesn't fit at the old position.
    /// Throws if the position couldn't be set, or neither size could.
    public func setFrame(_ frame: CGRect) throws(AccessibilityError) {
        let firstSize = setSize(frame.size)
        let position = setPosition(frame.origin)
        let secondSize = setSize(frame.size)
        try AccessibilityError.check(position)
        if firstSize != .success { try AccessibilityError.check(secondSize) }
    }

    /// Presses the window's green fullscreen button, like a click. Some apps (e.g. Figma) ignore
    /// `AXFullScreen = false` but respond to the button.
    public func pressFullScreenButton() throws(AccessibilityError) {
        try pressButton(kAXFullScreenButtonAttribute)
    }

    /// Presses the window's red close button, like a click.
    public func close() throws(AccessibilityError) {
        try pressButton(kAXCloseButtonAttribute)
    }

    public func raise() throws(AccessibilityError) {
        try AccessibilityError.check(AXUIElementPerformAction(element, kAXRaiseAction as CFString))
    }

    private func pressButton(_ attribute: String) throws(AccessibilityError) {
        let raw = try copyValue(attribute)
        guard CFGetTypeID(raw) == AXUIElementGetTypeID() else { throw AccessibilityError(.noValue) }
        try AccessibilityError.check(AXUIElementPerformAction(raw as! AXUIElement, kAXPressAction as CFString))
    }

    private func setSize(_ size: CGSize) -> AXError {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return .illegalArgument }
        return AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    private func setPosition(_ point: CGPoint) -> AXError {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return .illegalArgument }
        return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    private func setValue(_ value: CFTypeRef, for attribute: String) throws(AccessibilityError) {
        try AccessibilityError.check(AXUIElementSetAttributeValue(element, attribute as CFString, value))
    }

    private func copyValue(_ attribute: String) throws(AccessibilityError) -> CFTypeRef {
        var value: CFTypeRef?
        try AccessibilityError.check(AXUIElementCopyAttributeValue(element, attribute as CFString, &value))
        guard let value else { throw AccessibilityError(.noValue) }
        return value
    }

    private func copyBool(_ attribute: String) throws(AccessibilityError) -> Bool {
        guard let number = try copyValue(attribute) as? NSNumber else { throw AccessibilityError(.noValue) }
        return number.boolValue
    }

    private func copyAXValue(_ attribute: String) throws(AccessibilityError) -> AXValue {
        let raw = try copyValue(attribute)
        guard CFGetTypeID(raw) == AXValueGetTypeID() else { throw AccessibilityError(.noValue) }
        return (raw as! AXValue)
    }
}
