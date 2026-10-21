import CoreGraphics

@testable import WindowEngine

/// A window that behaves like a well-behaved app's, with switches for the ways real apps misbehave.
@MainActor
final class FakeWindow: ControllableWindow {
    let displays: [ConnectedDisplay]
    var title: String? = "Document"
    var currentFrame: CGRect
    var fullScreen = false
    var minimized = false
    /// The window has closed: every call throws `.invalidUIElement`.
    var isGone = false

    /// The app ignores this many `setFrame` calls before it applies one (it applies the move late).
    var ignoredSetFrames = 0
    /// The next `setFrame` lands at the requested origin but with this size, as when macOS clamps it.
    var clampedSizeOnNextSetFrame: CGSize?
    /// The app ignores this many `setFullScreen(true)` calls before it enters fullscreen.
    var ignoredFullScreenEntries = 0
    /// The app ignores `AXFullScreen` entirely.
    var ignoresFullScreen = false
    /// Runs at the start of every `setFrame`, e.g. to close the window or cancel the task.
    var onSetFrame: (() -> Void)?

    private(set) var setFrameCalls = 0
    private(set) var setFullScreenCalls: [Bool] = []
    private(set) var unminimizeCalls = 0
    private(set) var raiseCalls = 0

    init(frame: CGRect, displays: [ConnectedDisplay], fullScreen: Bool = false) {
        currentFrame = frame
        self.displays = displays
        self.fullScreen = fullScreen
    }

    var frame: CGRect {
        get throws(AccessibilityError) {
            try checkPresent()
            return currentFrame
        }
    }

    var isFullScreen: Bool {
        get throws(AccessibilityError) {
            try checkPresent()
            return fullScreen
        }
    }

    var isMinimized: Bool {
        get throws(AccessibilityError) {
            try checkPresent()
            return minimized
        }
    }

    func setFrame(_ frame: CGRect) throws(AccessibilityError) {
        onSetFrame?()
        try checkPresent()
        setFrameCalls += 1
        // A fullscreen window can't be moved.
        guard !fullScreen else { return }
        if ignoredSetFrames > 0 {
            ignoredSetFrames -= 1
            return
        }
        if let size = clampedSizeOnNextSetFrame {
            clampedSizeOnNextSetFrame = nil
            currentFrame = CGRect(origin: frame.origin, size: size)
            return
        }
        currentFrame = frame
    }

    func setFullScreen(_ on: Bool) throws(AccessibilityError) {
        try checkPresent()
        setFullScreenCalls.append(on)
        guard !ignoresFullScreen, on != fullScreen else { return }
        if on, ignoredFullScreenEntries > 0 {
            ignoredFullScreenEntries -= 1
            return
        }
        guard let display = ConnectedDisplays.display(containing: currentFrame, in: displays) else { return }
        fullScreen = on
        currentFrame = on ? display.bounds : display.visibleBounds.insetBy(dx: 100, dy: 100)
    }

    func unminimize() throws(AccessibilityError) {
        try checkPresent()
        unminimizeCalls += 1
        minimized = false
    }

    func raise() throws(AccessibilityError) {
        try checkPresent()
        raiseCalls += 1
    }

    func pressFullScreenButton() throws(AccessibilityError) {
        try setFullScreen(!fullScreen)
    }

    private func checkPresent() throws(AccessibilityError) {
        if isGone { throw AccessibilityError(.invalidUIElement) }
    }
}
