import SwiftUI
import CalendarCore

/// Phase 6 (needs-ui): the per-color customization table in Settings. Each rule
/// keys off an event's ``ColorKey`` and overrides ticker lead time, ticker line
/// template, overlay skin, and sound. Anything left unset falls back to the
/// global settings — the resolver in ``ColorRuleSet`` does the merging.
///
/// Rules are persisted live through ``AppModel/upsertColorRule(_:)``; a rule
/// that overrides nothing is dropped (an empty rule is no rule).
struct ColorRulesSection: View {
    @Bindable var model: AppModel

    var body: some View {
        Section {
            let rules = model.settings.colorRules.rules
            if rules.isEmpty {
                Text("Пока нет правил. Добавьте правило для цвета, чтобы задать своё "
                     + "время появления, шаблон строки тикера, скин и звук.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rules) { rule in
                    ColorRuleRow(model: model, rule: rule)
                }
            }
            addMenu
        } header: {
            Text("Кастомизация по цвету")
        } footer: {
            Text("Правила привязаны к цвету события. Сейчас применяются к бегущей "
                 + "строке; скин и звук подхватит движок оверлеев, когда их будет "
                 + "запускать планировщик.")
        }
    }

    private var addMenu: some View {
        let existing = Set(model.settings.colorRules.rules.map(\.colorKey.hex))
        let options = model.ruleColorOptions.filter { !existing.contains($0.hex) }
        return Menu {
            if options.isEmpty {
                Text("Нет доступных цветов")
            } else {
                ForEach(options, id: \.hex) { key in
                    Button {
                        // Seed with the current global lead so the new rule is
                        // non-empty and persists, ready for the user to tweak.
                        model.upsertColorRule(
                            ColorRule(colorKey: key,
                                      tickerLeadMinutes: model.settings.tickerLeadMinutes))
                    } label: {
                        Text(menuLabel(for: key))
                    }
                }
            }
        } label: {
            Label("Добавить правило", systemImage: "plus.circle")
        }
        .menuStyle(.borderlessButton)
    }

    private func menuLabel(for key: ColorKey) -> String {
        if let name = model.colorName(for: key) { return "\(name) (\(key.hex))" }
        return key.hex
    }
}

/// One expandable rule row: a color swatch + name header, revealing the
/// override controls.
private struct ColorRuleRow: View {
    let model: AppModel
    let rule: ColorRule

    var body: some View {
        DisclosureGroup {
            leadControl
            templateControl
            skinControl
            soundControl
            Button(role: .destructive) {
                model.removeColorRule(rule.colorKey)
            } label: {
                Label("Удалить правило", systemImage: "trash")
            }
            .buttonStyle(.borderless)
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: rule.colorKey.hex) ?? .secondary)
                    .frame(width: 14, height: 14)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(.separator))
                Text(title)
                Spacer()
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var title: String {
        model.colorName(for: rule.colorKey) ?? rule.colorKey.hex
    }

    /// A short hint of what the rule overrides, shown in the collapsed header.
    private var summary: String {
        var parts: [String] = []
        if let lead = rule.tickerLeadMinutes { parts.append("\(lead) мин") }
        if rule.tickerTemplate != nil { parts.append("шаблон") }
        if rule.overlaySkinID != nil { parts.append("скин") }
        if rule.sound != nil { parts.append("звук") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Controls

    @ViewBuilder
    private var leadControl: some View {
        Toggle("Своё время появления", isOn: Binding(
            get: { rule.tickerLeadMinutes != nil },
            set: { on in
                save(lead: on ? (rule.tickerLeadMinutes ?? model.settings.tickerLeadMinutes) : nil)
            }
        ))
        if let lead = rule.tickerLeadMinutes {
            Stepper(value: Binding(get: { lead }, set: { save(lead: $0) }),
                    in: 0...120, step: 5) {
                LabeledContent("Появляется за", value: "\(lead) мин")
            }
        }
    }

    private var templateControl: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("Шаблон строки тикера",
                      text: Binding(get: { rule.tickerTemplate ?? "" },
                                    set: { save(template: $0) }))
            Text("Плейсхолдеры: {{lead}}, {{title}}, {{time}}, {{location}}")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var skinControl: some View {
        Picker("Скин оверлея", selection: Binding(
            get: { rule.overlaySkinID },
            set: { save(skin: $0) }
        )) {
            Text("По умолчанию").tag(String?.none)
            ForEach(model.availableSkins, id: \.id) { skin in
                Text(skin.name).tag(String?.some(skin.id))
            }
        }
    }

    private var soundControl: some View {
        TextField("Звук (имя ассета)",
                  text: Binding(get: { rule.sound ?? "" },
                                set: { save(sound: $0) }))
    }

    // MARK: - Commit

    // One overload per field: each rebuilds the rule with that field swapped and
    // the rest copied from `rule`, then persists. `ColorRule.init` sanitizes
    // (empty strings → `nil`); `upsertColorRule` prunes a now-empty rule.

    private func save(lead: Int?) {
        persist(ColorRule(colorKey: rule.colorKey, tickerLeadMinutes: lead,
                          tickerTemplate: rule.tickerTemplate,
                          overlaySkinID: rule.overlaySkinID, sound: rule.sound))
    }

    private func save(template: String) {
        persist(ColorRule(colorKey: rule.colorKey, tickerLeadMinutes: rule.tickerLeadMinutes,
                          tickerTemplate: template,
                          overlaySkinID: rule.overlaySkinID, sound: rule.sound))
    }

    private func save(skin: String?) {
        persist(ColorRule(colorKey: rule.colorKey, tickerLeadMinutes: rule.tickerLeadMinutes,
                          tickerTemplate: rule.tickerTemplate,
                          overlaySkinID: skin, sound: rule.sound))
    }

    private func save(sound: String) {
        persist(ColorRule(colorKey: rule.colorKey, tickerLeadMinutes: rule.tickerLeadMinutes,
                          tickerTemplate: rule.tickerTemplate,
                          overlaySkinID: rule.overlaySkinID, sound: sound))
    }

    private func persist(_ rule: ColorRule) {
        model.upsertColorRule(rule)
    }
}
