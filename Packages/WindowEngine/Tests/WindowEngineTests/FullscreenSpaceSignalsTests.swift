import CoreGraphics
import Testing

@testable import WindowEngine

struct FullscreenSpaceSignalsTests {
    let display = CGRect(x: 1000, y: 0, width: 1000, height: 800)
    let statusLayer = 25
    let placedApp: pid_t = 42

    private func entry(_ owner: pid_t?, layer: Int = 0, _ bounds: CGRect) -> OnScreenWindowListEntry {
        OnScreenWindowListEntry(ownerProcessIdentifier: owner, layer: layer, bounds: bounds)
    }

    private func counts(_ entries: [OnScreenWindowListEntry]) -> OnScreenWindowCounts {
        FullscreenSpaceSignals.onScreenWindowCounts(
            in: entries, onDisplayWithBounds: display, placedAppProcessIdentifier: placedApp,
            statusItemLayer: statusLayer)
    }

    @Test func countsStatusItemsAndOtherAppsWindows() {
        let result = counts([
            entry(1, layer: statusLayer, CGRect(x: 1900, y: 0, width: 30, height: 24)),
            entry(1, layer: statusLayer, CGRect(x: 1850, y: 0, width: 30, height: 24)),
            entry(99, CGRect(x: 1200, y: 100, width: 400, height: 300)),
        ])
        #expect(result == OnScreenWindowCounts(statusItems: 2, otherAppWindows: 1, placedAppWindows: 0))
    }

    @Test func countsThePlacedAppsWindowsSeparately() {
        #expect(
            counts([entry(placedApp, display)])
                == OnScreenWindowCounts(statusItems: 0, otherAppWindows: 0, placedAppWindows: 1))
    }

    @Test func ignoresWindowsCenteredOnAnotherDisplay() {
        // Mostly on the display to the left, overhanging this one by 100 pt.
        #expect(counts([entry(99, CGRect(x: 500, y: 100, width: 600, height: 300))]).otherAppWindows == 0)
    }

    @Test func ignoresTinyWindowsAndOtherLayers() {
        let result = counts([
            entry(99, CGRect(x: 1200, y: 100, width: 1, height: 1)),
            entry(99, layer: 3, CGRect(x: 1200, y: 100, width: 400, height: 300)),
        ])
        #expect(result == OnScreenWindowCounts(statusItems: 0, otherAppWindows: 0, placedAppWindows: 0))
    }

    @Test func statusItemLayerIsTheStatusWindowLevel() {
        #expect(FullscreenSpaceSignals.statusItemLayer == Int(CGWindowLevelForKey(.statusWindow)))
    }
}
