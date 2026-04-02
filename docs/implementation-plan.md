This is a **Product Requirement Document (PRD)** formatted specifically for **Cursor AI**. You can paste this entire block into a new file named `implementation_plan.md` and then ask Cursor to "Follow the instructions in this file to build the app."

---

# Implementation Plan: Hammerspoon Layout Configurator

## 1. Project Overview
A native macOS app built with **SwiftUI** designed to manage window layouts. 
- **Purpose**: The app acts as a UI-friendly "Frontend" for a Hammerspoon-based window management system.
- **Mechanism**: The app writes a Lua table to `~/.hammerspoon/layouts_generated.lua` and triggers `hs.reload()` via AppleScript.
- **Sandbox**: This app must be **non-sandboxed** to allow direct file system access.

## 2. Technical Stack
- **Language**: Swift 6
- **UI Framework**: SwiftUI
- **Target**: macOS 14+ (Sonoma or later)
- **Permissions**: Disabled App Sandboxing.

## 3. Core Logic Components

### A. HammerspoonManager.swift
A utility class to handle file I/O and Hammerspoon communication.

**Requirements:**
1.  **File Path**: Expand `~/.hammerspoon/layouts_generated.lua` to a full POSIX path.
2.  **Writer**: A function `writeLayoutConfig(luaCode: String)` that writes the string to disk.
3.  **Reloader**: A function `reloadHammerspoon()` that executes the AppleScript:
    `tell application "Hammerspoon" to execute lua code "hs.reload()"`

### B. ContentView.swift
Initial UI for the Proof of Concept.

**Requirements:**
1.  A "Hello World" title.
2.  A button labeled "Apply Hardcoded Layout".
3.  On press, it should:
    - Define a hardcoded string containing the Lua table structure.
    - Call the writer.
    - Call the reloader.

## 4. Hardcoded Lua Template
The hardcoded string to be used for the initial button press:
```lua
local LAYOUTS = {
  [1] = {
    label     = "Single Screen Setup",
    screenMap = { [1] = { "ARC", "CURSOR", "SLACK" } },
  },
  [2] = {
    label     = "Dual Screen Setup",
    screenMap = {
      [1] = { "ARC" },
      [2] = { "CURSOR", "SLACK" },
    },
  },
}
return LAYOUTS
```

## 5. Cursor Instructions for Implementation

### Step 1: Project Setup
- Create a new macOS SwiftUI project.
- **Important**: Go to the project settings -> "Signing & Capabilities". **Remove "App Sandbox"** and **Remove "Library Validation"**.
- In the "Info" tab, ensure there is no "App Sandbox" entry.

### Step 2: Implement HammerspoonManager
```swift
import Foundation

class HammerspoonManager {
    static let shared = HammerspoonManager()
    
    private var configPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".hammerspoon/layouts_generated.lua")
    }
    
    func writeLayout(luaContent: String) {
        do {
            try luaContent.write(to: configPath, atomically: true, encoding: .utf8)
            print("Successfully wrote to \(configPath.path)")
            reloadHammerspoon()
        } catch {
            print("Error writing file: \(error)")
        }
    }
    
    func reloadHammerspoon() {
        let scriptSource = "tell application \"Hammerspoon\" to execute lua code \"hs.reload()\""
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let err = error {
                print("AppleScript Error: \(err)")
            }
        }
    }
}
```

### Step 3: Implement SwiftUI View
```swift
import SwiftUI

struct ContentView: View {
    let hardcodedLua = """
    local LAYOUTS = {
      [1] = {
        label     = "Single Screen Setup",
        screenMap = { [1] = { "ARC", "CURSOR", "SLACK" } },
      },
      [2] = {
        label     = "Dual Screen Setup",
        screenMap = {
          [1] = { "ARC" },
          [2] = { "CURSOR", "SLACK" },
        },
      }
    }
    return LAYOUTS
    """

    var body: some View {
        VStack(spacing: 20) {
            Text("Hammerspoon Configurator")
                .font(.headline)
            
            Button("Apply Hardcoded Layout") {
                HammerspoonManager.shared.writeLayout(luaContent: hardcodedLua)
            }
            .buttonStyle(.borderedProminent)
            
            Text("This will overwrite ~/.hammerspoon/layouts_generated.lua")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 300, height: 200)
    }
}
```

## 6. Verification Steps
1. Run the app.
2. Click the button.
3. Open Terminal and run `cat ~/.hammerspoon/layouts_generated.lua` to verify the content.
4. Check Hammerspoon Console to see if it reloaded.

---

### Architect's Note for the User:
Once you have this working, the next step is to replace the `hardcodedLua` string with a dynamic generator that builds that string based on a list of apps you select in the UI. For now, this plan gets your "bridge" between Swift and Hammerspoon built.