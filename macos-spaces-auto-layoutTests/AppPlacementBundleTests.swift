import Foundation
import Testing

@testable import macos_spaces_auto_layout

final class AppPlacementBundleTests {
    private let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Creates `<directory>/<name>.app/Contents/Info.plist` with the given keys,
    /// plus an English `InfoPlist.strings` when `localized` is given.
    private func makeApp(named name: String, plist: [String: String], localized: [String: String]? = nil) throws -> URL
    {
        let appURL = directory.appendingPathComponent("\(name).app")
        let contents = appURL.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))

        if let localized {
            let lproj = contents.appendingPathComponent("Resources/en.lproj")
            try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
            let strings = try PropertyListSerialization.data(fromPropertyList: localized, format: .xml, options: 0)
            try strings.write(to: lproj.appendingPathComponent("InfoPlist.strings"))
        }
        return appURL
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
