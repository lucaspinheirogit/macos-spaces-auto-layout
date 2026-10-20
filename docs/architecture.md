# Architecture

This describes the code as it is today. For where it's going, see the [recommended architecture](research/04-recommended-architecture.md).

## Overview

```
MacosSpacesAutoLayoutApp ──owns──▶ DeskSetupStore ──reads/writes──▶ DeskSetupFileStorage ──▶ setups.json
          │                              ▲
          ▼                              │ update(_:)
   DeskSetupListView ──sheet──▶ DeskSetupEditorView ──▶ DeskSetupEditorModel (edits a copy of a DeskSetup)
```

- A single SwiftUI window.
- The app has no external dependencies or helper tools; it uses only Apple frameworks.
- Not sandboxed (`ENABLE_APP_SANDBOX = NO`), because the future window engine needs the Accessibility API, which doesn't work in the sandbox. See [research 02 §6](research/02-technical-apis.md#6-permissions-and-distribution).

## Modules

All paths are under `macos-spaces-auto-layout/`.

| Path | Responsibility |
|---|---|
| `MacosSpacesAutoLayoutApp.swift` | `@main`. Creates the `DeskSetupStore` and the "Setups" window. Under XCTest it gives the store a temporary file (see [Tests](#tests)) |
| `AppIdentity.swift` | The app's bundle identifier, shared by the storage folder and the logging subsystem |
| `DeskSetups/DeskSetup.swift` | Value types `DeskSetup`, `DeskSetupDisplay`, `AppPlacement`; `firstLaunchSetups`, `displayCountSymbolName`, `displayCountLabel` and `display(containingBundleId:)` |
| `DeskSetups/AppPlacement+Bundle.swift` | `AppPlacement(appURL:)`: reads the bundle identifier and the (localized) name from an `.app` bundle |
| `DeskSetups/DeskSetupEditorModel.swift` | `@Observable` state of the editor sheet: the setup being edited, `isMainDisplay(_:)`, `addApp(fromBundleAt:toDisplay:)` and `save()` |
| `Persistence/DeskSetupFile.swift` | The file format: `{ schemaVersion, setups }`, decoding of every version, and duplicate-id repair |
| `Persistence/DeskSetupFileStorage.swift` | Reads and writes a `DeskSetupFile` at a file URL, and moves unreadable files aside. `.default` is the real location; `.temporary` is a throwaway file for SwiftUI previews and the test host |
| `Persistence/DeskSetupStore.swift` | `@Observable` list of setups. `update(_:)` replaces a setup by id and saves, or throws `DeskSetupStoreError`. `savingBlockedReason` says why saving is refused, if it is |
| `Views/DeskSetupListView.swift` | The setups list, with a banner when saving is blocked. Scrolls when it's taller than the window allows |
| `Views/DeskSetupRowView.swift` | One setup in the list: icon, name, display count, Edit button. Presents the editor sheet |
| `Views/DeskSetupEditorView.swift` | Editor sheet: name field, one column per display, the app file picker, alerts, Cancel/Save |
| `Views/DeskSetupDisplayColumnView.swift` | One display in the editor: name, MAIN badge, its apps, Add App button |
| `Views/AppPlacementRowView.swift` | One app in a display column: icon and name |
| `Views/SavingBlockedBannerView.swift` | The warning shown above the list when the store refuses to save |
| `Views/CardStyle.swift` | `cardStyle()`: the rounded, shadowed background of rows, columns and the banner |
| `Views/CappedHeightScrollView.swift` | A vertical scroll view as tall as its content up to a maximum, for the list and the editor columns |

## Data model

```swift
struct DeskSetup         { id: UUID; name: String; displays: [DeskSetupDisplay] }
struct DeskSetupDisplay  { id: UUID; name: String; apps: [AppPlacement] }   // displays[0] is the main display
struct AppPlacement      { id: UUID; bundleId: String; name: String }
```

- All three are `Codable`, `Hashable` and `Sendable` value types.
- They are `nonisolated`, so code off the main actor (such as the future window engine) can use them.
- `bundleId` is required. It's the stable key for finding and launching an app. The editor shows an alert and adds nothing when a bundle doesn't have one.
- An app is in a setup at most once: the editor refuses a bundle id that's already on any of the setup's displays.
- Displays are generic placeholders ("Display 1", "Display 2", …). They aren't tied to physical monitors yet.
- `DeskSetup.firstLaunchSetups` has 1, 2 and 3 displays, with fixed UUID literals as ids.

### Storage

`~/Library/Application Support/<bundle id>/setups.json`, pretty-printed with sorted keys:

```json
{
  "schemaVersion" : 1,
  "setups" : [
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
}
```

- `DeskSetupFile.currentSchemaVersion` is 1. Version 0 is a bare array of setups, without the envelope. It's still read, and the next save writes it as version 1.
- Unknown keys are ignored, at every level.
- `macos-spaces-auto-layoutTests/Fixtures/` has a file for each version. The format tests decode them and compare the encoded keys against them.

| Situation | Behaviour |
|---|---|
| No file yet | The store starts with `DeskSetup.firstLaunchSetups`. Nothing is written until the first save |
| Version 0 or 1 | Loads. Any id used twice (setup, display or app) gets a fresh UUID, and the store logs how many |
| Newer version that still decodes | Loads read-only: `savingBlockedReason = .newerSchemaVersion`. The file isn't moved or changed |
| Newer version that doesn't decode | Shows the first-launch setups, read-only, for the same reason. The file isn't moved or changed |
| Contents can't be decoded | Logs the error (`os.Logger`, subsystem = bundle identifier), renames the file to `setups.corrupt-<UTC timestamp>.json` next to it (adding `-2`, `-3`, … if that name exists), and starts from the first-launch setups. The user's data is kept in that file |
| Contents can't be decoded, and the rename fails | Starts from the first-launch setups with `savingBlockedReason = .couldNotMoveAside` |
| File can't be read (a folder at the path, no permission) | Starts from the first-launch setups with `savingBlockedReason = .unreadableFile` |
| `update(_:)` while saving is blocked | Throws `.savingBlocked`. Nothing changes in memory or on disk |
| `update(_:)` with an unknown id | Ignored |
| `update(_:)` | Writes the whole list atomically, then changes the in-memory list. If the write fails it throws `.writeFailed` and the in-memory list stays as it was |

When saving is blocked, the list shows a banner with `SavingBlockedReason.message`.

## Editing flow

1. **Edit** on a row opens `DeskSetupEditorView`, which creates a `DeskSetupEditorModel` holding a copy of that `DeskSetup` in `setupBeingEdited`.
2. **Add App** on a column opens a `.fileImporter` for application bundles, attached to the sheet, so a pick can only land in the sheet that's open. `addApp(fromBundleAt:toDisplay:)` returns an `AddAppOutcome`:
   - `.added`: the app is appended to that display.
   - `.missingBundleIdentifier`: an alert says the app can't be recognized later.
   - `.alreadyInSetup`: an alert names the display that already has it.
3. Renaming and adding apps change only the model's copy.
4. **Cancel** closes the sheet and drops the model. **Save** calls `model.save()`, which calls `store.update(_:)`. The sheet closes only when that succeeds; otherwise it stays open with the edits and shows the error in an alert.

## Concurrency

- Swift 6 language mode.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` with approachable concurrency, so views, `DeskSetupStore` and `DeskSetupEditorModel` run on the main actor.
- The model types, `DeskSetupFile` and `DeskSetupFileStorage` are marked `nonisolated` so they aren't tied to the main actor.

## Tests

`macos-spaces-auto-layoutTests` uses Swift Testing and runs inside the app (it's the test host). The app sees `XCTestConfigurationFilePath` in its environment and uses `DeskSetupFileStorage.temporary`, so a test run never reads, moves or writes the real `setups.json`.

| Suite | Covers |
|---|---|
| `DeskSetupModelTests` | `displayCountSymbolName` and `displayCountLabel` (0 to 4 displays), the first-launch setups and their unique, fixed ids, `display(containingBundleId:)`, JSON round trip, `bundleId` required |
| `DeskSetupFileFormatTests` | The fixtures: version 0 and 1 decode, the encoded file matches the version 1 fixture and its keys, unknown keys are ignored, newer versions, other data is a `DecodingError`, duplicate-id repair |
| `DeskSetupStoreTests` | Every row of the storage table above, repeated updates, backup naming and name collisions, and that the test host uses temporary storage |
| `DeskSetupEditorModelTests` | Every `AddAppOutcome`, the main display, edits staying local until saved, saving, and a failed save keeping the edits |
| `AppPlacementBundleTests` | Name priority (localized `CFBundleDisplayName` → `CFBundleDisplayName` → localized `CFBundleName` → `CFBundleName` → file name), nil without a bundle id or Info.plist |

- `TestSupport.swift` holds the fixture loader, the setup the fixtures decode to, and `makeAppBundle(in:named:plist:localized:)`.
- The fixture JSON files are resources of the test target; the synchronized folder copies them to the root of the test bundle.
- Each test works in its own temporary folder: Swift Testing creates a new suite instance per test, and `deinit` deletes the folder.
- The test target doesn't use `MainActor` default isolation, so the suites that use the store or the editor model are marked `@MainActor`.

Run them with the command in [`CLAUDE.md`](../CLAUDE.md#build-and-test) or ⌘U in Xcode. See [testing.md](testing.md) for how to add tests and what to check by hand.

## Not built yet

| Goal | Today | Needed (see [roadmap](roadmap.md)) |
|---|---|---|
| Setups are real desk arrangements | Generic "Display N" columns | Display fingerprints captured from the connected hardware (UUIDs) |
| Apps go fullscreen or maximized on their display | Apps are only listed | Window engine using the Accessibility API, with a mode per app (Maximized by default) and a per-app option to launch the app if it isn't running |
| Switch automatically when moving between desks | None | Display change watcher, setup matching, and a per-setup choice to apply automatically, ask first, or do nothing |
| Manage setups | Rename and add apps only | Add and delete setups and displays; remove and reorder apps |
| Easy install for others | Local Xcode build | Accessibility permission onboarding, notarized release |
