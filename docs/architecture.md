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

## Window engine

`Packages/WindowEngine` is a local Swift package (tools 6.2, macOS 15, no dependencies) that puts one app's window on one display, maximized or in native fullscreen. The app target links it but doesn't call it yet; the [spike CLI](../spike/README.md) does. Its tests run with `swift test` in the package folder.

### Types

| File | Responsibility |
|---|---|
| `WindowPlacer.swift` | `placeStandardWindow(ofBundleId:onDisplay:among:mode:onStep:)`: the step machine below. Its timing settings are properties with descriptive names (`existingWindowTimeout`, `settleTime`, `fullscreenRetryBackoff`…) |
| `WindowPlacementMode.swift` | `.maximized` or `.fullscreen` |
| `PlacementStep.swift` | The steps, as a `String` enum. The raw values (`app`, `move`, `enter-fullscreen`…) are what the CLI prints and the bench CSV stores |
| `PlacementStepResult.swift` | One finished step: `step`, `succeeded`, `elapsedMilliseconds`, `attempts`, `diagnosticDetail` |
| `ConnectedDisplay.swift` | One active display: `id` (`CGDirectDisplayID`), `uuid`, `name`, `isMain`, `isBuiltin`, `bounds`, `visibleBounds` (minus menu bar and Dock), and `index` in its list |
| `ConnectedDisplays.swift` | `current()` lists the active displays (main first, then by `minX`, `minY`, id) and throws `DisplayListError` if CoreGraphics fails. `display(containing:in:)` finds the display a frame mostly overlaps. `separateSpacesEnabled` reads the Mission Control setting |
| `ScreenGeometry.swift` | Pure rect math: `globalTopLeftRect(fromAppKitRect:primaryDisplayHeight:)`, `indexOfLargestOverlap(with:in:)`, `approximatelyEqual`, `isFullscreenFrame(_:displayBounds:)`, `centerIsInside(_:bounds:)`, `debugFrameDescription(_:)` |
| `FullscreenSpaceSignals.swift` | `onScreenWindowCounts(in:onDisplayWithBounds:excludingProcessIdentifier:)`: a pure count of the status items and other apps' windows centered on a display, as `OnScreenWindowCounts` |
| `ConditionPoller.swift` | `waitUntil(timeout:holdingFor:_:)` and `waitForStableValue(stableFor:timeout:_:)`, polling every 50 ms on an injected `Clock` |
| `AccessibilityWindow.swift` | Another app's window through the Accessibility API: frame, `AXFullScreen`, minimized, raise, the fullscreen and close buttons |
| `AccessibilityApplication.swift` | An app's Accessibility element (`runningApplication`), its `windows` and `mainOrFirstStandardWindow` |
| `AccessibilityError.swift` | The `AXError` of a failed read or setter. `isInvalidElement` means the window or app is gone |
| `AccessibilityPermission.swift` | `isTrusted(prompt:)` |
| `AppLauncher.swift` | `runningApplication(bundleId:)` (skips terminated instances), `launchInBackground(_:)`, `reopen(_:activates:)` |
| `ControllableWindow.swift`, `ApplicationLocator.swift`, `OnScreenWindowListProvider.swift`, `DisplayProvider.swift` | The seams (see below), each with its real implementation |
| `Duration+WholeMilliseconds.swift` | `wholeMilliseconds`, rounded down |

All rects are in global top-left coordinates (see the [glossary](glossary.md#coordinate-systems)). `ConnectedDisplays` converts `NSScreen.visibleFrame` using the main display's height from `CGDisplayBounds(CGMainDisplayID())`.

### The step machine

`placeStandardWindow` runs these steps in order and stops at the first one that fails. It returns the steps that ran (the placement succeeded if all of them did) and reports each one to `onStep` as it finishes.

| Step | Recorded | Does | Succeeds when |
|---|---|---|---|
| `target-display` | Only on failure | Checks the target's `CGDirectDisplayID` is in `among` | |
| `app` | Always | Finds the running app or launches it in the background. If Accessibility shows no standard window but the app has an off-screen window (usually in another Space, where Accessibility can't see it), activates the app first, which switches to that Space. Then waits up to 2 s for a standard window. If none appears, reopens the app (like a Dock click; it's brought forward only in fullscreen mode) and waits up to 10 s more | A standard window exists |
| `unminimize` | If the window is minimized | Sets `kAXMinimizedAttribute` to false | It reads false within 2 s |
| `already-done` | Fullscreen mode, if it's already done | Skips the rest | The window is fullscreen on the target |
| `exit-fullscreen` | If the window is fullscreen | Sets `AXFullScreen = false`, then waits up to 2 s for the source display's status items to come back (with an always-hidden menu bar they never do; that only adds a note) | It reads false, and the frame stays the same for 300 ms |
| `move` | Always | Sets the frame to the target's visible area, up to 3 attempts | The window's frame stays mostly on the target (compared by display id) for 300 ms, within 2 s per attempt |
| `verify-maximized` | Maximized mode | Sets the frame again if the size came out clamped, up to 3 attempts | The frame matches the visible area within 2 pt |
| `enter-fullscreen` | Fullscreen mode | Activates the app, raises the window and sets `AXFullScreen = true` if it doesn't already read true; up to 3 attempts with 0.5 s and 1 s pauses. A failed activation is noted in the detail | For 300 ms in a row: it reads true, fills the target (the top may be inset up to 50 pt below a notch), and the target shows no status items and no other apps' windows, within 5 s per attempt |

`AXFullScreen` reads true long before the transition ends, and on a notched MacBook a fullscreen frame equals a maximized one. So fullscreen is confirmed from the on-screen window list: once a fullscreen Space shows, the menu bar status items and every other app's windows vanish from that display. The list comes from `CGWindowListCopyWindowInfo` with owner PIDs, layers and bounds only, so it needs no Screen Recording permission, and it only stays current while AppKit's event loop runs.

Failures:

- **A closed window.** A read or setter that fails with `.invalidUIElement` fails the current step at once with "window closed". Other Accessibility errors (the app is busy, an attribute has no value yet) count as "not yet", and the step keeps polling. A frame that can't be read never counts as stable.
- **A hung app.** Every application and window element gets a 1 s Accessibility messaging timeout (`AXUIElementSetMessagingTimeout`), so one call can't block the main actor for the system default of about 6 s.
- **Cancellation.** Every wait and pause throws `CancellationError` as soon as the task is cancelled, and `placeStandardWindow` rethrows it. Every other problem is a failed step, never a thrown error.

### Isolation

- The package has no default actor isolation. Pure value types (`ConnectedDisplay`, `PlacementStepResult`, `PlacementStep`, `WindowPlacementMode`, `OnScreenWindowListEntry`, `OnScreenWindowCounts`, the errors) are nonisolated and `Sendable`. `ScreenGeometry` and `FullscreenSpaceSignals` are nonisolated namespaces of pure functions.
- Code that calls the Accessibility API, `NSWorkspace` or `NSScreen` is `@MainActor`: `WindowPlacer`, the `Accessibility*` types, `AppLauncher`, `ConnectedDisplays` and the seam protocols. `ConditionPoller` is `Sendable`; its waits run on the main actor because they call main-actor conditions.

### Seams

`WindowPlacer` gets everything that touches macOS through its initializer. The defaults are the real implementations.

| Protocol | Real implementation | Gives the placer |
|---|---|---|
| `ApplicationLocator` | `WorkspaceApplicationLocator` | The running app's process, launch in the background, reopen, activate, its main or first standard window, and whether it has an off-screen window (`CGWindowListCopyWindowInfo` over all Spaces: a layer-0 window bigger than 1 pt that isn't on screen) |
| `ControllableWindow` | `AccessibilityWindow` | Frame, fullscreen and minimized state, and the setters, each throwing `AccessibilityError` |
| `OnScreenWindowListProvider` | `CoreGraphicsWindowList` | The raw on-screen window list (`OnScreenWindowListEntry`), counted by `FullscreenSpaceSignals` |
| `ConditionPoller(clock:pollInterval:)` | `ContinuousClock`, 50 ms | Elapsed time, waits and backoff pauses |

`DisplayProvider` (real: `ConnectedDisplayProvider`) lists the displays for callers; the placer takes the display list as an argument.

### Tests

`Packages/WindowEngine/Tests/WindowEngineTests`, with Swift Testing. None of them touch real windows or sleep: `Fakes/` holds a `FakeWindow` with switches for misbehaving apps, a `FakeApplicationLocator`, a `FakeWindowList` that hides status items and other windows behind a fullscreen Space, and a `TestClock` whose sleeps advance time at once, so step timings are exact.

| Suite | Covers |
|---|---|
| `WindowPlacerTests` | Every step and failure path: maximize, a fullscreen move across displays, already placed, launch, unminimize, a late move, a clamped size, fullscreen retry with backoff, reopen (background for maximized), an app that ignores `AXFullScreen` either way, a window that closes mid-step, no window, not installed, a target not in the list, display identity by id, a failed activation, cancellation |
| `ConditionPollerTests` | Timeouts, the holding time restarting on flicker, the poll interval, rethrown errors, cancellation, stable values (a missing one never is), `wholeMilliseconds` |
| `ScreenGeometryTests` | Coordinate conversion, largest overlap, fullscreen frames below a notch, centers on a display, frame descriptions (including null and non-finite rects) |
| `FullscreenSpaceSignalsTests` | Counting status items and other apps' windows, ignoring the placed app, overhanging and tiny windows, and other layers |

## Not built yet

| Goal | Today | Needed (see [roadmap](roadmap.md)) |
|---|---|---|
| Setups are real desk arrangements | Generic "Display N" columns | Display fingerprints captured from the connected hardware (UUIDs) |
| Apps go fullscreen or maximized on their display | Apps are only listed. The [window engine](#window-engine) can place one window, but the app doesn't call it | Window engine using the Accessibility API, with a mode per app (Maximized by default) and a per-app option to launch the app if it isn't running |
| Switch automatically when moving between desks | None | Display change watcher, setup matching, and a per-setup choice to apply automatically, ask first, or do nothing |
| Manage setups | Rename and add apps only | Add and delete setups and displays; remove and reorder apps |
| Easy install for others | Local Xcode build | Accessibility permission onboarding, notarized release |
