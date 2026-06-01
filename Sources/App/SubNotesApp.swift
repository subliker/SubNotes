import SwiftUI
import AppKit
import CalendarCore

@main
struct SubNotesApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            EventListView(model: model)
                .frame(width: 320, height: 380)
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

    private let reader = EventReader()

    init() {
        Task { await refresh() }
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
            } else if model.events.isEmpty {
                placeholder("Нет ближайших событий",
                            systemImage: "calendar")
            } else {
                List(model.events) { event in
                    EventRow(event: event)
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
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: event.calendarColorHex) ?? .accentColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .lineLimit(1)
                Text(timeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var timeLabel: String {
        if event.isAllDay {
            return "Весь день"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "E, HH:mm"
        return formatter.string(from: event.start)
    }
}

private extension Color {
    init?(hex: String?) {
        guard let hex,
              let value = Int(hex.dropFirst(), radix: 16),
              hex.hasPrefix("#") else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
