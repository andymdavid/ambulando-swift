import AmbulandoCore
import AppKit
import SwiftUI

/// UX lab (Mac): Search as a command menu, as Ari's ⌘K. One field over the window; before you type it lists where to go
/// and what to do, and as you type it narrows those and adds places by name and the stored tasks, documents, files and
/// messages that match (the same local full-text search as the iPhone's Search). ↑↓ move, ↵ opens, Esc closes.
struct MacCommandMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(MacUI.self) private var ui
    @AppStorage("appearance") private var appearance = AppearancePreference.system.rawValue
    @AppStorage(AppMode.agentsPreference) private var showAgents = false
    @AppStorage(AppMode.contextPreference) private var showContext = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""
    @State private var hits: [SearchHit] = []
    @State private var selection = 0
    @State private var keys: Any?
    @FocusState private var focused: Bool

    struct Item: Identifiable {
        let id: String
        let icon: String
        let label: String
        var hint: String? = nil
        var place: String? = nil
        var keys: [String] = []
        let run: () -> Void
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black.opacity(0.4).ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { close() }
                    .accessibilityHidden(true)
                panel
                    .frame(width: min(620, geometry.size.width - 32))
                    .padding(.top, geometry.size.height * 0.18)
            }
        }
        .onAppear {
            focused = true
            if let text = Self.labRequest { query = text }
            keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { handle($0) ? nil : $0 }
        }
        .onDisappear { if let keys { NSEvent.removeMonitor(keys) } }
        .task(id: query) { await search() }
        .onChange(of: query) { _, _ in selection = 0 }
    }

    private var panel: some View {
        let groups = self.groups
        let flat = groups.flatMap(\.1)
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Amb.mutedForeground)
                TextField("Type a command or search…", text: $query)
                    .textFieldStyle(.plain).font(.amb(.body)).focused($focused)
                    .accessibilityIdentifier("command.field")
            }
            .padding(.horizontal, 14).frame(height: 48)
            Rectangle().fill(Amb.border).frame(height: 0.5)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if flat.isEmpty {
                            Text(ConversationSearch.active(query) ? "No results for “\(query)”." : "No matching commands.")
                                .font(.amb(.subheadline)).foregroundStyle(Amb.mutedForeground)
                                .frame(maxWidth: .infinity).padding(.vertical, 28)
                        }
                        ForEach(groups, id: \.0) { title, items in
                            Text(title).font(.amb(.caption).weight(.medium)).foregroundStyle(Amb.faint)
                                .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 4)
                            ForEach(items) { item in
                                let index = flat.firstIndex { $0.id == item.id } ?? 0
                                row(item, selected: index == selection).id(item.id)
                                    .onHover { if $0 { selection = index } }
                                    .onTapGesture { run(item) }
                            }
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 360)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: selection) { _, index in
                    if flat.indices.contains(index) { proxy.scrollTo(flat[index].id) }
                }
            }
        }
        .background(Amb.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Amb.borderStrong, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        .accessibilityElement(children: .contain).accessibilityIdentifier("command.menu")
    }

    private func row(_ item: Item, selected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon).font(.amb(.subheadline)).foregroundStyle(Amb.mutedForeground).frame(width: 18)
            Text(item.label).font(.amb(.subheadline)).foregroundStyle(Amb.foreground).lineLimit(1).layoutPriority(1)
            if let hint = item.hint, !hint.isEmpty {
                Text(hint).font(.amb(.caption)).foregroundStyle(Amb.faint).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let place = item.place { Text(place).font(.amb(.caption)).foregroundStyle(Amb.faint).lineLimit(1).fixedSize() }
            if !item.keys.isEmpty {
                HStack(spacing: 3) { ForEach(item.keys, id: \.self) { Keycap(text: $0) } }
            }
        }
        .padding(.horizontal, 8).frame(height: 36)
        .background(selected ? Amb.selectedFill : Color.clear, in: RoundedRectangle(cornerRadius: Amb.radiusControl, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("command.item")
    }

    // MARK: Items

    private var groups: [(String, [Item])] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let matches: (Item) -> Bool = { q.isEmpty || $0.label.localizedStandardContains(q) }
        var out: [(String, [Item])] = []
        let go = goTo.filter(matches), places = q.isEmpty ? [] : self.places.filter(matches), actions = self.actions.filter(matches)
        if !go.isEmpty { out.append(("Go to", go)) }
        if !places.isEmpty { out.append(("Places", Array(places.prefix(8)))) }
        if !actions.isEmpty { out.append(("Actions", actions)) }
        for (kind, title) in [(SearchHit.Kind.task, "Tasks"), (.doc, "Documents"), (.file, "Files"), (.message, "Messages")] {
            let rows = hits.filter { $0.kind == kind }.map(item)
            if !rows.isEmpty { out.append((title, rows)) }
        }
        return out
    }

    private var goTo: [Item] {
        var items = [Item(id: "go.home", icon: "house", label: "Home", hint: "All workspace activity", keys: ["⇧", "⌘", "H"]) {
            model.choosePlace(.home)
        }, Item(id: "go.activity", icon: AppMode.activity.systemImage, label: AppMode.activity.title, hint: "What needs you, and work in progress") {
            model.show(.activity)
        }]
        for (index, section) in AppMode.visible(agents: showAgents, context: showContext).enumerated() {
            items.append(Item(id: "go.\(section.rawValue)", icon: section.systemImage, label: section.title,
                              keys: index < 9 ? ["⌘", "\(index + 1)"] : []) { model.show(section) })
        }
        return items
    }

    /// Scopes and channels by name (DMs by the people in them), opened as the sidebar opens them.
    private var places: [Item] {
        let nav = model.navigation.value
        var items: [Item] = []
        for group in nav.groups {
            if !group.isDirectMessages {
                items.append(Item(id: "place.\(group.id)", icon: "square.stack", label: group.scope.name, hint: "Scope") {
                    model.choosePlace(WorkContext(scopeId: group.id))
                })
            }
            for channel in group.channels {
                let dm = SidebarNavigation.isDirectMessageChannel(channel)
                items.append(Item(id: "place.\(channel.id)", icon: dm ? "person.2" : "number", label: nav.label(channel),
                                  hint: dm ? "Direct message" : group.scope.name) {
                    model.choosePlace(WorkContext(scopeId: channel.scopeId, channelId: channel.id))
                })
            }
        }
        return items
    }

    private var actions: [Item] {
        let dark = colorScheme == .dark
        return [
            Item(id: "do.thread", icon: "square.and.pencil", label: "New thread") {
                model.show(.chat)
                DispatchQueue.main.async { model.composingThread = true }
            },
            Item(id: "do.task", icon: "checkmark.circle", label: "New task") { compose("task", in: .tasks) },
            Item(id: "do.doc", icon: "doc.badge.plus", label: "New document") { compose("doc", in: .docs) },
            Item(id: "do.notifications", icon: "bell", label: "Notifications", keys: ["⇧", "⌘", "N"]) { ui.showNotifications = true },
            Item(id: "do.settings", icon: "gearshape", label: "Settings", keys: ["⌘", ","]) { ui.showSettings = true },
            Item(id: "do.theme", icon: dark ? "sun.max" : "moon", label: dark ? "Switch to light theme" : "Switch to dark theme") {
                appearance = (dark ? AppearancePreference.light : .dark).rawValue
            },
        ]
    }

    private func compose(_ kind: String, in section: AppMode) {
        model.popToRoot(section)
        model.show(section)
        UXComposeRequest.shared.pending = kind
    }

    private func item(_ hit: SearchHit) -> Item {
        let icon = switch hit.kind {
        case .task: "checkmark.circle"
        case .doc: "doc.text"
        case .file: "paperclip"
        case .message: "bubble.left"
        }
        let label = hit.kind == .message ? hit.snippet : hit.title
        let hint = hit.kind == .message ? hit.title : (hit.kind == .file ? nil : hit.snippet)
        return Item(id: hit.id, icon: icon, label: label, hint: hint, place: place(hit)) { open(hit) }
    }

    private func place(_ hit: SearchHit) -> String? {
        let nav = model.navigation.value
        return nav.channel(hit.channelId).map { "#" + nav.label($0) }
    }

    private func open(_ hit: SearchHit) {
        switch hit.kind {
        case .task: model.openRecord(kind: "task", id: hit.recordId)
        case .doc: model.openRecord(kind: "doc", id: hit.recordId)
        case .file: model.openRecord(kind: "file", id: hit.recordId)
        case .message:
            if let channel = hit.channelId { model.openInChat(channelId: channel, threadId: hit.threadId) }
        }
    }

    /// UX lab (sample app only): `-UXCommand <text>` opens the menu at launch with that text typed, for captures.
    static var labRequest: String? {
        FixtureEnvironment.requested ? UserDefaults.standard.string(forKey: "UXCommand") : nil
    }

    // MARK: Behaviour

    private func run(_ item: Item) {
        close()
        item.run()
    }

    private func close() { ui.showSearch = false }

    /// Arrow keys, Return and Escape while the menu is open (the text field would otherwise take the arrows).
    private func handle(_ event: NSEvent) -> Bool {
        let flat = groups.flatMap(\.1)
        switch event.keyCode {
        case 125: if !flat.isEmpty { selection = min(selection + 1, flat.count - 1) }; return true   // ↓
        case 126: selection = max(selection - 1, 0); return true                                      // ↑
        case 36, 76: if flat.indices.contains(selection) { run(flat[selection]) }; return true         // ↵
        case 53: close(); return true                                                                  // Esc
        default: return false
        }
    }

    /// Debounced; a slower earlier query never replaces a newer one (the task is cancelled when the query changes).
    private func search() async {
        guard ConversationSearch.active(query), let workspace = model.selectedWorkspace?.id, let store = model.store else { hits = []; return }
        let text = query
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
        let found = (try? await store.reader.search(workspaceId: workspace, text: text, limit: 40)) ?? []
        guard !Task.isCancelled else { return }
        hits = found
    }
}
