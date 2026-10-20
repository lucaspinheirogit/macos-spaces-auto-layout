import Foundation
import Testing

@testable import macos_spaces_auto_layout

final class AppPlacementBundleTests {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeApp(named name: String, plist: [String: String], localized: [String: String]? = nil) throws -> URL
    {
        try makeAppBundle(in: directory, named: name, plist: plist, localized: localized)
    }

    @Test func prefersDisplayName() throws {
        let url = try makeApp(
            named: "Folder",
            plist: [
                "CFBundleIdentifier": "com.example.app",
                "CFBundleDisplayName": "Display Name",
                "CFBundleName": "Bundle Name",
            ])
        let app = try #require(AppPlacement(appURL: url))
        #expect(app.bundleId == "com.example.app")
        #expect(app.name == "Display Name")
    }

    @Test func prefersLocalizedDisplayName() throws {
        let url = try makeApp(
            named: "Folder",
            plist: [
                "CFBundleIdentifier": "com.example.app",
                "CFBundleDevelopmentRegion": "en",
                "CFBundleDisplayName": "Display Name",
            ],
            localized: ["CFBundleDisplayName": "Localized Name"]
        )
        #expect(AppPlacement(appURL: url)?.name == "Localized Name")
    }

    @Test func fallsBackToBundleName() throws {
        let url = try makeApp(
            named: "Folder",
            plist: [
                "CFBundleIdentifier": "com.example.app",
                "CFBundleName": "Bundle Name",
            ])
        #expect(AppPlacement(appURL: url)?.name == "Bundle Name")
    }

    @Test func fallsBackToFileName() throws {
        let url = try makeApp(named: "Folder", plist: ["CFBundleIdentifier": "com.example.app"])
        #expect(AppPlacement(appURL: url)?.name == "Folder")
    }

    @Test func returnsNilWithoutBundleIdentifier() throws {
        let url = try makeApp(named: "Folder", plist: ["CFBundleName": "Bundle Name"])
        #expect(AppPlacement(appURL: url) == nil)
    }

    @Test func returnsNilWithoutInfoPlist() {
        let url = directory.appendingPathComponent("Missing.app")
        #expect(AppPlacement(appURL: url) == nil)
    }
}
