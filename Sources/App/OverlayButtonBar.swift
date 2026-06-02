import SwiftUI
import CalendarCore

/// The reminder actions the floating button bar can perform. PLAN.md §Overlays:
/// «Отложить / Закрыть / Открыть / Подключиться (Meet/Zoom — парсим из события)».
enum OverlayAction {
    case snooze, dismiss, openInCalendar, connect
}

/// Carries the button bar's frame (SwiftUI global coords, top-left origin) up to
/// the overlay host. The host hands it to ``OverlayWindow`` so *exactly* that
/// region captures clicks while the rest of the surface stays click-through.
struct ButtonBarFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Phase 4 (#9): a standard floating control bar drawn on top of *any* skin
/// ("плавающий слой кнопок поверх любого скина"). These buttons are the only
/// click-catching part of the overlay; the surrounding surface passes clicks
/// through to the app behind — ``OverlayWindow`` toggles that based on the
/// reported bar frame.
struct OverlayButtonBar: View {
    let event: CalEvent
    /// Accent resolved from the event's `ColorKey` (color-as-key).
    var accent: Color = .accentColor
    let perform: (OverlayAction) -> Void

    var body: some View {
        bar
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ButtonBarFrameKey.self,
                        value: proxy.frame(in: .global)
                    )
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 96)
    }

    /// Individual pills, each styled like the reminder card itself — Liquid Glass
    /// tinted by the event's accent with the same accent stroke — so the controls
    /// and the window read as one design. Labels use the primary label color for
    /// contrast; the primary "Подключиться" action is filled with the accent.
    private var bar: some View {
        HStack(spacing: 12) {
            // Only offered when the event actually carries a meeting link.
            if event.videoLink != nil {
                barButton("Подключиться", systemImage: "video.fill",
                          prominent: true) { perform(.connect) }
            }
            barButton("Открыть", systemImage: "calendar") { perform(.openInCalendar) }
            barButton("Отложить", systemImage: "clock.arrow.circlepath") { perform(.snooze) }
            barButton("Закрыть", systemImage: "xmark") { perform(.dismiss) }
        }
        .fixedSize()
    }

    private func barButton(
        _ title: String, systemImage: String, prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background {
                    if prominent {
                        // Primary action: accent fill on the same glass base.
                        Capsule().fill(accent).glassEffect(.regular, in: Capsule())
                    } else {
                        // Same material language as the reminder card.
                        Capsule()
                            .fill(.clear)
                            .glassEffect(.regular.tint(accent.opacity(0.18)), in: Capsule())
                    }
                }
                .overlay(Capsule().stroke(accent.opacity(0.45), lineWidth: 1.5))
                .contentShape(Capsule())
                .shadow(radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }
}
