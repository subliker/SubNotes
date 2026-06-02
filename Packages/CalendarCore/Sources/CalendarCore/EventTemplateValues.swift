import Foundation

public extension CalEvent {
    /// Builds the value dictionary consumed by ``TemplateRenderer`` for a skin's
    /// text zones. Time formatting is injected so the mapping stays locale-stable
    /// in tests; the app passes a localized short-time formatter.
    ///
    /// All-day events resolve `{{time}}` to empty, letting templates collapse the
    /// surrounding separator instead of printing a meaningless clock time.
    func templateValues(timeFormatter: DateFormatter) -> [String: String] {
        [
            TemplateRenderer.Key.title.rawValue: title,
            TemplateRenderer.Key.time.rawValue: isAllDay ? "" : timeFormatter.string(from: start),
            TemplateRenderer.Key.location.rawValue: location ?? ""
        ]
    }
}
