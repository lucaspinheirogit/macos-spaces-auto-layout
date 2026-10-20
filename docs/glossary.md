# Glossary

The words this project uses, what each one means, and the type that holds it. When a word here has a type, use that type's name in code, docs and issues so a search finds every use.

## Product terms

| Term | Meaning | Type |
|---|---|---|
| **Setup** | One desk arrangement: a name and the displays it expects, each with the apps that go on it. Called a desk setup in code | `DeskSetup` (app) |
| **Setup display** | A display slot in a setup ("Display 1", "Display 2"…). The first one is shown as **MAIN**. It isn't tied to a physical monitor yet | `DeskSetupDisplay` (app) |
| **App placement** | One app assigned to a setup display, identified by its bundle identifier. An app is in a setup at most once | `AppPlacement` (app) |
| **First-launch setups** | The three setups (1, 2 and 3 displays) shown when there's no saved file. Their ids are fixed | `DeskSetup.firstLaunchSetups` (app) |
| **Schema version** | The format version stored in `setups.json`. A file from a newer version loads read-only | `DeskSetupFile.schemaVersion` (app) |
| **Saving blocked** | The store refuses to save because that could destroy a file it couldn't load. The list shows a banner | `DeskSetupStore.savingBlockedReason` (app) |
| **Maximized** | The window fills the display's visible area (its bounds minus the menu bar and Dock), like Sequoia's *Fill*. It isn't the green button's zoom | `PlacementMode.maximized` (spike) |
| **Fullscreen** | The window is in macOS native fullscreen, in its own Space on that display, set through the `AXFullScreen` attribute. It isn't *Full Screen Tile* | `PlacementMode.fullscreen` (spike) |
| **Apply** | Arrange a setup's apps on the connected displays | Not built yet |

## macOS terms

| Term | Meaning | Type or API |
|---|---|---|
| **Connected display** | A physical or virtual display macOS reports as active | `DisplayInfo` (spike), `CGDirectDisplayID`, `NSScreen` |
| **Display ID** | `CGDirectDisplayID`. Identifies a display only while it stays connected; it can change after a replug or reboot | `DisplayInfo.id` |
| **Display UUID** | `CGDisplayCreateUUIDFromDisplayID`. Usually survives reboots, but can change with the port or dock, and two identical monitors can share one | `DisplayInfo.uuid` |
| **Display index** | Position in one `Displays.current()` list: main display first, then left to right. Only meaningful within that list | `DisplayInfo.index` |
| **Main display** | The display with the menu bar (`CGDisplayIsMain`), set in System Settings → Displays. Not the same as a setup's first display | `DisplayInfo.isMain` |
| **Built-in display** | The MacBook's own screen (`CGDisplayIsBuiltin`) | `DisplayInfo.isBuiltin` |
| **Space** | A macOS desktop. A fullscreen window gets a Space of its own. There's no public API to choose a window's Space | none |
| **Displays have separate Spaces** | Mission Control setting. When it's off, all displays share one set of Spaces and fullscreen behaves differently | `Displays.separateSpacesEnabled` |
| **Status items** | Menu bar extras and Control Center. They disappear from a display while a fullscreen Space shows on it, which is how the engine knows fullscreen has finished | `Displays.OnScreen.statusItems` |
| **Standard window** | A window with subrole `AXStandardWindow` (not a panel, sheet or palette). The engine places one per app | `AXWindow.isStandard` |
| **Settle time** | How long a check must keep holding before a step counts as done (300 ms). Catches windows that move back after an animation | `Placement.settleTime`, `Wait.until(timeout:stableFor:)` |

## Coordinate systems

macOS uses two coordinate spaces for the same screen area. Mixing them up puts windows in the wrong place on any display that isn't the primary one.

| Space | Origin | y grows | Used by |
|---|---|---|---|
| **Global top-left** | Top-left corner of the primary display | Down | The Accessibility API (`kAXPositionAttribute`), `CGDisplayBounds`, `CGWindowListCopyWindowInfo` |
| **AppKit** | Bottom-left corner of the primary display | Up | `NSScreen.frame`, `NSScreen.visibleFrame`, `NSWindow.frame` |

- The **primary display** is the one at the origin, with the menu bar: `CGMainDisplayID()`, `NSScreen.screens[0]`.
- Converting from AppKit to global top-left: `y = primaryHeight - rect.maxY`, where `primaryHeight` is the primary display's height. `Geometry.topLeftRect(fromAppKit:primaryHeight:)` does this.
- Displays left of or above the primary display have negative coordinates.
- The engine works in global top-left coordinates only. It converts `NSScreen` rects as soon as it reads them.
