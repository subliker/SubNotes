import Foundation

/// Events that fall on a single calendar day, split into all-day and timed.
/// The popover renders one section per `EventDay`, all-day items as a banner
/// above the timed ones.
public struct EventDay: Identifiable, Hashable, Sendable {
    /// Start of the day in the grouping calendar.
    public let date: Date
    public let allDay: [CalEvent]
    public let timed: [CalEvent]

    public var id: Date { date }

    public init(date: Date, allDay: [CalEvent], timed: [CalEvent]) {
        self.date = date
        self.allDay = allDay
        self.timed = timed
    }
}

public enum EventGrouping {
    /// Groups events into ascending-by-day sections. Each event is filed under
    /// the day of its `start`; timed events within a day are sorted by start,
    /// all-day events kept separate. Empty days are omitted.
    public static func byDay(_ events: [CalEvent], calendar: Calendar = .current) -> [EventDay] {
        let buckets = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.start)
        }
        return buckets.keys.sorted().map { day in
            let dayEvents = buckets[day] ?? []
            let allDay = dayEvents.filter(\.isAllDay).sorted { $0.title < $1.title }
            let timed = dayEvents.filter { !$0.isAllDay }.sorted { $0.start < $1.start }
            return EventDay(date: day, allDay: allDay, timed: timed)
        }
    }
}
