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
swift run fullscreen-spike place com.apple.Safari --display 0 --mode fullscreen
swift run fullscreen-spike place com.apple.Safari --display 0 --mode maximized
swift run fullscreen-spike bench --runs 20
swift run fullscreen-spike bench com.apple.Safari com.apple.dt.Xcode --runs 10
```

| Command | What it does |
|---|---|
| `displays` | Lists displays (index, name, UUID, main / built-in, bounds, visible area) and whether "Displays have separate Spaces" is on |
| `windows <bundleId>` | Lists the app's windows: title, subrole, frame, fullscreen, which display |
| `place <bundleId> [--display N] [--mode fullscreen\|maximized]` | Places the app's window once and prints each step with its timing |
| `bench [bundleId…] [--runs N]` | Repeats placements for each app (default: the 7 test apps, 20 runs), writes `results/bench-<timestamp>.csv` and prints a summary table |

> **`bench` takes over the screen.** It toggles fullscreen on real apps for several minutes (about 3 s per run). Don't use the mouse or keyboard while it runs. Each app is put back the way it was at the end; apps that weren't running are quit.

## How a placement works

`Placement.place(_:on:among:mode:)` runs these steps and stops at the first one whose check fails:

| Step | Does | Checks |
|---|---|---|
| `app` | Finds the app or launches it in the background, then waits for a standard window (≤ 10 s) | A standard window exists |
| `already-done` | Fullscreen mode only: skips everything if the window is already fullscreen on the target display | |
| `exit-fullscreen` | Sets `AXFullScreen = false` if the window is fullscreen | Reads false and the frame stops changing (≤ 5 s) |
| `move` | Sets the frame to the target's visible area (up to 3 attempts) | The window is mostly on the target display (≤ 2 s per attempt) |
| `verify-maximized` | Maximized mode only | The frame matches the visible area within 2 pt |
| `enter-fullscreen` | Activates the app, raises the window, sets `AXFullScreen = true` (up to 3 attempts, 0.5 s / 1 s backoff) | Reads true, on the target display, and fills it (≤ 5 s per attempt) |

On notched MacBooks, most apps' fullscreen windows sit below the camera housing, so "fills the display" allows the top edge to be inset by up to 50 pt.

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

`steps` is `name:ms:ok` joined by `|`. Findings are written up in [docs/research/05-fullscreen-spike-results.md](../docs/research/05-fullscreen-spike-results.md).

## Tests

```sh
swift test
```

Unit tests cover the pure logic (geometry, CSV, summary statistics). They don't touch real windows.
