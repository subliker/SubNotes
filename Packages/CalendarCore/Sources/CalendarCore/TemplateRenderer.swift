import Foundation

/// Fills a skin text-zone template (`"{{time}} · {{location}}"`) from a set of
/// resolved values. Pure and locale-free: date formatting happens upstream and
/// arrives here as plain strings, so this stays trivially unit-testable.
///
/// The interesting behavior is *graceful emptiness*: when a placeholder resolves
/// to an empty value, the renderer drops not just the placeholder but an adjacent
/// separator, so `"{{time}} · {{location}}"` with no location renders `"10:30"`
/// — never a dangling `"10:30 · "`.
public enum TemplateRenderer {

    /// Recognized placeholder keys. The values dict is keyed by these raw names.
    public enum Key: String, CaseIterable, Sendable {
        case title, time, location
    }

    private enum Resolved {
        case literal(String)
        case value(String)   // a placeholder that produced non-empty text
        case empty           // a placeholder that produced nothing
    }

    /// Substitutes `{{key}}` placeholders with `values[key]`, then collapses the
    /// separators that surrounded any placeholder that resolved to empty/missing.
    public static func render(_ template: String, values: [String: String]) -> String {
        let resolved: [Resolved] = tokenize(template).map { token in
            switch token {
            case .literal(let s):
                return .literal(s)
            case .placeholder(let key):
                let v = values[key]?.trimmingCharacters(in: .whitespaces) ?? ""
                return v.isEmpty ? .empty : .value(v)
            }
        }

        // Suppress a separator literal adjacent to each empty placeholder: prefer
        // the preceding separator, else the following one.
        var suppressed = Set<Int>()
        for (i, r) in resolved.enumerated() {
            guard case .empty = r else { continue }
            if let prev = neighborSeparator(in: resolved, from: i, step: -1, suppressed: suppressed) {
                suppressed.insert(prev)
            } else if let next = neighborSeparator(in: resolved, from: i, step: +1, suppressed: suppressed) {
                suppressed.insert(next)
            }
        }

        var out = ""
        for (i, r) in resolved.enumerated() where !suppressed.contains(i) {
            switch r {
            case .literal(let s): out += s
            case .value(let v): out += v
            case .empty: break
            }
        }
        return trimSeparators(out)
    }

    // MARK: - Tokenizing

    private enum Token {
        case literal(String)
        case placeholder(String)
    }

    private static func tokenize(_ template: String) -> [Token] {
        var tokens: [Token] = []
        var literal = ""
        var rest = Substring(template)

        while let open = rest.range(of: "{{") {
            literal += rest[rest.startIndex..<open.lowerBound]
            let afterOpen = rest[open.upperBound...]
            guard let close = afterOpen.range(of: "}}") else {
                literal += rest[open.lowerBound...]   // no closing braces: literal tail
                rest = Substring()
                break
            }
            let key = afterOpen[afterOpen.startIndex..<close.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            if !literal.isEmpty { tokens.append(.literal(literal)); literal = "" }
            tokens.append(.placeholder(key))
            rest = afterOpen[close.upperBound...]
        }
        literal += rest
        if !literal.isEmpty { tokens.append(.literal(literal)) }
        return tokens
    }

    // MARK: - Separator handling

    private static let separatorChars = CharacterSet(charactersIn: " ·-–—|,:•/")

    private static func isSeparator(_ s: String) -> Bool {
        !s.isEmpty && s.unicodeScalars.allSatisfy { separatorChars.contains($0) }
    }

    private static func trimSeparators(_ s: String) -> String {
        var scalars = Array(s.unicodeScalars)
        while let f = scalars.first, separatorChars.contains(f) { scalars.removeFirst() }
        while let l = scalars.last, separatorChars.contains(l) { scalars.removeLast() }
        return String(String.UnicodeScalarView(scalars))
    }

    private static func neighborSeparator(
        in resolved: [Resolved], from index: Int, step: Int, suppressed: Set<Int>
    ) -> Int? {
        let j = index + step
        guard resolved.indices.contains(j), !suppressed.contains(j) else { return nil }
        guard case .literal(let s) = resolved[j], isSeparator(s) else { return nil }
        return j
    }
}
