import Foundation
import ServiceManagement
import os

/// Wraps `SMAppService.mainApp` so the Settings toggle can register/unregister
/// SubNotes as a login item — no helper bundle, no signing, works for an
/// unsigned ad-hoc build (the user approves it in System Settings › General ›
/// Login Items the first time).
@MainActor
@Observable
final class LoginItemManager {

    private static let log = Logger(subsystem: "com.subnotes.app", category: "LoginItem")

    /// Whether the app is currently registered to launch at login.
    private(set) var isEnabled: Bool

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Re-reads the live status (it can change in System Settings behind our
    /// back, e.g. the user revokes approval).
    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the login item, then reflects the resulting
    /// status. Failures are logged and leave `isEnabled` showing reality.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Self.log.error("Login item \(enabled ? "register" : "unregister") failed: \(error.localizedDescription)")
        }
        refresh()
    }
}
