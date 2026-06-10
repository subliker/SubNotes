import Foundation

/// One per-color customization rule, keyed by ``ColorKey`` (Phase 6).
///
/// The color is the identity: at most one rule exists per `ColorKey`, so the
/// rule's `id` is its color's hex. Every override is optional — an unset field
/// means "fall back to the global default" — letting a rule tweak just the lead
/// time, just the ticker template, etc., without restating the rest.
///
/// Out-of-range or empty overrides fed in via ``init(...)`` are normalized to
/// `nil`, so callers can treat any `ColorRule` as already valid.
public struct ColorRule: Codable, Hashable, Sendable, Identifiable {

    /// The color this rule customizes. Also the rule's stable identity.
    public let colorKey: ColorKey

    /// Override for how many minutes before the event the ticker shows it.
    /// `nil` → use the global ``AppSettings/tickerLeadMinutes``. Always `>= 0`.
    public let tickerLeadMinutes: Int?

    /// Override ticker line template (placeholders `{{lead}}`, `{{title}}`,
    /// `{{time}}`, `{{location}}`). `nil` → built-in default line. Never empty.
    public let tickerTemplate: String?

    /// Override overlay skin id for reminders of this color. `nil` → default
    /// skin. Never empty.
    public let overlaySkinID: String?

    /// Override sound asset name for reminders of this color. `nil` → default.
    /// Never empty.
    public let sound: String?

    /// A rule's identity is its color — one rule per `ColorKey`.
    public var id: String { colorKey.hex }

    public init(
        colorKey: ColorKey,
        tickerLeadMinutes: Int? = nil,
        tickerTemplate: String? = nil,
        overlaySkinID: String? = nil,
        sound: String? = nil
    ) {
        self.colorKey = colorKey
        self.tickerLeadMinutes = ColorRule.sanitizedLead(tickerLeadMinutes)
        self.tickerTemplate = ColorRule.sanitizedString(tickerTemplate)
        self.overlaySkinID = ColorRule.sanitizedString(overlaySkinID)
        self.sound = ColorRule.sanitizedString(sound)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        colorKey = try c.decode(ColorKey.self, forKey: .colorKey)
        tickerLeadMinutes = ColorRule.sanitizedLead(
            try c.decodeIfPresent(Int.self, forKey: .tickerLeadMinutes))
        tickerTemplate = ColorRule.sanitizedString(
            try c.decodeIfPresent(String.self, forKey: .tickerTemplate))
        overlaySkinID = ColorRule.sanitizedString(
            try c.decodeIfPresent(String.self, forKey: .overlaySkinID))
        sound = ColorRule.sanitizedString(
            try c.decodeIfPresent(String.self, forKey: .sound))
    }

    /// `true` when the rule overrides nothing — pure default fallback. The UI
    /// can prune such rules instead of persisting empty rows.
    public var isEmpty: Bool {
        tickerLeadMinutes == nil && tickerTemplate == nil
            && overlaySkinID == nil && sound == nil
    }

    // MARK: - Sanitization

    private static func sanitizedLead(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return value >= 0 ? value : nil
    }

    private static func sanitizedString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}
