import Foundation

public enum PlacementMode: String, Sendable, CaseIterable {
    case fullscreen, maximized
}

public struct StepResult: Sendable, Equatable {
    public let name: String
    public let ok: Bool
    public let ms: Int
    /// How many times the step tried its action (move, maximize, enter fullscreen).
    public let attempts: Int
    public let detail: String

    public init(name: String, ok: Bool, ms: Int, attempts: Int = 1, detail: String = "") {
        self.name = name
        self.ok = ok
        self.ms = ms
        self.attempts = attempts
        self.detail = detail
    }
}
