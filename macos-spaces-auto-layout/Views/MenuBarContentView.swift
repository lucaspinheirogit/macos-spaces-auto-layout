import AppKit
import SwiftUI
import WindowEngine

/// The menu bar item's menu: what's happening, Apply now for each setup, and the way to the Setups window.
struct MenuBarContentView: View {
    let store: DeskSetupStore
    let applier: DeskSetupApplier
    let accessibilityAccess: AccessibilityAccess

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if !accessibilityAccess.isGranted {
            Text("Needs Accessibility access to arrange windows")
            Button("Grant Accessibility Access…") { accessibilityAccess.requestAccess() }
            Divider()
        }

        if let status = Self.statusMessage(for: applier.state) {
            Text(status)
            Divider()
        }

        Section("Apply now") {
            ForEach(store.setups) { setup in
                Button(Self.applyTitle(for: setup)) {
                    Task { await applier.apply(setup) }
                }
                .disabled(
                    !DeskSetupApplier.canApply(setup) || applier.isApplying || !accessibilityAccess.isGranted)
            }
        }

        Divider()
        Button("Open Setups…") {
            openWindow(id: MacosSpacesAutoLayoutApp.setupsWindowId)
            NSApp.activate()
        }
        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    static func applyTitle(for setup: DeskSetup) -> String {
        if setup.displays.count != 1 { return "\(setup.name) (\(setup.displayCountLabel): not yet)" }
        if setup.displays[0].apps.isEmpty { return "\(setup.name) (no apps)" }
        return setup.name
    }

    static func statusMessage(for state: DeskSetupApplier.State) -> String? {
        switch state {
        case .idle:
            return nil
        case .applying(let setupName, nil):
            return "Applying \(setupName)…"
        case .applying(_, let progress?):
            return "Arranging \(appName(ofBundleId: progress.bundleId)) (\(progress.index + 1) of \(progress.total))…"
        case .finished(let setupName, let outcome):
            switch outcome {
            case .arranged(let appCount):
                return "\(setupName): arranged \(appCount) app\(appCount == 1 ? "" : "s")"
            case .someAppsFailed(let appNames):
                return "\(setupName): couldn't arrange \(appNames.joined(separator: ", "))"
            case .needsAccessibility:
                return "\(setupName): needs Accessibility access"
            case .needsSingleDisplay:
                return "\(setupName): only one-display setups can be applied for now"
            case .noApps:
                return "\(setupName): has no apps"
            case .noConnectedDisplay:
                return "\(setupName): no display found"
            case .cancelled:
                return "\(setupName): stopped"
            }
        }
    }

    /// The running app's name, or the bundle id if it isn't running.
    private static func appName(ofBundleId bundleId: String) -> String {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first?.localizedName ?? bundleId
    }
}
