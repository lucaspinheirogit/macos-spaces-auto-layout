# Architecture

This describes the code as it is today. For where it's going, see the [recommended architecture](research/04-recommended-architecture.md).

## Overview

```
MacosSpacesAutoLayoutApp ──owns──▶ SetupStore ──reads/writes──▶ SetupFileStorage ──▶ setups.json
          │                            ▲
          ▼                            │ update(_:)
   SetupsListView ──sheet──▶ SetupEditorView (edits a copy of a Setup)
```

- A single SwiftUI window.
- The app has no external dependencies or helper tools; it uses only Apple frameworks.
- Not sandboxed (`ENABLE_APP_SANDBOX = NO`), because the future window engine needs the Accessibility API, which doesn't work in the sandbox. See [research 02 §6](research/02-technical-apis.md#6-permissions-and-distribution).

## Modules

| Path | Responsibility |
|---|---|
| `MacosSpacesAutoLayoutApp.swift` | `@main`. Creates the `SetupStore` and the "Setups" window |
| `AppIdentity.swift` | The app's bundle identifier, shared by the storage folder and the logging subsystem |
| `Models/Setup.swift` | Value types `Setup`, `SetupDisplay`, `AppPlacement`, the default setups, `symbolName` and `displayCountLabel` |
| `Models/AppPlacement+Bundle.swift` | `AppPlacement(appURL:)`: reads the bundle identifier and the (localized) name from an `.app` bundle |
| `Store/SetupStore.swift` | `@Observable` list of setups. `update(_:)` replaces a setup by id and saves |
| `Store/SetupFileStorage.swift` | Reads and writes `[Setup]` as JSON at a file URL, and moves unreadable files aside. `.default` is the real location; `.preview` is a temp file for SwiftUI previews |
| `Views/SetupsListView.swift` | The setups list: one row per setup with its icon, name, display count and Edit button |
| `Views/SetupEditorView.swift` | Editor sheet: name field, one column per display with its apps, Add App picker (with an alert for apps that have no bundle identifier), Cancel/Save |

## Data model

```swift
struct Setup         { id: UUID; name: String; displays: [SetupDisplay] }
struct SetupDisplay  { id: UUID; name: String; apps: [AppPlacement] }   // displays[0] is the main display
struct AppPlacement  { id: UUID; bundleId: String; name: String }
```

- All three are `Codable`, `Hashable` and `Sendable` value types.
- They are `nonisolated`, so code off the main actor (such as the future window engine) can use them.
- `bundleId` is required. It's the stable key for finding and launching an app. The Add App picker shows an alert and adds nothing when a bundle doesn't have one.
- Displays are generic placeholders ("Display 1", "Display 2", …). They aren't tied to physical monitors yet.

### Storage

`~/Library/Application Support/<bundle id>/setups.json`, pretty-printed with sorted keys:

```json
[
  {
    "displays" : [
      {
        "apps" : [
          { "bundleId" : "com.apple.Safari", "id" : "6F1C…", "name" : "Safari" }
        ],
        "id" : "0B7E…",
        "name" : "Display 1"
      }
    ],
    "id" : "A41D…",
    "name" : "Single Display"
  }
]
```

| Situation | Behaviour |
|---|---|
| No file yet | The store starts with `Setup.defaults` (1, 2 and 3 displays). Nothing is written until the first save |
| File can't be read or decoded | The store logs an error (`os.Logger`, subsystem = bundle identifier), renames the file to `setups.corrupt-<UTC timestamp>.json` next to it, and starts from the defaults. The user's data is kept in that file |
| Any `update(_:)` | The whole list is written atomically |

## Editing flow

1. **Edit** on a row opens `SetupEditorView` with a copy of that `Setup` in `@State var draft`.
2. Renaming and adding apps change only the draft.
3. **Cancel** throws the draft away. **Save** calls `store.update(draft)`, which saves to disk.

## Concurrency

- Swift 6 language mode.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` with approachable concurrency, so views and `SetupStore` run on the main actor.
- The model types and `SetupFileStorage` are marked `nonisolated` so they aren't tied to the main actor.

## Tests

`macos-spaces-auto-layoutTests` uses Swift Testing and runs inside the app (it's the test host).

| Suite | Covers |
|---|---|
| `SetupTests` | `symbolName`, `displayCountLabel`, the defaults, JSON round trip, `bundleId` required |
| `SetupStoreTests` | Default seeding, saving and reloading, ignoring unknown ids, corrupt-file fallback and backup naming |
| `AppPlacementBundleTests` | Name priority (localized `CFBundleDisplayName` → `CFBundleDisplayName` → `CFBundleName` → file name), nil without a bundle id or Info.plist |

Each test suite works in its own temporary folder and deletes it when the suite instance is released.

Run them with `xcodebuild … test` (see the [README](../README.md#build-run-test)) or ⌘U in Xcode.

## Not built yet

| Goal | Today | Needed (see [roadmap](roadmap.md)) |
|---|---|---|
| Setups are real desk arrangements | Generic "Display N" columns | Display fingerprints captured from the connected hardware (UUIDs) |
| Apps go fullscreen or maximized on their display | Apps are only listed | Window engine using the Accessibility API, with a mode per app (Maximized by default) and a per-app option to launch the app if it isn't running |
| Switch automatically when moving between desks | None | Display change watcher, setup matching, and a per-setup choice to apply automatically, ask first, or do nothing |
| Manage setups | Rename and add apps only | Add and delete setups and displays; remove and reorder apps |
| Easy install for others | Local Xcode build | Accessibility permission onboarding, notarized release |
