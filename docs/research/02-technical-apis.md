# 02: Technical APIs

This document covers the APIs the app would need: for each one, what it does, whether it's public, and what can go wrong.

## Overview: how each feature maps to an API

```
 Detect setup change ─▶ CoreGraphics reconfiguration callback / NSApplication notification   (public)
 Identify displays   ─▶ CGDisplayCreateUUIDFromDisplayID + CGDisplayIsBuiltin + NSScreen     (public)
 Launch apps         ─▶ NSWorkspace / NSRunningApplication                                   (public)
 Find & move windows ─▶ AXUIElement (Accessibility API)                                      (public, needs TCC permission)
 Native fullscreen   ─▶ AXUIElement "AXFullScreen" attribute                                 (public in practice, constant not in headers)
 Spaces (Desktops)   ─▶ CGS / SkyLight                                                       (PRIVATE, fragile — avoid)
```

---

## 1. Detecting display changes

### `CGDisplayRegisterReconfigurationCallback`
- Available since macOS 10.3.
- Apple's docs say the callback is *"invoked twice for each display that's added, removed, or currently online — once before the reconfiguration, and once after."* ([Apple docs](https://developer.apple.com/documentation/coregraphics/cgdisplayregisterreconfigurationcallback(_:_:).md))
- Skip the `kCGDisplayBeginConfigurationFlag` pass. **Debounce:** one plug-in triggers many callbacks.

### `NSApplication.didChangeScreenParametersNotification`
- The simpler AppKit option. It fires after `NSScreen.screens` has updated.
- It also fires when the Dock or menu bar changes size, so compare the new display fingerprint with the old one before re-applying anything.

### Gotchas
- **Wake from sleep:** CoreGraphics can briefly report a placeholder display with an unknown vendor ID. Wait until the display list stops changing (about 1–3 s with no further changes) before matching a setup. ([Apple forums 794959](https://developer.apple.com/forums/thread/794959))
- Events that happen during sleep, or when unlocking a FileVault Mac after it was off, may not be delivered at all. ([hs.screen.watcher docs](https://www.hammerspoon.org/docs/hs.screen.watcher.html)) Also re-check on `NSWorkspace.didWakeNotification` and `sessionDidBecomeActiveNotification`.

## 2. Identifying displays

| Identifier | Stable across reboots? | Notes |
|---|---|---|
| `CGDirectDisplayID` | **No.** It *"typically remains constant until the machine is restarted"*. ([Apple docs](https://developer.apple.com/documentation/coregraphics/cgdirectdisplayid.md)) | Use it at runtime only |
| `CGDisplayCreateUUIDFromDisplayID` → `CFUUID` | **Yes**, generally | Built from EDID data (vendor, model, serial, week/year). Zed uses it. ([Zed source](https://git.secluded.site/zed/blob/v0.123.4/crates/gpui/src/platform/mac/display.rs?raw=1), [rio-window FFI](https://docs.rs/crate/rio-window/0.5.4/source/src/platform_impl/macos/ffi.rs)) |
| `CGDisplayVendorNumber` / `ModelNumber` / `SerialNumber` | Yes | Serial is often 0 or the same across a batch of monitors |
| `CGDisplayIsBuiltin` | Yes | Tells you whether the MacBook's own screen is active (it isn't in clamshell mode) |
| `NSScreen.localizedName` | Yes, but **not unique** | Fine for display in the UI. ([Apple docs](https://developer.apple.com/documentation/appkit/nsscreen/localizedname.md)) |
| `NSScreen.frame` (position in the arrangement) | Until the user rearranges displays | Use it to tell identical monitors apart (left or right) |

**Known pitfalls**
- **Identical monitors.** Some vendors write the same EDID to a whole batch, so two identical monitors get the **same UUID** and macOS mixes up their settings. Apple displays don't have this problem. ([Alin Panaitiu, "Weird monitor bugs"](https://notes.alinpanaitiu.com/Weird%20monitor%20bugs))
- **DisplayLink and docks.** Restarting DisplayLink Manager makes displays show up as "two NEW monitors". ([BetterDisplay #122](https://github.com/waydabber/BetterDisplay/discussions/122))
- **Clamshell mode.** The built-in display disappears from the active list. "Built-in present?" should be part of a setup's identity.

**Recommended setup fingerprint:** the sorted set of `{uuid, isBuiltin, vendor, model, resolution}`. Match exactly first, then fall back to the best partial match (for example, a different monitor of the same size). Use the display's position relative to the main display to tell monitors with identical UUIDs apart.

## 3. Launching and finding apps

- `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` + `openApplication(at:configuration:)`. Use `OpenConfiguration.activates = false` to avoid stealing focus while applying a layout.
- `NSWorkspace.shared.runningApplications` / `NSRunningApplication.runningApplications(withBundleIdentifier:)` to get the PID for the Accessibility API.
- `NSWorkspace.didLaunchApplicationNotification` tells you when an app has launched. Its windows usually appear **later**, so wait for the `kAXWindowCreatedNotification` Accessibility observer, or poll.
- **Store the bundle ID, not the display name.** The current codebase loses it (see [04](04-current-codebase-assessment.md)).

## 4. Accessibility API (AXUIElement): moving, resizing, fullscreen

Core calls:
```swift
let app = AXUIElementCreateApplication(pid)
var windows: CFTypeRef?
AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows)

// move / resize (two separate, non-atomic calls → set size, position, size again to avoid clamping)
var origin = CGPoint(x: frame.minX, y: frame.minY)          // AX uses top-left, global coords
AXUIElementSetAttributeValue(win, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &origin)!)
var size = frame.size
AXUIElementSetAttributeValue(win, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)

// native fullscreen
AXUIElementSetAttributeValue(win, "AXFullScreen" as CFString, kCFBooleanTrue)
```

### Native fullscreen notes
- `"AXFullScreen"` can be read and written. Tools have used it for years: System Events / AppleScript, Keyboard Maestro, Hammerspoon's `hs.window:setFullScreen`. ([KM forum](https://forum.keyboardmaestro.com/t/how-to-nicely-check-if-the-app-is-running-in-full-screen-mode/8905/3), [MacScripter](https://macscripter.net/t/detect-fullscreen/73380), [hs.window](https://www.hammerspoon.org/docs/hs.window.html))
- It is **not a `kAX…` constant in the public headers**. It's a string attribute. It's stable in practice but undocumented.
- Some apps use their own non-native fullscreen and ignore it (VLC, some games, some Electron configurations).
- **There's no API to choose which display fullscreen happens on.** The fullscreen Space is created on whatever display the window is on. The approach that works:
  1. If the window is fullscreen: set `AXFullScreen=false`, then **wait until it reads false** and the exit animation has finished (about 0.7–1 s).
  2. Move and resize the window onto the target display. **Check** that its frame is now inside that display.
  3. Bring the app to the front and raise the window (`kAXRaiseAction`).
  4. Set `AXFullScreen=true`, then **wait until it reads true**. Retry with backoff if it doesn't.

  Others confirm this approach: [WezTerm docs](https://wezterm.org/config/lua/config/native_macos_fullscreen_mode.html), [Parallels KB](https://kb.parallels.com/115171), and a [Unity bug](https://issuetracker-mig.prd.it.unity3d.com/issues/screen-dot-movemainwindowto-api-often-fails-to-switch-fullscreen-player-between-screens-on-mac-osx-with-specific-monitors) that only worked after waiting several frames between steps.
- Moving a normal window onto a display that's currently showing a fullscreen app hides the window behind that app. ([Rectangle #51](https://github.com/rxhanson/rectangle/issues/51))
- **Windows on other Spaces** (including other fullscreen Spaces) often **don't appear** in `kAXWindowsAttribute`, depending on the app. Expect missing windows, and re-scan after Space switches.
- **Run fullscreen transitions one at a time.** Running several at once makes the animations collide; this is where the current Hammerspoon setup "skips steps".

### Electron and Chromium apps
- `AXEnhancedUserInterface` (set by VoiceOver and some tools) breaks snapping and animations in Chromium apps. Turn it off temporarily while moving the window, or set `AXManualAccessibility`. ([Apple forums 659755](https://developer.apple.com/forums/thread/659755), [Electron a11y docs](https://electronjs.org/docs/latest/tutorial/accessibility))
- Accessibility-driven resizes of VS Code, Discord and similar apps can stutter. ([Apple forums 845559](https://developer.apple.com/forums/thread/845559))

### Observers
`AXObserverCreate` + `kAXWindowCreatedNotification`, `kAXMovedNotification`, `kAXResizedNotification`. Use them to react when an app's first window appears instead of polling blindly.

## 5. Spaces (Desktops): private APIs only

There's no public API to list Spaces, find which Space a window is on, or move windows between Spaces. Apple's Developer Technical Support confirmed this in 2026. ([Apple forums 830748](https://developer.apple.com/forums/thread/830748))

Private calls used by tools: `CGSMainConnectionID`, `CGSCopyManagedDisplaySpaces`, `CGSCopySpaces`, `CGSGetWindowWorkspace`, `CGSMoveWindowsToManagedSpace`, `CGSAddWindowsToSpaces` / `CGSRemoveWindowsFromSpaces`, and `SLS*` (SkyLight) equivalents.

**How often they break**

| macOS | What broke | Source |
|---|---|---|
| 14.5 Sonoma | Moving windows to other Spaces stopped working; yabai 7.1.1 fixed it | [yabai CHANGELOG](https://raw.githubusercontent.com/koekeishiya/yabai/master/CHANGELOG.md), [TotalSpaces forum](https://discuss.binaryage.com/t/can-we-help-test-total-spaces-3-if-we-have-apple-silicon/8199?page=13) |
| 15 Sequoia | Moving windows between Spaces **requires SIP disabled** (yabai 7.1.2); Amethyst dropped the feature | [yabai CHANGELOG](https://raw.githubusercontent.com/koekeishiya/yabai/master/CHANGELOG.md), [Amethyst #1682](https://github.com/ianyh/Amethyst/discussions/1682) |
| 15.1 / 15.3 / 15.4 / 26.2–26.6 | yabai's scripting addition needed patches nearly every point release | [yabai CHANGELOG](https://raw.githubusercontent.com/koekeishiya/yabai/master/CHANGELOG.md) |
| 26.x (yabai 7.1.25, May 2026) | Moving windows between Spaces works with SIP **enabled** again (method not investigated) | [yabai CHANGELOG](https://raw.githubusercontent.com/koekeishiya/yabai/master/CHANGELOG.md) |
| 27 beta | CGS calls still load, but the `com.apple.spaces` plist layout changed, breaking tools that read it | [Apple forums 830748](https://developer.apple.com/forums/thread/830748) |

yabai's **scripting addition** injects code into Dock.app, which needs SIP partly disabled: `csrutil enable --without fs --without debug --without nvram`, plus the `-arm64e_preview_abi` boot argument on Apple Silicon. That unlocks creating, destroying, focusing and moving Spaces, plus sticky windows, layers and similar. ([yabai SIP wiki](https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection)) **Asking users to disable SIP isn't acceptable for a consumer app.**

Hammerspoon's `hs.spaces` combines private APIs with clicking through Mission Control in the Dock via Accessibility. It flickers, needs tuned delays, and **cannot move fullscreen windows**. ([hs.spaces docs](https://www.hammerspoon.org/docs/hs.spaces.html))

**Decision:** the app doesn't need to manage Spaces. Native fullscreen creates its own Space on whatever display the window is on, and "maximized" windows stay on that display's current Desktop. Only "put app X on Desktop 3 of display 2" would need private APIs, and that's **out of scope**.

## 6. Permissions and distribution

| Need | Permission | Notes |
|---|---|---|
| Move, resize or fullscreen other apps' windows | **Accessibility** (Privacy & Security → Accessibility) | Check with `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` |
| Window titles from `CGWindowListCopyWindowInfo` | Screen Recording | **Avoid it.** Read titles through the Accessibility API instead. Sequoia re-asks for this permission every month. ([9to5Mac](https://9to5mac.com/2024/08/14/macos-sequoia-screen-recording-prompt-monthly/)) |
| Launch apps | none | |
| Send AppleEvents to Hammerspoon (current approach) | Automation + `NSAppleEventsUsageDescription` | Not needed after the rewrite |

**App Store:** not possible. A sandboxed app can't use `AXUIElementCreateApplication` on other apps, and `AXIsProcessTrusted` always returns false inside the sandbox. ([Apple forums 756130](https://developer.apple.com/forums/thread/756130), [810677](https://developer.apple.com/forums/thread/810677), [836644](https://developer.apple.com/forums/thread/836644)) **Ship as a Developer ID-signed, notarized, non-sandboxed app** (direct download, Homebrew cask, Setapp). The project already has `ENABLE_APP_SANDBOX = NO`.

Gotcha during development: each new code signature (a rebuild with a different signing identity) can invalidate the Accessibility permission. Sign with a stable Development team identity.

---

## Open technical questions (to answer in the spike)
1. How reliably does "move, then `AXFullScreen=true`" land on the right display, measured across Arc/Chrome, Cursor/VS Code (Electron), Slack (Electron), Xcode and Safari?
2. After a display is unplugged, where do the fullscreen Spaces from that display go, and can we still reach their windows through the Accessibility API?
3. How yabai 7.1.25 moves windows between Spaces with SIP enabled. Only matters if Desktop placement is ever wanted.
