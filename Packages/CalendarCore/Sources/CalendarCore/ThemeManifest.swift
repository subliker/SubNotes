import Foundation

public struct RelativeFrame: Codable, Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

public struct TextZone: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let frame: RelativeFrame
    /// Supports {{title}}, {{time}}, {{location}} placeholders.
    public let template: String
    public let fontSize: Double?
    public let alignment: TextAlignment?

    public enum TextAlignment: String, Codable, Sendable {
        case leading, center, trailing
    }

    public init(id: String, frame: RelativeFrame, template: String,
                fontSize: Double? = nil, alignment: TextAlignment? = nil) {
        self.id = id; self.frame = frame; self.template = template
        self.fontSize = fontSize; self.alignment = alignment
    }
}

public struct ButtonSpec: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let action: ButtonAction
    public let frame: RelativeFrame
    public let label: String?

    public enum ButtonAction: String, Codable, Sendable {
        case dismiss, snooze, openInCalendar, connect
    }

    public init(id: String, action: ButtonAction, frame: RelativeFrame, label: String? = nil) {
        self.id = id; self.action = action; self.frame = frame; self.label = label
    }
}

public struct AnimationSpec: Codable, Sendable, Equatable {
    public let type: AnimationType
    public let duration: Double

    public enum AnimationType: String, Codable, Sendable {
        case none, fade, slide, spriteKit
    }

    public init(type: AnimationType, duration: Double) {
        self.type = type; self.duration = duration
    }
}

public struct ThemeManifest: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let version: Int
    /// Display duration in seconds; nil means stay until dismissed.
    public let duration: Double?
    public let sound: String?
    public let animation: AnimationSpec?
    public let textZones: [TextZone]
    public let buttons: [ButtonSpec]
    /// Relative paths to asset files inside the .subnotes-theme bundle.
    public let assets: [String]

    public init(
        id: String,
        name: String,
        version: Int,
        duration: Double? = nil,
        sound: String? = nil,
        animation: AnimationSpec? = nil,
        textZones: [TextZone] = [],
        buttons: [ButtonSpec] = [],
        assets: [String] = []
    ) {
        self.id = id; self.name = name; self.version = version
        self.duration = duration; self.sound = sound; self.animation = animation
        self.textZones = textZones; self.buttons = buttons; self.assets = assets
    }
}
