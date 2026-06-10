import Foundation

/// A lightweight, AppKit-free description of a system calendar, used to drive
/// the Settings calendar-picker without leaking `EKCalendar` into the UI layer.
/// `EventReader` produces these; the picker stores chosen ``id``s into
/// ``AppSettings/enabledCalendarIDs``.
public struct CalendarInfo: Identifiable, Sendable, Equatable {

    /// EventKit's `calendarIdentifier`.
    public let id: String

    /// Display title (e.g. account or calendar name).
    public let title: String

    /// Calendar color as a `#RRGGBB` hex string, if available.
    public let colorHex: String?

    public init(id: String, title: String, colorHex: String? = nil) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
    }
}

extension AppSettings {
    /// Whether a calendar with `id` is enabled under these settings. `nil`
    /// ``enabledCalendarIDs`` (the default) means *all* calendars are on.
    public func isCalendarEnabled(_ id: String) -> Bool {
        guard let enabledCalendarIDs else { return true }
        return enabledCalendarIDs.contains(id)
    }

    /// Returns a copy with the given scalar fields replaced (each defaults to the
    /// current value). Goes through `init`, so the same clamping applies. Calendar
    /// selection has its own seam, ``togglingCalendar(_:enabled:knownIDs:)``.
    public func with(
        horizonDays: Int? = nil,
        tickerLeadMinutes: Int? = nil,
        snoozeIntervals: [Int]? = nil,
        overlayGlassOpacity: Double? = nil,
        colorRules: ColorRuleSet? = nil
    ) -> AppSettings {
        AppSettings(
            enabledCalendarIDs: enabledCalendarIDs,
            horizonDays: horizonDays ?? self.horizonDays,
            tickerLeadMinutes: tickerLeadMinutes ?? self.tickerLeadMinutes,
            snoozeIntervals: snoozeIntervals ?? self.snoozeIntervals,
            overlayGlassOpacity: overlayGlassOpacity ?? self.overlayGlassOpacity,
            colorRules: colorRules ?? self.colorRules
        )
    }

    /// Returns a copy with `id` toggled on/off. Going from "all enabled" (`nil`)
    /// to a partial selection materializes the full set first, minus the one
    /// being switched off, so the user's first toggle behaves intuitively.
    public func togglingCalendar(_ id: String, enabled: Bool, knownIDs: [String]) -> AppSettings {
        var selection = Set(enabledCalendarIDs ?? knownIDs)
        if enabled { selection.insert(id) } else { selection.remove(id) }
        // Collapse "everything selected" back to `nil` so newly-added calendars
        // stay visible by default.
        let next: [String]? = Set(knownIDs).isSubset(of: selection) ? nil : Array(selection)
        return AppSettings(
            enabledCalendarIDs: next,
            horizonDays: horizonDays,
            tickerLeadMinutes: tickerLeadMinutes,
            snoozeIntervals: snoozeIntervals,
            overlayGlassOpacity: overlayGlassOpacity,
            colorRules: colorRules
        )
    }
}
