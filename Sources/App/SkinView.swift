import SwiftUI
import CalendarCore

/// Phase 4 (#8): renders a reminder overlay from a ``ThemeManifest`` and a
/// ``CalEvent``. Text zones are positioned by their manifest-relative frames over
/// the full-screen transparent overlay; templates are filled by the locale-free
/// ``TemplateRenderer`` in CalendarCore.
///
/// Scope boundary: this draws the *skin* — background, text zones, entry
/// animation. The interactive button layer (#9) renders on top and is the only
/// part that captures clicks; here the manifest's button frames only reserve
/// space so the card's backing material extends to include them.
struct SkinView: View {
    let manifest: ThemeManifest
    let event: CalEvent
    /// Accent color resolved from the event's `ColorKey` (color-as-key).
    var accent: Color = .accentColor

    @State private var shown = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private var values: [String: String] {
        event.templateValues(timeFormatter: Self.timeFormatter)
    }

    var body: some View {
        // SpriteKit skins (e.g. the airplane demo) render their own animated
        // scene; the static zone layout below covers fade/slide/none skins.
        if manifest.animation?.type == .spriteKit {
            PlaneSkinView(manifest: manifest, event: event, accent: accent)
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                card(in: size)
                ForEach(manifest.textZones) { zone in
                    textZone(zone, in: size)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .opacity(shown ? 1 : 0)
        .offset(y: slideOffset)
        .onAppear {
            withAnimation(entryAnimation) { shown = true }
        }
    }

    // MARK: - Pieces

    /// A glass card spanning the bounding box of all zones and buttons, so text
    /// reads against a surface instead of floating on the bare desktop.
    @ViewBuilder
    private func card(in size: CGSize) -> some View {
        if let box = contentBoundingBox {
            let pad: CGFloat = 24
            let rect = CGRect(
                x: box.minX * size.width - pad,
                y: box.minY * size.height - pad,
                width: box.width * size.width + pad * 2,
                height: box.height * size.height + pad * 2
            )
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(accent.opacity(0.5), lineWidth: 2)
                )
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    private func textZone(_ zone: TextZone, in size: CGSize) -> some View {
        let rect = CGRect(
            x: zone.frame.x * size.width,
            y: zone.frame.y * size.height,
            width: zone.frame.width * size.width,
            height: zone.frame.height * size.height
        )
        let text = TemplateRenderer.render(zone.template, values: values)
        return Text(text)
            .font(.system(size: zone.fontSize ?? 17, weight: .semibold))
            .multilineTextAlignment(alignment(zone.alignment))
            .frame(width: rect.width, height: rect.height, alignment: frameAlignment(zone.alignment))
            .position(x: rect.midX, y: rect.midY)
    }

    // MARK: - Layout helpers

    /// Union of every zone and button frame, in relative [0,1] coordinates.
    private var contentBoundingBox: CGRect? {
        let frames = manifest.textZones.map(\.frame) + manifest.buttons.map(\.frame)
        guard !frames.isEmpty else { return nil }
        let minX = frames.map(\.x).min()!
        let minY = frames.map(\.y).min()!
        let maxX = frames.map { $0.x + $0.width }.max()!
        let maxY = frames.map { $0.y + $0.height }.max()!
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func alignment(_ a: TextZone.TextAlignment?) -> TextAlignment {
        switch a {
        case .leading: return .leading
        case .trailing: return .trailing
        case .center, nil: return .center
        }
    }

    private func frameAlignment(_ a: TextZone.TextAlignment?) -> Alignment {
        switch a {
        case .leading: return .leading
        case .trailing: return .trailing
        case .center, nil: return .center
        }
    }

    // MARK: - Entry animation

    private var entryAnimation: Animation {
        guard let anim = manifest.animation else { return .default }
        switch anim.type {
        case .none: return .linear(duration: 0)
        case .fade, .spriteKit: return .easeOut(duration: anim.duration)
        case .slide: return .spring(duration: anim.duration)
        }
    }

    /// Slide skins drop in from above until shown.
    private var slideOffset: CGFloat {
        guard manifest.animation?.type == .slide, !shown else { return 0 }
        return -60
    }
}
