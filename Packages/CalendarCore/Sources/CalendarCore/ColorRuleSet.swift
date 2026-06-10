import Foundation

/// The global fallback values a ``ColorRule`` overrides. Whatever a rule leaves
/// `nil` resolves to these (driven by ``AppSettings`` and the active skin).
public struct ColorCustomizationDefaults: Equatable, Sendable {
    public var tickerLeadMinutes: Int
    public var overlaySkinID: String?
    public var sound: String?

    public init(
        tickerLeadMinutes: Int,
        overlaySkinID: String? = nil,
        sound: String? = nil
    ) {
        self.tickerLeadMinutes = tickerLeadMinutes
        self.overlaySkinID = overlaySkinID
        self.sound = sound
    }
}

/// The effective customization for one color after a matching ``ColorRule`` is
/// merged over the ``ColorCustomizationDefaults``. This is what the ticker and
/// (later) overlay engine actually consume — they never branch on rules
/// directly.
public struct ResolvedColorCustomization: Equatable, Sendable {
    public let tickerLeadMinutes: Int
    /// `nil` → render the built-in default ticker line instead of a template.
    public let tickerTemplate: String?
    public let overlaySkinID: String?
    public let sound: String?
}

/// An ordered set of ``ColorRule``s — the persisted Phase 6 customization table.
///
/// Color is the key: there is at most one rule per ``ColorKey``. On
/// construction, later duplicates of a color are dropped (first wins) and
/// no-op rules are pruned, so resolution is an unambiguous single lookup.
public struct ColorRuleSet: Codable, Hashable, Sendable {

    public let rules: [ColorRule]

    public static let empty = ColorRuleSet(rules: [])

    public init(rules: [ColorRule]) {
        self.rules = ColorRuleSet.normalized(rules)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decoded = try container.decode([ColorRule].self)
        self.rules = ColorRuleSet.normalized(decoded)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rules)
    }

    /// The rule matching `colorKey`, or `nil` when none applies (no color, or no
    /// rule for that color).
    public func rule(for colorKey: ColorKey?) -> ColorRule? {
        guard let colorKey else { return nil }
        return rules.first { $0.colorKey == colorKey }
    }

    /// Merges the matching rule's overrides over `defaults` for `colorKey`.
    public func resolve(
        for colorKey: ColorKey?,
        defaults: ColorCustomizationDefaults
    ) -> ResolvedColorCustomization {
        let r = rule(for: colorKey)
        return ResolvedColorCustomization(
            tickerLeadMinutes: r?.tickerLeadMinutes ?? defaults.tickerLeadMinutes,
            tickerTemplate: r?.tickerTemplate,
            overlaySkinID: r?.overlaySkinID ?? defaults.overlaySkinID,
            sound: r?.sound ?? defaults.sound
        )
    }

    // MARK: - Normalization

    /// First rule per color wins; no-op rules are dropped.
    private static func normalized(_ rules: [ColorRule]) -> [ColorRule] {
        var seen = Set<String>()
        var out: [ColorRule] = []
        for rule in rules where !rule.isEmpty {
            if seen.insert(rule.colorKey.hex).inserted {
                out.append(rule)
            }
        }
        return out
    }
}
