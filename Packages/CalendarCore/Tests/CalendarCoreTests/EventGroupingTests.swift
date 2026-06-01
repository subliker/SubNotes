import Foundation
import Testing
@testable import CalendarCore

@Suite struct EventGroupingTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func event(
        _ id: String,
        day: Int,
        hour: Int = 0,
        allDay: Bool = false
    ) -> CalEvent {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 6
        comps.day = day
        comps.hour = hour
        let start = calendar.date(from: comps)!
        return CalEvent(
            id: id,
            title: id,
            start: start,
            end: start.addingTimeInterval(3600),
            isAllDay: allDay
        )
    }

    @Test func groupsAndSortsByDay() {
        let days = EventGrouping.byDay([
            event("b", day: 2, hour: 9),
            event("a", day: 1, hour: 15),
            event("c", day: 2, hour: 8)
        ], calendar: calendar)

        #expect(days.count == 2)
        #expect(days[0].timed.map(\.id) == ["a"])
        // Same-day timed events sorted by start.
        #expect(days[1].timed.map(\.id) == ["c", "b"])
    }

    @Test func separatesAllDayFromTimed() {
        let days = EventGrouping.byDay([
            event("timed", day: 1, hour: 10),
            event("allday", day: 1, allDay: true)
        ], calendar: calendar)

        #expect(days.count == 1)
        #expect(days[0].allDay.map(\.id) == ["allday"])
        #expect(days[0].timed.map(\.id) == ["timed"])
    }

    @Test func omitsEmptyInput() {
        #expect(EventGrouping.byDay([], calendar: calendar).isEmpty)
    }
}
