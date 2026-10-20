# CLAUDE.md

A macOS app that arranges windows by "setup": the user defines which apps go on which display, and the app puts them there (maximized or in native fullscreen) when the user plugs into that desk. Today it's a setup editor; the window engine is being built.

## Start here

- [`README.md`](README.md): what the app does, requirements, project structure
- [`docs/architecture.md`](docs/architecture.md): how the code works today, and what isn't built yet
- [`docs/roadmap.md`](docs/roadmap.md): the phases (GitHub milestones)
- [`docs/workflow.md`](docs/workflow.md): how to pick up, track and ship work with GitHub Issues
- [`docs/research/`](docs/research/README.md): feasibility research and spike results
- [`spike/README.md`](spike/README.md): the fullscreen spike (`WindowKit` library + CLI)

## Build and test

App (Xcode project, Swift Testing):

```sh
xcodebuild -project macos-spaces-auto-layout.xcodeproj \
  -scheme macos-spaces-auto-layout \
  -destination 'platform=macOS' \
  build test
```

Spike (Swift package):

```sh
cd spike && swift build && swift test
```

`swift run fullscreen-spike bench` takes over the screen for minutes and needs Accessibility permission. Don't run it unless the user asks.

## Conventions

- Swift 6 language mode, macOS 15+, Apple frameworks only (no dependencies).
- Not sandboxed: the Accessibility API doesn't work in the App Sandbox.
- **Docs describe the current state only.** No change history, no "now does", no mentions of deleted files. History lives in git and closed issues.
- Docs change in the same PR as the code they describe.
- Match the surrounding code's style, naming and comment density.

## Workflow

@docs/workflow.md

## Roadmap

@docs/roadmap.md
