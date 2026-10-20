/// Lists the connected displays. `ConnectedDisplayProvider` is the real one; tests use fakes.
@MainActor
public protocol DisplayProvider {
    /// Active displays: the main display first, then left to right, then top to bottom.
    func connectedDisplays() throws -> [ConnectedDisplay]
}

/// The real `DisplayProvider`, backed by CoreGraphics and `NSScreen`.
@MainActor
public struct ConnectedDisplayProvider: DisplayProvider {
    public init() {}

    public func connectedDisplays() throws -> [ConnectedDisplay] {
        try ConnectedDisplays.current()
    }
}
