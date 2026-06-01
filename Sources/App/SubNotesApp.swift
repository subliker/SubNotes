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
            Image(systemName: "calendar.badge.clock")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
@Observable
final class AppModel {
    var events: [CalEvent] = []
    var accessGranted = false

    var days: [EventDay] { EventGrouping.byDay(events) }

    private let reader = EventReader()

    init() {
        Task {
            await refresh()
            await observeStoreChanges()
        }
    }

    func refresh() async {
        do {
            accessGranted = try await reader.requestAccess()
        } catch {
            accessGranted = false
        }
        guard accessGranted else { return }
        events = reader.upcomingEvents()
    }

    private func observeStoreChanges() async {
        for await _ in reader.storeChanges() {
            guard accessGranted else { continue }
            events = reader.upcomingEvents()
        }
    }
}

struct EventListView: View {
    @Bindable var model: AppModel

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
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
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

private extension Color {
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
