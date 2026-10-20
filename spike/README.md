# Fullscreen spike

A command-line tool that measures how reliably an app can be put into **native fullscreen on a chosen display** using only public APIs (Accessibility + CoreGraphics). It answers the go/no-go question from [Phase 0 of the roadmap](../docs/research/04-recommended-architecture.md#roadmap).

The window logic lives in the `WindowKit` library so the app can reuse it if the spike succeeds.

## Requirements

- macOS 15 or later, Swift 6.2 or later (Xcode 26)
- **Accessibility permission for your terminal app.** The first run that touches windows shows the system prompt. Enable your terminal (Terminal, Warp, iTerm…) in System Settings → Privacy & Security → Accessibility, then run the command again.

## Commands

Run from this folder:

```sh
swift run fullscreen-spike displays
swift run fullscreen-spike windows com.apple.Safari
swift run fullscreen-spike trace com.apple.Safari
swift run fullscreen-spike place com.apple.Safari --display 0 --mode fullscreen
swift run fullscreen-spike place com.apple.Safari --display 0 --mode maximized
swift run fullscreen-spike bench --runs 20
swift run fullscreen-spike bench com.apple.Safari com.apple.dt.Xcode --runs 10
```

| Command | What it does |
|---|---|
| `displays` | Lists displays (index, name, UUID, main / built-in, bounds, visible area) and whether "Displays have separate Spaces" is on |
| `windows <bundleId>` | Lists the app's windows: title, subrole, frame, fullscreen, which display |
| `trace <bundleId> [--button]` | Toggles fullscreen once and prints the `AXFullScreen` attribute, the frame and the on-screen signals every 50 ms for 2.5 s. `--button` presses the window's green fullscreen button instead of setting the attribute |
| `place <bundleId> [--display N] [--mode fullscreen\|maximized]` | Places the app's window once and prints each step with its timing |
| `bench [bundleId…] [--runs N]` | Repeats placements for each app (default: the 7 test apps, 20 runs), writes `results/bench-<timestamp>.csv` and prints a summary table |

> **`bench` takes over the screen.** It toggles fullscreen on real apps for several minutes (about 3 s per run). Don't use the mouse or keyboard while it runs. Each app is put back the way it was at the end: apps that weren't running are quit, and a window the bench made an app open is closed.

## How a placement works

`Placement.place(_:on:among:mode:)` runs these steps and stops at the first one whose check fails:

| Step | Does | Checks |
|---|---|---|
| `app` | Finds the app or launches it in the background, then waits for a standard window. If none appears within 2 s, reopens the app (like a Dock click) so it creates one, and waits up to 10 s more | A standard window exists |
| `already-done` | Fullscreen mode only: skips everything if the window is already fullscreen on the target display | |
| `exit-fullscreen` | Sets `AXFullScreen = false` if the window is fullscreen, then waits up to 2 s for the menu bar status items to come back (they never do with an always-hidden menu bar, so this only adds a note to the step) | Reads false, and the frame has stopped changing for 300 ms |
| `move` | Sets the frame to the target's visible area (up to 3 attempts) | The window stays mostly on the target display for 300 ms in a row (≤ 2 s per attempt). Right after leaving fullscreen, macOS can still put it back where it was |
| `verify-maximized` | Maximized mode only. Sets the frame again (up to 3 times) if the app applied the move late and the size got clamped | The frame matches the visible area within 2 pt |
| `enter-fullscreen` | Activates the app, raises the window, sets `AXFullScreen = true` (up to 3 attempts, 0.5 s / 1 s backoff). A retry activates and raises again, and sets the attribute again only if it doesn't read true | For 300 ms in a row: reads true, fills the target display, and the display shows no menu bar status items and no other apps' windows (≤ 5 s per attempt) |

On notched MacBooks, most apps' fullscreen windows sit below the camera housing, so "fills the display" allows the top edge to be inset by up to 50 pt.

### Knowing when fullscreen has really finished

`AXFullScreen` reads true about 0.1 s after it's set, long before the ~0.6 s animation ends, and on a notched MacBook a fullscreen window has the same frame as a maximized one. So the attribute and frame alone can't confirm the transition. The on-screen window list can: once a fullscreen Space is showing, the menu bar status items (Control Center and menu extras) and every other app's windows disappear from that display. `Displays.onScreen(on:excludingPID:)` counts the ones centered on the display from `CGWindowListCopyWindowInfo` using only owner PIDs, layers and bounds, which needs no Screen Recording permission.

This list only stays current while AppKit's event loop runs, so the tool runs its commands inside `NSApplication.run()`, as the real app will.

## Bench scenarios

| Displays | Scenario | Starting state → target |
|---|---|---|
| 1 | `normal-to-fullscreen` | Maximized window → fullscreen |
| 1 | `fullscreen-to-maximized` | Fullscreen window → maximized (exit + resize) |
| 2+ | `fullscreen-move` | Fullscreen on one display → fullscreen on the next display (exit → move → enter) |

## Testing two displays without a monitor

[BetterDisplay](https://github.com/waydabber/BetterDisplay) (free tier) can create a virtual display that macOS treats as real, with its own Spaces: BetterDisplay menu → Create New Virtual Screen. Run `displays` to check it's listed, then run `bench`. Confirm the results on a real monitor before trusting them, since timing and display identity can differ.

## Results

CSV files in `results/` have one row per run:

`app, run, scenario, from_display, to_display, mode, success, failed_step, total_ms, steps`

`steps` is `name:ms:ok` joined by `|`, with `:attempts` appended to a step that took more than one attempt (e.g. `enter-fullscreen:6424:1:2`). Findings are written up in [docs/research/05-fullscreen-spike-results.md](../docs/research/05-fullscreen-spike-results.md).

## Tests

```sh
swift test
```

Unit tests cover the pure logic (geometry, waits, CSV, summary statistics). They don't touch real windows.
