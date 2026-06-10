import Foundation
import Testing
@testable import CalendarCore

@Suite struct AppSettingsTests {

    // MARK: - Defaults

    @Test func defaultsMatchSpec() {
        let s = AppSettings()
        #expect(s.enabledCalendarIDs == nil)
        #expect(s.horizonDays == 7)
        #expect(s.tickerLeadMinutes == 15)
        #expect(s.snoozeIntervals == [5, 10, 15])
        #expect(s.overlayGlassOpacity == 0.85)
        #expect(s.colorRules == .empty)
    }

    // MARK: - Color rules (Phase 6)

    @Test func colorRulesRoundTrip() throws {
        let original = AppSettings(colorRules: ColorRuleSet(rules: [
            ColorRule(colorKey: ColorKey(hex: "#FF0000")!, tickerLeadMinutes: 30),
            ColorRule(colorKey: ColorKey(hex: "#00FF00")!, overlaySkinID: "plane")
        ]))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded == original)
        #expect(decoded.colorRules.rules.count == 2)
    }

    @Test func withPreservesColorRules() {
        let rules = ColorRuleSet(rules: [
            ColorRule(colorKey: ColorKey(hex: "#FF0000")!, tickerLeadMinutes: 30)
        ])
        let s = AppSettings(colorRules: rules)
        #expect(s.with(horizonDays: 14).colorRules == rules)
        #expect(s.togglingCalendar("a", enabled: false, knownIDs: ["a", "b"]).colorRules == rules)
        #expect(s.with(colorRules: .empty).colorRules == .empty)
    }

    @Test func legacyJSONWithoutColorRulesDecodesEmpty() throws {
        let json = #"{"horizonDays": 7}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(AppSettings.self, from: json)
        #expect(s.colorRules == .empty)
    }

    // MARK: - Round-trip encode/decode

    @Test func encodeDecodeRoundTrip() throws {
        let original = AppSettings(
            enabledCalendarIDs: ["cal-a", "cal-b"],
            horizonDays: 14,
            tickerLeadMinutes: 30,
            snoozeIntervals: [1, 5, 60]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded == original)
    }

    @Test func decodesPartialJSONWithDefaults() throws {
        let json = #"{"horizonDays": 3}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(AppSettings.self, from: json)
        #expect(s.horizonDays == 3)
        #expect(s.tickerLeadMinutes == 15)
        #expect(s.snoozeIntervals == [5, 10, 15])
        #expect(s.enabledCalendarIDs == nil)
    }

    @Test func decodesEmptyObjectAsAllDefaults() throws {
        let s = try JSONDecoder().decode(AppSettings.self, from: #"{}"#.data(using: .utf8)!)
        #expect(s == AppSettings())
    }

    // MARK: - Sanitization of out-of-range values

    @Test func negativeHorizonFallsBackToDefault() {
        #expect(AppSettings(horizonDays: -3).horizonDays == 7)
        #expect(AppSettings(horizonDays: 0).horizonDays == 7)
        #expect(AppSettings(horizonDays: 1).horizonDays == 1)
    }

    @Test func negativeLeadFallsBackButZeroAllowed() {
        #expect(AppSettings(tickerLeadMinutes: -1).tickerLeadMinutes == 15)
        #expect(AppSettings(tickerLeadMinutes: 0).tickerLeadMinutes == 0)
        #expect(AppSettings(tickerLeadMinutes: 45).tickerLeadMinutes == 45)
    }

    @Test func nonPositiveSnoozeEntriesAreDropped() {
        #expect(AppSettings(snoozeIntervals: [-5, 0, 10, 20]).snoozeIntervals == [10, 20])
    }

    @Test func emptySnoozeFallsBackToDefault() {
        #expect(AppSettings(snoozeIntervals: []).snoozeIntervals == [5, 10, 15])
        #expect(AppSettings(snoozeIntervals: [-1, 0]).snoozeIntervals == [5, 10, 15])
    }

    @Test func opacityIsClampedToUnitRange() {
        #expect(AppSettings(overlayGlassOpacity: -0.5).overlayGlassOpacity == 0)
        #expect(AppSettings(overlayGlassOpacity: 1.7).overlayGlassOpacity == 1)
        #expect(AppSettings(overlayGlassOpacity: 0.4).overlayGlassOpacity == 0.4)
        #expect(AppSettings(overlayGlassOpacity: .nan).overlayGlassOpacity == 0.85)
    }

    @Test func sanitizationAlsoAppliesOnDecode() throws {
        let json = #"{"horizonDays": -10, "tickerLeadMinutes": -2, "snoozeIntervals": [0, -3], "overlayGlassOpacity": 9}"#
            .data(using: .utf8)!
        let s = try JSONDecoder().decode(AppSettings.self, from: json)
        #expect(s.horizonDays == 7)
        #expect(s.tickerLeadMinutes == 15)
        #expect(s.snoozeIntervals == [5, 10, 15])
        #expect(s.overlayGlassOpacity == 1)
    }

    // MARK: - Calendar selection

    @Test func allCalendarsEnabledByDefault() {
        let s = AppSettings()
        #expect(s.isCalendarEnabled("anything"))
    }

    @Test func togglingOffMaterializesSelectionMinusOne() {
        let known = ["a", "b", "c"]
        let s = AppSettings().togglingCalendar("b", enabled: false, knownIDs: known)
        #expect(s.isCalendarEnabled("a"))
        #expect(!s.isCalendarEnabled("b"))
        #expect(s.isCalendarEnabled("c"))
        #expect(Set(s.enabledCalendarIDs ?? []) == Set(["a", "c"]))
    }

    @Test func reEnablingEveryCalendarCollapsesBackToNil() {
        let known = ["a", "b"]
        let off = AppSettings().togglingCalendar("a", enabled: false, knownIDs: known)
        let on = off.togglingCalendar("a", enabled: true, knownIDs: known)
        #expect(on.enabledCalendarIDs == nil)
    }
}

@Suite struct SettingsStoreTests {

    /// A fresh, isolated UserDefaults suite per test.
    private func makeStore() -> (SettingsStore, UserDefaults, String) {
        let suiteName = "test.subnotes.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SettingsStore(defaults: defaults, key: "settings")
        return (store, defaults, suiteName)
    }

    @Test func returnsDefaultsWhenEmpty() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.settings == AppSettings())
    }

    @Test func savesAndReloads() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let s = AppSettings(enabledCalendarIDs: ["x"], horizonDays: 21,
                            tickerLeadMinutes: 5, snoozeIntervals: [2, 4])
        store.save(s)
        #expect(store.settings == s)
    }

    @Test func savePersistsAcrossStoreInstances() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.save(AppSettings(horizonDays: 30))
        let reopened = SettingsStore(defaults: defaults, key: "settings")
        #expect(reopened.settings.horizonDays == 30)
    }

    @Test func updateMutatesAndPersists() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.save(AppSettings(horizonDays: 10))
        let result = store.update { $0 = AppSettings(horizonDays: 20) }
        #expect(result.horizonDays == 20)
        #expect(store.settings.horizonDays == 20)
    }

    @Test func resetReturnsToDefaults() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.save(AppSettings(horizonDays: 99))
        store.reset()
        #expect(store.settings == AppSettings())
    }

    @Test func corruptDataFallsBackToDefaults() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: "settings")
        #expect(store.settings == AppSettings())
    }
}
