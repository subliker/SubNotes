import Foundation

/// One reminder occurrence: an event paired with the moment one of its alarms
/// fires. A single event can yield several triggers (it may have many alarms).
public struct ReminderTrigger: Equatable, Sendable, Identifiable {
    public let event: CalEvent
    public let fireDate: Date

    public init(event: CalEvent, fireDate: Date) {
        self.event = event
        self.fireDate = fireDate
    }

    /// Stable identity per (event, fire moment) so the UI can de-duplicate and
    /// track which triggers it has already presented.
    public var id: String {
        "\(event.id)@\(fireDate.timeIntervalSinceReferenceDate)"
    }
}

/// Pure scheduling logic for overlay reminders (Phase 4).
///
/// EventKit alarms are normalized into absolute `CalEvent.reminders` dates
/// upstream; everything here is a function of those dates, the events, and a
/// reference `now`, with no EventKit or UI dependency, so it is unit tested.
/// The AppKit layer owns the timer and the actual overlay presentation; it asks
/// this type *when* to wake and *what* is due, and presents the queue one item
/// at a time.
public enum ReminderScheduler {

    /// Every reminder trigger across `events`, soonest first. A reminder whose
    /// event has already ended by `now` is dropped (stale — e.g. fired while the
    /// Mac was asleep but the meeting is long over). Ties are broken by event
    /// start then title so the order is deterministic.
    public static func triggers(
        _ events: [CalEvent],
        now: Date = Date()
    ) -> [ReminderTrigger] {
        events
            .flatMap { event in
                event.reminders.map { ReminderTrigger(event: event, fireDate: $0) }
            }
            .filter { $0.event.end > now }
            .sorted(by: Self.order)
    }

    /// The earliest fire moment strictly after `now`, i.e. when the scheduler
    /// timer should next wake. `nil` when nothing is pending. Ignores triggers
    /// already due (those are handled by ``due(_:now:coalesceWindow:)``).
    public static func nextFireDate(
        _ events: [CalEvent],
        after now: Date = Date()
    ) -> Date? {
        triggers(events, now: now)
            .first { $0.fireDate > now }?
            .fireDate
    }

    /// Triggers that are due at `now` (their fire moment has arrived), ordered as
    /// a presentation queue. Reminders whose fire moments fall within
    /// `coalesceWindow` of each other are treated as simultaneous: instead of the
    /// raw sub-second fire order, they are ordered by event start then title, so
    /// a burst that fires "at the same time" presents in a meaningful order. The
    /// consumer shows the queue one item after another.
    ///
    /// Triggers for events that have already ended are excluded (see
    /// ``triggers(_:now:)``), so reminders missed during sleep surface only while
    /// still relevant.
    public static func due(
        _ events: [CalEvent],
        now: Date = Date(),
        coalesceWindow: TimeInterval = 1
    ) -> [ReminderTrigger] {
        let dueTriggers = triggers(events, now: now).filter { $0.fireDate <= now }
        guard coalesceWindow > 0 else { return dueTriggers }

        // Walk the fire-ordered triggers, grouping each run whose fire moments
        // stay within `coalesceWindow` of the run's first, then order each group
        // by event start / title rather than raw fire instant.
        var result: [ReminderTrigger] = []
        var group: [ReminderTrigger] = []
        for trigger in dueTriggers {
            if let anchor = group.first,
               trigger.fireDate.timeIntervalSince(anchor.fireDate) > coalesceWindow {
                result.append(contentsOf: group.sorted(by: orderWithinGroup))
                group.removeAll(keepingCapacity: true)
            }
            group.append(trigger)
        }
        result.append(contentsOf: group.sorted(by: orderWithinGroup))
        return result
    }

    // MARK: - Private

    /// Deterministic ordering: by fire moment, then event start, then title,
    /// then event id. Guarantees a stable queue for simultaneous reminders.
    private static func order(_ a: ReminderTrigger, _ b: ReminderTrigger) -> Bool {
        if a.fireDate != b.fireDate { return a.fireDate < b.fireDate }
        return orderWithinGroup(a, b)
    }

    /// Ordering for reminders deemed simultaneous: by event start, then title,
    /// then id. Ignores the (near-equal) fire moments.
    private static func orderWithinGroup(_ a: ReminderTrigger, _ b: ReminderTrigger) -> Bool {
        if a.event.start != b.event.start { return a.event.start < b.event.start }
        if a.event.title != b.event.title { return a.event.title < b.event.title }
        return a.event.id < b.event.id
    }
}
