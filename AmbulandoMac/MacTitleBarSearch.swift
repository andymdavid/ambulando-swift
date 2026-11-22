import SwiftUI

/// UX lab: Search as a field centred in the window's title bar (as Ari), not an icon among the others. It opens the
/// same Search sheet as ⌘F, which it shows as its hint.
struct MacTitleBarSearch: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(Amb.mutedForeground)
                Text("Search or jump to…").foregroundStyle(Amb.mutedForeground)
                Spacer(minLength: 8)
                HStack(spacing: 3) { Keycap(text: "⌘"); Keycap(text: "K") }
            }
            .font(.amb(.footnote))
            .padding(.horizontal, 10)
            .frame(width: 360, height: 28)
            .background(Amb.background, in: RoundedRectangle(cornerRadius: Amb.radiusControl, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Amb.radiusControl, style: .continuous).stroke(Amb.border))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search").accessibilityIdentifier("search")
    }
}

/// Puts `MacTitleBarSearch` in the middle of the window's title bar, once per window. SwiftUI's `.principal` and
/// `.navigation` toolbar items (and a toolbar search field) never reach this window's toolbar, so the field is an
/// AppKit hosting view centred in the title bar, under the same theme and text size.
struct MacTitleBarSearchInstaller: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> NSView { Probe(action: action) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class Probe: NSView {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action; super.init(frame: .zero) }
        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // The title bar's container, above the toolbar view: the toolbar's title area spans the whole bar and
            // would otherwise take the click.
            guard let window, let titlebar = window.standardWindowButton(.closeButton)?.superview?.superview,
                  !titlebar.subviews.contains(where: { $0.identifier == Self.id }) else { return }
            let host = ClickableHost(rootView: AnyView(MacTitleBarSearch(action: action).appTextSize()))
            host.identifier = Self.id
            host.translatesAutoresizingMaskIntoConstraints = false
            titlebar.addSubview(host, positioned: .above, relativeTo: nil)
            NSLayoutConstraint.activate([
                host.centerXAnchor.constraint(equalTo: titlebar.centerXAnchor),
                host.centerYAnchor.constraint(equalTo: titlebar.centerYAnchor),
            ])
        }

        static let id = NSUserInterfaceItemIdentifier("ux.titlebar.search")
    }

    /// The title bar treats a press as the start of a window drag; this host keeps presses for its button, and takes
    /// the first click even when the window isn't key.
    private final class ClickableHost: NSHostingView<AnyView> {
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }
}

/// One key of a shortcut, drawn as a small keycap (as Ari's ⌘ K).
struct Keycap: View {
    let text: String
    var body: some View {
        Text(text).font(.amb(.caption2).weight(.medium)).foregroundStyle(Amb.mutedForeground)
            .frame(minWidth: 18, minHeight: 18)
            .background(Amb.background, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Amb.border))
    }
}
