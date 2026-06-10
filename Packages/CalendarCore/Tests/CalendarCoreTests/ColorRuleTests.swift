import Foundation
import Testing
@testable import CalendarCore

@Suite struct ColorRuleTests {
    private let red = ColorKey(hex: "#FF0000")!
    private let blue = ColorKey(hex: "#0000FF")!

    // MARK: - ColorRule sanitization

    @Test func dropsNegativeLead() {
        let rule = ColorRule(colorKey: red, tickerLeadMinutes: -5)
        #expect(rule.tickerLeadMinutes == nil)
    }

    @Test func keepsZeroAndPositiveLead() {
        #expect(ColorRule(colorKey: red, tickerLeadMinutes: 0).tickerLeadMinutes == 0)
        #expect(ColorRule(colorKey: red, tickerLeadMinutes: 30).tickerLeadMinutes == 30)
    }

    @Test func trimsAndNilsEmptyStrings() {
        let rule = ColorRule(
            colorKey: red,
            tickerTemplate: "  ",
            overlaySkinID: "\n",
            sound: " plane "
        )
        #expect(rule.tickerTemplate == nil)
        #expect(rule.overlaySkinID == nil)
        #expect(rule.sound == "plane")
    }

    @Test func emptyRuleIsEmpty() {
        #expect(ColorRule(colorKey: red).isEmpty)
        #expect(!ColorRule(colorKey: red, tickerLeadMinutes: 5).isEmpty)
    }

    @Test func idIsColorHex() {
        #expect(ColorRule(colorKey: red).id == "#FF0000")
    }

    // MARK: - ColorRuleSet normalization

    @Test func dropsDuplicateColorsKeepingFirst() {
        let set = ColorRuleSet(rules: [
            ColorRule(colorKey: red, tickerLeadMinutes: 30),
            ColorRule(colorKey: red, tickerLeadMinutes: 10),
            ColorRule(colorKey: blue, tickerLeadMinutes: 5)
        ])
        #expect(set.rules.count == 2)
        #expect(set.rule(for: red)?.tickerLeadMinutes == 30)
        #expect(set.rule(for: blue)?.tickerLeadMinutes == 5)
    }

    @Test func prunesEmptyRules() {
        let set = ColorRuleSet(rules: [
            ColorRule(colorKey: red),
            ColorRule(colorKey: blue, sound: "ping")
        ])
        #expect(set.rules.map(\.colorKey) == [blue])
    }

    @Test func ruleForNilColorIsNil() {
        let set = ColorRuleSet(rules: [ColorRule(colorKey: red, tickerLeadMinutes: 5)])
        #expect(set.rule(for: nil) == nil)
    }

    // MARK: - Editing

    @Test func upsertingAppendsNewColor() {
        let set = ColorRuleSet.empty
            .upserting(ColorRule(colorKey: red, tickerLeadMinutes: 30))
        #expect(set.rule(for: red)?.tickerLeadMinutes == 30)
    }

    @Test func upsertingReplacesInPlace() {
        let set = ColorRuleSet(rules: [
            ColorRule(colorKey: red, tickerLeadMinutes: 30),
            ColorRule(colorKey: blue, sound: "ping")
        ])
        let updated = set.upserting(ColorRule(colorKey: red, tickerLeadMinutes: 5))
        #expect(updated.rules.map(\.colorKey) == [red, blue])   // order preserved
        #expect(updated.rule(for: red)?.tickerLeadMinutes == 5)
    }

    @Test func upsertingEmptyRuleRemovesColor() {
        let set = ColorRuleSet(rules: [ColorRule(colorKey: red, tickerLeadMinutes: 30)])
        let updated = set.upserting(ColorRule(colorKey: red))
        #expect(updated.rule(for: red) == nil)
    }

    @Test func removingDropsColor() {
        let set = ColorRuleSet(rules: [
            ColorRule(colorKey: red, tickerLeadMinutes: 30),
            ColorRule(colorKey: blue, sound: "ping")
        ])
        #expect(set.removing(red).rules.map(\.colorKey) == [blue])
    }

    // MARK: - Resolution

    @Test func resolveFallsBackToDefaultsWithoutRule() {
        let defaults = ColorCustomizationDefaults(
            tickerLeadMinutes: 15, overlaySkinID: "default", sound: nil)
        let resolved = ColorRuleSet.empty.resolve(for: red, defaults: defaults)
        #expect(resolved.tickerLeadMinutes == 15)
        #expect(resolved.tickerTemplate == nil)
        #expect(resolved.overlaySkinID == "default")
        #expect(resolved.sound == nil)
    }

    @Test func resolveMergesOverridesOverDefaults() {
        let set = ColorRuleSet(rules: [
            ColorRule(colorKey: red, tickerLeadMinutes: 30, overlaySkinID: "plane")
        ])
        let defaults = ColorCustomizationDefaults(
            tickerLeadMinutes: 15, overlaySkinID: "default", sound: "chime")
        let resolved = set.resolve(for: red, defaults: defaults)
        #expect(resolved.tickerLeadMinutes == 30)      // overridden
        #expect(resolved.overlaySkinID == "plane")     // overridden
        #expect(resolved.sound == "chime")             // fell back to default
    }

    // MARK: - Codable

    @Test func roundTripsThroughJSON() throws {
        let set = ColorRuleSet(rules: [
            ColorRule(colorKey: red, tickerLeadMinutes: 30, tickerTemplate: "🔴 {{title}}"),
            ColorRule(colorKey: blue, sound: "ping")
        ])
        let data = try JSONEncoder().encode(set)
        let decoded = try JSONDecoder().decode(ColorRuleSet.self, from: data)
        #expect(decoded == set)
    }

    @Test func decodesAsBareArray() throws {
        // The set encodes as a plain JSON array of rules, not a wrapping object.
        let json = ##"[{"colorKey":{"hex":"#FF0000"},"tickerLeadMinutes":30}]"##
        let decoded = try JSONDecoder().decode(ColorRuleSet.self, from: Data(json.utf8))
        #expect(decoded.rule(for: red)?.tickerLeadMinutes == 30)
    }
}
