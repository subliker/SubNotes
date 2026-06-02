import SwiftUI
import AppKit

/// Phase 4 foundation: a transparent, full-screen window that floats above
/// everything — including other apps' full-screen spaces — and, by default,
/// lets clicks pass straight through to whatever is behind it ("click-through
/// in empty zones").
///
/// #7 delivered the window surface and its layering/passthrough behavior; #8 the
/// skin renderer. The interactive button layer (#9) sits on top: instead of
/// flipping `isInteractive` for the whole surface, the window now captures clicks
/// *only* over the reported control rects (``interactiveScreenRects``) and stays
/// click-through everywhere else.
///
/// It is an `NSPanel` with `.nonactivatingPanel` so a click on a control fires
/// immediately without activating SubNotes or stealing the foreground app's
/// focus — exactly what a transient reminder overlay wants.
final class OverlayWindow: NSPanel {

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Transparent surface, no chrome.
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        titlebarAppearsTransparent = true

        // Float above normal windows *and* above full-screen apps and the menu
        // bar. `.screenSaver` is the established level for transient overlays;
        // the collection behavior is what actually lets it draw over another
        // app's full-screen space without forcing a space switch (Risks §2).
        level = .screenSaver
        collectionBehavior = [
            .canJoinAllSpaces,   // visible on every space, including full-screen ones
            .fullScreenAuxiliary, // allowed to overlay a full-screen window
            .stationary,         // don't move/animate with Spaces transitions
            .ignoresCycle        // stay out of Cmd-` window cycling
        ]

        // An overlay must never steal focus from the user's current app.
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .none

        // Default: fully click-through. Interactive regions arrive with the
        // button layer (#9).
        ignoresMouseEvents = true
    }

    deinit { removeMouseMonitors() }

    // Borderless panels refuse key/main by default; make that explicit so the
    // overlay never grabs focus even while its controls receive clicks.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // MARK: - Per-region click-through (#9)

    /// Screen-space rects (AppKit bottom-left origin, global coords) over which
    /// the overlay should capture clicks. Everywhere else stays click-through.
    /// Empty restores full passthrough.
    var interactiveScreenRects: [CGRect] = [] {
        didSet { refreshMouseMonitoring() }
    }

    /// Mouse-moved monitors that keep `ignoresMouseEvents` in sync with whether
    /// the cursor currently sits over a control rect. A *global* monitor fires
    /// while the events go to the app behind (so we can re-arm when the cursor
    /// returns over the bar); a *local* one covers the case where they reach us.
    private var mouseMonitors: [Any] = []

    private func refreshMouseMonitoring() {
        guard !interactiveScreenRects.isEmpty else {
            removeMouseMonitors()
            ignoresMouseEvents = true
            return
        }
        if mouseMonitors.isEmpty {
            let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
            let global = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
                self?.updateMousePassthrough()
            }
            let local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                self?.updateMousePassthrough()
                return event
            }
            mouseMonitors = [global, local].compactMap { $0 }
        }
        updateMousePassthrough()
    }

    private func updateMousePassthrough() {
        let location = NSEvent.mouseLocation
        let overControl = interactiveScreenRects.contains { $0.contains(location) }
        ignoresMouseEvents = !overControl
    }

    private func removeMouseMonitors() {
        for monitor in mouseMonitors { NSEvent.removeMonitor(monitor) }
        mouseMonitors.removeAll()
    }
}

/// Owns the lifecycle of overlay windows: builds one per screen, shows it
/// without activating the app, and tears it down. Content is any SwiftUI view,
/// so the skin engine (#8) can supply the real renderer later.
@MainActor
final class OverlayController {
    private var windows: [OverlayWindow] = []

    var isShowing: Bool { !windows.isEmpty }

    /// Presents `content` full-screen on the screen carrying the menu bar (the
    /// one the user is currently looking at). Replaces any existing overlay.
    func present<Content: View>(@ViewBuilder _ content: () -> Content) {
        dismiss()

        // The menu-bar screen is the active one for a menu-bar app; fall back to
        // the main screen if none is reported.
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let window = OverlayWindow(screen: screen)
        let host = NSHostingView(rootView: AnyView(content()))
        host.frame = screen.frame
        host.autoresizingMask = [.width, .height]
        window.contentView = host

        // orderFrontRegardless shows the window without activating SubNotes, so
        // the user's foreground app keeps focus.
        window.orderFrontRegardless()
        windows.append(window)
    }

    func dismiss() {
        for window in windows {
            window.interactiveScreenRects = []  // tear down mouse monitors
            window.orderOut(nil)
        }
        windows.removeAll()
    }

    /// Marks the regions (in SwiftUI global coords, top-left origin, as reported
    /// by the button layer) that should capture clicks. Converts them to AppKit
    /// screen space and hands them to the window so the bar is clickable while the
    /// rest of the overlay passes clicks through to the app behind.
    func setInteractiveSwiftUIRects(_ rects: [CGRect]) {
        guard let window = windows.first,
              let screen = window.screen ?? NSScreen.main else { return }
        let frame = screen.frame
        window.interactiveScreenRects = rects
            .filter { $0 != .zero }
            .map { r in
                CGRect(
                    x: frame.minX + r.minX,
                    y: frame.minY + (frame.height - r.maxY),
                    width: r.width,
                    height: r.height
                )
            }
    }
}

/// A throwaway placeholder so #7 is visually verifiable on its own: a centered
/// glass card proving the window is transparent, covers the screen, floats over
/// full-screen apps, and passes clicks through the empty area around the card.
/// Replaced by the manifest-driven skin renderer in #8.
struct OverlayPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.badge.fill")
                .font(.largeTitle)
            Text("Напоминание")
                .font(.headline)
            Text("Overlay window (Phase 4 #7)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
