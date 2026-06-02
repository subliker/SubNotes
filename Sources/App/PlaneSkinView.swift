import SwiftUI
import SpriteKit
import CalendarCore

/// Phase 4 (#8): the animated "airplane" demo skin called out in PLAN.md. An
/// emoji plane tows a text banner across the screen, driven by SpriteKit. It
/// proves the manifest's `spriteKit` animation type and that a moving, layered
/// skin renders correctly over the transparent, click-through overlay window.
///
/// As with ``SkinView``, this only draws the skin; the interactive button layer
/// (#9) lands on top. The banner text comes from the manifest's first two text
/// zones, filled by the locale-free ``TemplateRenderer`` in CalendarCore.
struct PlaneSkinView: View {
    @State private var scene: PlaneSkinScene

    init(manifest: ThemeManifest, event: CalEvent, accent: Color = .accentColor) {
        let scene = PlaneSkinScene(manifest: manifest, event: event, accent: NSColor(accent))
        _scene = State(initialValue: scene)
    }

    var body: some View {
        // `.resizeFill` makes the scene track the full-screen overlay; transparency
        // lets the desktop behind show through the empty areas.
        SpriteView(scene: scene, options: [.allowsTransparency])
            .ignoresSafeArea()
    }
}

/// The SpriteKit scene behind ``PlaneSkinView``. Builds the plane + banner once
/// the view hands it a real size, then flies the whole rig left-to-right.
final class PlaneSkinScene: SKScene {
    private let titleText: String
    private let subtitleText: String
    private let accent: NSColor
    private let flightDuration: TimeInterval
    private var started = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    init(manifest: ThemeManifest, event: CalEvent, accent: NSColor) {
        let values = event.templateValues(timeFormatter: Self.timeFormatter)
        let zones = manifest.textZones
        self.titleText = zones.first
            .map { TemplateRenderer.render($0.template, values: values) } ?? event.title
        self.subtitleText = zones.dropFirst().first
            .map { TemplateRenderer.render($0.template, values: values) } ?? ""
        self.accent = accent
        self.flightDuration = manifest.animation?.duration ?? 7
        super.init(size: .zero)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func didMove(to view: SKView) { startFlightIfReady() }
    override func didChangeSize(_ oldSize: CGSize) { startFlightIfReady() }

    /// SpriteView reports the real size via `didChangeSize`/`didMove`; wait for a
    /// non-degenerate size, then build and launch the flight exactly once.
    private func startFlightIfReady() {
        guard !started, size.width > 1, size.height > 1 else { return }
        started = true
        buildAndAnimate()
    }

    // Concrete fonts (not the hidden system font) so measurement here matches
    // what SKLabelNode actually renders — `.AppleSystemUIFont` doesn't resolve in
    // SpriteKit, which silently substitutes a differently-sized fallback.
    private static let titleFont = NSFont(name: "HelveticaNeue-Bold", size: 20)
        ?? .boldSystemFont(ofSize: 20)
    private static let subtitleFont = NSFont(name: "HelveticaNeue", size: 14)
        ?? .systemFont(ofSize: 14)

    private func buildAndAnimate() {
        let bannerHeight: CGFloat = 72
        let ropeLength: CGFloat = 44
        let planeSize: CGFloat = 56
        let textPadding: CGFloat = 22

        // SKLabelNode truncates each line to `maxInner` with its own font, so the
        // banner can never be narrower than its text. The banner then sizes to the
        // *rendered* (already-ellipsized) label widths and is capped at half-screen.
        let maxInner = min(520, size.width * 0.5) - textPadding * 2

        let titleLabel = label(titleText, font: Self.titleFont,
                               color: .labelColor, maxWidth: maxInner)
        let subtitleLabel = subtitleText.isEmpty ? nil
            : label(subtitleText, font: Self.subtitleFont,
                    color: .secondaryLabelColor, maxWidth: maxInner)

        let contentWidth = max(titleLabel.frame.width, subtitleLabel?.frame.width ?? 0)
        let bannerWidth = max(220, contentWidth + textPadding * 2)

        // floatNode bobs gently; rig moves horizontally. Keeping them on separate
        // nodes lets the two SKActions compose without fighting over `position`.
        let rig = SKNode()
        let floatNode = SKNode()
        rig.addChild(floatNode)

        let banner = SKShapeNode(
            rectOf: CGSize(width: bannerWidth, height: bannerHeight), cornerRadius: 16
        )
        banner.fillColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92)
        banner.strokeColor = accent
        banner.lineWidth = 2
        floatNode.addChild(banner)

        titleLabel.position = CGPoint(x: 0, y: subtitleLabel == nil ? 0 : 11)
        floatNode.addChild(titleLabel)

        if let subtitleLabel {
            subtitleLabel.position = CGPoint(x: 0, y: -13)
            floatNode.addChild(subtitleLabel)
        }

        // Tow line from the banner's right edge to the plane.
        let rope = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: bannerWidth / 2, y: 0))
        path.addLine(to: CGPoint(x: bannerWidth / 2 + ropeLength, y: 4))
        rope.path = path
        rope.strokeColor = accent.withAlphaComponent(0.7)
        rope.lineWidth = 2
        floatNode.addChild(rope)

        let plane = SKLabelNode(text: "✈️")
        plane.fontSize = planeSize
        plane.horizontalAlignmentMode = .center
        plane.verticalAlignmentMode = .center
        plane.position = CGPoint(x: bannerWidth / 2 + ropeLength + planeSize / 2, y: 8)
        floatNode.addChild(plane)

        let rigWidth = bannerWidth + ropeLength + planeSize
        rig.position = CGPoint(x: -rigWidth, y: size.height * 0.72)
        addChild(rig)

        // Fly fully across and off the far edge, then clean up.
        let travel = size.width + rigWidth * 2
        let fly = SKAction.moveBy(x: travel, y: 0, duration: flightDuration)
        fly.timingMode = .linear
        rig.run(SKAction.sequence([fly, .removeFromParent()]))

        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 14, duration: 1.3),
            SKAction.moveBy(x: 0, y: -14, duration: 1.3)
        ])
        bob.timingMode = .easeInEaseOut
        floatNode.run(SKAction.repeatForever(bob))
    }

    /// A single-line label that ellipsizes itself to `maxWidth`. Letting
    /// SKLabelNode do the truncation (rather than measuring and trimming by hand)
    /// guarantees the cut matches the font it actually renders with.
    private func label(
        _ text: String, font: NSFont, color: NSColor, maxWidth: CGFloat
    ) -> SKLabelNode {
        let node = SKLabelNode(text: text)
        node.fontName = font.fontName
        node.fontSize = font.pointSize
        node.fontColor = color
        node.horizontalAlignmentMode = .center
        node.verticalAlignmentMode = .center
        node.numberOfLines = 1
        node.lineBreakMode = .byTruncatingTail
        node.preferredMaxLayoutWidth = maxWidth
        return node
    }
}
