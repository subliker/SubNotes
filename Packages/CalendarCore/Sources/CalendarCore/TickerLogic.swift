import Foundation

/// One imminent event plus how many whole minutes remain until it starts.
public struct TickerEntry: Equatable, Sendable {
    public let event: CalEvent
    /// Minutes until `event.start`, rounded up. 0 means it is starting now.
    public let minutesUntilStart: Int

    public init(event: CalEvent, minutesUntilStart: Int) {
        self.event = event
        self.minutesUntilStart = minutesUntilStart
    }
}

/// Pure logic behind the menu-bar ticker (RunCat-style smart appearance).
///
/// The ticker only matters in the window `[start - lead, start)`: it surfaces an
/// event a few minutes before it begins, then hides. All decisions here are
/// time/event functions with no UI or EventKit dependency, so they are unit
/// tested; the AppKit layer only renders the resulting text.
///
/// String templates and lead time will later be parameterizable per `ColorKey`;
/// the entry already carries the event so a future resolver can branch on its
/// `colorKey` without changing call sites.
public enum TickerLogic {
    /// Timed events that start within `leadMinutes` from `now` and have not yet
    /// started, soonest first. All-day events are excluded — they have no
    /// meaningful "starts in N minutes" moment.
    public static func imminentEntries(
        _ events: [CalEvent],
        now: Date = Date(),
        leadMinutes: Int = 15
    ) -> [TickerEntry] {
        let lead = TimeInterval(leadMinutes * 60)
        return events
            .filter { !$0.isAllDay }
            .compactMap { event in
                let delta = event.start.timeIntervalSince(now)
                guard delta >= 0, delta <= lead else { return nil }
                let minutes = Int((delta / 60).rounded(.up))
                return TickerEntry(event: event, minutesUntilStart: minutes)
            }
            .sorted { $0.event.start < $1.event.start }
    }

    /// The single ticker line for the nearest imminent event, or `nil` when the
    /// ticker should hide (nothing imminent). Russian UI, matching the popover.
    public static func tickerText(
        _ events: [CalEvent],
        now: Date = Date(),
        leadMinutes: Int = 15
    ) -> String? {
        guard let entry = imminentEntries(events, now: now, leadMinutes: leadMinutes).first
        else { return nil }
        return line(for: entry)
    }

    /// Renders one entry, e.g. «⏰ через 10 мин · Standup» or «⏰ сейчас · Standup».
    public static func line(for entry: TickerEntry) -> String {
        let lead = entry.minutesUntilStart <= 0
            ? "сейчас"
            : "через \(entry.minutesUntilStart) мин"
        return "⏰ \(lead) · \(entry.event.title)"
    }
}
