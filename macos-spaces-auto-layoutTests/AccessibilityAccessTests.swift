import Testing

@testable import macos_spaces_auto_layout

@MainActor
final class AccessibilityAccessTests {
    private var isTrusted = false

    private func makeAccess() -> AccessibilityAccess {
        AccessibilityAccess(isTrusted: { [unowned self] in isTrusted })
    }

    @Test func readsThePermissionAtStart() {
        isTrusted = true
        #expect(makeAccess().isGranted)
    }

    @Test func refreshSeesTheUserGrantAndRevokeAccess() {
        let access = makeAccess()
        #expect(!access.isGranted)
        isTrusted = true
        access.refresh()
        #expect(access.isGranted)
        isTrusted = false
        access.refresh()
        #expect(!access.isGranted)
    }

    @Test func monitoringPicksUpAChange() async throws {
        let access = makeAccess()
        access.startMonitoring()
        defer { access.stopMonitoring() }
        isTrusted = true
        let deadline = ContinuousClock.now + .seconds(5)
        while !access.isGranted && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(access.isGranted)
    }
}
