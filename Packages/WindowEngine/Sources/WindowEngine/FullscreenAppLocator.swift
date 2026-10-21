import AppKit

/// Finds the apps with a fullscreen window on a display. `WorkspaceFullscreenAppLocator` is the real one; tests use
/// fakes.
@MainActor
public protocol FullscreenAppLocator {
    /// The bundle ids of the running apps whose main or first standard window is fullscreen on the display, front to
    /// back, without duplicates.
    func bundleIdsOfAppsInFullscreen(on display: ConnectedDisplay) -> [String]
}

/// The real `FullscreenAppLocator`. The window list (over all Spaces) gives the candidates: apps with a normal window
/// the size of a fullscreen window on the display. On a notched display a maximized window is that size too, so each
/// candidate's `AXFullScreen` decides. Its main window is visible to Accessibility even from another Space.
@MainActor
public struct WorkspaceFullscreenAppLocator: FullscreenAppLocator {
    public init() {}

    public func bundleIdsOfAppsInFullscreen(on display: ConnectedDisplay) -> [String] {
        let infos =
            CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        var candidates: [pid_t] = []
        for info in infos {
            guard info[kCGWindowLayer as String] as? Int == 0,
                let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                pid != ProcessInfo.processInfo.processIdentifier, !candidates.contains(pid),
                let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDict),
                ScreenGeometry.isFullscreenFrame(bounds, displayBounds: display.bounds)
            else { continue }
            candidates.append(pid)
        }
        return candidates.compactMap { pid in
            guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated,
                let bundleId = app.bundleIdentifier,
                let window = AccessibilityApplication(app).mainOrFirstStandardWindow,
                (try? window.isFullScreen) == true
            else { return nil }
            return bundleId
        }
    }
}
