# CLAUDE.md

Working rules for this repo. The full product spec and roadmap live in
[PLAN.md](PLAN.md) — read it before non-trivial work; this file is the short
list of conventions that are easy to forget.

## What this is

SubNotes — a menu-bar-only macOS companion on top of the system Calendar
(EventKit). Three surfaces: popover event list, RunCat-style menu-bar ticker,
and skinnable reminder overlays. Settings is the only real window.

## Hard constraints (don't violate without asking)

- **Unsigned & open-source.** No paid Apple tooling: no Team ID, no provisioning,
  no App Groups, no signed entitlements. Ad-hoc only (`CODE_SIGN_IDENTITY = -`).
  If a feature needs signing, it doesn't ship — flag it instead.
- **Read-only MVP.** We read calendars via EventKit; no event-editing code yet.
  Keep the read/write boundary clean for a future edit phase.
- **Menu-bar only** (`LSUIElement`), no Dock icon.
- **Color-as-key.** Customization rules key off `ColorKey`, not a concrete color
  source — keep that indirection so a later Google API per-event color can swap in.
- **No features outside PLAN.md.** Issues are sliced strictly from the plan.

## Workflow

- **Branch + PR per phase/issue.** Never commit to `main`. Branch names:
  `feat/<slug>` (or `auto/<issue>-<slug>` for the weekend routine), `docs/<slug>`.
- One PR closes its issue (`Closes #N`).
- **Labels are a contract:** `core` = drivable to green CI without a GUI (logic +
  unit tests); `needs-ui` = requires the user's visual acceptance (overlays,
  skins, ticker, settings) — built but not self-verifiable.
- The weekend autonomous routine only touches `core` issues and opens **draft**
  PRs; merging is the user's manual "accepted" signal.
- **Keep the README roadmap in sync.** Any change that shifts a phase's status
  must update the "Roadmap to release" diagram + table in [README.md](README.md)
  in the *same* PR. The schema must not lag reality.

## Build & test

```sh
xcodegen generate                 # regenerate SubNotes.xcodeproj after file changes
cd Packages/CalendarCore && swift test
xcodebuild -project SubNotes.xcodeproj -scheme SubNotes \
  -configuration Debug -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Pure logic (parsers, models, schedulers, ticker) lives in the **CalendarCore**
Swift package with unit tests; the AppKit/SwiftUI layer in `Sources/App` owns
timers, windows, and presentation. Push logic down into CalendarCore so it stays
testable on CI (the routine's Linux env runs CI only — no local build).

## Conventions

- **UI strings and commit messages: Russian.** Code, identifiers, and comments:
  English. Match the surrounding comment density and idiom.
- Conventional-commit subjects (`feat(App):`, `docs:`, `feat(CalendarCore):`).
- Co-author trailer on commits:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
