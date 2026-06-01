import Foundation

public enum VideoProvider: String, Codable, Hashable, Sendable {
    case meet
    case zoom
    case teams
    case webex
    case other
}

/// A video-meeting link extracted from an event's text fields.
public struct VideoLink: Codable, Hashable, Sendable {
    public let url: URL
    public let provider: VideoProvider

    public init(url: URL, provider: VideoProvider) {
        self.url = url
        self.provider = provider
    }
}

/// Pure, EventKit-free extraction of a meeting link from arbitrary event text
/// (notes, location, url field). Kept separate so it is unit-testable on its own.
public enum VideoLinkParser {
    /// Returns the first recognized meeting link (Meet/Zoom/Teams/Webex) found
    /// across the given texts, scanning in order. Bare URLs of unknown providers
    /// are ignored — they are too likely to be unrelated links.
    public static func firstLink(in texts: [String?]) -> VideoLink? {
        for case let text? in texts {
            for url in urls(in: text) {
                let provider = classify(url)
                guard provider != .other else { continue }
                return VideoLink(url: url, provider: provider)
            }
        }
        return nil
    }

    public static func firstLink(in text: String?) -> VideoLink? {
        firstLink(in: [text])
    }

    private static func urls(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap { match in
            guard let url = match.url, url.scheme?.hasPrefix("http") == true else { return nil }
            return url
        }
    }

    private static func classify(_ url: URL) -> VideoProvider {
        guard let host = url.host?.lowercased() else { return .other }
        if host == "meet.google.com" {
            return .meet
        }
        if host.hasSuffix("zoom.us") {
            return .zoom
        }
        if host == "teams.microsoft.com" || host == "teams.live.com" {
            return .teams
        }
        if host.hasSuffix("webex.com") {
            return .webex
        }
        return .other
    }
}
