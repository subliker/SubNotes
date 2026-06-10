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

    /// Per-color variant: each event is judged against *its own* lead window,
    /// resolved from `rules` over the global `defaultLeadMinutes`. A "red" rule
    /// with a 30-minute lead surfaces that event earlier than the rest. All-day
    /// events are still excluded; results are soonest-first.
    public static func imminentEntries(
        _ events: [CalEvent],
        now: Date = Date(),
        defaultLeadMinutes: Int = 15,
        rules: ColorRuleSet
    ) -> [TickerEntry] {
        events
            .filter { !$0.isAllDay }
            .compactMap { event in
                let lead = rules.rule(for: event.colorKey)?.tickerLeadMinutes
                    ?? defaultLeadMinutes
                let window = TimeInterval(lead * 60)
                let delta = event.start.timeIntervalSince(now)
                guard delta >= 0, delta <= window else { return nil }
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

    /// Per-color variant of ``tickerText(_:now:leadMinutes:)``: applies per-color
    /// lead windows for selection and the per-color template for the rendered
    /// line. `nil` when nothing is imminent.
    public static func tickerText(
        _ events: [CalEvent],
        now: Date = Date(),
        defaultLeadMinutes: Int = 15,
        rules: ColorRuleSet,
        timeFormatter: DateFormatter
    ) -> String? {
        guard let entry = imminentEntries(
            events, now: now, defaultLeadMinutes: defaultLeadMinutes, rules: rules
        ).first else { return nil }
        return line(for: entry, rules: rules, timeFormatter: timeFormatter)
    }

    /// The «сейчас» / «через N мин» phrase for an entry — the `{{lead}}`
    /// placeholder value in per-color templates and the default line.
    public static func leadPhrase(for entry: TickerEntry) -> String {
        entry.minutesUntilStart <= 0 ? "сейчас" : "через \(entry.minutesUntilStart) мин"
    }

    /// Renders one entry, e.g. «⏰ через 10 мин · Standup» or «⏰ сейчас · Standup».
    public static func line(for entry: TickerEntry) -> String {
        "⏰ \(leadPhrase(for: entry)) · \(entry.event.title)"
    }

    /// Per-color line: when a rule supplies a `tickerTemplate`, render it with
    /// the `{{lead}}`, `{{title}}`, `{{time}}`, `{{location}}` placeholders;
    /// otherwise fall back to ``line(for:)``. `timeFormatter` localizes
    /// `{{time}}` (injected so the logic stays testable).
    public static func line(
        for entry: TickerEntry,
        rules: ColorRuleSet,
        timeFormatter: DateFormatter
    ) -> String {
        guard let template = rules.rule(for: entry.event.colorKey)?.tickerTemplate
        else { return line(for: entry) }
        var values = entry.event.templateValues(timeFormatter: timeFormatter)
        values["lead"] = leadPhrase(for: entry)
        return TemplateRenderer.render(template, values: values)
    }

    /// The visible slice of a scrolling marquee. Text that fits the window is
    /// shown as-is (no scroll); longer text wraps around through a gap so it
    /// reads continuously. Drives the menu-bar label one character at a time.
    public static func marqueeFrame(
        _ text: String,
        offset: Int,
        windowLength: Int,
        gap: String = "     "
    ) -> String {
        let chars = Array(text)
        guard chars.count > windowLength else { return text }
        let padded = chars + Array(gap)
        let n = padded.count
        let start = ((offset % n) + n) % n
        var frame = String()
        frame.reserveCapacity(windowLength)
        for i in 0..<windowLength {
            frame.append(padded[(start + i) % n])
        }
        return frame
    }
}
