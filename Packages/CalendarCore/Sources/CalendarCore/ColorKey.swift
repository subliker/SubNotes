import Foundation

/// A normalized color identity for an event. Used both for display and as the
/// key future per-color customization keys off (notification rules, ticker
/// string templates, overlay skins) — so it must be stable and comparable.
///
/// Where the color comes from is intentionally pluggable (see `EventColorResolving`):
/// today it is the event's *calendar* color from EventKit; a later Google API
/// path can resolve a per-event color without changing rules keyed on `ColorKey`.
public struct ColorKey: Codable, Hashable, Sendable {
    /// Normalized `#RRGGBB`, uppercase.
    public let hex: String

    /// Accepts `#RGB`, `#RRGGBB`, or the same without the leading `#`, and
    /// normalizes to `#RRGGBB` uppercase. Returns nil for anything unparseable.
    public init?(hex raw: String?) {
        guard let raw else { return nil }
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 {
            s = s.map { "\($0)\($0)" }.joined()
        }
        guard s.count == 6, Int(s, radix: 16) != nil else { return nil }
        self.hex = "#" + s.uppercased()
    }
}
