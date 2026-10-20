import CoreGraphics

/// A window `WindowPlacer` can read and change. `AccessibilityWindow` is the real one; tests use fakes.
///
/// Every read and setter throws an `AccessibilityError`. One whose `isInvalidElement` is true means the window is
/// gone, and the placement stops; any other error counts as "not yet".
@MainActor
public protocol ControllableWindow {
    var title: String? { get }
    /// Frame in global top-left coordinates.
    var frame: CGRect { get throws(AccessibilityError) }
    var isFullScreen: Bool { get throws(AccessibilityError) }
    var isMinimized: Bool { get throws(AccessibilityError) }

    func setFrame(_ frame: CGRect) throws(AccessibilityError)
    func setFullScreen(_ fullScreen: Bool) throws(AccessibilityError)
    func unminimize() throws(AccessibilityError)
    func raise() throws(AccessibilityError)
    func pressFullScreenButton() throws(AccessibilityError)
}

extension AccessibilityWindow: ControllableWindow {}
