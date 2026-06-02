import Foundation
import Testing
@testable import CalendarCore

@Suite struct EventTemplateValuesTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func formatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "HH:mm"
        return f
    }

    private func event(allDay: Bool = false, location: String? = nil) -> CalEvent {
        CalEvent(
            id: "e", title: "Standup", start: start, end: start.addingTimeInterval(3600),
            isAllDay: allDay, location: location
        )
    }

    @Test func mapsTitleTimeAndLocation() {
        let v = event(location: "Room 1").templateValues(timeFormatter: formatter())
        #expect(v["title"] == "Standup")
        #expect(v["time"] == "22:13")
        #expect(v["location"] == "Room 1")
    }

    @Test func allDayHasEmptyTime() {
        let v = event(allDay: true).templateValues(timeFormatter: formatter())
        #expect(v["time"] == "")
    }

    @Test func missingLocationIsEmpty() {
        let v = event().templateValues(timeFormatter: formatter())
        #expect(v["location"] == "")
    }

    @Test func rendersThroughTemplate() {
        let v = event(allDay: true).templateValues(timeFormatter: formatter())
        #expect(TemplateRenderer.render("{{time}} · {{title}}", values: v) == "Standup")
    }
}
