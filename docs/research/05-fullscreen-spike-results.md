# 05: Fullscreen Spike Results

> **Dated snapshot.** This records what was found and planned at the time. For how the code works today see [architecture](../architecture.md); for what's next see the [roadmap](../roadmap.md).

*Measured 2026-10-20 on a 14" MacBook Pro (notched built-in display, 1512×982 pt), macOS 26. Two-display runs add a 2560×1440 pt [BetterDisplay](https://github.com/waydabber/BetterDisplay) virtual screen to the right of the built-in display. Tool and method: [`spike/`](../../spike/README.md).*

## Verdict so far

**On one display: go.** Native fullscreen can be entered and left reliably with public APIs only. All 6 apps tested succeeded in **120 of 120 runs** (one run needed a retry), as long as the app itself was responsive. Figma's numbers come from a re-run after it installed a pending update; before it, Figma failed 9 of 10 exits (see finding 6).

**Across two displays, on a virtual screen: go.** Moving a fullscreen window to the other display (exit → move → enter), the core of the product, succeeded in **120 of 120 runs**, 60 in each direction; 2 runs needed a retry. That clears the ≥ 95% bar from [04 → Phase 0](04-recommended-architecture.md#roadmap). It depends on the move check waiting for the window to hold its new position (finding 8).

**Not confirmed yet on a real monitor**, which decides the final go/no-go.

## Results

### One display

20 runs per app, alternating the two single-display scenarios:

| App | Kind | Normal → fullscreen | Fullscreen → maximized | Enter p50 / p95 | Exit p50 / p95 |
|---|---|---|---|---|---|
| Arc | Chromium | 10/10 | 10/10 | 865 / 6428 ms¹ | 1288 / 1308 ms |
| Cursor | Electron | 10/10 | 10/10 | 851 / 891 ms | 714 / 752 ms |
| Slack | Electron | 10/10 | 10/10 | 838 / 983 ms | 713 / 758 ms |
| Safari | Native | 10/10 | 10/10 | 858 / 920 ms | 776 / 818 ms |
| Xcode | Native | 10/10 | 10/10 | 893 / 1019 ms | 754 / 802 ms |
| Figma | Electron | 10/10 | 10/10 | 841 / 878 ms | 718 / 787 ms |

Times cover the whole placement: finding the window, the transition, and a 300 ms check that the result holds. They were measured before `move` waited for the window to hold its position (finding 8), which adds about 300 ms to every placement.

¹ The run took 6.4 s: the first fullscreen attempt timed out after 5 s, and the second succeeded. No other run came near the 5 s timeout. These CSVs predate the attempt count in the `steps` field, so the retry is read from the timing.

### Two displays (virtual screen)

20 runs per app of `fullscreen-move`, alternating built-in → virtual and virtual → built-in:

| App | Success | Total p50 / p95 | Runs with a retry |
|---|---|---|---|
| Arc | 20/20 | 2578 / 2661 ms | 0 |
| Cursor | 20/20 | 1906 / 1983 ms | 0 |
| Slack | 20/20 | 1914 / 5864 ms | 2² |
| Safari | 20/20 | 2002 / 2092 ms | 0 |
| Xcode | 20/20 | 2114 / 2181 ms | 0 |
| Figma | 20/20 | 1941 / 2048 ms | 0 |

Per step, across all 120 runs (p50 / p95): exit 777 / 1315 ms, move 352 / 487 ms, enter 848 / 921 ms. Both directions take about the same time (p50 2.0 s). Four runs took over 3 s: Cursor, Slack and Xcode's first runs, where leaving fullscreen took 2.4–2.8 s, and Slack's second run (retries, see ²).

² Run 1 needed a second move attempt (5.9 s); run 2 needed a second move and a second fullscreen attempt (9.4 s, the slowest run).

In the bench, entering fullscreen only counted once the target display showed no status items, and that held on both displays. Coming back is shown by manual `place` runs instead: leaving fullscreen on either display, the status items reappeared there (the bench doesn't record this when it works). So the signal from finding 2 works on a secondary display.

Warp wasn't benchmarked, because it was the terminal running the tool. Raw data: [`spike/results/`](../../spike/results/). `bench-2026-10-20T215519Z.csv` shows the failure from finding 8: three runs that timed out because fullscreen came back on the display the window had left.

## What the spike found

Each of these changed how the engine has to work:

1. **`AXFullScreen` flips immediately; the transition doesn't.**
   - The attribute reads true about 0.1 s after it's set, while the animation runs for about 0.6 s.
   - On a notched MacBook, a fullscreen window also has the same frame as a maximized one.
   - So neither the attribute nor the frame can confirm the transition. A step that trusts them reports "done" too early, which matches the "steps get skipped" problem of the old Hammerspoon scripts.

2. **A reliable completion signal exists, and it's public.**
   - Once a fullscreen Space is showing, the menu bar status items (Control Center and menu extras) and every other app's windows disappear from that display.
   - Leaving fullscreen brings the status items back.
   - `CGWindowListCopyWindowInfo` reports this using only owner PIDs, layers and bounds, which needs **no Screen Recording permission**.
   - The engine treats a transition as complete once these signals have held for 300 ms.

3. **The window list only stays current while AppKit's event loop runs.**
   - In a command-line process without one, the list never changed during a transition.
   - The real app always runs that loop, and so does the spike.

4. **Apps can be running with no window.**
   - Safari launched in the background opened none.
   - Reopening the app (what a Dock click does, via `NSWorkspace.openApplication`) makes it create one.

5. **Window sizes get clamped to the old position.**
   - macOS limits a window's size to what fits where the window currently is.
   - If the app applies the move late, the maximized size comes out too small.
   - Fix: check the final frame and apply it again if needed.

6. **A misbehaving app can ignore every fullscreen request.**
   - While Figma had an update pending, it accepted every way of leaving fullscreen without an error but never left: the attribute, the green button, and View → Toggle Full Screen, with or without bringing it to the front first.
   - After the update, it passed 20/20.
   - The engine can't fix a stuck app, but it can detect it: `Placement` reports a step that times out instead of retrying forever. The app must then fall back to Maximized (not built yet).

7. **Other fullscreen apps hide the signals.**
   - With the terminal in fullscreen, its Space hid the status items on the shared display.
   - `Placement` activates the target app and raises its window before each fullscreen attempt. The engine must also wait until that window is on screen before judging the result (not built yet).

8. **Right after leaving fullscreen, entering it again too soon lands on the old display.**
   - The frame set by `move` reads back on the target at once (1–17 ms). Entering fullscreen straight after put the window back into fullscreen on the display it had left, in every cross-display run.
   - Waiting until the window has stayed on the target for 300 ms fixes it: every move then passed on its first attempt (about 350 ms) and entered fullscreen on the right display.
   - The exact cause is unknown. Because the window never left the target during those 300 ms, it isn't simply macOS moving it back; more likely macOS hadn't yet registered which display the window is on. One manual maximized move right after an exit did need a second attempt, so a move can also fail to stick, which the retry covers.
   - Fix: `move` only counts once the window has stayed on the target for 300 ms, and sets the frame again if it doesn't (up to 3 attempts).

## What's next

1. **Confirm on a real monitor.** Plug one in and run `swift run fullscreen-spike bench --runs 20` again. Timing and display identity can differ from a virtual screen.
2. Decide the go/no-go from that result, then promote `WindowKit` from the spike into the app ([04 → Phase 1](04-recommended-architecture.md#roadmap)).
