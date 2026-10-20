# Roadmap

What we're building next, in order. The work itself lives in **GitHub Issues**; this page explains the phases. For why the phases are in this order, see the [recommended architecture](research/04-recommended-architecture.md#roadmap).

## Phases

Each phase is a GitHub milestone. Its page lists the open and closed issues and shows a progress bar.

| Phase | Goal | Done when |
|---|---|---|
| [0: Spike](https://github.com/lucaspinheirogit/macos-spaces-auto-layout/milestone/1) | Find out whether native fullscreen works across displays with public APIs | The two-display bench decides go/no-go (≥ 95% success with retries), and the open product questions are answered |
| [1: Engine MVP](https://github.com/lucaspinheirogit/macos-spaces-auto-layout/milestone/2) | The app can arrange windows: identify displays, match a setup, place each app Maximized or Fullscreen | "Apply now" in the menu bar arranges a setup's apps on a real desk |
| [2: Editor](https://github.com/lucaspinheirogit/macos-spaces-auto-layout/milestone/3) | Setups describe real desks | Setups store captured displays and a mode per app, can be fully managed, and can apply automatically |
| [3: Polish](https://github.com/lucaspinheirogit/macos-spaces-auto-layout/milestone/4) | Others can install and rely on it | Launch at login, results and notifications, multi-window rules, a notarized release |
| [4: Experimental](https://github.com/lucaspinheirogit/macos-spaces-auto-layout/milestone/5) | Optional, later | Space placement with private APIs, behind a flag, only if users ask |

Ideas that aren't in a phase yet are open issues with the [`idea`](https://github.com/lucaspinheirogit/macos-spaces-auto-layout/labels/idea) label and no milestone.

## How we track work

Labels, milestones, what to do when picking up an issue, and how PRs close issues: see [workflow.md](workflow.md).
