import SwiftUI
import AppKit

/// Phase 4 foundation: a transparent, full-screen window that floats above
/// everything — including other apps' full-screen spaces — and, by default,
/// lets clicks pass straight through to whatever is behind it ("click-through
/// in empty zones").
///
/// This issue (#7) delivers only the window surface and its layering/passthrough
/// behavior. The skin-rendering engine (#8) and the interactive button layer
/// (#9) build on top: the button layer will flip `isInteractive` (or refine the
/// hit test) so controls capture clicks while the rest of the surface stays
/// click-through.
final class OverlayWindow: NSWindow {

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
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

    // Borderless windows refuse key/main by default; make that explicit so the
    // overlay never grabs focus even when a future interactive region asks for
    // first responder.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Toggles whether the window swallows mouse events. `false` (default) means
    /// every click passes through to the app behind; `true` lets hosted controls
    /// receive clicks. The button layer (#9) will drive this.
    var isInteractive: Bool {
        get { !ignoresMouseEvents }
        set { ignoresMouseEvents = !newValue }
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
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
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
