import Testing
import WindowEngine

@testable import macos_spaces_auto_layout

@MainActor
struct MenuBarContentViewTests {
    private static func setup(displayCount: Int, apps: [String]) -> DeskSetup {
        DeskSetup(
            name: "Desk",
            displays: (0..<displayCount).map { index in
                DeskSetupDisplay(
                    name: "Display \(index + 1)",
                    apps: index == 0 ? apps.map { AppPlacement(bundleId: $0, name: $0) } : [])
            })
    }

    @Test func titlesSayWhyASetupCantBeApplied() {
        #expect(MenuBarContentView.applyTitle(for: Self.setup(displayCount: 1, apps: ["a"])) == "Desk")
        #expect(MenuBarContentView.applyTitle(for: Self.setup(displayCount: 1, apps: [])) == "Desk (no apps)")
        #expect(
            MenuBarContentView.applyTitle(for: Self.setup(displayCount: 2, apps: ["a"])) == "Desk (2 Displays: not yet)"
        )
    }

    @Test func statusDescribesEachState() {
        #expect(MenuBarContentView.statusMessage(for: .idle) == nil)
        #expect(MenuBarContentView.statusMessage(for: .applying(setupName: "Desk", progress: nil)) == "Applying Desk…")
        let progress = FullscreenSpaceProgress(
            bundleId: "com.example.not-running", isInSetup: true, index: 2, total: 5)
        #expect(
            MenuBarContentView.statusMessage(for: .applying(setupName: "Desk", progress: progress))
                == "Arranging com.example.not-running (3 of 5)…")
        #expect(
            MenuBarContentView.statusMessage(for: .finished(setupName: "Desk", outcome: .arranged(appCount: 1)))
                == "Desk: arranged 1 app")
        #expect(
            MenuBarContentView.statusMessage(
                for: .finished(setupName: "Desk", outcome: .someAppsFailed(appNames: ["Slack", "Xcode"])))
                == "Desk: couldn't arrange Slack, Xcode")
    }
}
