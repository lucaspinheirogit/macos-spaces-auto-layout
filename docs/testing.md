# Testing

What's tested automatically, how to add a test, and what still needs checking by hand. The commands are in [`CLAUDE.md`](../CLAUDE.md#build-and-test).

## Automated tests

All suites use **Swift Testing** (`import Testing`, `@Test`, `#expect`). CI runs them on every pull request.

| Target | Runs with | Covers |
|---|---|---|
| `macos-spaces-auto-layoutTests` | `xcodebuild … test`, or ⌘U in Xcode | The setups model, its storage, and reading app bundles |
| `WindowEngineTests` | `swift test` in `Packages/WindowEngine` | Every window placement step and failure path (with fakes on a test clock), waits, geometry and the window-list counting |
| `BenchReportTests` | `swift test` in `spike` | The bench CSV and summary |

None of them need Accessibility permission. None of them move real windows or read the real `setups.json`.

## Adding a test

1. Add `<Type>Tests.swift` next to the others. The test target is a synchronized folder, so there's no project file to edit.
2. In the app's tests, use `@testable import macos_spaces_auto_layout`.
3. The test target doesn't default to `@MainActor` the way the app does. Mark a suite `@MainActor` when it uses main-actor types such as the store.
4. **Files:** create a temporary folder in the suite's `init` and delete it in `deinit`. Swift Testing creates a new suite instance for every test, so each test gets a clean folder. Pass a storage that points into that folder; never use the default location.
5. **Saved data formats:** keep an example file for each format that has shipped, and test that it still decodes (see [conventions](conventions.md#saved-data)).
6. **Code that talks to macOS** (Accessibility, `NSWorkspace`, the window list, clocks): test it through a protocol with a fake implementation. Keep the decision logic in plain functions that take values, so it can be tested without fakes. The window engine's fakes, and a `TestClock` whose sleeps return at once, are in `Packages/WindowEngine/Tests/WindowEngineTests/Fakes/`.

## Checks by hand

Some behaviour can only be seen on a real desktop. A PR that changes it lists these checks under **Manual** in its test plan.

- **Accessibility permission:**
  - The terminal or Xcode running the code needs it (System Settings → Privacy & Security → Accessibility).
  - A build with a different code signature counts as a new app. Ad-hoc builds lose the permission when rebuilt.
- **The spike CLI** ([`spike/README.md`](../spike/README.md)): `displays`, `windows`, `place` and `trace` show what one placement does. `bench` measures many placements and takes over the screen for minutes, so run it only when the change is about reliability.
- **A second display without a monitor:** create a [BetterDisplay](https://github.com/waydabber/BetterDisplay) virtual screen. Then confirm on a real monitor, because timing and display identity can differ.
- **The app:**
  - Edit and save a setup, relaunch, and check the change is still there.
  - Apply now: with a one-display setup and a few other apps in fullscreen, apply it from the menu bar and check the order of Spaces in Mission Control. Revoke Accessibility access in System Settings and check the banner and menu item come back within a second.
  - For storage changes, also start from a `setups.json` written by the previous build.
