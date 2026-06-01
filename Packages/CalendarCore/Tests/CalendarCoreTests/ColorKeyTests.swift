import Foundation
import Testing
@testable import CalendarCore

@Suite struct ColorKeyTests {
    @Test func normalizesSixDigitHexWithHash() {
        #expect(ColorKey(hex: "#ff8800")?.hex == "#FF8800")
    }

    @Test func normalizesWithoutHash() {
        #expect(ColorKey(hex: "ff8800")?.hex == "#FF8800")
    }

    @Test func expandsShortHex() {
        #expect(ColorKey(hex: "#f80")?.hex == "#FF8800")
    }

    @Test func trimsWhitespace() {
        #expect(ColorKey(hex: "  #FF8800 ")?.hex == "#FF8800")
    }

    @Test func rejectsInvalid() {
        #expect(ColorKey(hex: nil) == nil)
        #expect(ColorKey(hex: "") == nil)
        #expect(ColorKey(hex: "#GGGGGG") == nil)
        #expect(ColorKey(hex: "#FF88") == nil)
    }

    @Test func equalKeysGroupTogether() {
        // The grouping property the whole color-as-key idea relies on.
        #expect(ColorKey(hex: "#ff8800") == ColorKey(hex: "FF8800"))
    }
}
