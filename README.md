# SubNotes

A lightweight macOS companion that sits on top of the system Calendar. It does
not duplicate your calendar — Google events already sync into Calendar.app via
Internet Accounts. SubNotes adds the things the stock app lacks:

- **Desktop widget** — your next events at a glance.
- **Menu-bar ticker** — reminders that appear shortly before an event (RunCat-style).
- **Interactive overlays** — customizable, skinnable reminder windows
  (from a simple card to a flying-plane banner).

Menu-bar only (no Dock icon), built with SwiftUI + AppKit, reading the system
calendars through EventKit. Targets recent macOS (Liquid Glass).

Declared support: liquid glASS.

> Status: early development. See [PLAN.md](PLAN.md) for the full roadmap.

## Roadmap to release

Schematic path from spike to the first public build. Solid = shipped/in progress
up to release; dotted = post-release. Keep this diagram in sync as phases land
(see the workflow rules in [PLAN.md](PLAN.md)).

```mermaid
flowchart LR
    P0["Phase 0 · Spike<br/>✅"] --> P1["Phase 1 · CalendarCore<br/>✅"]
    P1 --> P2["Phase 2 · Popover list<br/>✅"]
    P2 --> P3["Phase 3 · Menu-bar ticker<br/>✅"]
    P3 --> P4["Phase 4 · Overlays + skin engine<br/>✅"]
    P4 --> P5["Phase 5 · Settings · login item · .dmg + CI<br/>🚧"]
    P5 --> REL(["🚀 Release<br/>unsigned .dmg via GitHub"])
    REL -.-> P6["Phase 6 · Color-keyed rules"]
    P6 -.-> GA["Google Calendar API<br/>per-event color"]
```

| Phase | Scope | Status |
|---|---|---|
| 0 | Spike — menu-bar app reads EventKit (widget dropped) | ✅ done |
| 1 | CalendarCore — model, access, live refresh, video links | ✅ done |
| 2 | Popover list — grouped by day, color key, deep-link | ✅ done |
| 3 | Menu-bar ticker — smart appearance | ✅ done |
| 4 | Overlays — transparent window, skin engine, button layer | ✅ done |
| 5 | Settings window + login item ✅ · `.dmg` packaging + CI → **release** | 🚧 in progress |

Phase 6 (color-keyed customization) and the read-only Google Calendar API step
land **after** the first release.

## Why this project

> "I don't give a damn about learning Swift — I just want a utility that's
> convenient for me. With this project I want to find out for myself how
> autonomous neural networks really are at this kind of thing right now."
>
> — the author

> «Мне нахрен не нужно учить Swift, я просто хочу удобную мне утилиту. Этим
> проектом я хочу понять для себя, насколько самостоятельны нейросети в
> подобном сейчас.»
>
> — автор

## Installing

SubNotes ships as an **unsigned** `.dmg` on [GitHub Releases](https://github.com/subliker/SubNotes/releases)
(no Apple Developer account — that's a deliberate constraint of the project).
Because it isn't notarized, macOS quarantines it on download. After dragging
`SubNotes.app` into `/Applications`, clear the quarantine flag once:

```sh
xattr -dr com.apple.quarantine /Applications/SubNotes.app
```

Then launch it from `/Applications`. SubNotes lives in the menu bar only (no
Dock icon) and asks for Calendar access on first run.

## Themes

Reminder overlays are rendered from **skins**: a `.subnotes-theme` folder with a
`manifest.json` inside. Three skins ship built in (`default`, `banner`,
`plane`) — see
[`Packages/CalendarCore/Sources/CalendarCore/Resources/BuiltInThemes`](Packages/CalendarCore/Sources/CalendarCore/Resources/BuiltInThemes)
for working examples. Custom skins use the exact same format.

```
MySkin.subnotes-theme/
├── manifest.json
└── … (optional assets referenced from the manifest)
```

`manifest.json` fields:

| Field | Type | Notes |
|---|---|---|
| `id` | string | Unique skin id (required, non-empty). A user theme overrides a built-in one sharing the same `id`. |
| `name` | string | Display name (required, non-empty). |
| `version` | int | Manifest version, `>= 1`. |
| `duration` | number? | Seconds the overlay stays on screen; omit to stay until dismissed (must be positive when set). |
| `sound` | string? | Optional sound asset name. |
| `animation` | object? | `{ "type": "none" \| "fade" \| "slide" \| "spriteKit", "duration": <seconds> }`. |
| `textZones` | array | Text fields, positioned in **relative** coordinates (see below). |
| `buttons` | array | Action buttons, positioned in relative coordinates. |
| `assets` | array | Relative paths to asset files inside the theme folder. |

Every `frame` is a relative rectangle over the overlay window — `x`, `y`,
`width`, `height` are fractions in `0…1`.

A **`textZone`** has `id`, `frame`, a `template` string, and optional `fontSize`
and `alignment` (`leading` / `center` / `trailing`). Templates support the
placeholders `{{title}}`, `{{time}}`, `{{location}}`.

A **`button`** has `id`, `frame`, an optional `label`, and an `action` — one of
`dismiss`, `snooze`, `openInCalendar`, `connect` (`connect` only appears when a
video link is detected in the event).

Minimal example:

```json
{
  "id": "default",
  "name": "Default",
  "version": 1,
  "duration": 8,
  "animation": { "type": "fade", "duration": 0.3 },
  "textZones": [
    {
      "id": "title",
      "frame": { "x": 0.39, "y": 0.44, "width": 0.22, "height": 0.05 },
      "template": "{{title}}",
      "fontSize": 22,
      "alignment": "center"
    }
  ],
  "buttons": [
    {
      "id": "dismiss",
      "action": "dismiss",
      "frame": { "x": 0.43, "y": 0.55, "width": 0.07, "height": 0.045 },
      "label": "Закрыть"
    }
  ],
  "assets": []
}
```

## Building

Requires Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
open SubNotes.xcodeproj
```

## License

[MIT](LICENSE)
