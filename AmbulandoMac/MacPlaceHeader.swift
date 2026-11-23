import AmbulandoCore
import SwiftUI

/// UX lab (Phase 4): the content header on the Mac. The sidebar says where you are; this names the place ("Ambulando /
/// # general", "Solo / Rick") and, under it, the views of that place (Deck, Chat, Tasks, Docs, Files). It replaces the
/// section bar across the top and the context strip under it. Toolbox, which has no place, has no tabs.
struct MacPlaceHeader: View {
    @Environment(AppModel.self) private var model
    @Environment(MacUI.self) private var ui
    let sections: [AppMode]

    private var tabs: [AppMode] { sections.filter { !$0.isPlaceless } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button { ui.sidebarVisible.toggle() } label: {
                    Image(systemName: "sidebar.left").frame(width: 28, height: 28).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(Amb.mutedForeground).ambHover()
                .ambTooltip(ui.sidebarVisible ? "Hide sidebar" : "Show sidebar")
                .accessibilityLabel(ui.sidebarVisible ? "Hide Sidebar" : "Show Sidebar")
                .accessibilityIdentifier("sidebar.toggle")
                crumb
                Spacer(minLength: 8)
                MacRefreshDataButton()
            }
            .padding(.leading, 8).padding(.trailing, 4)
            .frame(minHeight: 40)
            if showsTabs {
                HStack(spacing: 20) {
                    ForEach(tabs, id: \.self) { tab($0) }
                }
                .padding(.leading, Self.textInset)
                .accessibilityElement(children: .contain).accessibilityLabel("Sections").accessibilityIdentifier("section.bar")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Amb.background)
        .overlay(alignment: .bottom) { Rectangle().fill(Amb.border).frame(height: 0.5) }
    }

    /// Crumb and tabs share a left edge: after the 8pt inset, the 28pt sidebar button and the 8pt gap.
    private static let textInset: CGFloat = 44

    /// The open channel, when it's a direct message (Solo or with people).
    private var directMessage: ChannelRecord? {
        model.navigation.value.channel(model.context.channelId).flatMap { SidebarNavigation.isDirectMessageChannel($0) ? $0 : nil }
    }

    private var showsTabs: Bool { !model.mode.isPlaceless }

    @ViewBuilder private var crumb: some View {
        let nav = model.navigation.value
        HStack(spacing: 6) {
            if model.mode.isPlaceless {
                Text(model.mode.title).fontWeight(.semibold).foregroundStyle(Amb.foreground)
            } else if let dm = directMessage {
                Text(SoloDirectory.shared.contains(dm.id) ? "Solo" : "Direct messages").foregroundStyle(Amb.mutedForeground)
                Text("/").foregroundStyle(Amb.faint)
                Text(nav.label(dm)).fontWeight(.semibold).foregroundStyle(Amb.foreground)
            } else if let scope = nav.scope(model.context.scopeId) {
                if let channel = nav.channel(model.context.channelId) {
                    Text(scope.name).foregroundStyle(Amb.mutedForeground)
                    Text("/").foregroundStyle(Amb.faint)
                    Text("# " + nav.label(channel)).fontWeight(.semibold).foregroundStyle(Amb.foreground)
                } else {
                    Text(scope.name).fontWeight(.semibold).foregroundStyle(Amb.foreground)
                }
            } else {
                Text("Home").fontWeight(.semibold).foregroundStyle(Amb.foreground)
                Text(model.selectedWorkspace?.label ?? "").foregroundStyle(Amb.mutedForeground)
            }
        }
        .font(.amb(.subheadline)).lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("place.title")
    }

    private func tab(_ section: AppMode) -> some View {
        let selected = model.mode == section
        return Button {
            if selected { model.popToRoot(section) } else { model.show(section) }
        } label: {
            Text(section.title)
                .font(.amb(.subheadline).weight(selected ? .medium : .regular))
                .foregroundStyle(selected ? Amb.foreground : Amb.mutedForeground)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(selected ? Amb.foreground : Color.clear).frame(height: 2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("section.\(section.rawValue)")
    }
}

extension AppModel {
    /// UX lab (Mac): a place chosen in the sidebar keeps the current tab (Tasks stays Tasks, now for that place).
    /// Replaces the web's rule that a sidebar choice opens Deck unless the view is locked. Toolbox ignores the place,
    /// so choosing one from Toolbox opens its Deck.
    func choosePlace(_ next: WorkContext) {
        let destination: AppMode = mode.isPlaceless ? .deck : mode
        selectContext(next)
        if destination == .deck { deckPath = []; deckInboxRequests &+= 1 }
        mode = destination
    }
}
