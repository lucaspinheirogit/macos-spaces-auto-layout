# 06: Fullscreen Space Order on One Display

> **Dated snapshot.** This records what was found and planned at the time. For how the code works today see [architecture](../architecture.md); for what's next see the [roadmap](../roadmap.md).

*Measured 2026-10-21 on a 14" MacBook Pro (notched built-in display, 1512×982 pt), macOS 26.6.2, one display, with 7 other apps already fullscreen (Arc, Warp, Cursor ×2, Beekeeper Studio, Xcode, Slack). Test apps: Safari and TextEdit. For [#41](https://github.com/lucaspinheirogit/macos-spaces-auto-layout/issues/41).*

## The question

A single-display setup should leave the Spaces as: Desktop → the setup's apps, in setup order → every other fullscreen app, still fullscreen. No public API reorders Spaces, so the plan relies on the Space macOS creates when a window enters fullscreen. Where does that Space go, and can the engine find the other apps' fullscreen windows?

## Verdict

**Go.** A new fullscreen Space always goes at the end of the list, so the order can be built by entering fullscreen in sequence. Fullscreen windows in other Spaces can be reached with public APIs by activating their app first. One thing can't be done publicly: reading the current Space order.

## Method

- Placements used the spike CLI: `place <bundleId> --mode fullscreen`, and `--mode maximized` to leave fullscreen.
- After each step, a throwaway probe printed the Space list from the private, read-only `CGSCopyManagedDisplaySpaces` (one entry per Space with its type, and for a fullscreen Space the owner `pid` and window id `fs_wid`). It was only used to observe the result; nothing in the app or `WindowEngine` calls it.

## Results

| # | Action | Active Space before | Where the new Space went |
|---|---|---|---|
| 1 | Safari, a window on the Desktop → fullscreen | Warp (position 2 of 7) | End of the list |
| 2 | TextEdit → fullscreen | Safari (last) | End of the list |
| 3 | Safari, last but one: exit, then enter again | TextEdit | Exit removed its Space; enter put a new one at the end |
| 4 | TextEdit, in the middle: exit, then enter again | Safari | Same: moved to the end |

The other apps' Spaces kept their order through all of it.

## What the spike found

1. **Entering fullscreen appends a Space at the end of the display's list.**
   - It doesn't matter which Space is active, or where the window was before.
   - Leaving fullscreen removes the Space; entering again appends a new one. So exit + enter moves any fullscreen app to the end.
   - Apply order for #41: enter (or exit and re-enter) each setup app in setup order, then exit and re-enter each other fullscreen app. Result: Desktop → setup apps → others.

2. **An app's window list doesn't include windows in other Spaces, but its main window does.**
   - With Warp's Space active, `kAXWindowsAttribute` returned nothing for Slack, Xcode, Arc, Cursor, Beekeeper Studio and Safari, all fullscreen elsewhere.
   - `kAXMainWindowAttribute` still returned the fullscreen window for Slack, Xcode, Arc, Cursor, Beekeeper Studio and TextEdit, so `WindowPlacer` (which asks for the main window first) found every one in under 50 ms without switching Spaces.
   - When an app has no main window, the list is all that's left, and it's empty: that's the case behind [#37](https://github.com/lucaspinheirogit/macos-spaces-auto-layout/issues/37). `NSRunningApplication.activate()` switches to the app's Space, and its window then appears in the list with `AXFullScreen` true: after 0.3 s for Cursor, after 0.7 s for Slack, Xcode and Arc (sampled at 0.3, 0.7 and 1.5 s).
   - So before deciding an app has no window (and reopening it), the engine should activate it and look again.

3. **The public window list sees every fullscreen window, but can't say which ones are fullscreen.**
   - `CGWindowListCopyWindowInfo` with `.optionAll` lists all 9 fullscreen windows (matching the probe's `fs_wid`s), with owner PID, layer 0 and `onscreen=false` for those in other Spaces.
   - On a notched display their bounds (0,33 1512×949) are the same as a maximized window's, the same ambiguity as [05 finding 1](05-fullscreen-spike-results.md#what-the-spike-found). So the list only gives candidates: apps with a layer-0 window the size of the display. Activating each candidate and reading `AXFullScreen` confirms it.

4. **An app with several fullscreen windows only shows one after activation.**
   - Cursor has two fullscreen Spaces. Activating it showed only one window in Accessibility.
   - The window list does report both, so the engine can tell when an app has more fullscreen windows than it reached. v1 places one window per app ([04](04-recommended-architecture.md#decision-summary)); any others are left where they are, which puts them before the setup's apps.

5. **The current Space order can't be read with public APIs.**
   - The window list orders windows front to back, not by Space.
   - `com.apple.spaces` in `~/Library/Preferences` has a Space list, but it was stale: it didn't include the Spaces made during the test, and listed Slack under a display that isn't connected. It's also private and changed format in macOS 27 ([01](01-macos-native-capabilities.md)).
   - So when the engine moves the other fullscreen apps to the end, it can't keep their order relative to each other without a private API. Their new order is the order the engine visits them in.

6. **Leaving fullscreen doesn't always show the Desktop.**
   - When Safari left fullscreen, macOS showed TextEdit's fullscreen Space instead of the Desktop. The status items stayed hidden, so `exit-fullscreen`'s on-screen check waited its full 2.5 s ("status items never reappeared") before the step counted as done.
   - With several apps in fullscreen this will be common. The exit check needs a signal that doesn't depend on the Desktop being shown, or the apply will spend 2.5 s on every exit.

## Decision

The other fullscreen apps **don't keep their relative order**. Only the setup's apps have a defined order; the others just end up after them, in the order the engine visits them. This keeps the engine on public APIs (finding 5), in line with [04](04-recommended-architecture.md#decision-summary).
