import Foundation
import Testing

@testable import macos_spaces_auto_layout

/// Pins the on-disk format of `setups.json`. A failure here means existing files would stop loading.
struct DeskSetupFileFormatTests {
    @Test func decodesLegacyBareArrayAsVersionZero() throws {
        let file = try DeskSetupFile.decode(from: Fixture.data(named: "setups-v0"))
        #expect(file.schemaVersion == 0)
        #expect(file.setups == [Fixture.homeDesk])
    }

    @Test func decodesVersionOne() throws {
        let file = try DeskSetupFile.decode(from: Fixture.data(named: "setups-v1"))
        #expect(file == DeskSetupFile(schemaVersion: 1, setups: [Fixture.homeDesk]))
    }

    @Test func encodesExactlyTheVersionOneFixture() throws {
        let encoded = try JSONSerialization.jsonObject(with: DeskSetupFile(setups: [Fixture.homeDesk]).encoded())
        let fixture = try JSONSerialization.jsonObject(with: Fixture.data(named: "setups-v1"))
        #expect((encoded as? NSDictionary) == (fixture as? NSDictionary))
    }

    @Test func encodedKeysArePinned() throws {
        let data = try DeskSetupFile(setups: [Fixture.homeDesk]).encoded()
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let setup = try #require((root["setups"] as? [[String: Any]])?.first)
        let display = try #require((setup["displays"] as? [[String: Any]])?.first)
        let app = try #require((display["apps"] as? [[String: Any]])?.first)

        #expect(Set(root.keys) == ["schemaVersion", "setups"])
        #expect(root["schemaVersion"] as? Int == DeskSetupFile.currentSchemaVersion)
        #expect(Set(setup.keys) == ["id", "name", "displays"])
        #expect(Set(display.keys) == ["id", "name", "apps"])
        #expect(Set(app.keys) == ["id", "bundleId", "name"])
    }

    @Test func ignoresUnknownKeys() throws {
        let file = try DeskSetupFile.decode(from: Fixture.data(named: "setups-v1-unknown-keys"))
        #expect(file == DeskSetupFile(schemaVersion: 1, setups: [Fixture.homeDesk]))
    }

    @Test func decodesNewerVersionThatStillFits() throws {
        let file = try DeskSetupFile.decode(from: Fixture.data(named: "setups-v99"))
        #expect(file == DeskSetupFile(schemaVersion: 99, setups: [Fixture.homeDesk]))
    }

    @Test func reportsNewerVersionThatDoesNotFit() throws {
        let data = try Fixture.data(named: "setups-v99-incompatible")
        #expect(throws: DeskSetupFile.NewerSchemaVersionError(schemaVersion: 99)) {
            try DeskSetupFile.decode(from: data)
        }
    }

    @Test(arguments: ["not json", #"{"setups": []}"#, #"{"schemaVersion": 1}"#, #"[{"name": "No id"}]"#])
    func rejectsOtherDataAsDecodingError(json: String) {
        #expect(throws: DecodingError.self) {
            try DeskSetupFile.decode(from: Data(json.utf8))
        }
    }

    @Test func repairsDuplicateIdsAndKeepsTheFirst() {
        let shared = UUID()
        let app = AppPlacement(id: shared, bundleId: "com.apple.Safari", name: "Safari")
        var file = DeskSetupFile(setups: [
            DeskSetup(id: shared, name: "A", displays: [DeskSetupDisplay(id: shared, name: "Display 1", apps: [app])]),
            DeskSetup(id: shared, name: "B", displays: []),
        ])

        #expect(file.repairDuplicateIds() == 3)
        #expect(file.setups[0].id == shared)
        let ids = [
            file.setups[0].id, file.setups[0].displays[0].id, file.setups[0].displays[0].apps[0].id, file.setups[1].id,
        ]
        #expect(Set(ids).count == 4)
        #expect(file.setups.map(\.name) == ["A", "B"])
    }

    @Test func repairLeavesUniqueIdsAlone() throws {
        var file = try DeskSetupFile.decode(from: Fixture.data(named: "setups-v1"))
        #expect(file.repairDuplicateIds() == 0)
        #expect(file.setups == [Fixture.homeDesk])
    }
}
