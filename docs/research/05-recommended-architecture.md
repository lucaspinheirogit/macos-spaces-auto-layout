# 05: Recommended Architecture and Roadmap

## Decision summary

| Question | Decision | Why |
|---|---|---|
| Native macOS feature? | None exists | [01](01-macos-native-capabilities.md) |
| Hammerspoon as engine? | **No.** Use it for prototyping only | Extra install, AppleScript bridge, experimental layout module, can't be shipped to other users ([03](03-existing-tools.md), [04](04-current-codebase-assessment.md)) |
| yabai / private Spaces APIs? | **No** | Break nearly every macOS release; some need SIP disabled ([02 §5](02-technical-apis.md#5-spaces-desktops-private-apis-only)) |
| Engine tech | **Native Swift**: Accessibility API (AXUIElement), CoreGraphics (CGDisplay), NSWorkspace | All public and stable. One app, one permission |
| Placement modes | **Maximized** (default, reliable) + **Native fullscreen** (opt-in, best-effort with checks) | Fullscreen per display has no direct API ([02 §4](02-technical-apis.md#4-accessibility-api-axuielement-moving-resizing-fullscreen)) |
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

struct AppPlacement: Codable, Identifiable {
    var id = UUID()
    var bundleId: String        // source of truth (not display name!)
    var displayUUID: String     // which DisplayFingerprint
    var mode: PlacementMode
    var launchIfNotRunning = true
    var windowTitlePattern: String? // optional, for multi-window apps (later)
}

struct Setup: Codable, Identifiable {
    var id = UUID()
    var name: String                    // "Home desk", "MacBook only"
    var displays: [DisplayFingerprint]  // captured from current hardware
    var placements: [AppPlacement]
    var autoApply = true
}
```

UI change: the editor gets a **"Capture current displays"** button instead of free-form "Monitor N". Each column shows the real display name and its position (left, main, right).

## Apply algorithm

```
on display change:
  wait until the display list is unchanged for ~2s (cap ~10s)
  fp = currentFingerprint()
  setup = matcher.bestMatch(fp)        // exact UUID set > same count+builtin+sizes > none
  if setup?.autoApply: engine.apply(setup)

engine.apply(setup):                   // one job at a time, cancel previous run
  for p in setup.placements (non-fullscreen first, then fullscreen, one by one):
    app = running(p.bundleId) ?? launch(p.bundleId, activates: false)
    win = await firstStandardWindow(app, timeout: 10s)   // AXObserver kAXWindowCreated + poll
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

Key differences from the current Hammerspoon engine:
- **A step whose check fails stops that app's job and reports it** instead of carrying on (fixes issue D12 in [04](04-current-codebase-assessment.md)).
- Waits on Accessibility notifications, with polling as a fallback, instead of fixed delays.
- Fullscreen transitions run strictly one at a time.
- Apps that aren't running get launched.
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

**Phase 2: UI rewire**
- Replace `HammerspoonManager` and the Lua files with a JSON `SetupStore`.
- Editor: capture displays, set the mode for each app, add, remove and reorder.
- Replace the "active" toggle with "auto-apply".

**Phase 3: Polish**
- Launch at login (`SMAppService`).
- Per-app results and notifications.
- Rules for apps with several windows.
- Notarized release.
- Optional: "Snapshot current arrangement into this setup".

**Phase 4 (optional, later)**
- Desktop (Space) placement using private APIs, behind an "experimental" flag.
- Only if users ask for it, and following how yabai 7.1.25 does SIP-on window moves.

## Open questions for the product owner
1. Is **Maximized** acceptable as the default, with native fullscreen opt-in? (This affects how much depends on the spike.)
2. Should the app **launch** missing apps, or only arrange apps that are already open?
3. Should setups apply **automatically** on display change, or ask first ("Switch to Home desk?")?
4. Apps with several windows (e.g. two browser windows on different screens): needed in v1?
5. Keep the deployment target at macOS 26, or move to 27? Lowering it to 15 would reach more users; the APIs used are available there.
