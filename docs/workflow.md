# Workflow

How work on this repo is planned, tracked and shipped. Most of it is done by Claude Code sessions, so this is written to be followed step by step.

## Where things live

| What | Where |
|---|---|
| How the code works today | [`docs/architecture.md`](architecture.md) |
| The phases and their order | [`docs/roadmap.md`](roadmap.md), plus one GitHub milestone per phase |
| Tasks, ideas and bugs | GitHub Issues |
| Research and spike results | [`docs/research/`](research/README.md) |
| Product and technical decisions | The doc that describes the affected behaviour, with a comment on the issue linking to it |
| Change history | Git and closed issues, never the docs |

There is no other tracker (no Linear, Trello or Projects board). If it isn't in an issue or a doc, it isn't tracked.

## Labels

Every issue has exactly one of these:

| Label | Meaning | Milestone |
|---|---|---|
| `enhancement` | Planned work: a feature, refactor or docs task | Its phase |
| `research` | A spike, measurement or product decision | Its phase |
| `idea` | A possible feature, not committed to a phase | None |
| `bug` | Something that's broken | The phase it blocks, or none until triaged |

GitHub's other default labels (`documentation`, `question`, `duplicate` and so on) aren't used.

## Milestones

- One per phase, named `Phase N: Name` (for example `Phase 1: Engine MVP`). [`roadmap.md`](roadmap.md) lists them with their goals.
- Work on the lowest open phase first. Issues in a later phase can be picked up early only when the user asks.
- An issue with no milestone is an idea or an untriaged bug.
- When every issue in a milestone is closed, tell the user and close the milestone once they agree.

## What needs the user's okay

| Fine without asking | Ask first |
|---|---|
| Open an `idea` or `bug` issue for something noticed while working | Promote an idea (give it `enhancement` and a milestone) |
| Comment on the issue being worked on | Move an issue to another milestone |
| Tick checklist items in that issue's body as they're done | Close an issue without a PR, or as "not planned" |
| Create a branch, commit, push it, and open a PR | Create, rename or close milestones and labels |
| | Merge a PR, or push to `main` |

## Doing a task

1. **Find the issue.** `gh issue view <n> --comments`. If the user asks for work that has no issue, and it's more than a small fix, create the issue first (with the right label and milestone) so the PR can close it.
2. **Read what it links to** (docs, research, related issues).
3. **Check it's ready.** If it depends on an open decision (see the `research` issues in the current phase) or the scope is unclear, ask the user before building.
4. **Branch from an up-to-date `main`**: `<type>/<short-name>`, where type is `feat`, `fix`, `refactor`, `docs` or `spike`. Example: `feat/launch-at-login`.
5. **Stay in scope.** Anything else you notice becomes a new issue (`idea` or `bug`, no milestone), not a TODO comment and not part of this PR. Mention it in your summary.
6. **Update the docs in the same PR** as the code: `architecture.md` when the structure or behaviour changes, `README.md` when something user-facing changes, `roadmap.md` when phases change.
7. **Build and test** (see [`CLAUDE.md`](../CLAUDE.md)).
8. **Open the PR** (see below), then tell the user the PR link and anything left open.

## Commits and PRs

- **Commit messages:** an imperative, sentence-case summary with no prefix, e.g. `Add launch at login toggle`. Fixes from a review go in a commit named `Address review: …`.
- **PR title:** what the change does, in the same style.
- **PR body:**
  - `## Summary`: what changed and why, in a few bullets.
  - `## Test plan`: checkboxes for what was run and what's still manual.
  - One line per issue: `Closes #<n>` when the PR finishes it, `Part of #<n>` when it doesn't.
- `Closes #<n>` closes the issue when the PR merges. Use it only when every checklist item in the issue is done.
- The user merges PRs. After a merge, check that the issue closed (`gh issue view <n>`).

## Writing issues

- **Title:** the outcome, short: "Launch at login", "Match the connected displays to a setup".
- **Body:** what and why, links to the relevant docs by repo path, and a `- [ ]` checklist when there are several parts. Add a "done when" line if it isn't obvious.
- **Label and milestone:** as in the tables above.
- When the user mentions an idea in conversation, open an `idea` issue for it.
- Before opening one, search for an existing issue: `gh issue list --search "<words>" --state all`.

## Decisions and plan changes

- When a decision is made (for example an answer in the product-questions issue), write it into the doc it affects, tick it in the issue, and comment with a link to the doc.
- If a result changes the plan (for example the spike says no-go for fullscreen), update `roadmap.md`, the research doc and the affected issues together, after confirming with the user.
- Duplicates: after confirming with the user, close the newer issue with a comment linking to the older one.

## Commands

```sh
gh issue list --milestone "Phase 1: Engine MVP"            # open work in a phase
gh issue list --label idea                                 # the idea list
gh issue list --search "hotkey" --state all                # look for an existing issue
gh issue view 12 --comments                                # read an issue
gh issue create --title "…" --body "…" --label idea        # add an idea
gh issue create --title "…" --body "…" --label enhancement --milestone "Phase 2: Editor"
gh issue edit 22 --remove-label idea --add-label enhancement --milestone "Phase 3: Polish"
gh issue comment 5 --body "Decided: … (see docs/…)"
gh issue close 29 --reason "not planned" --comment "Why: …"
gh api repos/{owner}/{repo}/milestones?state=all -q '.[] | "\(.number) \(.title): \(.open_issues) open, \(.closed_issues) closed"'
```

To tick a checklist item, edit the issue body: `gh issue view <n> --json body -q .body > "$TMPDIR/body.md"`, change `- [ ]` to `- [x]`, then `gh issue edit <n> --body-file "$TMPDIR/body.md"`.
