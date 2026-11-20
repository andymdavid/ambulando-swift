import AmbulandoCore
import SwiftUI

/// UX lab (Phase 4): the Mac sidebar, laid out with the one `SidebarRow`. Same content and behaviour as the shared
/// `SidebarContent` (which the iPhone drawer and iPad keep): Home, Unread & Active, each scope with its channels, Manage
/// scopes and the workspace switcher. Several enabled workspaces still use the shared stacked navigation.
struct MacSidebarContent: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: SidebarSheet?
    /// A channel created in the New channel sheet, opened in Chat once the sheet has gone (as the web selects it).
    @State private var created: ChannelRecord?

    private func openCreated() {
        guard let channel = created else { return }
        created = nil
        model.selectContext(WorkContext(scopeId: channel.scopeId, channelId: channel.id))
        model.show(.chat)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Amb.SidebarLayout.rowSpacing) {
                    if model.enabledWorkspaceEntries.count > 1 {
                        StackedWorkspaceNavigation { entry, scope in
                            Task {
                                await model.activateWorkspace(entry)
                                guard entry.enabled, model.selectedWorkspaceBoundary == entry.boundary else { return }
                                sheet = .newChannel(scope)
                            }
                        }
                        if model.selectedWorkspace != nil { manageScopesRow(label: "Manage scopes in \(model.selectedWorkspace?.label ?? "workspace")") }
                    } else if let entry = model.enabledWorkspaceEntries.first, entry.collapsed {
                        SidebarRow(label: entry.workspace.label, identifier: "workspace.collapse.\(entry.workspace.label)",
                                   accessibilityLabel: "Expand \(entry.workspace.label)", action: { model.toggleWorkspaceCollapsed(entry) }) {
                            Image(systemName: "chevron.right").font(.amb(.caption2).weight(.semibold)).foregroundStyle(Amb.faint)
                        }
                    } else {
                        workspaceNavigation
                    }
                }
                .padding(.horizontal, Amb.SidebarLayout.gutter).padding(.vertical, 10)
            }
            WorkspaceFooter()
        }
        .onAppear { model.loadMembership() }
        .sheet(item: $sheet, onDismiss: openCreated) { sheet in
            switch sheet {
            case .newChannel(let scope): NewChannelSheet(scope: scope) { created = $0 }
            case .channelSettings(let channel): ChannelSettingsSheet(channelId: channel.id)
            case .manageScopes: ScopeManagementSheet()
            }
        }
    }

    @ViewBuilder private var workspaceNavigation: some View {
        let nav = model.navigation.value
        let context = model.context
        SidebarRow(label: "Home", selected: context.isHome, identifier: "sidebar.home", accessibilityLabel: "All workspace activity",
                   action: { model.chooseInSidebar(.home) }) {
            WorkspaceAvatar(label: model.selectedWorkspace?.label ?? "A", size: Amb.SidebarLayout.iconSlot)
        }

        NavigationStatus(state: model.navigationState, compact: true).padding(.top, 6)

        let unread = SidebarNavigation.unreadChannels(nav.groups, unreadChannelIds: nav.unread)
        if !unread.isEmpty {
            SidebarSectionHeading(text: "Unread & Active")
            // Own identities: the same channel is also listed under its scope below.
            ForEach(unread.map { ("unread:" + $0.id, $0) }, id: \.0) { _, channel in
                channelRow(channel, nav: nav, unread: true, level: 0, identifierPrefix: "sidebar.unread")
            }
        }

        SidebarSectionHeading(text: "Scopes")
        ForEach(nav.groups) { group in
            let collapsed = nav.collapsed.contains(group.id)
            let selected = context.scopeId == group.id && context.channelId == nil
            let canCreate = ManagementPermissions.canCreateChannel(in: group.scope, membership: model.membership)
            SidebarRow(label: group.scope.name, selected: selected, weight: .medium,
                       disclosure: .init(collapsed: collapsed, accessibilityLabel: "\(collapsed ? "Expand" : "Collapse") \(group.scope.name) channels",
                                         identifier: "sidebar.collapse.\(group.scope.name)") { model.toggleScopeCollapsed(group.id) },
                       hasRowAction: canCreate,
                       accessibilityLabel: "Open \(group.scope.name) home", identifier: "sidebar.scope.\(group.scope.name)",
                       action: { model.chooseInSidebar(WorkContext(scopeId: group.id)) },
                       leading: { EmptyView() }, status: { EmptyView() }) {
                // sol `.sidebar-scope-add-channel`: shown where the member may create channels in the scope.
                if canCreate {
                    SidebarRowButton(systemImage: "plus", accessibilityLabel: "Create channel in \(group.scope.name)",
                                     identifier: "sidebar.addChannel.\(group.scope.name)") { sheet = .newChannel(group.scope) }
                }
            }
            if !collapsed {
                if group.channels.isEmpty {
                    Text("No channels visible").font(.amb(.caption)).foregroundStyle(Amb.faint)
                        .padding(.leading, Amb.SidebarLayout.inset + Amb.SidebarLayout.indent).frame(minHeight: Amb.SidebarLayout.rowHeight)
                }
                ForEach(group.channels) { channel in
                    channelRow(channel, nav: nav, unread: nav.unread.contains(channel.id), level: 1, identifierPrefix: "sidebar.channel")
                }
            }
        }
        if !nav.groups.isEmpty { manageScopesRow(label: "Manage scopes").padding(.top, Amb.SidebarLayout.sectionGap / 2) }
    }

    /// One channel (sol `.sidebar-scope-channel-row`), with Channel settings as its hover action.
    private func channelRow(_ channel: ChannelRecord, nav: NavigationSnapshot, unread: Bool, level: Int, identifierPrefix: String) -> some View {
        let label = nav.label(channel)
        let settings = identifierPrefix == "sidebar.channel"
        return SidebarRow(label: label, selected: model.context.channelId == channel.id, unread: unread, level: level,
                          hasRowAction: settings, identifier: "\(identifierPrefix).\(label)",
                          action: { model.chooseInSidebar(WorkContext(scopeId: channel.scopeId, channelId: channel.id)) }) {
            if SidebarNavigation.isDirectMessageChannel(channel) {
                Image(systemName: "person.2").font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
            } else {
                Text("#").font(.amb(.subheadline)).foregroundStyle(Amb.mutedForeground)
            }
        } status: {
            if unread { SidebarUnreadDot() }
        } rowAction: {
            // sol `.sidebar-scope-channel-menu`: Channel settings on every channel (not repeated on Unread & Active).
            if settings {
                SidebarRowButton(systemImage: "ellipsis", accessibilityLabel: "Channel settings for \(label)",
                                 identifier: "sidebar.channelSettings.\(label)") { sheet = .channelSettings(channel) }
            }
        }
    }

    /// sol `.sidebar-manage-scopes-footer`.
    private func manageScopesRow(label: String) -> some View {
        SidebarRow(label: label, identifier: "sidebar.manageScopes", action: { sheet = .manageScopes }) {
            Image(systemName: "slider.horizontal.3").font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
        }
    }
}
