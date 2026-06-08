import Foundation

/// Persists ``AppSettings`` to `UserDefaults` as a single JSON blob.
///
/// The backing store is injectable so tests can run against a throwaway suite
/// instead of `.standard`. Reads are forgiving: missing or corrupt data falls
/// back to defaults rather than throwing.
public final class SettingsStore: @unchecked Sendable {

    /// Key under which the encoded ``AppSettings`` blob is stored.
    public static let defaultsKey = "com.subnotes.appSettings"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = SettingsStore.defaultsKey) {
        self.defaults = defaults
        self.key = key
    }

    /// Current settings, or freshly-defaulted settings when nothing valid is
    /// stored yet.
    public var settings: AppSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }
        return decoded
    }

    /// Encodes and writes the given settings. No-op (silently) if encoding fails.
    public func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    /// Reads, mutates, and writes back in one call.
    @discardableResult
    public func update(_ transform: (inout AppSettings) -> Void) -> AppSettings {
        var current = settings
        transform(&current)
        save(current)
        return current
    }

    /// Removes the stored blob, so the next read returns defaults.
    public func reset() {
        defaults.removeObject(forKey: key)
    }
}
