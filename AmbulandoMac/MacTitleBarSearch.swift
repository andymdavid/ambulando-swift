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
                Text("⌘F").font(.amb(.caption)).foregroundStyle(Amb.faint)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Amb.border))
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
            guard let window, let titlebar = window.standardWindowButton(.closeButton)?.superview,
                  !titlebar.subviews.contains(where: { $0.identifier == Self.id }) else { return }
            let host = NSHostingView(rootView: MacTitleBarSearch(action: action).appTextSize())
            host.identifier = Self.id
            host.translatesAutoresizingMaskIntoConstraints = false
            titlebar.addSubview(host)
            NSLayoutConstraint.activate([
                host.centerXAnchor.constraint(equalTo: titlebar.centerXAnchor),
                host.centerYAnchor.constraint(equalTo: titlebar.centerYAnchor),
            ])
        }

        static let id = NSUserInterfaceItemIdentifier("ux.titlebar.search")
    }
}
