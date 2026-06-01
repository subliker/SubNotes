import Foundation
import EventKit

/// Reads events from the system calendars via EventKit. Read-only for now;
/// keep this the single seam where calendar access lives so a future write
/// path can be added without touching the rest of the app.
@MainActor
public final class EventReader {
    private let store = EKEventStore()

    public init() {}

    public func requestAccess() async throws -> Bool {
        // Use the completion-handler API wrapped in a continuation: the async
        // variant would send the non-Sendable EKEventStore across an isolation
        // boundary, which Swift 6 strict concurrency rejects.
        try await withCheckedThrowingContinuation { continuation in
            store.requestFullAccessToEvents { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    public var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    public func upcomingEvents(within days: Int = 7) -> [CalEvent] {
        let start = Date()
        guard let end = Calendar.current.date(byAdding: .day, value: days, to: start) else {
            return []
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                CalEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Untitled",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarColorHex: event.calendar.cgColor.hexString
                )
            }
    }
}

private extension CGColor {
    var hexString: String? {
        guard let components, components.count >= 3 else { return nil }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
