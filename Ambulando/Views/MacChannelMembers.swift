import AmbulandoCore
import SwiftUI

#if os(macOS)
/// UX lab (Mac, round 6.6): who has access to a channel, by the channel's New thread. The faces are up to three people
/// with access and the total (the last answer Tower gave, saved as the channel access page saves it); clicking opens a
/// Members popover to add people, agents or groups, change their access, or remove them. Same calls to Tower as the
/// channel access page (`channelGrants`, `.channelGrant`, `.revokeChannelGrant`), with the same authority check.
/// A DM shows its two people: Tower fixes a DM's participants.
struct ChannelMembersButton: View {
    @Environment(AppModel.self) private var model
    let channelId: String
    let workspace: WorkspaceRecord
    let people: PeopleDirectory
    @State private var saved = LiveQuery<ChannelMembersSaved>(initial: ChannelMembersSaved())
    @State private var open = false

    private var channel: ChannelRecord? { model.navigation.value.channel(channelId) }
    private var direct: Bool { channel.map(SidebarNavigation.isDirectMessageChannel) ?? false }
    private var name: String { channel.map { model.navigation.value.label($0) } ?? "channel" }

    /// The people shown as faces: a DM's participants, else people with access.
    private var faces: [String] {
        if direct, let channel { return SidebarNavigation.participants(channel) }
        return saved.value.entries.filter { $0.type == "actor" }.compactMap(\.npub)
    }
    private var count: Int { direct ? faces.count : saved.value.entries.count }

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 6) {
                if faces.isEmpty {
                    Image(systemName: "person.2").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                } else {
                    HStack(spacing: -6) {
                        ForEach(Array(faces.prefix(3)), id: \.self) { npub in
                            PersonAvatar(person: people.person(npub), size: 22, agent: people.isAgent(npub))
                                .overlay(Circle().stroke(Amb.background, lineWidth: 1.5))
                        }
                    }
                }
                if saved.loaded, count > 0 || direct {
                    Text("\(count)").font(.amb(.footnote).weight(.medium)).foregroundStyle(Amb.secondaryForeground).monospacedDigit()
                } else if faces.isEmpty {
                    Text("Members").font(.amb(.footnote).weight(.medium)).foregroundStyle(Amb.secondaryForeground)
                }
            }
            .padding(.horizontal, 6).frame(height: 28).contentShape(Rectangle())
        }
        .buttonStyle(.plain).ambHover()
        .ambTooltip("Members of #\(name)")
        .accessibilityLabel("Members of #\(name)").accessibilityIdentifier("channel.members")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            ChannelMembersPopover(channelId: channelId, workspace: workspace, people: people, saved: saved.value, direct: direct, name: name)
        }
        .task(id: channelId) {
            start()
            // UX lab (sample app only): `-UXMembers <text>` opens the popover at launch with that text typed, for captures.
            if Self.labQuery != nil { try? await Task.sleep(for: .seconds(1.5)); open = true }
        }
    }

    static var labQuery: String? { FixtureEnvironment.requested ? UserDefaults.standard.string(forKey: "UXMembers") : nil }

    private func start() {
        guard let store = model.store, let connection = model.connection?.id else { return }
        let w = workspace.id, c = channelId
        saved.start(store: store, matches: { $0.table == .appState || $0.table == .access }) {
            try await ChannelMembersSaved.load(store: store, connection: connection, workspace: w, channel: c)
        }
    }
}

/// The channel's access as last saved on this Mac: its grants, read against the workspace's people and groups.
struct ChannelMembersSaved: Sendable, Equatable {
    var entries: [ChannelMemberEntry] = []
    var directory: [AdministrationRow] = []
    var groups: [AdministrationRow] = []

    static func key(connection: String, workspace: String, channel: String) -> String {
        "admin.channel-grants.v1:\(connection):\(workspace):\(channel)"
    }

    static func load(store: LocalStore, connection: String, workspace: String, channel: String) async throws -> ChannelMembersSaved {
        let directory = try await store.reader.administrationRows(connection: connection, workspace: workspace, list: .members)
        let groups = try await store.reader.administrationRows(connection: connection, workspace: workspace, list: .groups)
        var grants: [AdministrationRow] = []
        if let raw = try await store.reader.state(key(connection: connection, workspace: workspace, channel: channel)) {
            grants = (try? JSONDecoder().decode([AdministrationRow].self, from: Data(raw.utf8))) ?? []
        }
        return ChannelMembersSaved(entries: grants.map { ChannelMemberEntry($0, directory: directory, groups: groups) }
                                       .sorted { ($0.rank, $0.name.lowercased()) < ($1.rank, $1.name.lowercased()) },
                                   directory: directory, groups: groups)
    }
}

/// One grant, named: a person or agent (with their npub when known) or a group.
struct ChannelMemberEntry: Sendable, Equatable, Identifiable {
    let row: AdministrationRow
    let type: String
    let principalId: String
    let name: String
    let npub: String?
    let agent: Bool
    /// view, contribute, manage or custom.
    let access: String
    var id: String { "\(type):\(principalId)" }
    /// Managers first, then posters, then viewers.
    var rank: Int { ["manage": 0, "contribute": 1, "view": 2][access] ?? 3 }

    init(_ row: AdministrationRow, directory: [AdministrationRow], groups: [AdministrationRow]) {
        let fields = row.fields
        let kind = fields["principal_type"] ?? "actor", principal = fields["principal_id"] ?? row.id
        self.row = row
        type = kind
        principalId = principal
        access = fields["access_level"] ?? "custom"
        if kind == "group" {
            let group = groups.first { $0.id == principal }
            name = fields["display_name"] ?? fields["name"] ?? group?.title ?? "Group"
            npub = nil; agent = false
        } else {
            let person = directory.first { $0.fields["actor_id"] == principal || ($0.fields["npub"] != nil && $0.fields["npub"] == fields["npub"]) }
            let key = fields["npub"] ?? person?.fields["npub"]
            npub = key
            let known = fields["display_name"] ?? person?.fields["display_name"] ?? person?.fields["name"]
            name = known ?? key.map { String($0.prefix(12)) + "…" } ?? "Someone"
            agent = (fields["kind"] ?? person?.fields["kind"]) == "agent"
        }
    }

    static func label(_ access: String) -> String {
        switch access {
        case "view": "Can view"
        case "contribute": "Can post"
        case "manage": "Can manage"
        default: "Custom"
        }
    }
}

private struct ChannelMembersPopover: View {
    @Environment(AppModel.self) private var model
    let channelId: String
    let workspace: WorkspaceRecord
    let people: PeopleDirectory
    let saved: ChannelMembersSaved
    let direct: Bool
    let name: String
    @State private var canManage = false
    @State private var checked = false
    @State private var query = ""
    @State private var addAs = "contribute"
    @State private var groups: [AdministrationRow] = []
    @State private var removing: String?
    @State private var working: String?
    @State private var error: String?
    @FocusState private var adding: Bool

    private var me: String? { model.connection?.signerNpub }
    private var everyone: [ChannelMemberEntry] { saved.entries.filter { $0.type != "group" } }
    private var groupEntries: [ChannelMemberEntry] { saved.entries.filter { $0.type == "group" } }
    private var allGroups: [AdministrationRow] { groups.isEmpty ? saved.groups : groups }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Members").font(.amb(.headline)).foregroundStyle(Amb.foreground)
                Text(direct ? "in this conversation" : "\(saved.entries.count) with access to #\(name)")
                    .font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                Spacer()
                if working != nil { ProgressView().controlSize(.small) }
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)
            if !direct && canManage { addField }
            Rectangle().fill(Amb.border).frame(height: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if direct { directList } else if !query.isEmpty && canManage { suggestions } else { list }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 340).fixedSize(horizontal: false, vertical: true)
            if let error {
                Text(error).font(.amb(.caption)).foregroundStyle(Amb.destructive).padding(.horizontal, 14).padding(.bottom, 8)
            }
            if model.membership?.isAdmin == true, !direct { footer }
        }
        .frame(width: 380)
        .background(Amb.raised)
        .task {
            if let text = ChannelMembersButton.labQuery, !text.isEmpty { query = text }
            if !direct { await refresh() }
        }
    }

    // MARK: Adding

    private var addField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus").font(.amb(.caption).weight(.semibold)).foregroundStyle(Amb.mutedForeground)
            TextField("Add people, agents or a group…", text: $query)
                .textFieldStyle(.plain).font(.amb(.footnote)).focused($adding)
                .onSubmit { if let first = candidates.first { add(first) } }
                .accessibilityIdentifier("members.add")
            Menu {
                ForEach(["view", "contribute", "manage"], id: \.self) { level in Button(ChannelMemberEntry.label(level)) { addAs = level } }
            } label: {
                Text("as \(ChannelMemberEntry.label(addAs).lowercased())").font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
            }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .ambTooltip("Access for people you add")
        }
        .padding(.horizontal, 10).frame(height: 30)
        .overlay(RoundedRectangle(cornerRadius: Amb.radiusControl).stroke(adding ? Amb.borderStrong : Amb.border))
        .padding(.horizontal, 14).padding(.bottom, 10)
    }

    private struct Candidate: Identifiable {
        let type: String, id: String, name: String, npub: String?, agent: Bool, detail: String
    }

    /// People, agents and groups in the workspace, leaving out anyone already in.
    private var candidates: [Candidate] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let inside = Set(saved.entries.map(\.principalId)), insideNpubs = Set(saved.entries.compactMap(\.npub))
        let people: [Candidate] = saved.directory.compactMap { row in
            guard let id = row.fields["actor_id"], !inside.contains(id), !(row.fields["npub"].map(insideNpubs.contains) ?? false) else { return nil }
            let agent = row.fields["kind"] == "agent"
            return Candidate(type: "actor", id: id, name: row.title, npub: row.fields["npub"], agent: agent, detail: agent ? "agent" : (row.fields["role"] ?? "member"))
        }
        let groups: [Candidate] = allGroups.filter { !inside.contains($0.id) }.map {
            Candidate(type: "group", id: $0.id, name: $0.title, npub: nil, agent: false, detail: "group · \($0.children.count == 1 ? "1 person" : "\($0.children.count) people")")
        }
        return (people + groups).filter { $0.name.localizedStandardContains(q) || ($0.npub?.localizedStandardContains(q) ?? false) }.prefix(8).map { $0 }
    }

    @ViewBuilder private var suggestions: some View {
        if candidates.isEmpty {
            Text("No one in this workspace matches “\(query)”.").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                .padding(.horizontal, 14).padding(.vertical, 10)
        }
        ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
            Button { add(candidate) } label: {
                HStack(spacing: 10) {
                    if candidate.type == "group" { groupMark } else { avatar(candidate.npub, agent: candidate.agent) }
                    Text(candidate.name).font(.amb(.subheadline)).foregroundStyle(Amb.foreground).lineLimit(1)
                    Text(candidate.detail).font(.amb(.caption)).foregroundStyle(Amb.faint)
                    Spacer(minLength: 8)
                    if index == 0 { Keycap(text: "↵") }
                }
                .padding(.horizontal, 14).frame(height: 36).contentShape(Rectangle())
            }
            .buttonStyle(.plain).ambHover(radius: 0)
            .accessibilityIdentifier("members.candidate")
        }
        Text("From this workspace").font(.amb(.caption)).foregroundStyle(Amb.faint).padding(.horizontal, 14).padding(.top, 6)
    }

    // MARK: List

    @ViewBuilder private var list: some View {
        if saved.entries.isEmpty {
            Text(checked ? "No one has been given access to #\(name) yet." : "Asking Tower…")
                .font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground).padding(.horizontal, 14).padding(.vertical, 10)
        }
        ForEach(everyone) { entry in row(entry) }
        if !groupEntries.isEmpty {
            Text("Groups").font(.amb(.caption).weight(.medium)).foregroundStyle(Amb.faint)
                .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)
            ForEach(groupEntries) { entry in row(entry) }
        }
        if checked && !canManage {
            Text("Ask someone who can manage #\(name) to add people.").font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
                .padding(.horizontal, 14).padding(.top, 8)
        }
    }

    private func row(_ entry: ChannelMemberEntry) -> some View {
        HStack(spacing: 10) {
            if entry.type == "group" { groupMark } else { avatar(entry.npub, agent: entry.agent) }
            Text(entry.name).font(.amb(.subheadline)).foregroundStyle(Amb.foreground).lineLimit(1)
            if entry.npub != nil, entry.npub == me { Text("you").font(.amb(.caption)).foregroundStyle(Amb.faint) }
            if entry.agent { Text("agent").font(.amb(.caption)).foregroundStyle(Amb.faint) }
            Spacer(minLength: 8)
            if removing == entry.id {
                Button("Remove") { remove(entry) }.buttonStyle(.ambGhost).foregroundStyle(Amb.destructive)
                    .ambTooltip("Other grants may still give access").accessibilityIdentifier("members.remove.confirm")
                Button("Keep") { removing = nil }.buttonStyle(.ambGhost)
            } else if canManage && entry.access != "custom" {
                Menu {
                    ForEach(["view", "contribute", "manage"], id: \.self) { level in
                        Button { change(entry, to: level) } label: {
                            if level == entry.access { Label(ChannelMemberEntry.label(level), systemImage: "checkmark") } else { Text(ChannelMemberEntry.label(level)) }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(ChannelMemberEntry.label(entry.access))
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                    }
                    .font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground)
                }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                .accessibilityIdentifier("members.access")
                Button { removing = entry.id } label: { Image(systemName: "xmark").font(.amb(.caption2).weight(.semibold)) }
                    .buttonStyle(.plain).foregroundStyle(Amb.mutedForeground)
                    .ambRevealOnHover()
                    .ambTooltip("Remove access").accessibilityLabel("Remove \(entry.name)")
            } else {
                Text(ChannelMemberEntry.label(entry.access)).font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                    .ambTooltip(entry.access == "custom" ? "Custom permissions set on the web; change them there" : "")
            }
        }
        .padding(.horizontal, 14).frame(height: 38)
        .ambHoverRow(radius: 0)
    }

    @ViewBuilder private var directList: some View {
        let participants = model.navigation.value.channel(channelId).map(SidebarNavigation.participants) ?? []
        ForEach(participants, id: \.self) { npub in
            HStack(spacing: 10) {
                avatar(npub, agent: people.isAgent(npub))
                Text(people.person(npub).name).font(.amb(.subheadline)).foregroundStyle(Amb.foreground).lineLimit(1)
                if npub == me { Text("you").font(.amb(.caption)).foregroundStyle(Amb.faint) }
                Spacer()
            }
            .padding(.horizontal, 14).frame(height: 38)
        }
        Text("A direct message keeps the people it started with.").font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
            .padding(.horizontal, 14).padding(.top, 6)
    }

    private var footer: some View {
        HStack {
            Text("New to the workspace? Add them in Workspace settings first.").font(.amb(.caption)).foregroundStyle(Amb.faint)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(Amb.border).frame(height: 0.5) }
    }

    private func avatar(_ npub: String?, agent: Bool) -> some View {
        PersonAvatar(person: people.person(npub), size: 24, agent: agent)
    }

    private var groupMark: some View {
        Image(systemName: "person.3").font(.amb(.caption)).foregroundStyle(Amb.mutedForeground)
            .frame(width: 24, height: 24).background(Amb.muted, in: Circle())
    }

    // MARK: Tower

    private func add(_ candidate: Candidate) {
        query = ""
        run("Adding \(candidate.name)…", .channelGrant(channel: channelId, principalType: candidate.type, principal: candidate.id, access: addAs, update: false))
        adding = true
    }

    private func change(_ entry: ChannelMemberEntry, to level: String) {
        guard level != entry.access else { return }
        run("Saving…", .channelGrant(channel: channelId, principalType: entry.type, principal: entry.principalId, access: level, update: true))
    }

    private func remove(_ entry: ChannelMemberEntry) {
        removing = nil
        run("Removing…", .revokeChannelGrant(channel: channelId, principalType: entry.type, principal: entry.principalId))
    }

    private func run(_ label: String, _ command: AdministrationCommand) {
        guard let manager = model.manager, let connection = model.connection, model.selectedWorkspace?.id == workspace.id else { return }
        working = label; error = nil
        Task {
            do { try await manager.administer(connection, workspace, command: command) }
            catch { self.error = ((error as? ManagementError)?.errorDescription) ?? error.localizedDescription }
            await refresh()
        }
    }

    /// Asks Tower who has access (saved for the faces), and whether you may change it, as the channel access page does.
    private func refresh() async {
        guard let manager = model.manager, let connection = model.connection, let store = model.store else { return }
        defer { working = nil; checked = true }
        do {
            let fresh = try await manager.membership(connection, workspace)
            let rows = try await manager.channelGrants(connection, workspace, channel: channelId)
            if saved.directory.isEmpty { try? await manager.refreshAdministration(connection, workspace, list: .members) }
            if let channel = model.navigation.value.channel(channelId),
               let access = try? await manager.scopeAccess(connection, workspace, scope: channel.scopeId) { groups = access.groups }
            let knownGroups = groups.isEmpty ? ((try? await store.reader.administrationRows(connection: connection.id, workspace: workspace.id, list: .groups)) ?? []) : groups
            canManage = AdministrationAuthority.canManageChannelGrants(membership: fresh, grants: rows, groups: knownGroups, npub: connection.signerNpub)
        } catch {
            canManage = false
            self.error = ((error as? ManagementError)?.errorDescription) ?? "Tower didn't answer. Showing the last saved list."
        }
    }
}
#endif
