import SwiftUI
import AppKit
import CalendarCore

/// Off-by-default "demo" mode used only to produce the README screenshots on
/// deterministic test data — never EventKit. Enabled by launching the app with
/// `SUBNOTES_DEMO=1` in the environment. When on, ``AppModel`` seeds itself with
/// ``DemoData`` instead of touching the user's calendars, and ``DemoWindows``
/// lays out each surface as a real on-screen window (so Liquid Glass renders
/// authentically) for an external `screencapture` to grab by window id.
enum DemoMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["SUBNOTES_DEMO"] == "1"
    }
}

/// Deterministic sample events/calendars for the demo surfaces. Times are pinned
/// to "today/tomorrow" so the day headers read «Сегодня» / «Завтра».
enum DemoData {
    private static let cal = Calendar.current

    private static func today(_ h: Int, _ m: Int) -> Date {
        cal.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }

    private static func tomorrow(_ h: Int, _ m: Int) -> Date {
        let base = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: h, minute: m, second: 0, of: base) ?? base
    }

    static let calendars: [CalendarInfo] = [
        CalendarInfo(id: "work", title: "Работа", colorHex: "#3B82F6"),
        CalendarInfo(id: "personal", title: "Личное", colorHex: "#22C55E"),
        CalendarInfo(id: "family", title: "Семья", colorHex: "#EC4899"),
    ]

    private static let meet = VideoLink(
        url: URL(string: "https://meet.google.com/abc-defg-hij")!, provider: .meet
    )

    static let events: [CalEvent] = [
        CalEvent(id: "d1", title: "Дейли-стендап", start: today(10, 0), end: today(10, 15),
                 calendarColorHex: "#3B82F6", calendarTitle: "Работа",
                 location: "Zoom", videoLink: meet),
        CalEvent(id: "d2", title: "Обед с Киригаей", start: today(13, 0), end: today(14, 0),
                 calendarColorHex: "#22C55E", calendarTitle: "Личное",
                 location: "Кафе «Орбита»"),
        CalEvent(id: "d3", title: "День рождения Аксиньи", start: today(0, 0), end: today(23, 59),
                 isAllDay: true, calendarColorHex: "#EC4899", calendarTitle: "Семья"),
        CalEvent(id: "d4", title: "Ревью дизайна", start: tomorrow(11, 30), end: tomorrow(12, 30),
                 calendarColorHex: "#F59E0B", calendarTitle: "Работа",
                 location: "Переговорка 4", videoLink: meet),
        CalEvent(id: "d5", title: "1:1 с менеджером", start: tomorrow(15, 0), end: tomorrow(15, 30),
                 calendarColorHex: "#8B5CF6", calendarTitle: "Работа"),
        CalEvent(id: "d6", title: "Попробовать новую игру Мастера меча онлайн",
                 start: tomorrow(20, 0), end: tomorrow(22, 0),
                 calendarColorHex: "#22C55E", calendarTitle: "Личное"),
    ]

    /// A sample Phase 6 customization rule so the Settings color-rules table is
    /// populated in the demo/screenshot (amber "work" events get a longer lead
    /// and a custom ticker line).
    static let colorRules = ColorRuleSet(rules: [
        ColorRule(colorKey: ColorKey(hex: "#F59E0B")!,
                  tickerLeadMinutes: 30,
                  tickerTemplate: "🟠 {{lead}} · {{title}}")
    ])

    /// The event shown on the reminder overlay (carries a Meet link so the
    /// «Подключиться» button appears).
    static let overlayEvent = CalEvent(
        id: "ov", title: "Ревью дизайна",
        start: Date().addingTimeInterval(600), end: Date().addingTimeInterval(4200),
        calendarColorHex: "#F59E0B", calendarTitle: "Работа",
        location: "Переговорка 4", videoLink: meet
    )
}

/// Builds and shows the demo windows, then prints each one's CGWindowID so an
/// external capture script can grab exactly that window. Active only in demo mode.
@MainActor
enum DemoWindows {
    private static var retained: [NSWindow] = []

    static func present(model: AppModel) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let popover = makeBorderless(
            size: CGSize(width: 320, height: 460), origin: CGPoint(x: 120, y: 360)
        ) {
            EventListView(model: model)
                .frame(width: 320, height: 460)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        let settings = makeTitled(
            title: "Настройки — SubNotes",
            size: CGSize(width: 460, height: 560), origin: CGPoint(x: 480, y: 320)
        ) {
            SettingsView(model: model)
        }

        let overlay = makeBorderless(
            size: CGSize(width: 760, height: 480), origin: CGPoint(x: 980, y: 360)
        ) {
            DemoOverlayCard()
        }

        retained = [popover, settings, overlay]

        // Give SwiftUI a beat to render the glass, then announce window ids.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            print("SCREENSHOT_WINDOW popover \(popover.windowNumber)")
            print("SCREENSHOT_WINDOW settings \(settings.windowNumber)")
            print("SCREENSHOT_WINDOW overlay \(overlay.windowNumber)")
            print("SCREENSHOT_READY")
            fflush(stdout)
        }
    }

    private static func makeBorderless<Content: View>(
        size: CGSize, origin: CGPoint, @ViewBuilder _ content: () -> Content
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(origin: origin, size: size),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.contentView = NSHostingView(rootView: AnyView(content()))
        window.makeKeyAndOrderFront(nil)
        return window
    }

    private static func makeTitled<Content: View>(
        title: String, size: CGSize, origin: CGPoint, @ViewBuilder _ content: () -> Content
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(origin: origin, size: size),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = title
        window.contentView = NSHostingView(rootView: AnyView(content()))
        window.makeKeyAndOrderFront(nil)
        return window
    }
}

/// A self-contained reminder overlay for the screenshot: the built-in card skin
/// over a soft gradient backdrop, with the floating button bar on top.
private struct DemoOverlayCard: View {
    private var manifest: ThemeManifest {
        ThemeLoader.loadBuiltIn().first { $0.id == "default" }
            ?? ThemeLoader.loadBuiltIn().first!
    }

    private let event = DemoData.overlayEvent
    private let accent = Color(red: 0.96, green: 0.62, blue: 0.04)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.20, green: 0.16, blue: 0.40),
                         Color(red: 0.36, green: 0.30, blue: 0.62)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            SkinView(manifest: manifest, event: event, accent: accent, glassOpacity: 0.85)
            OverlayButtonBar(event: event, accent: accent, perform: { _ in })
        }
        .frame(width: 760, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
