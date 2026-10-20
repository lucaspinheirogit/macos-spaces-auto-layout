import Foundation
import Testing

@testable import macos_spaces_auto_layout

struct SetupTests {
    @Test(arguments: [
        (1, "rectangle"),
        (2, "rectangle.split.2x1"),
        (3, "rectangle.split.3x1"),
        (4, "rectangle.split.3x1"),
    ])
    func symbolNameFollowsDisplayCount(count: Int, expected: String) {
        let displays = (0..<count).map { SetupDisplay(name: "Display \($0)", apps: []) }
        #expect(Setup(name: "Test", displays: displays).symbolName == expected)
    }

    @Test(arguments: [(1, "1 Display"), (2, "2 Displays"), (3, "3 Displays")])
    func displayCountLabelPluralizes(count: Int, expected: String) {
        let displays = (0..<count).map { SetupDisplay(name: "Display \($0)", apps: []) }
        #expect(Setup(name: "Test", displays: displays).displayCountLabel == expected)
    }

    @Test func defaultsHaveOneTwoAndThreeDisplays() {
        #expect(Setup.defaults.map(\.displays.count) == [1, 2, 3])
        #expect(Setup.defaults.allSatisfy { $0.displays.allSatisfy(\.apps.isEmpty) })
    }

    @Test func roundTripsThroughJSON() throws {
        let setup = Setup(
            name: "Home desk",
            displays: [
                SetupDisplay(name: "Display 1", apps: [AppPlacement(bundleId: "com.apple.Safari", name: "Safari")]),
                SetupDisplay(name: "Display 2", apps: []),
            ])
        let data = try JSONEncoder().encode(setup)
        #expect(try JSONDecoder().decode(Setup.self, from: data) == setup)
    }

    @Test func decodingFailsWithoutBundleId() {
        let json = #"{"id":"\#(UUID().uuidString)","name":"Safari"}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AppPlacement.self, from: Data(json.utf8))
        }
    }
}
