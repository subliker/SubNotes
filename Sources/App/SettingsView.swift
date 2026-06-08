import SwiftUI
import CalendarCore

/// Phase 5 (#23): the app's only real window. Edits the persisted ``AppSettings``
/// live through ``AppModel/applySettings(_:)`` (every control writes immediately,
/// no Save button) and the autostart toggle through ``LoginItemManager`` (#24).
struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            calendarsSection
            dataSection
            tickerSection
            overlaySection
            startupSection
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 560)
    }

    // MARK: - Calendars

    private var calendarsSection: some View {
        Section("Календари") {
            if !model.accessGranted {
                Label("Нет доступа к календарю", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            } else if model.availableCalendars.isEmpty {
                Text("Календари не найдены")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.availableCalendars) { cal in
                    Toggle(isOn: calendarBinding(cal)) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: cal.colorHex) ?? .secondary)
                                .frame(width: 10, height: 10)
                            Text(cal.title)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("Данные") {
            Stepper(value: horizonBinding, in: 1...30) {
                LabeledContent("Горизонт загрузки",
                               value: "\(model.settings.horizonDays) дн.")
            }
        }
    }

    // MARK: - Ticker

    private var tickerSection: some View {
        Section("Бегущая строка") {
            Stepper(value: leadBinding, in: 0...120, step: 5) {
                LabeledContent("Появляется за",
                               value: "\(model.settings.tickerLeadMinutes) мин")
            }
        }
    }

    // MARK: - Overlay

    private var overlaySection: some View {
        Section("Оверлей напоминания") {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Плотность стекла",
                               value: "\(Int((model.settings.overlayGlassOpacity * 100).rounded())) %")
                Slider(value: opacityBinding, in: 0...1) {
                    Text("Плотность стекла")
                } minimumValueLabel: {
                    Image(systemName: "circle.dotted")
                } maximumValueLabel: {
                    Image(systemName: "circle.fill")
                }
            }

            snoozeEditor
        }
    }

    @ViewBuilder
    private var snoozeEditor: some View {
        let intervals = model.settings.snoozeIntervals
        ForEach(Array(intervals.enumerated()), id: \.offset) { index, value in
            HStack {
                Stepper(value: snoozeBinding(index), in: 1...180, step: 5) {
                    LabeledContent("Отложить #\(index + 1)", value: "\(value) мин")
                }
                Button(role: .destructive) {
                    removeSnooze(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(intervals.count <= 1)
            }
        }
        Button {
            addSnooze()
        } label: {
            Label("Добавить интервал", systemImage: "plus.circle")
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Startup

    private var startupSection: some View {
        Section("Запуск") {
            Toggle("Запускать при входе в систему", isOn: Binding(
                get: { model.loginItems.isEnabled },
                set: { model.loginItems.setEnabled($0) }
            ))
        }
    }

    // MARK: - Bindings

    private func calendarBinding(_ cal: CalendarInfo) -> Binding<Bool> {
        Binding(
            get: { model.settings.isCalendarEnabled(cal.id) },
            set: { enabled in
                let ids = model.availableCalendars.map(\.id)
                model.applySettings(
                    model.settings.togglingCalendar(cal.id, enabled: enabled, knownIDs: ids)
                )
            }
        )
    }

    private var horizonBinding: Binding<Int> {
        Binding(
            get: { model.settings.horizonDays },
            set: { model.applySettings(model.settings.with(horizonDays: $0)) }
        )
    }

    private var leadBinding: Binding<Int> {
        Binding(
            get: { model.settings.tickerLeadMinutes },
            set: { model.applySettings(model.settings.with(tickerLeadMinutes: $0)) }
        )
    }

    private var opacityBinding: Binding<Double> {
        Binding(
            get: { model.settings.overlayGlassOpacity },
            set: { model.applySettings(model.settings.with(overlayGlassOpacity: $0)) }
        )
    }

    private func snoozeBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { model.settings.snoozeIntervals[index] },
            set: { newValue in
                var list = model.settings.snoozeIntervals
                guard list.indices.contains(index) else { return }
                list[index] = newValue
                model.applySettings(model.settings.with(snoozeIntervals: list))
            }
        )
    }

    private func removeSnooze(at index: Int) {
        var list = model.settings.snoozeIntervals
        guard list.indices.contains(index), list.count > 1 else { return }
        list.remove(at: index)
        model.applySettings(model.settings.with(snoozeIntervals: list))
    }

    private func addSnooze() {
        let list = model.settings.snoozeIntervals + [(model.settings.snoozeIntervals.last ?? 5) + 5]
        model.applySettings(model.settings.with(snoozeIntervals: list))
    }
}
