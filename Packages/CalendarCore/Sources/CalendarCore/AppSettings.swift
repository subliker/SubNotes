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
    /// Opacity of the reminder overlay's Liquid Glass card — `0` almost clear,
    /// `1` fully dense. Confirmed as a desired knob on acceptance #7.
    public static let defaultOverlayGlassOpacity = 0.85

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

    /// Opacity of the overlay's Liquid Glass card. Always within `0...1`.
    public let overlayGlassOpacity: Double

    // MARK: - Init

    public init(
        enabledCalendarIDs: [String]? = nil,
        horizonDays: Int = AppSettings.defaultHorizonDays,
        tickerLeadMinutes: Int = AppSettings.defaultTickerLeadMinutes,
        snoozeIntervals: [Int] = AppSettings.defaultSnoozeIntervals,
        overlayGlassOpacity: Double = AppSettings.defaultOverlayGlassOpacity
    ) {
        self.enabledCalendarIDs = enabledCalendarIDs
        self.horizonDays = AppSettings.sanitizedHorizon(horizonDays)
        self.tickerLeadMinutes = AppSettings.sanitizedLead(tickerLeadMinutes)
        self.snoozeIntervals = AppSettings.sanitizedSnooze(snoozeIntervals)
        self.overlayGlassOpacity = AppSettings.sanitizedOpacity(overlayGlassOpacity)
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
        let opacity = try c.decodeIfPresent(Double.self, forKey: .overlayGlassOpacity)
            ?? AppSettings.defaultOverlayGlassOpacity
        horizonDays = AppSettings.sanitizedHorizon(horizon)
        tickerLeadMinutes = AppSettings.sanitizedLead(lead)
        snoozeIntervals = AppSettings.sanitizedSnooze(snooze)
        overlayGlassOpacity = AppSettings.sanitizedOpacity(opacity)
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

    private static func sanitizedOpacity(_ value: Double) -> Double {
        guard value.isFinite else { return defaultOverlayGlassOpacity }
        return min(max(value, 0), 1)
    }
}
