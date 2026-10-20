# 01: What macOS Offers Natively

**Bottom line:** No version of macOS (15 Sequoia, 26 Tahoe, or the 27 betas) has a built-in "workspace profile" or a way to save a layout for each display setup. Some native features help a little, but none of them save "app X fullscreen on display Y" or re-apply it when you plug in different monitors.

> Note: as of Oct 2026 Apple's help pages already list **macOS 27** as current, alongside 26 and 15. The project's deployment target is macOS 15.

---

## 1. Does macOS remember window positions when displays change?

**Partly, and unreliably. Nothing is documented or guaranteed.**

macOS tries to put windows back when a known display reconnects. Users have reported for years that this often goes wrong:

- Windows pile onto one display after sleep, or get stuck so they only show up in Mission Control. ([Apple forums 651131](https://developer.apple.com/forums/thread/651131?page=3))
- Windows don't go back after unplugging and re-plugging an external monitor, so people build Keyboard Maestro macros instead. ([KM forum](https://forum.keyboardmaestro.com/t/macro-to-restore-window-desktops-position-once-external-monitor-is-reconnected/28707))
- DisplayLink docks move every window onto the DisplayLink screens when they reconnect. ([DisplayLink forum](https://www.displaylink.org/forum/archive/index.php/t-69232.html))
- Windows get rearranged or moved between Spaces after sleep; the BetterDisplay developer calls it a macOS bug. ([BetterDisplay #76](https://github.com/waydabber/BetterDisplay/issues/76))

This automatic restore is the problem the app has to work around, so it can't be the solution.

## 2. Mission Control: "Displays have separate Spaces"

- When it's **on** (the default), each display has its own set of Spaces, and a fullscreen app gets its own Space on the display it's on.
- When it's **off**, a fullscreen app can black out the other displays. ([Duet help](https://www.duetdisplay.com/help-center/when-i-fullscreen-an-app-on-my-mac-the-other-screens-go-black), [Sound On Sound](https://www.soundonsound.com/techniques/apple-notes-0))
- Changing it needs a log-out.
- yabai requires it to be on for macOS 13 through 26. ([yabai README](https://cdn.jsdelivr.net/gh/asmvik/yabai@master/README.md))

**For this project:** the app needs this setting **on** to do fullscreen per display. The app should check it and warn the user during onboarding. It's stored as `com.apple.spaces` → `spans-displays`: false means separate Spaces.

## 3. Dock → Options → "Assign To"

Right-click an app's Dock icon → Options → Assign To. The choices are **All Desktops**, **This Desktop**, **Desktop on Display N** (only shown with 2 or more displays), or **None**. ([Apple support mh14112](https://support.apple.com/guide/mac-help/mh14112/mac))

Why it's not enough:
- It's one global setting per app. It doesn't change based on which displays are connected.
- No public API can read or write it. It lives in the private `com.apple.spaces` plist under `app-bindings`. ([Apple forums 830748](https://developer.apple.com/forums/thread/830748))
- It doesn't apply to fullscreen Spaces. ([TidBITS](https://talk.tidbits.com/t/binding-an-app-to-2nd-monitor/7396))
- One vendor says it has been unreliable since Ventura 13.3.1. I haven't confirmed this. ([Astropad](https://support.astropad.com/en/articles/11835406-how-do-i-control-where-apps-open-on-mac-desktop-spaces))

## 4. Window tiling (Sequoia 15 and later)

Built-in shortcuts ([Apple support mchl9674d0b0](https://support.apple.com/guide/mac-help/mchl9674d0b0/mac)):

| Action | Shortcut |
|---|---|
| Fill | Fn‑Ctrl‑F |
| Center | Fn‑Ctrl‑C |
| Left/Right/Top/Bottom half | Fn‑Ctrl‑Arrow |
| Arrange two windows | Fn‑Ctrl‑Shift‑Arrow |
| Return to previous size | Fn‑Ctrl‑R |
| Full Screen Tile (Entire / Left / Right) | Menu only |

These also appear under **Window → Move & Resize**, **Window → Full Screen Tile**, and in the green-button menu.

Why it's not enough: tiling acts on one window at a time and saves nothing. **Fill** is the same as the "Maximized" mode we want. The app can do the same thing by setting the window's frame through the Accessibility API, or by pressing the menu item. ([cloudspress overview](https://www.cloudspress.com/?p=720758))

## 5. Stage Manager

Each display has its own app groups. There are no saved profiles for each display setup and no public API to control it. ([MacMost guide](https://macmost.com/the-comprehensive-guide-to-mac-stage-manager.html)) It also doesn't work well with tools that move windows; Raycast only sees the top window in each group. **The app should probably detect Stage Manager and warn the user.**

## 6. Shortcuts app and Focus

- Shortcuts has *Find Window*, *Move Window*, *Resize Window* and *Split Screen Apps* actions.
- **It has no trigger for "display connected or disconnected"**, so it can't react automatically when you change desks.
- Users report windows ending up on the main display when they target another one. ([iMore](https://www.imore.com/apps/shortcuts-for-mac), [Apple forums 765572](https://developer.apple.com/forums/thread/765572))
- Focus filters can't control window layout.

A Shortcut you start by hand could cover a small part of the idea. It can't do automatic switching or fullscreen placement on a chosen display.

## 7. macOS 26 Tahoe and 27

- Tahoe's announcement covers the redesign, Spotlight and Continuity. It adds no workspace or per-display layout feature. ([Apple Newsroom](https://www.apple.com/ph/newsroom/2025/06/macos-tahoe-26-makes-the-mac-more-capable-productive-and-intelligent-than-ever))
- The one concrete macOS 27 change found: the private `com.apple.spaces` plist was reorganized. The `Monitors` key moved under `SpacesDisplayConfiguration → Management Data`. That broke a third-party tool that reads it. ([Apple forums 830748](https://developer.apple.com/forums/thread/830748))

## 8. Apple's official position

An Apple Developer Technical Support engineer, answering a developer building a layout manager in 2026:

> "As far as I know there are no APIs that let you achieve this goal… those are subject to change without notice… without there necessarily being any equivalent replacement."

The developer filed **FB23070247** asking for a public Spaces API. ([Apple forums 830748](https://developer.apple.com/forums/thread/830748))

---

## Summary

| Native feature | Saves per setup? | Automatic on display change? | Fullscreen on a chosen display? | Scriptable? |
|---|---|---|---|---|
| macOS automatic window restore | Sort of, unreliable | Yes, unreliable | No | No |
| Dock "Assign To" | No (one setting per app) | No | No | No public API |
| Sequoia tiling | No | No | Full Screen Tile only, on the current display | Through the Accessibility menu |
| Stage Manager | No | No | No | No |
| Shortcuts | Manual | **No trigger** | No | Yes |

**Conclusion:** we need a third-party app. Native features can be **used** (native fullscreen, the Fill frame), but nothing native **coordinates** them.
