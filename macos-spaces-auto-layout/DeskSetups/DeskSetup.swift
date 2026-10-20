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

    /// "0 Displays", "1 Display", "2 Displays", …
    var displayCountLabel: String {
        "\(displays.count) Display\(displays.count == 1 ? "" : "s")"
    }

    /// The display that holds the app with this bundle identifier, if any.
    func display(containingBundleId bundleId: String) -> DeskSetupDisplay? {
        displays.first { display in display.apps.contains { $0.bundleId == bundleId } }
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
    /// Setups shown on first launch. The ids are fixed, so every first launch starts from the same data.
    nonisolated static let firstLaunchSetups: [DeskSetup] = [
        DeskSetup(
            id: UUID(uuidString: "9A7108D0-5E47-4F11-9B8A-DFCCE949BCAD")!,
            name: "Single Display",
            displays: [
                DeskSetupDisplay(
                    id: UUID(uuidString: "032FA6E4-E22B-4B2A-A399-FABB5A8A7095")!, name: "Display 1", apps: [])
            ]),
        DeskSetup(
            id: UUID(uuidString: "8D9A2362-F8FB-4D9D-BDF7-6B38600EBF10")!,
            name: "Dual Display",
            displays: [
                DeskSetupDisplay(
                    id: UUID(uuidString: "609D5FF2-9148-4B70-8FA9-294157081C27")!, name: "Display 1", apps: []),
                DeskSetupDisplay(
                    id: UUID(uuidString: "97EBE165-F709-4638-B16E-768689932609")!, name: "Display 2", apps: []),
            ]),
        DeskSetup(
            id: UUID(uuidString: "C54ED0B0-FDF3-480B-B4D1-52B76A4CE923")!,
            name: "Triple Display",
            displays: [
                DeskSetupDisplay(
                    id: UUID(uuidString: "331E2735-1DF5-41FC-A0DC-C10F920E8F79")!, name: "Display 1", apps: []),
                DeskSetupDisplay(
                    id: UUID(uuidString: "8A42D726-421A-4387-93C5-E2B9B3FB205C")!, name: "Display 2", apps: []),
                DeskSetupDisplay(
                    id: UUID(uuidString: "A0519DCB-39A2-4E30-924B-25A79D3E5D61")!, name: "Display 3", apps: []),
            ]),
    ]
}
