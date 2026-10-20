# 05: Fullscreen Spike Results

*Measured 2026-10-20 on a 14" MacBook Pro (notched built-in display, 1512×982 pt), macOS 26, single display. Tool and method: [`spike/`](../../spike/README.md).*

## Verdict so far

**On one display: go.** Native fullscreen can be entered and left reliably with public APIs only. All 6 apps tested succeeded in **120 of 120 runs** (one run needed a retry), as long as the app itself was responsive. Figma's numbers come from a re-run after it installed a pending update; before it, Figma failed 9 of 10 exits (see finding 6).

**Not tested yet: moving fullscreen windows between displays**, which is the core of the product. That needs a second display (a BetterDisplay virtual screen or a real monitor) and decides the final go/no-go from [04 → Phase 0](04-recommended-architecture.md#roadmap).

## Results

20 runs per app, alternating the two single-display scenarios:

| App | Kind | Normal → fullscreen | Fullscreen → maximized | Enter p50 / p95 | Exit p50 / p95 |
|---|---|---|---|---|---|
| Arc | Chromium | 10/10 | 10/10 | 865 / 6428 ms¹ | 1288 / 1308 ms |
| Cursor | Electron | 10/10 | 10/10 | 851 / 891 ms | 714 / 752 ms |
| Slack | Electron | 10/10 | 10/10 | 838 / 983 ms | 713 / 758 ms |
| Safari | Native | 10/10 | 10/10 | 858 / 920 ms | 776 / 818 ms |
| Xcode | Native | 10/10 | 10/10 | 893 / 1019 ms | 754 / 802 ms |
| Figma | Electron | 10/10 | 10/10 | 841 / 878 ms | 718 / 787 ms |

Times cover the whole placement: finding the window, the transition, and a 300 ms check that the result holds.

¹ The run took 6.4 s: the first fullscreen attempt timed out after 5 s, and the second succeeded. No other run came near the 5 s timeout. These CSVs predate the attempt count in the `steps` field, so the retry is read from the timing.

Warp wasn't benchmarked, because it was the terminal running the tool. Raw data: [`spike/results/`](../../spike/results/).

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

## What's next

1. **Two-display bench.**
   - Create a virtual screen in BetterDisplay (already installed) and run `swift run fullscreen-spike bench --runs 20`.
   - Each run moves a fullscreen window to the other display: exit → move → enter.
   - Check that the signals behave on a secondary display too: status items should come back on the display the window left (an `exit-fullscreen` note says when they don't), and disappear from the one it entered.
   - Then confirm on a real monitor.
2. Decide the go/no-go from that result, then promote `WindowKit` from the spike into the app ([04 → Phase 1](04-recommended-architecture.md#roadmap)).
