import Foundation

/// A normalized calendar event, decoupled from EventKit so it can be shared
/// across the app, the widget, and (later) overlays via a JSON snapshot.
public struct CalEvent: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let calendarColorHex: String?
    public let calendarTitle: String?
    public let location: String?
    public let videoLink: VideoLink?

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        calendarColorHex: String? = nil,
        calendarTitle: String? = nil,
        location: String? = nil,
        videoLink: VideoLink? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarColorHex = calendarColorHex
        self.calendarTitle = calendarTitle
        self.location = location
        self.videoLink = videoLink
    }
}
