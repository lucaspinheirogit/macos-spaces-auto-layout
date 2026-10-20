# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A macOS app that arranges windows by "setup": the user defines which apps go on which display, and the app puts them there (maximized or in native fullscreen) when the user plugs into that desk. Today it's a setup editor; the window engine is being built.

## Start here

- [`README.md`](README.md): what the app does, requirements, project structure
- [`docs/architecture.md`](docs/architecture.md): how the code works today, and what isn't built yet
- [`docs/roadmap.md`](docs/roadmap.md): the phases (GitHub milestones)
- [`docs/workflow.md`](docs/workflow.md): how to pick up, track and ship work with GitHub Issues
- [`docs/conventions.md`](docs/conventions.md): naming, where code goes, concurrency, saved-data rules, formatting
- [`docs/testing.md`](docs/testing.md): how to add tests, and what to check by hand
- [`docs/glossary.md`](docs/glossary.md): the domain words, the types that hold them, and coordinate systems
- [`docs/research/`](docs/research/README.md): feasibility research and spike results (dated snapshots)
- [`spike/README.md`](spike/README.md): the fullscreen spike CLI, built on the `Packages/WindowEngine` package

## Code layout

Three build units, each with its own tests:

- **The app** (`macos-spaces-auto-layout/`, Xcode project): SwiftUI setup editor plus `setups.json` persistence. It links `WindowEngine` but doesn't call it yet.
- **`Packages/WindowEngine`** (local Swift package): places one app's window on one display, maximized or fullscreen, through the Accessibility API. Everything that touches macOS comes in through protocol seams, so the tests run on fakes and a `TestClock`.
- **`spike/`** (Swift package): the `fullscreen-spike` CLI and bench report that drive `WindowEngine` on real windows.

Actor isolation differs between them, and that trips up new code: the app target defaults to `MainActor`, but its test target and `WindowEngine` don't. Mark test suites that use the store or editor model `@MainActor`, and mark package code that calls Accessibility, `NSWorkspace` or `NSScreen` `@MainActor`.

## Build and test

App (Xcode project, Swift Testing):

```sh
xcodebuild -project macos-spaces-auto-layout.xcodeproj \
  -scheme macos-spaces-auto-layout \
  -destination 'platform=macOS' \
  build test
```

Window engine (Swift package, linked by the app):

```sh
cd Packages/WindowEngine && swift build && swift test
```

One suite (append `/<testName>()` for one test; the `xcodebuild` line takes the same project, scheme and destination as above):

```sh
xcodebuild … test -only-testing:macos-spaces-auto-layoutTests/DeskSetupStoreTests
cd Packages/WindowEngine && swift test --filter WindowPlacerTests
```

Spike (Swift package):

```sh
cd spike && swift build && swift test
```

Formatting (CI fails on any difference):

```sh
swift format format -i --recursive .
swift format lint --strict --recursive .
```

CI (`.github/workflows/ci.yml`) runs all of the above on every pull request, building the app with `CODE_SIGN_IDENTITY=-`. Warnings are errors. No test needs Accessibility permission. The app's tests use temporary storage, so they never touch the real `setups.json`.

`swift run fullscreen-spike bench` takes over the screen for minutes and needs Accessibility permission. Don't run it unless the user asks.

## Conventions

- Swift 6 language mode, macOS 15+, Apple frameworks only (no dependencies).
- Not sandboxed: the Accessibility API doesn't work in the App Sandbox.
- **Docs describe the current state only.** No change history, no "now does", no mentions of deleted files. History lives in git and closed issues. The exception is `docs/research/`: those are dated snapshots of what was found and decided at the time. Fix factual errors in them, but don't rewrite them to match the code.
- Docs change in the same PR as the code they describe.
- Match the surrounding code's style, naming and comment density. Names follow [`docs/conventions.md`](docs/conventions.md).

## Workflow

@docs/workflow.md

## Roadmap

@docs/roadmap.md
