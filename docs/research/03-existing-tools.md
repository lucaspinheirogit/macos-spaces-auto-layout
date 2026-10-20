# 03: Existing Tools

> **Dated snapshot.** This records what was found and planned at the time. For how the code works today see [architecture](../architecture.md); for what's next see the [roadmap](../roadmap.md).

**Bottom line:** Several apps already re-apply saved window layouts when displays change: **Moom, Rectangle Pro, Stay and Display Maid**. **None of them reliably place apps in native fullscreen on a chosen display**, and the ones that launch apps don't treat a "setup" as a first-class thing. That combination — fullscreen on a chosen display, launching the apps, and a simple setup UI — is what this project would add.

## Comparison table

| Tool | How it works | Native fullscreen / Spaces | Auto-applies on display change | Launches apps | Price / license | Status (2025–26) |
|---|---|---|---|---|---|---|
| **Moom 4.6** | Accessibility API | Not documented | **Yes**: per display configuration, plus on wake/unlock | Not found | $15 one-time | Active (4.6, Aug 2026) |
| **Rectangle Pro** | Accessibility API | Not documented | **Yes**: display connected/disconnected | **Yes** | Paid one-time license | Active |
| **Stay** (Cordless Dog) | Accessibility API | Doesn't reliably restore Spaces | **Yes** | No | Now free | v1.5.1 (Aug 2025) |
| **Display Maid** | Accessibility API | **No fullscreen, no inactive Spaces** | **Yes** | No | $5.99 | Stale (2023) |
| **Hammerspoon** | Accessibility API; `hs.spaces` uses private APIs + Mission Control automation | Can toggle fullscreen; can't move fullscreen windows across Spaces | Yes (you write the script) | Yes (you write the script) | Free, MIT | Active (1.1.1, Feb 2026) |
| **yabai** | Accessibility API + private APIs; optional code injection into the Dock (needs SIP off) | Has a native-fullscreen toggle; Space control needs SIP off | Via signals (scripted) | No | Free, MIT | Supports Tahoe |
| **AeroSpace** | Accessibility API + 1 private API; no SIP changes | **Ignores Spaces**; fakes workspaces by moving windows off-screen | Only by assigning workspaces to monitors | Via callbacks | Free, MIT | Public beta, active |
| **Amethyst** | Accessibility API | Moving windows between Spaces broke on macOS 15 | No | No | Free, MIT | Somewhat active |
| **Keyboard Maestro** | Accessibility API + triggers | Can't move windows between Spaces | **Yes** ("Display Layout Changed" trigger) | Yes | Paid | Active |
| **Phoenix** | Accessibility API, scripted in JS | No | Yes (`screensDidChange`) | Yes | Free, MIT | Somewhat active |
| **Raycast** | Accessibility API | Separate fullscreen toggle | Not found | Yes (with URL/path argument) | Pro | Active |
| **Workspaces 2** (Apptorium) | App/file/URL launcher | n/a | No | **Yes** | $19.99 | Active |
| **Lasso / BetterSnapTool / Magnet / Loop** | Accessibility API (snapping and grids) | No | Not found | No | Paid / paid / paid / free (GPL) | Active |
| **Stage Manager** | Built into macOS | Separate app sets per display | Unclear | No | Built in | n/a |

## Notes on individual tools

### Moom: closest commercial competitor for automatic switching
A saved layout can be set to *"apply automatically when switching to"* a given display configuration, and also on resolution or arrangement changes and on wake or unlock. Its "Adapt to display configuration changes" option rescales layouts. Since 4.6 it matches windows to saved slots by how close they are. It doesn't mention Spaces or launching apps. ([Moom](https://manytricks.com/moom/), [custom actions help](https://manytricks.com/moom/help/customactions.html), [4.6 notes](https://manytricks.com/blog/?p=6732))

### Rectangle Pro: closest competitor on features
- "Save Current Layout" can save one display or all of them.
- It launches closed or minimized apps.
- Each entry can target a display by name, ID or number.
- It can tell windows apart by title regex.
- Layouts can be triggered when a display connects or disconnects.
- Has a URL API.

Its docs don't mention Spaces or fullscreen. ([layouts docs](https://rectangleapp.com/pro/docs/layouts/), [general docs](https://rectangleapp.com/pro/docs/general/))

### Stay and Display Maid
Both store window frames per display configuration and restore them when a display connects or disconnects.
- **Stay:** if several windows match one stored window, they all get the same frame. Restore stops working when macOS "forgets" a configuration. ([Stay docs](https://cordlessdog.com/stay/documentation/restoring-windows))
- **Display Maid:** explicitly can't handle fullscreen apps or windows on inactive Spaces. ([App Store](https://apps.apple.com/us/app/display-maid/id450063525?mt=12))

### Hammerspoon (what the current project uses)
- `hs.screen.watcher` fires when displays are added or removed and when Displays settings change. It also fires when the **Dock changes size**, can fire **twice** for one plug-in, and may **miss events during sleep**. ([docs](https://www.hammerspoon.org/docs/hs.screen.watcher.html))
- `hs.window.layout` has `screensChangedDelay` but is labelled **"EXPERIMENTAL… DO NOT USE IN PRODUCTION"**. ([docs](https://hammerspoon.org/docs/hs.window.layout.html))
- `hs.spaces` depends on Mission Control UI automation, with visible flicker and tuned delays. `moveWindowToSpace` **"cannot move windows of fullscreen or tiled apps"**, and it can only return window objects for windows on visible Spaces. ([docs](https://www.hammerspoon.org/docs/hs.spaces.html))
- Known issue: `moveToScreen` sometimes shrinks Chrome windows instead of moving them. ([#3224](https://github.com/Hammerspoon/hammerspoon/issues/3224))

Hammerspoon is good for prototyping. Shipping it as the engine means asking end users to install and configure Hammerspoon, turn on `hs.allowAppleScript(true)`, and grant permissions to two apps.

### yabai
A powerful tiling window manager driven from the command line. Its Space features need SIP partly disabled, and it gets patched for nearly every macOS point release. It's a good reference for private APIs; it isn't a sensible dependency for a consumer app. ([README](https://cdn.jsdelivr.net/gh/asmvik/yabai@master/README.md), [SIP wiki](https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection), [commands](https://github.com/koekeishiya/yabai/wiki/Commands))

### AeroSpace
- It avoids macOS Spaces entirely: it hides windows of inactive workspaces in a screen corner and only uses one private API (`_AXUIElementGetWindow`).
- `workspace-to-monitor-force-assignment` assigns workspaces to monitors, which is close to our "setup" idea.
- Its guide calls native fullscreen on multiple monitors "clunky".

This is an interesting alternative if native fullscreen ever turns out to be unworkable: "fullscreen" could be redefined as maximized-and-alone. ([repo](https://github.com/nikitabobko/AeroSpace), [guide](https://nikitabobko.github.io/AeroSpace/guide))

### Amethyst
After macOS 15 broke Space moves, the maintainer refused to copy yabai's Dock injection (*"I don't think that is the right way to go"*). They are trying a workaround that triggers the system's own Space-switching keyboard shortcuts; it was still reported broken in July 2026. ([discussion #1682](https://github.com/ianyh/Amethyst/discussions/1682)) This shows what relying on Spaces costs.

### Open-source Swift references (worth reading before coding)
- **[Monitor Glue](https://github.com/erango/monitor-glue)** (MIT). The best design reference:
  - It identifies a layout by the **set of external display hardware UUIDs**, because display IDs change on reconnect.
  - It stores window frames **relative to each monitor**.
  - It matches windows by title, then by their order in the app.
  - It **retries restores for up to 3 minutes** after wake, because apps don't respond to the Accessibility API right away.
- **[Memmon](https://github.com/relikd/Memmon)** (MIT, under 300 lines of Swift). A minimal window restorer. It can only restore windows on other Spaces once you visit them.
- **[Plugback](https://github.com/mabyko/plugback)**. Pre-release.
- **[Loop](https://github.com/mrkai77/loop)** (GPLv3, Swift). Polished code for moving windows with the Accessibility API.

## Problems every tool runs into

1. **No public Spaces API.** Anything involving Spaces breaks on OS updates (14.5, 15, 27 beta). See [02 §5](02-technical-apis.md#5-spaces-desktops-private-apis-only).
2. **Native fullscreen and multiple displays.** You can't move a fullscreen window directly; you have to exit, move, then re-enter fullscreen, with waits that depend on the animations. No tool advertises reliable automatic fullscreen per display.
3. **Timing after connecting a display or waking.** Events fire multiple times, events get missed, and apps don't respond to the Accessibility API for a while after wake. Every tool uses delays plus retries.
4. **Display identity.** Display IDs change; identical monitors share UUIDs; macOS "forgets" configurations.
5. **Electron and Chromium.** `AXEnhancedUserInterface` side effects and resize stutter.
6. **Apps with several windows.** You need matching rules (title regex, order). Naive tools give every window the same frame.
7. **Windows on inactive Spaces** often can't be reached through the Accessibility API.
8. **Screen Recording permission** (re-requested every month on Sequoia) if you read titles via `CGWindowList`. Avoid it.

## What this means for positioning

- "Re-arrange windows when displays change" is **already well served**. Moom, Rectangle Pro and Stay do it.
- What would set this app apart:
  1. **Setups as a first-class idea** with a very simple UI ("MacBook + 2 monitors").
  2. **Native fullscreen per display**, done carefully with step-by-step verification.
  3. **Launching missing apps** as part of applying a setup.
  4. **No configuration language** (unlike Hammerspoon, yabai or AeroSpace).
- If native fullscreen proves too unreliable, the app becomes "Moom/Rectangle Pro, but simpler", which is a much weaker pitch. That's why the **fullscreen spike should come first** (see [04](04-recommended-architecture.md)).
