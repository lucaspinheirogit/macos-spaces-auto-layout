import CoreGraphics
import Testing

@testable import WindowKit

struct GeometryTests {
    @Test func convertsAppKitRectToTopLeft() {
        // Menu bar (24 pt) at the top of a 1000 pt tall primary display.
        let visible = CGRect(x: 0, y: 0, width: 1600, height: 976)
        #expect(
            Geometry.topLeftRect(fromAppKit: visible, primaryHeight: 1000)
                == CGRect(x: 0, y: 24, width: 1600, height: 976))
    }

    @Test func convertsRectOnSecondaryDisplayAbovePrimary() {
        // A display stacked above the primary has a negative top-left y.
        let rect = CGRect(x: 100, y: 1000, width: 1920, height: 1080)
        #expect(
            Geometry.topLeftRect(fromAppKit: rect, primaryHeight: 1000)
                == CGRect(x: 100, y: -1080, width: 1920, height: 1080))
    }

    @Test func picksDisplayWithLargestOverlap() {
        let left = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let right = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        let window = CGRect(x: 900, y: 100, width: 400, height: 300)  // 100 pt on left, 300 pt on right
        #expect(Geometry.bestMatch(for: window, in: [left, right]) == 1)
    }

    @Test func noDisplayWhenWindowIsOffScreen() {
        let display = CGRect(x: 0, y: 0, width: 1000, height: 800)
        #expect(Geometry.bestMatch(for: CGRect(x: 5000, y: 0, width: 10, height: 10), in: [display]) == nil)
        #expect(Geometry.bestMatch(for: .zero, in: []) == nil)
    }

    @Test func approximatelyEqualUsesTolerance() {
        let a = CGRect(x: 0, y: 24, width: 1600, height: 976)
        #expect(Geometry.approximatelyEqual(a, CGRect(x: 1, y: 25, width: 1598, height: 977)))
        #expect(!Geometry.approximatelyEqual(a, CGRect(x: 0, y: 24, width: 1590, height: 976)))
    }

    @Test func fullscreenFrameMayBeInsetBelowNotch() {
        let bounds = CGRect(x: 0, y: 0, width: 1512, height: 982)
        #expect(Geometry.fillsDisplay(bounds, bounds: bounds))
        #expect(Geometry.fillsDisplay(CGRect(x: 0, y: 32, width: 1512, height: 950), bounds: bounds))
    }

    @Test func maximizedFrameDoesNotCountAsFullscreen() {
        let bounds = CGRect(x: 0, y: 0, width: 1512, height: 982)
        // Visible area above a 70 pt Dock: not bottom-aligned.
        #expect(!Geometry.fillsDisplay(CGRect(x: 0, y: 32, width: 1512, height: 880), bounds: bounds))
        // On another display.
        #expect(!Geometry.fillsDisplay(CGRect(x: 1512, y: 0, width: 1512, height: 982), bounds: bounds))
    }

    @Test func windowOverhangingFromNeighbourIsNotOnDisplay() {
        let display = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        #expect(Geometry.isCentered(CGRect(x: 1200, y: 100, width: 400, height: 300), in: display))
        // Mostly on the display to the left, 100 pt over the edge.
        #expect(!Geometry.isCentered(CGRect(x: 500, y: 100, width: 600, height: 300), in: display))
    }

    @Test func describesFrames() {
        #expect(Geometry.describe(CGRect(x: 0, y: 24.6, width: 1512, height: 957.4)) == "0,24 1512x957")
        #expect(Geometry.describe(nil) == "?")
    }
}
