import Foundation
import Testing

@testable import macos_spaces_auto_layout

struct DeskSetupModelTests {
    @Test(arguments: [
        (1, "rectangle"),
        (2, "rectangle.split.2x1"),
        (3, "rectangle.split.3x1"),
        (4, "rectangle.split.3x1"),
    ])
    func displayCountSymbolNameFollowsDisplayCount(count: Int, expected: String) {
        let displays = (0..<count).map { DeskSetupDisplay(name: "Display \($0)", apps: []) }
        #expect(DeskSetup(name: "Test", displays: displays).displayCountSymbolName == expected)
    }

    @Test(arguments: [(1, "1 Display"), (2, "2 Displays"), (3, "3 Displays")])
    func displayCountLabelPluralizes(count: Int, expected: String) {
        let displays = (0..<count).map { DeskSetupDisplay(name: "Display \($0)", apps: []) }
        #expect(DeskSetup(name: "Test", displays: displays).displayCountLabel == expected)
    }

    @Test func firstLaunchSetupsHaveOneTwoAndThreeDisplays() {
        #expect(DeskSetup.firstLaunchSetups.map(\.displays.count) == [1, 2, 3])
        #expect(DeskSetup.firstLaunchSetups.allSatisfy { $0.displays.allSatisfy(\.apps.isEmpty) })
    }

    @Test func roundTripsThroughJSON() throws {
        let setup = DeskSetup(
            name: "Home desk",
            displays: [
                DeskSetupDisplay(name: "Display 1", apps: [AppPlacement(bundleId: "com.apple.Safari", name: "Safari")]),
                DeskSetupDisplay(name: "Display 2", apps: []),
            ])
        let data = try JSONEncoder().encode(setup)
        #expect(try JSONDecoder().decode(DeskSetup.self, from: data) == setup)
    }

    @Test func decodingFailsWithoutBundleId() {
        let json = #"{"id":"\#(UUID().uuidString)","name":"Safari"}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AppPlacement.self, from: Data(json.utf8))
        }
    }
}
