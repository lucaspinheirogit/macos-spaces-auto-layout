import Foundation

/// A physical desk arrangement (e.g. "MacBook + 2 monitors") and the apps placed on each display.
nonisolated struct DeskSetup: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var displays: [DeskSetupDisplay]

    /// SF Symbol shown next to the setup, based on how many displays it has.
    var displayCountSymbolName: String {
        switch displays.count {
        case ...1: "rectangle"
        case 2: "rectangle.split.2x1"
        default: "rectangle.split.3x1"
        }
    }

    /// "1 Display", "2 Displays", …
    var displayCountLabel: String {
        "\(displays.count) Display\(displays.count == 1 ? "" : "s")"
    }
}

/// One display in a setup. The first display in `DeskSetup.displays` is the main one.
nonisolated struct DeskSetupDisplay: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var apps: [AppPlacement]
}

/// An app assigned to a display, identified by its bundle identifier.
nonisolated struct AppPlacement: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var bundleId: String  // e.g. "com.tinyspeck.slackmacgap"
    var name: String
}

extension DeskSetup {
    /// Setups shown on first launch.
    nonisolated static let firstLaunchSetups: [DeskSetup] = [
        DeskSetup(name: "Single Display", displays: makeDisplays(count: 1)),
        DeskSetup(name: "Dual Display", displays: makeDisplays(count: 2)),
        DeskSetup(name: "Triple Display", displays: makeDisplays(count: 3)),
    ]

    private nonisolated static func makeDisplays(count: Int) -> [DeskSetupDisplay] {
        (1...count).map { DeskSetupDisplay(name: "Display \($0)", apps: []) }
    }
}
