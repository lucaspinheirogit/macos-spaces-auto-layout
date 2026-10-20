# Feasibility Research: Setup-Based Auto Layout for macOS

*Research date: 2026-10-20. Covers macOS 15 Sequoia, macOS 26 Tahoe and the macOS 27 betas.*

## The goal

A simple app where the user defines **setups**, for example:

| Setup | Displays |
|---|---|
| Setup 1 | MacBook screen |
| Setup 2 | MacBook + 1 monitor |
| Setup 3 | MacBook + 2 monitors |

Each setup stores **which apps open fullscreen on which screen**. When the user moves to a different desk, the open apps rearrange themselves onto the screens that setup expects.

## Short answer

**macOS does not do this natively. The project is feasible with public APIs only, plus the user granting Accessibility permission. It does not need Hammerspoon, yabai, or private Spaces APIs.**

The main risks are:

1. **Native fullscreen is asynchronous and flaky.** No API puts a window into fullscreen on a specific display. The window has to be moved there first and then set to fullscreen with the `AXFullScreen` attribute. This needs a state machine that checks each step and retries, not fixed delays.
2. **Display identification.** Use display UUIDs, not indexes. Two identical monitors can report the same UUID.
3. **No Mac App Store.** The Accessibility API doesn't work inside the App Store sandbox, so the app has to ship as a notarized direct download.

## Recommendation

Rewrite the window engine **as a native Swift app** (Accessibility + CoreGraphics + NSWorkspace) and drop the Hammerspoon bridge.

- Keep the SwiftUI screens that already exist.
- Offer **Maximized** (fill the screen) as the reliable default placement mode.
- Offer **Native Fullscreen** as an opt-in mode that tries its best and verifies each step.
- **Start with a 1–2 day spike** that tests whether moving a window and then fullscreening it works reliably on two displays, before building anything else.

## Documents

| # | Doc | What's inside |
|---|---|---|
| 01 | [macOS native capabilities](01-macos-native-capabilities.md) | What macOS already offers (Spaces, Assign To Desktop, tiling, Stage Manager, Shortcuts) and why it isn't enough |
| 02 | [Technical APIs](02-technical-apis.md) | Public APIs (CoreGraphics, NSScreen, Accessibility, NSWorkspace), private Spaces APIs and how often they break, permissions and distribution, identifying displays |
| 03 | [Existing tools](03-existing-tools.md) | Survey of 17+ tools (Moom, Rectangle Pro, Stay, Hammerspoon, yabai, AeroSpace…), a comparison table, and known pain points |
| 04 | [Current codebase assessment](04-current-codebase-assessment.md) | What the repo and the `~/.hammerspoon` scripts do, what's broken, and the gap to the goal |
| 05 | [Recommended architecture](05-recommended-architecture.md) | Data model, apply algorithm, risks, phased roadmap, open questions |

## Feasibility at a glance

| Capability | Feasible? | How |
|---|---|---|
| Detect when the display setup changes | Yes, solid | `CGDisplayRegisterReconfigurationCallback` / `NSApplication.didChangeScreenParametersNotification`, waiting a moment for changes to settle |
| Recognize which setup is connected | Yes, with caveats | `CGDisplayCreateUUIDFromDisplayID`, the built-in display flag, arrangement. Identical monitors are an edge case |
| Launch the apps a setup needs | Yes, solid | `NSWorkspace.openApplication(at:configuration:)` |
| Move a window to a display and maximize it | Yes, solid | AX `kAXPositionAttribute` / `kAXSizeAttribute` |
| Put a window into native fullscreen on a chosen display | Yes, but flaky | Move it first, check it arrived, then set `AXFullScreen = true`, check, retry |
| Move a window that is already fullscreen to another display | Indirectly | Exit fullscreen, check, move, check, re-enter fullscreen |
| Choose which regular Desktop (Space) a window is on | No public API | Private CGS/SkyLight APIs. Breaks often. **Recommend not supporting it** |
| Ship on the Mac App Store | No | Accessibility doesn't work in the sandbox. Use Developer ID and notarization |
| Run without Hammerspoon or yabai | Yes | Everything above is available directly from Swift |
