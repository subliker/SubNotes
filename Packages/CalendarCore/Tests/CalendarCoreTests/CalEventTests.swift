import Foundation
import Testing
@testable import CalendarCore

@Suite struct CalEventTests {
    @Test func codableRoundTrip() throws {
        let event = CalEvent(
            id: "abc",
            title: "Standup",
            start: Date(timeIntervalSince1970: 1_700_000_000),
            end: Date(timeIntervalSince1970: 1_700_001_800),
            isAllDay: false,
            calendarColorHex: "#FF8800",
            calendarTitle: "Work",
            location: "https://meet.google.com/abc-defg-hij",
            videoLink: VideoLink(
                url: URL(string: "https://meet.google.com/abc-defg-hij")!,
                provider: .meet
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([event])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([CalEvent].self, from: data)

        #expect(decoded == [event])
    }
}
