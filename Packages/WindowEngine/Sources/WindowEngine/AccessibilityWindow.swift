import AppKit
import ApplicationServices

/// A window of another app, controlled through the Accessibility API.
@MainActor
public struct AccessibilityWindow {
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
        guard let positionValue = axValue(kAXPositionAttribute), let sizeValue = axValue(kAXSizeAttribute) else {
            return nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position), AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }
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

    /// Presses the window's green fullscreen button, like a click. Some apps (e.g. Figma) ignore
    /// `AXFullScreen = false` but respond to the button.
    @discardableResult
    public func pressFullScreenButton() -> AXError {
        pressButton(kAXFullScreenButtonAttribute)
    }

    /// Presses the window's red close button, like a click.
    @discardableResult
    public func close() -> AXError {
        pressButton(kAXCloseButtonAttribute)
    }

    public func raise() {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    private func pressButton(_ attribute: String) -> AXError {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success, let raw = value, CFGetTypeID(raw) == AXUIElementGetTypeID() else {
            return error == .success ? .noValue : error
        }
        return AXUIElementPerformAction(raw as! AXUIElement, kAXPressAction as CFString)
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
