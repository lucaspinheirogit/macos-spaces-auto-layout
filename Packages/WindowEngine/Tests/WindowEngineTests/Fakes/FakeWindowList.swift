import CoreGraphics

@testable import WindowEngine

/// The on-screen window list for a desk with one other app open: each display shows menu bar status items and a
/// window of that app, unless the placed window's fullscreen Space is showing there.
@MainActor
final class FakeWindowList: OnScreenWindowListProvider {
    static let otherAppProcessIdentifier: pid_t = 99

    let displays: [ConnectedDisplay]
    var window: FakeWindow?
    /// Leaves the placed window's fullscreen Space off screen, like a Space that never comes forward.
    var placedWindowSpaceHidden = false

    init(displays: [ConnectedDisplay]) {
        self.displays = displays
    }

    func onScreenWindows() -> [OnScreenWindowListEntry] {
        displays.flatMap { display -> [OnScreenWindowListEntry] in
            if let window, window.fullScreen, !window.isGone, !placedWindowSpaceHidden,
                ScreenGeometry.centerIsInside(window.currentFrame, bounds: display.bounds)
            {
                return [
                    OnScreenWindowListEntry(
                        ownerProcessIdentifier: FakeApplicationLocator.processIdentifier, layer: 0,
                        bounds: window.currentFrame)
                ]
            }
            let statusItem = CGRect(x: display.bounds.maxX - 40, y: display.bounds.minY, width: 30, height: 24)
            return [
                OnScreenWindowListEntry(
                    ownerProcessIdentifier: 1, layer: FullscreenSpaceSignals.statusItemLayer, bounds: statusItem),
                OnScreenWindowListEntry(
                    ownerProcessIdentifier: Self.otherAppProcessIdentifier, layer: 0,
                    bounds: display.visibleBounds.insetBy(dx: 200, dy: 200)),
            ]
        }
    }
}
