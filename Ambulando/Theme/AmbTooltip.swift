import SwiftUI
#if os(macOS)
import AppKit
#endif

/// UX lab tooltip. The system `.help` tooltip can't be styled (grey box, system font), so on the Mac this draws its
/// own: a raised, rounded label in the theme (Geist, soft border and shadow) shown after a short pause, below the
/// pointer, in a borderless panel so nothing clips it. Text may contain line breaks for short lists.
/// On iPhone and iPad it falls back to `.help` (no hover tooltips on touch). Both keep the text as an accessibility
/// hint.
extension View {
    func ambTooltip(_ text: String) -> some View { modifier(AmbTooltipModifier(text: text)) }
}

private struct AmbTooltipModifier: ViewModifier {
    let text: String
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            // Continuous hover: a redraw of a hovered parent (row highlight) can report "ended" once; the next pointer
            // move reports "active" again, so the tooltip recovers instead of silently cancelling.
            .onContinuousHover { phase in
                switch phase {
                case .active: if !text.isEmpty { AmbTooltipPanel.shared.schedule(text) }
                case .ended: AmbTooltipPanel.shared.hide(text)
                }
            }
            .onDisappear { AmbTooltipPanel.shared.hide(text) }
            .simultaneousGesture(TapGesture().onEnded { AmbTooltipPanel.shared.hide() })
            .accessibilityHint(text)
        #else
        content.help(text)
        #endif
    }
}

#if os(macOS)
@MainActor
private final class AmbTooltipPanel {
    static let shared = AmbTooltipPanel()
    private var panel: NSPanel?
    private var pending: DispatchWorkItem?
    private var shownText: String?
    private var pendingText: String?

    func schedule(_ text: String) {
        // Continuous hover calls this on every pointer move: keep the timer or the visible tooltip for the same text.
        if text == shownText || text == pendingText { return }
        pending?.cancel()
        pendingText = text
        // Moving between tooltips while one is showing switches straight away, as system tooltips do.
        let delay: TimeInterval = shownText == nil ? 0.6 : 0.05
        let work = DispatchWorkItem { [weak self] in self?.pendingText = nil; self?.show(text) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Hides the tooltip; with `text`, only if that tooltip is the one pending or showing (another view may own it).
    func hide(_ text: String? = nil) {
        if let text, text != shownText, text != pendingText { return }
        pending?.cancel(); pending = nil; pendingText = nil
        shownText = nil
        panel?.orderOut(nil)
    }

    private func show(_ text: String) {
        let appearance = NSApp.keyWindow?.effectiveAppearance ?? NSApp.effectiveAppearance
        let host = NSHostingView(rootView: AmbTooltipLabel(text: text))
        host.appearance = appearance
        let size = host.fittingSize
        let panel = self.panel ?? makePanel()
        panel.appearance = appearance
        panel.contentView = host
        // Below and slightly right of the pointer; flipped above it near the bottom of the screen.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }?.visibleFrame ?? .zero
        // The label sits 10pt inside the panel (shadow room), so offset by that.
        var origin = NSPoint(x: mouse.x - 8, y: mouse.y - 12 - size.height)
        if origin.y < screen.minY { origin.y = mouse.y + 6 }
        origin.x = min(max(origin.x, screen.minX + 4), screen.maxX - size.width - 4)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFront(nil)
        shownText = text
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        self.panel = panel
        return panel
    }
}

private struct AmbTooltipLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.amb(.caption))
            .foregroundStyle(Amb.foreground)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 280, alignment: .leading)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Amb.raised, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Amb.borderStrong, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
            .padding(10)   // room for the shadow inside the panel
    }
}
#endif
