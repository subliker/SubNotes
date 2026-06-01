import AppKit
import CalendarCore

/// RunCat-style menu-bar ticker: a separate `NSStatusItem` that appears only
/// while an event is imminent and scrolls its text marquee-style, then hides.
///
/// It is intentionally a second status item next to the popover icon — the
/// popover is always present, the ticker only shows up in the lead window — so
/// "smart appearance" is just toggling this item's visibility. All *what to
/// show* decisions live in `TickerLogic` (unit tested); this class only renders.
@MainActor
final class TickerStatusItem {
    /// Default minutes before an event that the ticker starts showing it.
    var leadMinutes = 15

    private let model: AppModel
    private let statusItem: NSStatusItem
    private var loop: Task<Void, Never>?

    /// Marquee state.
    private let windowLength = 22
    private let gap = "     "
    private var sourceText: String?
    private var offset = 0

    /// The event a click should open; the nearest imminent one.
    private var currentEvent: CalEvent?

    /// Re-evaluate which event is imminent every this many scroll ticks.
    private let scrollInterval = Duration.milliseconds(250)
    private let evaluateEvery = 40 // 40 * 250ms ≈ 10s

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleClick)
        statusItem.isVisible = false

        evaluate()
        start()
    }

    deinit {
        loop?.cancel()
    }

    private func start() {
        loop = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: self?.scrollInterval ?? .milliseconds(250))
                guard let self else { return }
                if tick % self.evaluateEvery == 0 { self.evaluate() }
                self.advance()
                tick &+= 1
            }
        }
    }

    /// Recompute the imminent event and its text from the current events + time.
    private func evaluate() {
        let entries = TickerLogic.imminentEntries(
            model.events,
            leadMinutes: leadMinutes
        )
        guard let entry = entries.first else {
            currentEvent = nil
            sourceText = nil
            statusItem.isVisible = false
            return
        }
        let text = TickerLogic.line(for: entry)
        if text != sourceText {
            sourceText = text
            offset = 0
        }
        currentEvent = entry.event
        statusItem.isVisible = true
    }

    /// Advance the marquee by one character and render the visible window.
    private func advance() {
        guard let text = sourceText else { return }
        statusItem.button?.title = Self.marqueeFrame(
            text,
            offset: offset,
            windowLength: windowLength,
            gap: gap
        )
        offset &+= 1
    }

    @objc private func handleClick() {
        guard let event = currentEvent else { return }
        EventOpener.openInCalendar(event)
    }

    /// The visible slice of a scrolling marquee. Text that fits the window is
    /// shown as-is (no scroll); longer text wraps around through a gap so it
    /// reads continuously.
    static func marqueeFrame(
        _ text: String,
        offset: Int,
        windowLength: Int,
        gap: String
    ) -> String {
        let chars = Array(text)
        guard chars.count > windowLength else { return text }
        let padded = chars + Array(gap)
        let n = padded.count
        let start = ((offset % n) + n) % n
        var frame = String()
        frame.reserveCapacity(windowLength)
        for i in 0..<windowLength {
            frame.append(padded[(start + i) % n])
        }
        return frame
    }
}
