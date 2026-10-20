# 04: Recommended Architecture and Roadmap

## Decision summary

| Question | Decision | Why |
|---|---|---|
| Native macOS feature? | None exists | [01](01-macos-native-capabilities.md) |
| Hammerspoon as engine? | **No.** Use it for prototyping only | Extra install, AppleScript bridge, experimental layout module, can't be shipped to other users ([03](03-existing-tools.md)) |
| yabai / private Spaces APIs? | **No** | Break nearly every macOS release; some need SIP disabled ([02 §5](02-technical-apis.md#5-spaces-desktops-private-apis-only)) |
| Engine tech | **Native Swift**: Accessibility API (AXUIElement), CoreGraphics (CGDisplay), NSWorkspace | All public and stable. One app, one permission |
| Placement modes | **Maximized** (default, reliable) + **Native fullscreen** (opt-in, best-effort with checks) | Fullscreen per display has no direct API ([02 §4](02-technical-apis.md#4-accessibility-api-axuielement-moving-resizing-fullscreen)) |
| Apps that aren't running | **Per app**: each app has a "launch if not running" option, on by default | Most apps should be ready when you sit down; some (a heavy IDE, a game) should only be arranged if you opened them |
| Applying on display change | **Per setup**: off, ask first (default), or automatic | Asking first is the safe default while the engine is new; a desk you trust can be switched to automatic |
| Apps with several windows | **One window per app in v1**: its main window, else its first standard window | Telling windows apart (by title or order) is the hard part; rules for several windows come later ([#18](https://github.com/lucaspinheirogit/macos-spaces-auto-layout/issues/18)) |
| Setup identity | Set of display UUIDs + built-in flag + arrangement | Display IDs change across reboots; screen count is too coarse ([02 §2](02-technical-apis.md#2-identifying-displays)) |
| Distribution | Developer ID + notarization, not sandboxed, outside the Mac App Store | The Accessibility API doesn't work in the sandbox |

## Components

```
┌──────────── SwiftUI (existing, adapted) ────────────┐
│ SetupsListView · SetupEditorView · Onboarding (AX)  │
└──────────────┬──────────────────────────────────────┘
               │ @Observable SetupStore (Codable JSON in Application Support)
┌──────────────▼──────────────────────────────────────┐
│ DisplayMonitor   CG reconfig callback + NSApp notif │
│                  + wake/unlock → debounce/settle    │
│                  → DisplayFingerprint               │
├─────────────────────────────────────────────────────┤
│ SetupMatcher     fingerprint → best Setup (or none) │
├─────────────────────────────────────────────────────┤
│ LayoutEngine     serial queue of per-app jobs       │
│   AppLauncher    NSWorkspace                        │
│   WindowLocator  AXUIElement + AXObserver           │
│   WindowMover    position/size, verify              │
│   FullscreenSM   exit→verify→move→verify→enter→verify│
└─────────────────────────────────────────────────────┘
        menu-bar extra: current setup · Apply now · Pause
```

## Data model (Codable)

This extends the model the app already has (see [architecture](../architecture.md)) with display identity and per-app placement options.

```swift
struct DisplayFingerprint: Codable, Hashable {
    var uuid: String            // CGDisplayCreateUUIDFromDisplayID
    var isBuiltin: Bool
    var vendor: UInt32, model: UInt32, serial: UInt32
    var name: String            // NSScreen.localizedName, for UI only
    var pixelSize: CGSize
    var relativeOrigin: CGPoint // position vs. main display, disambiguates identical monitors
}

enum PlacementMode: String, Codable { case maximized, nativeFullscreen }

enum ApplyMode: String, Codable { case off, ask, automatic }

struct AppPlacement: Codable, Identifiable {
    var id = UUID()
    var bundleId: String        // source of truth (not display name!)
    var displayUUID: String     // which DisplayFingerprint
    var mode: PlacementMode = .maximized
    var launchIfNotRunning = true   // per app; off = only arrange it if already open
    var windowTitlePattern: String? // optional, for multi-window apps (Phase 3)
}

struct Setup: Codable, Identifiable {
    var id = UUID()
    var name: String                    // "Home desk", "MacBook only"
    var displays: [DisplayFingerprint]  // captured from current hardware
    var placements: [AppPlacement]
    var applyMode: ApplyMode = .ask  // what happens when the displays match this setup
}
```

UI change: the editor gets a **"Capture current displays"** button instead of the generic "Display N" columns. Each column shows the real display name and its position (left, main, right).

## Apply algorithm

```
on display change:
  wait until the display list is unchanged for ~2s (cap ~10s)
  fp = currentFingerprint()
  setup = matcher.bestMatch(fp)        // exact UUID set > same count+builtin+sizes > none
  switch setup?.applyMode:
    .automatic: engine.apply(setup)
    .ask:       notify "Switch to <setup>?" → engine.apply(setup) on confirm
    .off, nil:  do nothing ("Apply now" still works)

engine.apply(setup):                   // one job at a time, cancel previous run
  for p in setup.placements (non-fullscreen first, then fullscreen, one by one):
    app = running(p.bundleId)
          ?? (p.launchIfNotRunning ? launch(p.bundleId, activates: false) : skip, report "not running")
    win = await mainWindow(app, timeout: 10s)   // AXMainWindow, else first standard window; AXObserver kAXWindowCreated + poll
    target = screen(for: p.displayUUID) ?? fallbackScreen
    if p.mode == .maximized:
        if isFullscreen(win): await setFullscreen(win, false)   // verified
        setFrame(win, target.visibleFrame); verify(frame ⊂ target) else retry ×3
    else:
        if isFullscreen(win) && onScreen(win) == target: continue   // already right
        if isFullscreen(win): await setFullscreen(win, false)       // wait until false + animation settles
        setFrame(win, target.visibleFrame); verify on target
        raise(win); activate(app)
        await setFullscreen(win, true)                               // verify true, retry with backoff
  report per-app result (✓ / ⚠︎ reason) in menu bar
```

Key design rules (where Hammerspoon-style scripts with fixed delays fall short):
- **A step whose check fails stops that app's job and reports it** instead of carrying on.
- Waits on Accessibility notifications, with polling as a fallback, instead of fixed delays.
- Fullscreen transitions run strictly one at a time.
- Apps that aren't running get launched, unless that app's launch option is off.
- Display identity comes from UUIDs, so the setup that applies is predictable.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `AXFullScreen` ignored or slow for some apps (Electron, games, custom fullscreen) | Medium | Keep a per-app compatibility list; fall back to Maximized and show ⚠︎ |
| Windows on other Spaces don't appear in Accessibility | Medium–High | Re-scan after each transition; for fullscreen apps, toggling the app active usually brings its window back; document the limitation |
| Identical monitors share a UUID | Low–Medium | Tell them apart by `relativeOrigin`; allow manual "swap" in UI |
| Wake/reconnect timing (apps unresponsive) | High | Settle delay + retries for up to ~2–3 min (Monitor Glue approach) |
| macOS changes `AXFullScreen` behaviour | Low | Public-in-practice and used widely; one code path to patch |
| Users disable "Displays have separate Spaces" | Low | Detect via `com.apple.spaces spans-displays`, warn in onboarding |
| Accessibility permission reset on re-sign during dev | Certain (dev only) | Stable signing identity |

## Roadmap

The phases as first recommended. The current plan is [roadmap.md](../roadmap.md) and its GitHub milestones.

**Phase 0: Spike (1–2 days). Go/no-go for native fullscreen**
- Build a small Swift command-line tool or test target with no UI.
  - List displays with their UUIDs.
  - For a given bundle ID: launch the app, find its window, move it to display N, set `AXFullScreen`, and verify.
  - Repeat with the window starting out fullscreen on a different display.
- Test with Arc/Chrome, Cursor/VS Code, Slack, Safari and Xcode, 20 runs each. Record the success rate and timing.
- **Go** if at least 95% land correctly with retries. **Otherwise** make Maximized the only mode and treat fullscreen as experimental.

**Phase 1: Engine MVP**
- `DisplayMonitor`, `DisplayFingerprint`, `SetupMatcher`, `LayoutEngine` (Maximized + Fullscreen state machine), Accessibility permission onboarding.
- Menu-bar extra with "Apply now".

**Phase 2: Editor features**
- Capture displays, set the mode for each app, add, remove and reorder.
- Add an "auto-apply" switch per setup.

**Phase 3: Polish**
- Launch at login (`SMAppService`).
- Per-app results and notifications.
- Rules for apps with several windows.
- Notarized release.
- Optional: "Snapshot current arrangement into this setup".

**Phase 4 (optional, later)**
- Desktop (Space) placement using private APIs, behind an "experimental" flag.
- Only if users ask for it, and following how yabai 7.1.25 does SIP-on window moves.
