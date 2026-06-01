import Foundation
import Testing
@testable import CalendarCore

@Suite struct ThemeManifestTests {

    // MARK: - Helpers

    private func makeTheme(
        in parent: URL,
        name: String = "test",
        json: String
    ) throws -> URL {
        let dir = parent.appendingPathComponent("\(name).subnotes-theme", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try json.write(to: dir.appendingPathComponent("manifest.json"),
                       atomically: true, encoding: .utf8)
        return dir
    }

    private func withTempDir(_ body: (URL) throws -> Void) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try body(tmp)
    }

    private let minimalJSON = """
    {"id":"card","name":"Minimal Card","version":1}
    """

    // MARK: - Manifest parsing

    @Test func parsesMinimalManifest() throws {
        try withTempDir { tmp in
            let url = try makeTheme(in: tmp, json: minimalJSON)
            let manifest = try ThemeLoader.load(from: url)
            #expect(manifest.id == "card")
            #expect(manifest.name == "Minimal Card")
            #expect(manifest.version == 1)
            #expect(manifest.duration == nil)
            #expect(manifest.sound == nil)
            #expect(manifest.animation == nil)
            #expect(manifest.textZones.isEmpty)
            #expect(manifest.buttons.isEmpty)
            #expect(manifest.assets.isEmpty)
        }
    }

    @Test func parsesFullManifest() throws {
        let json = """
        {
          "id": "plane",
          "name": "Airplane Banner",
          "version": 2,
          "duration": 30,
          "sound": "whoosh",
          "animation": {"type": "slide", "duration": 0.5},
          "textZones": [
            {"id": "title", "frame": {"x":0.1,"y":0.1,"width":0.8,"height":0.2},
             "template": "{{title}}", "fontSize": 18, "alignment": "center"}
          ],
          "buttons": [
            {"id": "dismiss", "action": "dismiss",
             "frame": {"x":0.1,"y":0.8,"width":0.2,"height":0.1}, "label": "Закрыть"},
            {"id": "connect", "action": "connect",
             "frame": {"x":0.4,"y":0.8,"width":0.2,"height":0.1}}
          ],
          "assets": ["plane.png", "shadow.png"]
        }
        """
        try withTempDir { tmp in
            let url = try makeTheme(in: tmp, json: json)
            let manifest = try ThemeLoader.load(from: url)
            #expect(manifest.id == "plane")
            #expect(manifest.version == 2)
            #expect(manifest.duration == 30)
            #expect(manifest.sound == "whoosh")
            #expect(manifest.animation == AnimationSpec(type: .slide, duration: 0.5))
            #expect(manifest.textZones.count == 1)
            #expect(manifest.textZones[0].id == "title")
            #expect(manifest.textZones[0].template == "{{title}}")
            #expect(manifest.textZones[0].fontSize == 18)
            #expect(manifest.textZones[0].alignment == .center)
            #expect(manifest.buttons.count == 2)
            #expect(manifest.buttons[0].action == .dismiss)
            #expect(manifest.buttons[0].label == "Закрыть")
            #expect(manifest.buttons[1].action == .connect)
            #expect(manifest.buttons[1].label == nil)
            #expect(manifest.assets == ["plane.png", "shadow.png"])
        }
    }

    @Test func parsesAllAnimationTypes() throws {
        let types: [(String, AnimationSpec.AnimationType)] = [
            ("none", .none), ("fade", .fade), ("slide", .slide), ("spriteKit", .spriteKit)
        ]
        try withTempDir { tmp in
            for (raw, expected) in types {
                let json = """
                {"id":"t","name":"T","version":1,"animation":{"type":"\(raw)","duration":0.3}}
                """
                let url = try makeTheme(in: tmp, name: raw, json: json)
                let manifest = try ThemeLoader.load(from: url)
                #expect(manifest.animation?.type == expected)
            }
        }
    }

    @Test func parsesAllButtonActions() throws {
        let actions: [(String, ButtonSpec.ButtonAction)] = [
            ("dismiss", .dismiss), ("snooze", .snooze),
            ("openInCalendar", .openInCalendar), ("connect", .connect)
        ]
        let frame = #"{"x":0,"y":0,"width":0.1,"height":0.1}"#
        try withTempDir { tmp in
            for (raw, expected) in actions {
                let json = """
                {"id":"t","name":"T","version":1,"buttons":[{"id":"b","action":"\(raw)","frame":\(frame)}]}
                """
                let url = try makeTheme(in: tmp, name: raw, json: json)
                let manifest = try ThemeLoader.load(from: url)
                #expect(manifest.buttons[0].action == expected)
            }
        }
    }

    // MARK: - Validation: missing/invalid fields

    @Test func rejectsEmptyId() throws {
        try withTempDir { tmp in
            let url = try makeTheme(in: tmp, json: #"{"id":"","name":"X","version":1}"#)
            #expect(throws: ThemeLoader.LoadError.invalidManifest(reason: "id must not be empty")) {
                try ThemeLoader.load(from: url)
            }
        }
    }

    @Test func rejectsEmptyName() throws {
        try withTempDir { tmp in
            let url = try makeTheme(in: tmp, json: #"{"id":"x","name":"","version":1}"#)
            #expect(throws: ThemeLoader.LoadError.invalidManifest(reason: "name must not be empty")) {
                try ThemeLoader.load(from: url)
            }
        }
    }

    @Test func rejectsVersionZero() throws {
        try withTempDir { tmp in
            let url = try makeTheme(in: tmp, json: #"{"id":"x","name":"X","version":0}"#)
            #expect(throws: ThemeLoader.LoadError.invalidManifest(reason: "version must be >= 1")) {
                try ThemeLoader.load(from: url)
            }
        }
    }

    @Test func rejectsNegativeVersion() throws {
        try withTempDir { tmp in
            let url = try makeTheme(in: tmp, json: #"{"id":"x","name":"X","version":-1}"#)
            #expect(throws: ThemeLoader.LoadError.invalidManifest(reason: "version must be >= 1")) {
                try ThemeLoader.load(from: url)
            }
        }
    }

    @Test func rejectsZeroDuration() throws {
        try withTempDir { tmp in
            let url = try makeTheme(in: tmp, json: #"{"id":"x","name":"X","version":1,"duration":0}"#)
            #expect(throws: ThemeLoader.LoadError.invalidManifest(reason: "duration must be positive when set")) {
                try ThemeLoader.load(from: url)
            }
        }
    }

    @Test func rejectsNegativeDuration() throws {
        try withTempDir { tmp in
            let url = try makeTheme(in: tmp, json: #"{"id":"x","name":"X","version":1,"duration":-5}"#)
            #expect(throws: ThemeLoader.LoadError.invalidManifest(reason: "duration must be positive when set")) {
                try ThemeLoader.load(from: url)
            }
        }
    }

    @Test func rejectsTextZoneWithEmptyId() throws {
        let frame = #"{"x":0,"y":0,"width":0.1,"height":0.1}"#
        let json = """
        {"id":"x","name":"X","version":1,"textZones":[{"id":"","frame":\(frame),"template":"{{title}}"}]}
        """
        try withTempDir { tmp in
            let url = try makeTheme(in: tmp, json: json)
            #expect(throws: ThemeLoader.LoadError.invalidManifest(reason: "textZone id must not be empty")) {
                try ThemeLoader.load(from: url)
            }
        }
    }

    @Test func rejectsTextZoneWithEmptyTemplate() throws {
        let frame = #"{"x":0,"y":0,"width":0.1,"height":0.1}"#
        let json = """
        {"id":"x","name":"X","version":1,"textZones":[{"id":"t","frame":\(frame),"template":""}]}
        """
        try withTempDir { tmp in
            let url = try makeTheme(in: tmp, json: json)
            #expect(throws: ThemeLoader.LoadError.invalidManifest(reason: "textZone template must not be empty")) {
                try ThemeLoader.load(from: url)
            }
        }
    }

    @Test func rejectsButtonWithEmptyId() throws {
        let frame = #"{"x":0,"y":0,"width":0.1,"height":0.1}"#
        let json = """
        {"id":"x","name":"X","version":1,"buttons":[{"id":"","action":"dismiss","frame":\(frame)}]}
        """
        try withTempDir { tmp in
            let url = try makeTheme(in: tmp, json: json)
            #expect(throws: ThemeLoader.LoadError.invalidManifest(reason: "button id must not be empty")) {
                try ThemeLoader.load(from: url)
            }
        }
    }

    // MARK: - File system errors

    @Test func throwsWhenManifestFileMissing() throws {
        try withTempDir { tmp in
            let dir = tmp.appendingPathComponent("empty.subnotes-theme", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            #expect(throws: ThemeLoader.LoadError.manifestNotFound) {
                try ThemeLoader.load(from: dir)
            }
        }
    }

    @Test func throwsOnMalformedJSON() throws {
        try withTempDir { tmp in
            let url = try makeTheme(in: tmp, json: "not json at all {{{")
            #expect(throws: ThemeLoader.LoadError.invalidJSON) {
                try ThemeLoader.load(from: url)
            }
        }
    }

    // MARK: - loadAll

    @Test func loadAllReturnsValidThemes() throws {
        try withTempDir { tmp in
            _ = try makeTheme(in: tmp, name: "b-card", json: #"{"id":"b-card","name":"B","version":1}"#)
            _ = try makeTheme(in: tmp, name: "a-plane", json: #"{"id":"a-plane","name":"A","version":1}"#)
            let themes = ThemeLoader.loadAll(from: tmp)
            #expect(themes.map(\.id) == ["a-plane", "b-card"])
        }
    }

    @Test func loadAllSkipsInvalidThemes() throws {
        try withTempDir { tmp in
            _ = try makeTheme(in: tmp, name: "valid", json: #"{"id":"valid","name":"Valid","version":1}"#)
            _ = try makeTheme(in: tmp, name: "bad-json", json: "oops")
            _ = try makeTheme(in: tmp, name: "bad-id", json: #"{"id":"","name":"X","version":1}"#)
            let themes = ThemeLoader.loadAll(from: tmp)
            #expect(themes.map(\.id) == ["valid"])
        }
    }

    @Test func loadAllIgnoresNonThemeDirectories() throws {
        try withTempDir { tmp in
            _ = try makeTheme(in: tmp, name: "valid", json: minimalJSON)
            let otherDir = tmp.appendingPathComponent("other.bundle", isDirectory: true)
            try FileManager.default.createDirectory(at: otherDir, withIntermediateDirectories: true)
            let themes = ThemeLoader.loadAll(from: tmp)
            #expect(themes.count == 1)
        }
    }

    @Test func loadAllReturnsEmptyForMissingDirectory() {
        let missing = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString)")
        #expect(ThemeLoader.loadAll(from: missing).isEmpty)
    }

    @Test func loadAllAcceptsEmptyDirectory() throws {
        try withTempDir { tmp in
            #expect(ThemeLoader.loadAll(from: tmp).isEmpty)
        }
    }
}
