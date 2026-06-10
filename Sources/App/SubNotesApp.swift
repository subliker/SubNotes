import SwiftUI
import AppKit
import CalendarCore

@main
struct SubNotesApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            EventListView(model: model)
                .frame(width: 320, height: 420)
        } label: {
            TickerLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}

/// The single menu-bar item's label. RunCat-style smart appearance: when an
/// event is imminent it shows the scrolling ticker text, otherwise the calendar
/// icon. Clicking the item opens the popover either way (MenuBarExtra default),
/// so the events list is always one click from here.
struct TickerLabel: View {
    let model: AppModel

    var body: some View {
        if let frame = model.tickerFrame {
            Text(frame)
                .font(.system(.body, design: .monospaced))
        } else {
            Image(systemName: "calendar.badge.clock")
        }
    }
}

@MainActor
@Observable
final class AppModel {
    var events: [CalEvent] = []
    var accessGranted = false

    /// The menu-bar label's current marquee frame, or `nil` when no event is
    /// imminent (the label then shows the icon). Driven by `runTicker`.
    var tickerFrame: String?

    /// Live user preferences, persisted via ``settingsStore``. Mutating through
    /// ``applySettings(_:)`` re-reads events and re-renders affected surfaces.
    private(set) var settings: AppSettings

    /// Calendars offered in the Settings picker. Populated after access is
    /// granted; empty until then.
    private(set) var availableCalendars: [CalendarInfo] = []

    /// Login-item (autostart) state, bound to the Settings toggle (#24).
    let loginItems = LoginItemManager()

    /// Minutes before an event that the ticker starts showing it.
    private var tickerLeadMinutes: Int { settings.tickerLeadMinutes }

    var days: [EventDay] { EventGrouping.byDay(events) }

    private let reader = EventReader()
    private let settingsStore = SettingsStore()

    /// Presents the Phase 4 overlay window. Driven for now by a debug toggle in
    /// the popover; #8/#9 will hook it to `ReminderScheduler` triggers.
    let overlay = OverlayController()

    /// Themes available to the overlay: built-in skins plus any user themes.
    /// Loaded once; the picker / per-color rules (Phase 6) refine selection later.
    @ObservationIgnored
    private(set) lazy var themes: [ThemeManifest] = ThemeLoader.loadAll(userDirectory: nil)

    /// Which built-in theme the overlay is currently showing; advances on each
    /// toggle so UI acceptance of #8 can step through every skin.
    private var overlayThemeIndex = 0

    /// Cycles the overlay through the built-in skins for visual acceptance of #8:
    /// each press shows the next skin against the next event (or a sample), and a
    /// press past the last skin hides the overlay. #9 adds interactive buttons and
    /// the scheduler drives it for real.
    func toggleOverlay() {
        guard !themes.isEmpty else { return }
        if overlay.isShowing {
            overlayThemeIndex += 1
            if overlayThemeIndex >= themes.count {
                overlayThemeIndex = 0
                overlay.dismiss()
                return
            }
        } else {
            overlayThemeIndex = 0
        }
        presentOverlay(themes[overlayThemeIndex])
    }

    private func presentOverlay(_ manifest: ThemeManifest) {
        let event = events.first ?? Self.sampleEvent
        let accent = event.displayColor ?? .accentColor
        let index = overlayThemeIndex
        let total = themes.count
        let glassOpacity = settings.overlayGlassOpacity
        overlay.present {
            SkinAcceptanceView(
                manifest: manifest, event: event, accent: accent,
                glassOpacity: glassOpacity,
                index: index, total: total,
                perform: { [weak self] action in self?.handleOverlayAction(action, for: event) },
                onBarFrame: { [weak self] rect in
                    self?.overlay.setInteractiveSwiftUIRects([rect])
                }
            )
        }
    }

    /// Minutes to hide the overlay for when the user taps «Отложить» — the
    /// first configured snooze interval.
    private var snoozeMinutes: Int { settings.snoozeIntervals.first ?? 5 }

    /// Routes a button-layer action (#9). For acceptance this drives the live
    /// overlay; the scheduler will reuse the same handler when it presents
    /// reminders for real.
    func handleOverlayAction(_ action: OverlayAction, for event: CalEvent) {
        switch action {
        case .dismiss:
            overlayThemeIndex = 0
            overlay.dismiss()
        case .openInCalendar:
            EventOpener.openInCalendar(event)
            overlay.dismiss()
        case .connect:
            if let url = event.videoLink?.url { NSWorkspace.shared.open(url) }
            overlay.dismiss()
        case .snooze:
            let manifest = themes[overlayThemeIndex]
            overlay.dismiss()
            Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(Double(snoozeMinutes) * 60))
                guard !self.overlay.isShowing else { return }
                self.presentOverlay(manifest)
            }
        }
    }

    /// Stand-in event so the overlay is demoable before a real reminder fires.
    /// Carries a Meet link so the «Подключиться» button shows during acceptance.
    private static let sampleEvent = CalEvent(
        id: "sample",
        title: "Демо-напоминание",
        start: Date().addingTimeInterval(900),
        end: Date().addingTimeInterval(4500),
        location: "Переговорка",
        videoLink: VideoLink(url: URL(string: "https://meet.google.com/abc-defg-hij")!, provider: .meet)
    )

    /// Marquee tuning: window width in chars and scroll cadence.
    private let tickerWindow = 22
    private let tickerTick = Duration.milliseconds(250)
    /// Re-evaluate which event is imminent every this many ticks (~10s).
    private let tickerEvaluateEvery = 40

    /// Localizes `{{time}}` in per-color ticker templates (Phase 6).
    private static let tickerTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    init() {
        settings = settingsStore.settings

        // Demo mode (README screenshots): seed deterministic sample data and
        // lay out the surfaces as real windows, never touching EventKit.
        if DemoMode.isEnabled {
            accessGranted = true
            availableCalendars = DemoData.calendars
            events = DemoData.events
            settings = settings.with(colorRules: DemoData.colorRules)
            DispatchQueue.main.async { [self] in DemoWindows.present(model: self) }
            return
        }

        Task {
            await refresh()
            await observeStoreChanges()
        }
        Task { await runTicker() }
    }

    /// Persists `new` and re-applies it: reloads events under the new horizon /
    /// calendar filter so changes show immediately. The ticker and overlay read
    /// `settings` directly, so they pick up lead-time / opacity on their next tick.
    func applySettings(_ new: AppSettings) {
        settings = new
        guard !DemoMode.isEnabled else { return }
        settingsStore.save(new)
        if accessGranted {
            events = reader.upcomingEvents(
                within: new.horizonDays,
                calendarIDs: new.enabledCalendarIDs
            )
        }
    }

    // MARK: - Color rules (Phase 6)

    /// Distinct colors the user can attach a rule to — the colors actually
    /// present in their calendars and upcoming events. Sorted by hex for a
    /// stable menu order.
    var ruleColorOptions: [ColorKey] {
        var keys: [String: ColorKey] = [:]
        for cal in availableCalendars {
            if let key = ColorKey(hex: cal.colorHex) { keys[key.hex] = key }
        }
        for event in events {
            if let key = event.colorKey { keys[key.hex] = key }
        }
        return keys.values.sorted { $0.hex < $1.hex }
    }

    /// A friendly name for a color — the title of a calendar that uses it, if
    /// any — so a rule row reads «Работа» rather than a bare hex.
    func colorName(for key: ColorKey) -> String? {
        availableCalendars.first { ColorKey(hex: $0.colorHex) == key }?.title
    }

    /// Skins offered in a rule's skin picker (built-in + user themes).
    var availableSkins: [ThemeManifest] { themes }

    /// Inserts or replaces a rule, persisting through `applySettings`.
    func upsertColorRule(_ rule: ColorRule) {
        applySettings(settings.with(colorRules: settings.colorRules.upserting(rule)))
    }

    /// Removes the rule for a color.
    func removeColorRule(_ key: ColorKey) {
        applySettings(settings.with(colorRules: settings.colorRules.removing(key)))
    }

    /// Drives the menu-bar ticker: every ~10s recomputes the imminent-event
    /// line from current events + time, and every tick advances the marquee.
    private func runTicker() async {
        var tick = 0
        var offset = 0
        var source: String?
        while !Task.isCancelled {
            if tick % tickerEvaluateEvery == 0 {
                let text = TickerLogic.tickerText(
                    events,
                    defaultLeadMinutes: tickerLeadMinutes,
                    rules: settings.colorRules,
                    timeFormatter: Self.tickerTimeFormatter
                )
                if text != source {
                    source = text
                    offset = 0
                }
            }
            if let source {
                tickerFrame = TickerLogic.marqueeFrame(
                    source, offset: offset, windowLength: tickerWindow
                )
                offset &+= 1
            } else {
                tickerFrame = nil
            }
            tick &+= 1
            try? await Task.sleep(for: tickerTick)
        }
    }

    func refresh() async {
        do {
            accessGranted = try await reader.requestAccess()
        } catch {
            accessGranted = false
        }
        guard accessGranted else { return }
        availableCalendars = reader.availableCalendars()
        events = reader.upcomingEvents(
            within: settings.horizonDays,
            calendarIDs: settings.enabledCalendarIDs
        )
    }

    private func observeStoreChanges() async {
        for await _ in reader.storeChanges() {
            guard accessGranted else { continue }
            availableCalendars = reader.availableCalendars()
            events = reader.upcomingEvents(
                within: settings.horizonDays,
                calendarIDs: settings.enabledCalendarIDs
            )
        }
    }
}

/// Composes the manifest-driven ``SkinView`` with the standard floating button
/// layer (#9) and a small acceptance caption naming the current skin. The caption
/// is an acceptance aid (so the reviewer knows which built-in skin they see), not
/// part of the shipped surface; it sits outside the manifest-driven render.
struct SkinAcceptanceView: View {
    let manifest: ThemeManifest
    let event: CalEvent
    let accent: Color
    /// Liquid Glass density of the card, from settings (#23).
    var glassOpacity: Double = AppSettings.defaultOverlayGlassOpacity
    let index: Int
    let total: Int
    let perform: (OverlayAction) -> Void
    /// Reports the button bar's frame so the window makes only that region
    /// clickable (per-region click-through).
    let onBarFrame: (CGRect) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            SkinView(manifest: manifest, event: event, accent: accent, glassOpacity: glassOpacity)
            OverlayButtonBar(event: event, accent: accent, perform: perform)
            Text("Скин \(index + 1)/\(total): \(manifest.name)")
                .font(.callout.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 40)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onPreferenceChange(ButtonBarFrameKey.self) { onBarFrame($0) }
    }
}

struct EventListView: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if !model.accessGranted {
                placeholder("Нет доступа к календарю",
                            systemImage: "lock.fill")
            } else if model.days.isEmpty {
                placeholder("Нет ближайших событий",
                            systemImage: "calendar")
            } else {
                List {
                    ForEach(model.days) { day in
                        Section(DayLabel.format(day.date)) {
                            ForEach(day.allDay) { event in
                                EventRow(event: event)
                            }
                            ForEach(day.timed) { event in
                                EventRow(event: event)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("SubNotes")
                .font(.headline)
            Spacer()
            Button {
                model.toggleOverlay()
            } label: {
                Image(systemName: "rectangle.on.rectangle")
            }
            .buttonStyle(.borderless)
            .help("Перебрать скины оверлея (Phase 4)")
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            Button {
                // LSUIElement apps aren't active, so the Settings window would
                // open behind everything — activate first, then open it.
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Настройки…")
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func placeholder(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EventRow: View {
    let event: CalEvent

    var body: some View {
        Button {
            EventOpener.openInCalendar(event)
        } label: {
            HStack(spacing: 10) {
                Capsule()
                    .fill(event.displayColor ?? .accentColor)
                    .frame(width: 4, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .lineLimit(1)
                    Text(timeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if event.videoLink != nil {
                    Image(systemName: "video.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    private var timeLabel: String {
        if event.isAllDay {
            return "Весь день"
        }
        return Self.timeFormatter.string(from: event.start)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

/// Formats a day header as «Сегодня» / «Завтра» / «пн, 2 июня».
enum DayLabel {
    static func format(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "Сегодня" }
        if calendar.isDateInTomorrow(date) { return "Завтра" }
        return formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMMM"
        return f
    }()
}

/// Deep-links an event into the system Calendar.app. EventKit exposes no public
/// URL for an event, so we use the widely-used `ical://ekevent` scheme and fall
/// back to just launching Calendar.app if it is rejected.
enum EventOpener {
    static func openInCalendar(_ event: CalEvent) {
        let encoded = event.id.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? event.id
        if let url = URL(string: "ical://ekevent/\(encoded)?method=show&options=more"),
           NSWorkspace.shared.open(url) {
            return
        }
        if let calendarApp = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.iCal"
        ) {
            NSWorkspace.shared.openApplication(
                at: calendarApp,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }
}

private extension CalEvent {
    /// Prefers the resolved `ColorKey` (the future per-color customization key),
    /// falling back to the raw calendar color hex.
    var displayColor: Color? {
        Color(hex: colorKey?.hex) ?? Color(hex: calendarColorHex)
    }
}

extension Color {
    init?(hex: String?) {
        guard let hex,
              hex.hasPrefix("#"),
              let value = Int(hex.dropFirst(), radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
