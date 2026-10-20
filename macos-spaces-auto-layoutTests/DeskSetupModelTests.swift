import Foundation
import Testing

@testable import macos_spaces_auto_layout

struct DeskSetupModelTests {
    @Test(arguments: [
        (0, "rectangle"),
        (1, "rectangle"),
        (2, "rectangle.split.2x1"),
        (3, "rectangle.split.3x1"),
        (4, "rectangle.split.3x1"),
    ])
    func displayCountSymbolNameFollowsDisplayCount(count: Int, expected: String) {
        let displays = (0..<count).map { DeskSetupDisplay(name: "Display \($0)", apps: []) }
        #expect(DeskSetup(name: "Test", displays: displays).displayCountSymbolName == expected)
    }

    @Test(arguments: [(0, "0 Displays"), (1, "1 Display"), (2, "2 Displays"), (3, "3 Displays")])
    func displayCountLabelPluralizes(count: Int, expected: String) {
        let displays = (0..<count).map { DeskSetupDisplay(name: "Display \($0)", apps: []) }
        #expect(DeskSetup(name: "Test", displays: displays).displayCountLabel == expected)
    }

    @Test func firstLaunchSetupsHaveOneTwoAndThreeDisplays() {
        #expect(DeskSetup.firstLaunchSetups.map(\.displays.count) == [1, 2, 3])
        #expect(DeskSetup.firstLaunchSetups.allSatisfy { $0.displays.allSatisfy(\.apps.isEmpty) })
    }

    @Test func firstLaunchIdsAreUnique() {
        let setups = DeskSetup.firstLaunchSetups
        let ids = setups.map(\.id) + setups.flatMap { $0.displays.map(\.id) }
        #expect(ids.count == 9)
        #expect(Set(ids).count == ids.count)
    }

    /// The ids are literals, so every first launch (and every test) sees the same ones.
    @Test func firstLaunchIdsAreStable() {
        #expect(
            DeskSetup.firstLaunchSetups.map(\.id.uuidString) == [
                "9A7108D0-5E47-4F11-9B8A-DFCCE949BCAD",
                "8D9A2362-F8FB-4D9D-BDF7-6B38600EBF10",
                "C54ED0B0-FDF3-480B-B4D1-52B76A4CE923",
            ])
        #expect(
            DeskSetup.firstLaunchSetups[1].displays.map(\.id.uuidString) == [
                "609D5FF2-9148-4B70-8FA9-294157081C27",
                "97EBE165-F709-4638-B16E-768689932609",
            ])
    }

    @Test func findsTheDisplayHoldingAnApp() {
        let setup = Fixture.homeDesk
        #expect(setup.display(containingBundleId: "com.apple.Safari")?.name == "Display 1")
        #expect(setup.display(containingBundleId: "com.example.missing") == nil)
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
