# Fullscreen spike

A command-line tool that measures how reliably an app can be put into **native fullscreen on a chosen display** using only public APIs (Accessibility + CoreGraphics). It answers the go/no-go question from [Phase 0 of the roadmap](../docs/roadmap.md).

The window code lives in the [`WindowEngine`](../Packages/WindowEngine) package, which the app also links. How a placement works, step by step, is in [docs/architecture.md](../docs/architecture.md#window-engine). This package holds only the CLI (`fullscreen-spike`) and the bench report code (`BenchReport`: the CSV rows and the summary table).

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
swift run fullscreen-spike fullscreen-apps
swift run fullscreen-spike arrange com.apple.Safari com.apple.TextEdit
swift run fullscreen-spike bench --runs 20
swift run fullscreen-spike bench com.apple.Safari com.apple.dt.Xcode --runs 10
```

| Command | What it does |
|---|---|
| `displays` | Lists displays (index, name, UUID, main / built-in, bounds, visible area) and whether "Displays have separate Spaces" is on |
| `windows <bundleId>` | Lists the app's windows: title, subrole, frame, fullscreen, which display |
| `trace <bundleId> [--button]` | Brings the app forward, toggles fullscreen 0.5 s later, and prints the `AXFullScreen` attribute, the frame and the on-screen signals (status items, other apps' windows, the app's own windows) every 50 ms for 3 s. `--button` presses the window's green fullscreen button instead of setting the attribute |
| `place <bundleId> [--display N] [--mode fullscreen\|maximized]` | Places the app's window once with `WindowPlacer` and prints each step with its timing. The default is display 0, fullscreen |
| `fullscreen-apps [--display N]` | Lists the apps with a fullscreen window on the display (default 0), as `FullscreenSpaceSequencer` sees them |
| `arrange <bundleId…> [--display N]` | Runs `FullscreenSpaceSequencer`: these apps in fullscreen in this order, then every other fullscreen app moved behind them. Prints each app and step, and which apps failed |
| `bench [bundleId…] [--runs N]` | Repeats placements for each app (default: the 7 test apps, 20 runs), writes `results/bench-<timestamp>.csv` and prints a summary table |

> **`arrange` takes over the screen** for 1–3 s per app, including every other fullscreen app on the display.

> **`bench` takes over the screen.** It toggles fullscreen on real apps for several minutes (about 3 s per run). Don't use the mouse or keyboard while it runs. Each app is put back the way it was at the end: apps that weren't running are quit, and a window the bench made an app open is closed.

The tool runs its commands inside `NSApplication.run()`, because the on-screen window list only stays current while AppKit's event loop runs.

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

`steps` is `name:ms:ok` joined by `|`, with `:attempts` appended to a step that took more than one attempt (e.g. `enter-fullscreen:6424:1:2`). The names are the raw values of `PlacementStep`. Findings are written up in [docs/research/05-fullscreen-spike-results.md](../docs/research/05-fullscreen-spike-results.md).

## Tests

```sh
swift test
```

`BenchReportTests` covers the CSV rows and escaping, the step names, and the summary statistics. The window code's tests live in the `WindowEngine` package.
