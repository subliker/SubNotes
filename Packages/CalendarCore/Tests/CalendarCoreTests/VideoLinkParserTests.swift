import Foundation
import Testing
@testable import CalendarCore

@Suite struct VideoLinkParserTests {
    @Test func detectsGoogleMeet() throws {
        let link = VideoLinkParser.firstLink(in: "Join: https://meet.google.com/abc-defg-hij")
        #expect(link?.provider == .meet)
        #expect(link?.url.absoluteString == "https://meet.google.com/abc-defg-hij")
    }

    @Test func detectsZoomSubdomain() throws {
        let link = VideoLinkParser.firstLink(in: "https://us02web.zoom.us/j/123456789?pwd=xyz")
        #expect(link?.provider == .zoom)
    }

    @Test func detectsTeams() throws {
        let link = VideoLinkParser.firstLink(in: "https://teams.microsoft.com/l/meetup-join/19%3a...")
        #expect(link?.provider == .teams)
    }

    @Test func detectsWebex() throws {
        let link = VideoLinkParser.firstLink(in: "https://acme.webex.com/meet/room")
        #expect(link?.provider == .webex)
    }

    @Test func ignoresUnknownBareURL() throws {
        let link = VideoLinkParser.firstLink(in: "Docs at https://example.com/agenda")
        #expect(link == nil)
    }

    @Test func returnsNilWhenNoLink() throws {
        #expect(VideoLinkParser.firstLink(in: "No call today") == nil)
        #expect(VideoLinkParser.firstLink(in: nil) == nil)
    }

    @Test func prefersKnownProviderOverEarlierUnknown() throws {
        let texts: [String?] = [
            "see https://example.com/notes",
            "https://meet.google.com/xyz-pqrs-tuv"
        ]
        let link = VideoLinkParser.firstLink(in: texts)
        #expect(link?.provider == .meet)
    }

    @Test func scansFieldsInOrder() throws {
        // url field first, then location, then notes
        let link = VideoLinkParser.firstLink(in: [
            nil,
            "https://us02web.zoom.us/j/555",
            "https://meet.google.com/should-not-win"
        ])
        #expect(link?.provider == .zoom)
    }
}
