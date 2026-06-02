import Foundation
import Testing
@testable import CalendarCore

@Suite struct TemplateRendererTests {

    @Test func substitutesAllPlaceholders() {
        let out = TemplateRenderer.render(
            "{{time}} · {{title}}",
            values: ["time": "10:30", "title": "Standup"]
        )
        #expect(out == "10:30 · Standup")
    }

    @Test func dropsTrailingSeparatorWhenLastValueEmpty() {
        let out = TemplateRenderer.render(
            "{{time}} · {{location}}",
            values: ["time": "10:30", "location": ""]
        )
        #expect(out == "10:30")
    }

    @Test func dropsLeadingSeparatorWhenFirstValueEmpty() {
        let out = TemplateRenderer.render(
            "{{location}} · {{time}}",
            values: ["time": "10:30"]   // location missing entirely
        )
        #expect(out == "10:30")
    }

    @Test func collapsesMiddleSeparatorWhenInnerValueEmpty() {
        let out = TemplateRenderer.render(
            "{{title}} · {{location}} · {{time}}",
            values: ["title": "Standup", "time": "10:30"]
        )
        #expect(out == "Standup · 10:30")
    }

    @Test func whitespaceOnlyValueCountsAsEmpty() {
        let out = TemplateRenderer.render(
            "{{time}} · {{location}}",
            values: ["time": "10:30", "location": "   "]
        )
        #expect(out == "10:30")
    }

    @Test func keepsLiteralTextAroundPlaceholders() {
        let out = TemplateRenderer.render(
            "В {{time}} — {{title}}",
            values: ["time": "10:30", "title": "Standup"]
        )
        #expect(out == "В 10:30 — Standup")
    }

    @Test func allEmptyYieldsEmptyString() {
        let out = TemplateRenderer.render(
            "{{title}} · {{location}}",
            values: [:]
        )
        #expect(out == "")
    }

    @Test func toleratesWhitespaceInsidePlaceholderBraces() {
        let out = TemplateRenderer.render(
            "{{ title }}",
            values: ["title": "Standup"]
        )
        #expect(out == "Standup")
    }

    @Test func leavesUnknownPlaceholderEmptyAndTrims() {
        let out = TemplateRenderer.render(
            "{{title}} ({{unknown}})",
            values: ["title": "Standup"]
        )
        // The "(" / ")" literals aren't separators, so they remain.
        #expect(out == "Standup ()")
    }

    @Test func unclosedPlaceholderTreatedAsLiteral() {
        let out = TemplateRenderer.render(
            "{{title",
            values: ["title": "Standup"]
        )
        #expect(out == "{{title")
    }
}
