import Foundation

public struct ThemeLoader: Sendable {

    public enum LoadError: Error, Sendable, Equatable {
        case manifestNotFound
        case invalidJSON
        case invalidManifest(reason: String)
    }

    /// Loads and validates a single theme from a `.subnotes-theme` directory.
    public static func load(from themeURL: URL) throws -> ThemeManifest {
        let manifestURL = themeURL.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL) else {
            throw LoadError.manifestNotFound
        }
        let manifest: ThemeManifest
        do {
            manifest = try JSONDecoder().decode(ThemeManifest.self, from: data)
        } catch {
            throw LoadError.invalidJSON
        }
        try validate(manifest)
        return manifest
    }

    /// Loads all valid themes from a directory containing `.subnotes-theme` bundles.
    /// Invalid or unreadable themes are silently skipped.
    public static func loadAll(from directoryURL: URL) -> [ThemeManifest] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }
        return entries
            .filter { $0.pathExtension == "subnotes-theme" }
            .compactMap { try? load(from: $0) }
            .sorted { $0.id < $1.id }
    }

    /// Directory holding the themes bundled with the app, or nil if unavailable.
    public static var builtInThemesDirectory: URL? {
        Bundle.module.url(forResource: "BuiltInThemes", withExtension: nil)
    }

    /// Loads the themes shipped inside the app bundle.
    public static func loadBuiltIn() -> [ThemeManifest] {
        guard let dir = builtInThemesDirectory else { return [] }
        return loadAll(from: dir)
    }

    /// Built-in themes plus any user themes in `userDirectory`.
    /// User themes override built-in ones sharing the same id.
    public static func loadAll(userDirectory: URL?) -> [ThemeManifest] {
        let user = userDirectory.map { loadAll(from: $0) } ?? []
        let userIds = Set(user.map(\.id))
        let builtIn = loadBuiltIn().filter { !userIds.contains($0.id) }
        return (builtIn + user).sorted { $0.id < $1.id }
    }

    // MARK: - Private

    private static func validate(_ manifest: ThemeManifest) throws {
        guard !manifest.id.isEmpty else {
            throw LoadError.invalidManifest(reason: "id must not be empty")
        }
        guard !manifest.name.isEmpty else {
            throw LoadError.invalidManifest(reason: "name must not be empty")
        }
        guard manifest.version >= 1 else {
            throw LoadError.invalidManifest(reason: "version must be >= 1")
        }
        if let d = manifest.duration {
            guard d > 0 else {
                throw LoadError.invalidManifest(reason: "duration must be positive when set")
            }
        }
        for zone in manifest.textZones {
            guard !zone.id.isEmpty else {
                throw LoadError.invalidManifest(reason: "textZone id must not be empty")
            }
            guard !zone.template.isEmpty else {
                throw LoadError.invalidManifest(reason: "textZone template must not be empty")
            }
        }
        for button in manifest.buttons {
            guard !button.id.isEmpty else {
                throw LoadError.invalidManifest(reason: "button id must not be empty")
            }
        }
    }
}
