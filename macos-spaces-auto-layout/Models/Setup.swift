//
//  Setup.swift
//  macos-spaces-auto-layout
//

import Foundation

/// A physical desk arrangement (e.g. "MacBook + 2 monitors") and the apps placed on each display.
nonisolated struct Setup: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var displays: [SetupDisplay]

    /// SF Symbol shown next to the setup, based on how many displays it has.
    var symbolName: String {
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

/// One display in a setup. The first display in `Setup.displays` is the main one.
nonisolated struct SetupDisplay: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var apps: [AppPlacement]
}

/// An app assigned to a display, identified by its bundle identifier.
nonisolated struct AppPlacement: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var bundleId: String   // e.g. "com.tinyspeck.slackmacgap"
    var name: String
}

extension Setup {
    /// Setups shown on first launch.
    nonisolated static let defaults: [Setup] = [
        Setup(name: "Single Display", displays: makeDisplays(count: 1)),
        Setup(name: "Dual Display", displays: makeDisplays(count: 2)),
        Setup(name: "Triple Display", displays: makeDisplays(count: 3)),
    ]

    private nonisolated static func makeDisplays(count: Int) -> [SetupDisplay] {
        (1...count).map { SetupDisplay(name: "Display \($0)", apps: []) }
    }
}
