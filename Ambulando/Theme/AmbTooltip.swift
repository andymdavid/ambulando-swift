import SwiftUI
#if os(macOS)
import AppKit
#endif

/// UX lab tooltip. The system `.help` tooltip can't be styled (grey box, system font), so on the Mac this draws its
/// own: a raised, rounded label in the theme (Geist, soft border and shadow) shown after a short pause, centred
/// under the hovered item, in a borderless panel so nothing clips it. Text may contain line breaks for short lists.
/// On iPhone and iPad it falls back to `.help` (no hover tooltips on touch). Both keep the text as an accessibility
/// hint.
extension View {
    func ambTooltip(_ text: String) -> some View { modifier(AmbTooltipModifier(text: text)) }
}

private struct AmbTooltipModifier: ViewModifier {
    let text: String
    #if os(macOS)
    @State private var anchor = AmbTooltipAnchor()
    #endif
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .background(AmbTooltipAnchorView(anchor: anchor))
            .onContinuousHover { phase in
                switch phase {
                case .active: if !text.isEmpty { AmbTooltipPanel.shared.schedule(text, anchor: anchor) }
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
/// Holds the hovered view's AppKit view so the tooltip can anchor to its frame, not the pointer.
@MainActor
final class AmbTooltipAnchor {
    weak var view: NSView?
    /// The view's frame on screen, or nil when it isn't in a window.
    var screenFrame: NSRect? {
        guard let view, let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }
}

private struct AmbTooltipAnchorView: NSViewRepresentable {
    let anchor: AmbTooltipAnchor
    func makeNSView(context: Context) -> NSView { let v = NSView(); anchor.view = v; return v }
    func updateNSView(_ nsView: NSView, context: Context) { anchor.view = nsView }
}

@MainActor
private final class AmbTooltipPanel {
    static let shared = AmbTooltipPanel()
    private var panel: NSPanel?
    private var pending: DispatchWorkItem?
    private var shownText: String?
    private var pendingText: String?
    private var watch: Timer?

    func schedule(_ text: String, anchor: AmbTooltipAnchor) {
        // Continuous hover calls this on every pointer move: keep the timer or the visible tooltip for the same text.
        if text == shownText || text == pendingText { return }
        pending?.cancel()
        pendingText = text
        // Moving between tooltips while one is showing switches straight away, as system tooltips do.
        let delay: TimeInterval = shownText == nil ? 0.6 : 0.05
        let work = DispatchWorkItem { [weak self] in self?.pendingText = nil; self?.show(text, anchor: anchor) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Hides the tooltip; with `text`, only if that tooltip is the one pending or showing (another view may own it).
    func hide(_ text: String? = nil) {
        if let text, text != shownText, text != pendingText { return }
        pending?.cancel(); pending = nil; pendingText = nil
        shownText = nil
        watch?.invalidate(); watch = nil
        panel?.orderOut(nil)
    }

    private func show(_ text: String, anchor: AmbTooltipAnchor) {
        // Only for the item still under the pointer: a missed "hover ended" must not leave a stray tooltip.
        guard let frame = anchor.screenFrame, frame.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) else { return }
        let appearance = anchor.view?.window?.effectiveAppearance ?? NSApp.effectiveAppearance
        let host = NSHostingView(rootView: AmbTooltipLabel(text: text))
        host.appearance = appearance
        let size = host.fittingSize
        let panel = self.panel ?? makePanel()
        panel.appearance = appearance
        panel.contentView = host
        // Centred under the item (the label sits 10pt inside the panel for its shadow); above it near the screen edge.
        let screen = NSScreen.screens.first { $0.frame.intersects(frame) }?.visibleFrame ?? frame
        var origin = NSPoint(x: frame.midX - size.width / 2, y: frame.minY - size.height + 4)
        if origin.y < screen.minY { origin.y = frame.maxY - 4 }
        origin.x = min(max(origin.x, screen.minX), screen.maxX - size.width)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFront(nil)
        shownText = text
        // Hide as soon as the pointer leaves the item, whether or not a hover-ended event arrives.
        watch?.invalidate()
        watch = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if anchor.screenFrame?.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) != true { self.hide() }
            }
        }
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
