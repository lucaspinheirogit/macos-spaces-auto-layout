# macOS Spaces Auto Layout

A macOS app for people who move between desks. You define **setups** (for example *MacBook only*, *MacBook + 1 monitor*, *MacBook + 2 monitors*) and choose which apps go on each display. The goal is for the app to rearrange your windows when you plug into a different setup, either automatically or after asking you.

## Status

The app is currently a **setup editor**:

- It lists your setups and lets you rename them.
- You can add apps to each display of a setup.
- Everything is saved to disk.

The window engine that actually moves apps between displays isn't built yet. See [docs/architecture.md](docs/architecture.md#not-built-yet) for what's missing, [docs/roadmap.md](docs/roadmap.md) for what's being built next, and [docs/research/](docs/research/README.md) for the feasibility research.

## Requirements

- macOS 15 or later
- Xcode 26 or later

## Build, run, test

Open `macos-spaces-auto-layout.xcodeproj` in Xcode and run the `macos-spaces-auto-layout` scheme. The command-line build, test and formatting commands are in [CLAUDE.md](CLAUDE.md#build-and-test); [docs/testing.md](docs/testing.md) explains what the tests cover.

## Project structure

```
macos-spaces-auto-layout/          App target
  MacosSpacesAutoLayoutApp.swift   Entry point, owns the SetupStore
  Models/                          Setup, SetupDisplay, AppPlacement
  Store/                           SetupStore (observable) and JSON file storage
  Views/                           Setups list and setup editor
macos-spaces-auto-layoutTests/     Unit tests (Swift Testing)
spike/                             Fullscreen spike: WindowKit library + CLI (see spike/README.md)
CLAUDE.md                          Instructions for Claude Code sessions, build and test commands
.github/                           CI workflow and pull request template
docs/
  architecture.md                  How the code is organized
  conventions.md                   Naming, code placement, concurrency, saved-data rules
  testing.md                       Automated tests and manual checks
  glossary.md                      Domain terms and coordinate systems
  roadmap.md                       Phases (GitHub milestones)
  workflow.md                      How work is tracked and shipped with GitHub Issues
  research/                        Feasibility research and spike results (dated snapshots)
  design-1.png, design-2.png       UI mockups
```

## Data

Setups are saved as JSON at:

```
~/Library/Application Support/com.lucaspinheiro.SpacesAutoLayout/setups.json
```

To reset the app to its default setups, delete that file.
