import Foundation

/// User-facing preferences for SubNotes. Pure value type — no AppKit, no
/// persistence logic (that lives in ``SettingsStore``).
///
/// Out-of-range values fed in via ``init(...)`` or decoded from disk are
/// silently clamped back to their defaults, so the rest of the app can treat an
/// `AppSettings` instance as always valid.
public struct AppSettings: Codable, Sendable, Equatable {

    // MARK: - Defaults

    public static let defaultHorizonDays = 7
    public static let defaultTickerLeadMinutes = 15
    public static let defaultSnoozeIntervals = [5, 10, 15]

    // MARK: - Stored values

    /// Calendar identifiers the user has opted into. `nil` means *all* calendars
    /// are enabled — the default, since CalendarCore can't enumerate the system
    /// calendars itself.
    public let enabledCalendarIDs: [String]?

    /// How many days ahead events are loaded. Always >= 1.
    public let horizonDays: Int

    /// Minutes before an event the ticker starts showing it. Always >= 0.
    public let tickerLeadMinutes: Int

    /// Snooze durations (minutes) offered on a reminder overlay. Each entry is
    /// positive and the list is never empty.
    public let snoozeIntervals: [Int]

    // MARK: - Init

    public init(
        enabledCalendarIDs: [String]? = nil,
        horizonDays: Int = AppSettings.defaultHorizonDays,
        tickerLeadMinutes: Int = AppSettings.defaultTickerLeadMinutes,
        snoozeIntervals: [Int] = AppSettings.defaultSnoozeIntervals
    ) {
        self.enabledCalendarIDs = enabledCalendarIDs
        self.horizonDays = AppSettings.sanitizedHorizon(horizonDays)
        self.tickerLeadMinutes = AppSettings.sanitizedLead(tickerLeadMinutes)
        self.snoozeIntervals = AppSettings.sanitizedSnooze(snoozeIntervals)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabledCalendarIDs = try c.decodeIfPresent([String].self, forKey: .enabledCalendarIDs)
        let horizon = try c.decodeIfPresent(Int.self, forKey: .horizonDays)
            ?? AppSettings.defaultHorizonDays
        let lead = try c.decodeIfPresent(Int.self, forKey: .tickerLeadMinutes)
            ?? AppSettings.defaultTickerLeadMinutes
        let snooze = try c.decodeIfPresent([Int].self, forKey: .snoozeIntervals)
            ?? AppSettings.defaultSnoozeIntervals
        horizonDays = AppSettings.sanitizedHorizon(horizon)
        tickerLeadMinutes = AppSettings.sanitizedLead(lead)
        snoozeIntervals = AppSettings.sanitizedSnooze(snooze)
    }

    // MARK: - Sanitization

    private static func sanitizedHorizon(_ value: Int) -> Int {
        value >= 1 ? value : defaultHorizonDays
    }

    private static func sanitizedLead(_ value: Int) -> Int {
        value >= 0 ? value : defaultTickerLeadMinutes
    }

    private static func sanitizedSnooze(_ value: [Int]) -> [Int] {
        let positives = value.filter { $0 > 0 }
        return positives.isEmpty ? defaultSnoozeIntervals : positives
    }
}
