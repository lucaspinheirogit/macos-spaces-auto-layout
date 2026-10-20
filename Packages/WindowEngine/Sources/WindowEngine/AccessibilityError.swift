import ApplicationServices

/// A failed Accessibility call, with the `AXError` it returned.
public struct AccessibilityError: Error, Equatable, Sendable, CustomStringConvertible {
    public let code: AXError

    public init(_ code: AXError) {
        self.code = code
    }

    /// The element no longer exists: the window closed or the app quit. Retrying can't help.
    public var isInvalidElement: Bool { code == .invalidUIElement }

    public var description: String {
        switch code {
        case .invalidUIElement: "AXError \(code.rawValue) (element gone)"
        case .cannotComplete: "AXError \(code.rawValue) (app busy or not responding)"
        case .attributeUnsupported: "AXError \(code.rawValue) (attribute unsupported)"
        case .noValue: "AXError \(code.rawValue) (no value)"
        default: "AXError \(code.rawValue)"
        }
    }

    /// Throws unless `code` is `.success`.
    static func check(_ code: AXError) throws(AccessibilityError) {
        guard code == .success else { throw AccessibilityError(code) }
    }
}
