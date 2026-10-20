# Conventions

How code in this repo is named, organized and checked. Most of it is written and searched by AI agents, so names are chosen to be found with a plain text search.

## Naming

- **Names say what the thing is in this domain.** Prefer `SetupFileStorage` to `Storage` and `ConditionPoller` to `Wait`. A new name should return only its own hits when searched with `grep -rw`.
- **Use the words from the [glossary](glossary.md).** Use one word per concept. "Maximized" is never also "filled", and "setup" is never also "profile" or "layout".
- **Don't reuse Apple names** for our own types: `Accessibility`, `Layout`, `Workspace`, `Screen`, `Window`. A bare `Display` is out too.
- **Files are named after their main type**: `SetupStore.swift` holds `SetupStore`. Extensions that add one feature go in `Type+Feature.swift`, for example `AppPlacement+Bundle.swift`.
- **One SwiftUI view type per file.** Small private helper views can stay in their parent's file.
- **Properties and locals:**
  - Booleans read as questions: `isMain`, `isBuiltin`.
  - Durations say what they wait for: `statusItemsReturnTimeout`, not `timeout2`.
  - Single letters are fine only in closures of one line.
- **Tests:** the suite is `<Type>Tests` in `<Type>Tests.swift`. Test names read as sentences: `fallsBackToDefaultsAndKeepsCorruptFile()`.

## Where code goes

| Code | Place |
|---|---|
| App entry point, SwiftUI views, the setups model and its storage | `macos-spaces-auto-layout/`, in the folder for its area |
| Window engine: Accessibility, displays, placing windows | The window engine package (see [architecture](architecture.md)) |
| Measurement and bench tools | `spike/` |
| App tests | `macos-spaces-auto-layoutTests/`, one file per suite |

Both the app and its tests use Xcode's synchronized folders, so new files are picked up without editing `project.pbxproj`.

## Concurrency

- Swift 6 language mode, with complete concurrency checking.
- The app target defaults to `@MainActor`. Value types that other code may use off the main actor are marked `nonisolated`, and are `Sendable`.
- Code that calls the Accessibility API, `NSWorkspace` or `NSScreen` is `@MainActor`.
- Don't use `try? await Task.sleep`: it hides cancellation, and a cancelled loop then spins. Let `CancellationError` propagate.

## Logging and errors

- Log with `Logger(subsystem: AppIdentity.bundleIdentifier, category: "<TypeName>")`.
- Mark paths and other identifiers `privacy: .public` only when they don't contain user content.
- An error the user would notice (data not saved, an app not placed) has to reach the UI. A log line on its own isn't enough.

## Saved data

`setups.json` is the user's data, so a change to its format must keep working with files written by older builds.

- **A new field** decodes with `decodeIfPresent` and a default, so existing files still load.
- **Renaming a property** keeps its JSON key, through `CodingKeys`.
- **A change older files can't satisfy** bumps the schema version and adds a migration.
- Every format change adds a fixture file for the old format, and a test that decodes it.

## Formatting and checks

- `swift format` (the copy in the Xcode toolchain) with the repo's `.swift-format`: 4-space indents, 120 columns.
- Format before committing: `swift format format -i --recursive .`
- CI checks the formatting with `swift format lint --strict --recursive .`, builds the app and runs every test suite. Warnings are errors.
- Files have no header comment. The file name and git history already say what the header would.
