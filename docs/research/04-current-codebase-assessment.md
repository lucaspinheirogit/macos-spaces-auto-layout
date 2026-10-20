# 04: Current Codebase Assessment

**Bottom line:** the project has two halves, and **they are not connected.**
- The Swift app (in this repo) writes a Lua file that nothing reads.
- The real window engine is a set of Hammerspoon scripts **outside the repo** (`~/.hammerspoon/`), driven by hardcoded layouts.

Most of the "it's hard and unreliable" feeling comes from the Hammerspoon engine doing fullscreen moves with fixed delays and polling, and from the missing link between the two halves.

## 1. What exists

### In the repo
| File | Purpose |
|---|---|
| `docs/design-1.png`, `docs/design-2.png` | Mockups: layouts list (name, "N Monitors", Edit, on/off toggle) and an editor with one column per monitor |
| `macos-spaces-auto-layout/macos_spaces_auto_layoutApp.swift` | `@main`, a single `Window("Layouts")` |
| `.../ContentView.swift` | Holds the `LayoutStore` and shows `LayoutsView` |
| `.../LayoutsView.swift` | The list. Its toggle calls `store.activate` / `store.deactivate` (≈ lines 69–75) |
| `.../LayoutEditorView.swift` | Editor sheet. An `NSOpenPanel` app picker reads the app's Info.plist (≈ lines 141–171). Save calls `store.saveAndSync` (≈ line 63) |
| `.../Models.swift` | `AppEntry`, `MonitorRole`, `MonitorConfig`, `Layout`, `LayoutStore` |
| `.../HammerspoonManager.swift` | Generates the Lua file, parses it back with regexes, reloads Hammerspoon through `NSAppleScript` (≈ lines 133–139) |
| `project.pbxproj` | `ENABLE_APP_SANDBOX = NO`, `MACOSX_DEPLOYMENT_TARGET = 26.4`, `SWIFT_VERSION = 5.0`, MainActor default isolation, no entitlements file |

### Outside the repo: `~/.hammerspoon/`
| File | Purpose |
|---|---|
| `init.lua` | Starts the screen watcher, runs `monitor.updateLayout()` **on every load/reload**, binds hotkeys |
| `modules/screen-watcher.lua` | `hs.screen.watcher` with a 3 s debounce, then `updateLayout()` |
| `modules/monitor-setup.lua` | **Main engine.** Hardcoded `LAYOUTS` table (≈ lines 107–126) chosen by **number of screens** (≈ line 130). Takes a snapshot, exits fullscreen, moves windows, re-enters fullscreen |
| `modules/window-ops.lua` | `setFullScreen`, `moveToScreen`, `waitUntil` polling (every 0.15 s, gives up after 6 s and **carries on anyway**) |
| `modules/screen-sequence.lua`, `modules/async.lua` | Runs the steps as phases with fixed gaps (0.2 s between apps, 0.5 s between phases, 2 s at start and end). Contains dead code (`sequenceAppsToScreen`, `sequenceAllScreens`) |
| `modules/apps.lua` | Hardcoded bundle IDs (Arc, Cursor, Slack) |
| `config.lua`, `workspaces.lua`, `layout.lua`, `space_utils.lua`, `spacepigeon_config.json` | Older "SpacePigeon" preset system: quits **every** app, forces the number of Spaces on each monitor via `hs.spaces`, uses `moveWindowToSpace` with `kill9` and retries |
| `layouts_generated.lua` | Written by the Swift app. **Nothing reads it.** |

## 2. How the current engine works

```
display change ─▶ hs.screen.watcher ─▶ debounce 3s ─▶ LAYOUTS[#allScreens()]
  phase 1: snapshot all fullscreen apps + their screens
  phase 2: setFullScreen(false) for each, poll until not fullscreen (≤6s)
  phase 3: moveToScreen(target) for managed apps; unmanaged back to original screen
  phase 4: focus → 0.2s → setFullScreen(true) for each
```

The basic idea (exit fullscreen, move, re-enter fullscreen) is **the same approach this research recommends** (see [02 §4](02-technical-apis.md#4-accessibility-api-axuielement-moving-resizing-fullscreen)). The issues are in how it's carried out, not in the approach.

## 3. Issues found

### A. The UI and engine aren't connected
1. **Nothing reads `layouts_generated.lua`.** Turning a layout on reloads Hammerspoon, and `init.lua` then runs `updateLayout()` with the **hardcoded** layouts. The user's edits look like they take effect but don't.
2. **The schemas don't match.** Swift writes `screenMap = { [1] = { name=…, role=…, apps={ "Slack", … } } }`. The engine expects `screenMap = { [1] = { "com.tinyspeck.slackmacgap", … } }`.
3. **Bundle IDs are lost.** `generateLua` writes `$0.name` instead of `bundleId` (≈ line 44), and `parseApps` rebuilds entries from the name only (≈ line 127). The engine needs bundle IDs, and app icons disappear after a restart.

### B. Data model
4. Nothing is `Codable`, and the only saved copy is a Lua file read back with a fragile line-by-line regex parser (≈ lines 62–121).
5. **No display identity.** Monitors are "Monitor 1..N" with a PRIMARY/EXTENDED role. Nothing ties them to physical displays (no UUID, name or frame).
6. **The engine chooses a layout by screen count only**, so two different 2-monitor desks (home and office) can't have different setups.
7. `allScreens()[idx]` has **no guaranteed order**, so index 2 could even be the primary display. `resolveScreenTargets` crashes on `nil:name()` when there are fewer screens than the layout expects.

### C. State and UX logic
8. **Several layouts can be active at once.** `activate` doesn't turn the others off (`Models.swift` ≈ lines 83–87), and the generated file currently has two layouts marked active.
9. "Active" doesn't make sense for a model where **the connected displays decide** which layout applies.
10. **Edits to inactive layouts are lost**: `saveAndSync` only writes when the layout is active (`Models.swift` ≈ line 99).
11. The editor can't add or delete layouts or monitors, can't remove or reorder apps, and has no per-app fullscreen vs. maximized choice.

### D. Reliability (the logged pain point)
The chat logs from 2026-03-27 repeatedly report: *"sometimes dont turn on or off fullscreen, sometimes dont move between screens… skip a sequence in the flow run."* Causes:
12. **Timeouts are ignored.** `waitUntil` carries on after 6 s even when the check never passed, so later steps run on a window that isn't ready.
13. **Only the main window** (`app:mainWindow()`) is handled. Apps on another Space or in another fullscreen Space often return `nil`.
14. Fixed delays (0.2 s / 0.5 s / 2 s) rather than waiting for the window-moved or window-resized events.
15. Apps that aren't running are **skipped, not launched**.
16. Reloading Hammerspoon on every toggle re-runs the whole sequence, which can collide with a run already in progress.

### E. AppleScript bridge
17. `tell application "Hammerspoon" to execute lua code …` needs `hs.allowAppleScript(true)` in `init.lua`, and it isn't there.
18. There's no `NSAppleEventsUsageDescription`, so the Automation permission prompt may silently fail. Errors are only `print`ed.

### F. Housekeeping
19. The project targets **macOS 26.4 / Swift 5**. macOS 27 is now current, and the APIs the app needs are available back to macOS 15.
20. `.DS_Store` and `UserInterfaceState.xcuserstate` are committed.
21. The engine code lives outside version control.
22. The older SpacePigeon system relies on `hs.spaces.moveWindowToSpace`, which **no longer works on macOS 15+ without SIP changes** (see [02 §5](02-technical-apis.md#5-spaces-desktops-private-apis-only)), and it uses `kill9` on user apps.

## 4. What's worth keeping

| Keep | Replace | Drop |
|---|---|---|
| SwiftUI list and editor screens and the mockups' UX | `HammerspoonManager` → native `LayoutEngine` (Accessibility + CoreGraphics) | Lua generation and parsing, AppleScript bridge |
| App picker with icons (`NSOpenPanel` + Info.plist) | `Models.swift` → `Codable` model with display fingerprints and placement mode | SpacePigeon presets, `hs.spaces` use |
| Non-sandboxed build setting | "Active" toggle → "auto-apply when these displays are connected" plus a manual "Apply now" | Hardcoded `LAYOUTS` / `apps.lua` |
| The exit fullscreen → move → re-enter fullscreen sequence | Fixed delays → step-by-step checks with retries | Choosing a layout by screen count |

## 5. Gap to the goal

| Goal requirement | Today | Needed |
|---|---|---|
| User creates setups | UI exists, but edits never reach the engine | Native engine reading a `Codable` store |
| Setup = a specific set of physical displays | Screen count only | UUID-based display fingerprint, "capture current displays" button |
| App → screen, fullscreen | Hardcoded; main window only; flaky | Per-app placement mode, checked transitions, launch if not running |
| Switch automatically when moving between desks | Works for hardcoded layouts via Hammerspoon | Native display watcher with settle time, matching and re-apply |
| Simple for other people to install | Requires Hammerspoon plus manual Lua setup | Single notarized app, Accessibility permission onboarding |
