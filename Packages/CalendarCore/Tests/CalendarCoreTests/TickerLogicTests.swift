import Foundation
import Testing
@testable import CalendarCore

@Suite struct TickerLogicTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func event(
        _ id: String,
        startsInMinutes minutes: Double,
        allDay: Bool = false,
        color: String? = nil,
        location: String? = nil
    ) -> CalEvent {
        let start = now.addingTimeInterval(minutes * 60)
        return CalEvent(
            id: id,
            title: id,
            start: start,
            end: start.addingTimeInterval(3600),
            isAllDay: allDay,
            colorKey: color.flatMap { ColorKey(hex: $0) },
            location: location
        )
    }

    private func utcTimeFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "HH:mm"
        return f
    }

    @Test func includesEventsWithinLeadWindow() {
        let entries = TickerLogic.imminentEntries(
            [event("soon", startsInMinutes: 10)],
            now: now,
            leadMinutes: 15
        )
        #expect(entries.map(\.event.id) == ["soon"])
        #expect(entries.first?.minutesUntilStart == 10)
    }

    @Test func excludesEventsBeyondLead() {
        let entries = TickerLogic.imminentEntries(
            [event("later", startsInMinutes: 30)],
            now: now,
            leadMinutes: 15
        )
        #expect(entries.isEmpty)
    }

    @Test func excludesAlreadyStarted() {
        let entries = TickerLogic.imminentEntries(
            [event("past", startsInMinutes: -5)],
            now: now,
            leadMinutes: 15
        )
        #expect(entries.isEmpty)
    }

    @Test func excludesAllDay() {
        let entries = TickerLogic.imminentEntries(
            [event("allday", startsInMinutes: 5, allDay: true)],
            now: now,
            leadMinutes: 15
        )
        #expect(entries.isEmpty)
    }

    @Test func roundsPartialMinutesUp() {
        let entries = TickerLogic.imminentEntries(
            [event("partial", startsInMinutes: 9.2)],
            now: now,
            leadMinutes: 15
        )
        #expect(entries.first?.minutesUntilStart == 10)
    }

    @Test func sortsBySoonestFirst() {
        let entries = TickerLogic.imminentEntries(
            [event("b", startsInMinutes: 12), event("a", startsInMinutes: 3)],
            now: now,
            leadMinutes: 15
        )
        #expect(entries.map(\.event.id) == ["a", "b"])
    }

    @Test func tickerTextUsesNearestEvent() {
        let text = TickerLogic.tickerText(
            [event("b", startsInMinutes: 12), event("a", startsInMinutes: 3)],
            now: now,
            leadMinutes: 15
        )
        #expect(text == "⏰ через 3 мин · a")
    }

    @Test func tickerTextNilWhenNothingImminent() {
        #expect(TickerLogic.tickerText([event("later", startsInMinutes: 30)], now: now) == nil)
    }

    @Test func lineSaysNowAtZeroMinutes() {
        let entry = TickerEntry(event: event("e", startsInMinutes: 0), minutesUntilStart: 0)
        #expect(TickerLogic.line(for: entry) == "⏰ сейчас · e")
    }

    // MARK: - Per-color rules (Phase 6)

    @Test func perColorLeadWidensWindowForMatchingColor() {
        let rules = ColorRuleSet(rules: [
            ColorRule(colorKey: ColorKey(hex: "#FF0000")!, tickerLeadMinutes: 30)
        ])
        // 25 min away: beyond the 15-min default, inside the red rule's 30.
        let entries = TickerLogic.imminentEntries(
            [event("red", startsInMinutes: 25, color: "#FF0000")],
            now: now,
            defaultLeadMinutes: 15,
            rules: rules
        )
        #expect(entries.map(\.event.id) == ["red"])
    }

    @Test func perColorLeadLeavesOtherColorsOnDefault() {
        let rules = ColorRuleSet(rules: [
            ColorRule(colorKey: ColorKey(hex: "#FF0000")!, tickerLeadMinutes: 30)
        ])
        let entries = TickerLogic.imminentEntries(
            [event("blue", startsInMinutes: 25, color: "#0000FF")],
            now: now,
            defaultLeadMinutes: 15,
            rules: rules
        )
        #expect(entries.isEmpty)
    }

    @Test func perColorTemplateRendersPlaceholders() {
        let rules = ColorRuleSet(rules: [
            ColorRule(
                colorKey: ColorKey(hex: "#FF0000")!,
                tickerTemplate: "🔴 {{lead}} — {{title}} @ {{location}}"
            )
        ])
        let text = TickerLogic.tickerText(
            [event("Standup", startsInMinutes: 10, color: "#FF0000", location: "Meet")],
            now: now,
            defaultLeadMinutes: 15,
            rules: rules,
            timeFormatter: utcTimeFormatter()
        )
        #expect(text == "🔴 через 10 мин — Standup @ Meet")
    }

    @Test func perColorTemplateFallsBackToDefaultLineWithoutRule() {
        let text = TickerLogic.tickerText(
            [event("Standup", startsInMinutes: 10, color: "#0000FF")],
            now: now,
            defaultLeadMinutes: 15,
            rules: .empty,
            timeFormatter: utcTimeFormatter()
        )
        #expect(text == "⏰ через 10 мин · Standup")
    }

    @Test func perColorTemplateCollapsesMissingLocation() {
        let rules = ColorRuleSet(rules: [
            ColorRule(
                colorKey: ColorKey(hex: "#FF0000")!,
                tickerTemplate: "{{title}} · {{location}}"
            )
        ])
        let line = TickerLogic.line(
            for: TickerEntry(
                event: event("Standup", startsInMinutes: 5, color: "#FF0000"),
                minutesUntilStart: 5),
            rules: rules,
            timeFormatter: utcTimeFormatter()
        )
        #expect(line == "Standup")
    }

    @Test func marqueeShowsShortTextAsIs() {
        #expect(TickerLogic.marqueeFrame("abc", offset: 5, windowLength: 10) == "abc")
    }

    @Test func marqueeScrollsLongTextAndWraps() {
        let text = "0123456789"
        // offset 0 → first 5 chars.
        #expect(TickerLogic.marqueeFrame(text, offset: 0, windowLength: 5, gap: "__") == "01234")
        // offset 1 → shifted by one.
        #expect(TickerLogic.marqueeFrame(text, offset: 1, windowLength: 5, gap: "__") == "12345")
        // Wraps through the gap and back to the start (length 10 + gap 2 = 12).
        #expect(TickerLogic.marqueeFrame(text, offset: 12, windowLength: 5, gap: "__") == "01234")
    }
}
