/// The outcome of one step of a placement.
public struct PlacementStepResult: Sendable, Equatable {
    public let step: PlacementStep
    public let succeeded: Bool
    public let elapsedMilliseconds: Int
    /// How many times the step tried its action (move, maximize, enter fullscreen).
    public let attempts: Int
    /// What the step saw, for logs and the CLI. Not stable enough to parse.
    public let diagnosticDetail: String

    public init(
        step: PlacementStep, succeeded: Bool, elapsedMilliseconds: Int, attempts: Int = 1, diagnosticDetail: String = ""
    ) {
        self.step = step
        self.succeeded = succeeded
        self.elapsedMilliseconds = elapsedMilliseconds
        self.attempts = attempts
        self.diagnosticDetail = diagnosticDetail
    }
}
