import Foundation
import Testing

@testable import macos_spaces_auto_layout

/// The JSON files in `Fixtures/`. The synchronized test group copies them to the root of the test bundle's resources.
enum Fixture {
    private final class BundleToken {}

    static func data(named name: String) throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        let url = try #require(bundle.url(forResource: name, withExtension: "json"), "Missing fixture \(name).json")
        return try Data(contentsOf: url)
    }

    /// What every `setups-*.json` fixture with a "Home desk" setup decodes to.
    static let homeDesk = DeskSetup(
        id: UUID(uuidString: "A41D7C88-3333-4E5F-A1B2-000000000004")!,
        name: "Home desk",
        displays: [
            DeskSetupDisplay(
                id: UUID(uuidString: "0B7E5A21-2222-4C3D-8E9F-000000000002")!,
                name: "Display 1",
                apps: [
                    AppPlacement(
                        id: UUID(uuidString: "6F1C2D4E-1111-4A6B-9C0D-000000000001")!,
                        bundleId: "com.apple.Safari",
                        name: "Safari")
                ]),
            DeskSetupDisplay(
                id: UUID(uuidString: "0B7E5A21-2222-4C3D-8E9F-000000000003")!, name: "Display 2", apps: []),
        ])
}

/// Creates `<directory>/<name>.app/Contents/Info.plist` with the given keys,
/// plus an English `InfoPlist.strings` when `localized` is given.
func makeAppBundle(
    in directory: URL, named name: String, plist: [String: String], localized: [String: String]? = nil
) throws -> URL {
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
