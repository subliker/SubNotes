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

> Status: early development. See [PLAN.md](PLAN.md) for the roadmap.

## Building

Requires Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
open SubNotes.xcodeproj
```

## License

[MIT](LICENSE)
