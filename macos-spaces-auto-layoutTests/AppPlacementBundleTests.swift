//
//  AppPlacementBundleTests.swift
//  macos-spaces-auto-layoutTests
//

import Foundation
import Testing
@testable import macos_spaces_auto_layout

struct AppPlacementBundleTests {
    /// Creates `<tmp>/<name>.app/Contents/Info.plist` with the given keys.
    private func makeApp(named name: String, plist: [String: String]) throws -> URL {
        let appURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("\(name).app")
        let contents = appURL.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return appURL
    }

    @Test func prefersDisplayName() throws {
        let url = try makeApp(named: "Folder", plist: [
            "CFBundleIdentifier": "com.example.app",
            "CFBundleDisplayName": "Display Name",
            "CFBundleName": "Bundle Name",
        ])
        let app = try #require(AppPlacement(appURL: url))
        #expect(app.bundleId == "com.example.app")
        #expect(app.name == "Display Name")
    }

    @Test func fallsBackToBundleName() throws {
        let url = try makeApp(named: "Folder", plist: [
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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).app")
        #expect(AppPlacement(appURL: url) == nil)
    }
}
