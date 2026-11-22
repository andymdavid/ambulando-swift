import AmbulandoCore
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit

/// UX lab (Mac, round 6.1): Files as a table, the same as Tasks and Docs: search, sort and group in the toolbar; a labels
/// row (Name, Kind, Size, Channel, Updated); group rows; one-line files with a type badge and a ••• menu that
/// right-click repeats. Folders sit first in their channel and open in place, as Finder's list view. No tick boxes:
/// Tower has no archive, move or rename for files, so there would be nothing to do in bulk.
struct MacFileList: View {
    @Environment(AppModel.self) private var model
    @Environment(\.pushRoute) private var pushRoute
    let workspace: WorkspaceRecord
    let snapshot: FilesSnapshot
    let search: String
    let sort: MacFileSort
    let grouping: MacFileGrouping
    @Binding var sortBinding: MacFileSort
    @AppStorage("files.list.collapsed.v1") private var collapsedList = ""
    @AppStorage("files.list.openFolders.v1") private var openList = ""
    @State private var preview: URL?
    @State private var notice: String?

    private var showsChannel: Bool { model.context.channelId == nil }
    private var searching: Bool { !search.trimmingCharacters(in: .whitespaces).isEmpty }
    /// Names sit past a group's chevron, so a row reads as inside its group.
    private var nameIndent: CGFloat { grouping == .none ? 0 : 24 }

    /// The table's width, measured: Channel, then Kind, then Size give way so the name keeps its room.
    @State private var width: CGFloat = 0
    private enum Column: Hashable { case kind, size, channel, updated }
    private static let kindColumn: CGFloat = 110
    private static let sizeColumn: CGFloat = 96
    /// Size is right-aligned and Channel left-aligned: a gap keeps "48 bytes" off "#general".
    private static let sizeGap: CGFloat = 20
    private var columns: Set<Column> {
        var all: [(Column, CGFloat)] = [(.kind, Self.kindColumn), (.size, Self.sizeColumn)]
        if showsChannel { all.append((.channel, Amb.ListLayout.placeColumn)) }
        all.append((.updated, Amb.ListLayout.timeColumn))
        return AmbTable.fitting(all, dropOrder: [.channel, .kind, .size], width: width, titleIndent: max(nameIndent - 16, 0))
    }

    var body: some View {
        VStack(spacing: 0) {
            columnLabels
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if grouping != .channel { ForEach(snapshot.uploads) { uploadRow($0) } }
                    ForEach(groups) { group in
                        if grouping != .none {
                            AmbTableGroupRow(id: group.id, title: group.title, count: group.count, closed: collapsed.contains(key(group)),
                                             toggle: { toggle(group) }) { group.mark }
                        }
                        if grouping == .none || !collapsed.contains(key(group)) {
                            if grouping == .channel {
                                ForEach(snapshot.uploads.filter { $0.string("channel_id") == group.id }) { uploadRow($0) }
                            }
                            ForEach(group.entries) { entry in
                                switch entry {
                                case .folder(let folder, let files): folderRow(folder, files: files)
                                case .file(let file, let folder, let nested): fileRow(file, folder: folder, nested: nested)
                                }
                            }
                        }
                    }
                    if groups.isEmpty, searching {
                        Text("No files match “\(search)”.").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                }
                .padding(.bottom, Amb.Space.xl)
            }
        }
        .overlay(alignment: .bottom) {
            if let notice {
                Text(notice).font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Amb.raised, in: Capsule()).overlay(Capsule().stroke(Amb.border))
                    .padding(.bottom, Amb.Space.l)
                    .task(id: notice) { try? await Task.sleep(for: .seconds(4)); self.notice = nil }
            }
        }
        .quickLookPreview($preview)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .clipped()
    }

    // MARK: Columns

    private var columnLabels: some View {
        HStack(spacing: Amb.ListLayout.rowGap) {
            HStack(spacing: 0) {
                Color.clear.frame(width: nameIndent, height: 1)
                sortLabel("Name", .name)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if columns.contains(.kind) { sortLabel("Kind", .kind).frame(width: Self.kindColumn, alignment: .leading) }
            if columns.contains(.size) {
                HStack(spacing: 0) { Spacer(minLength: 0); sortLabel("Size", .size) }.padding(.trailing, Self.sizeGap).frame(width: Self.sizeColumn)
            }
            if columns.contains(.channel) { Text("Channel").frame(width: Amb.ListLayout.placeColumn, alignment: .leading) }
            if columns.contains(.updated) {
                HStack(spacing: 0) { Spacer(minLength: 0); sortLabel("Updated", .updated) }.frame(width: Amb.ListLayout.timeColumn)
            }
            Color.clear.frame(width: Amb.ListLayout.actionColumn, height: 1)
        }
        .font(.amb(.footnote).weight(.medium)).foregroundStyle(Amb.mutedForeground)
        .padding(.leading, AmbTable.gutter).padding(.trailing, Amb.ListLayout.trailing)
        .frame(height: 32)
        .overlay(alignment: .bottom) { Rectangle().fill(Amb.border).frame(height: 1) }
    }

    private func sortLabel(_ title: String, _ value: MacFileSort) -> some View {
        Button { sortBinding = value } label: {
            HStack(spacing: 3) {
                Text(title)
                if sort == value { Image(systemName: value.ascending ? "arrow.up" : "arrow.down").font(.amb(.caption2)) }
            }
            .foregroundStyle(sort == value ? Amb.foreground : Amb.mutedForeground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ambTooltip("Sort by \(title.lowercased())")
        .accessibilityIdentifier("files.sort.\(value.rawValue)")
    }

    // MARK: Groups

    private func matches(_ file: FileRecord) -> Bool {
        let q = search.trimmingCharacters(in: .whitespaces)
        return q.isEmpty || file.displayName.localizedStandardContains(q)
    }

    private var groups: [MacFileGroup] {
        let folderById = Dictionary(snapshot.groups.flatMap { $0.folders.map(\.folder) }.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        func flat(_ files: [FileRecord]) -> [MacFileEntry] {
            files.filter(matches).sorted(by: ordered).map { .file($0, folder: $0.folderId.flatMap { folderById[$0] }, nested: false) }
        }
        switch grouping {
        case .channel:
            return snapshot.groups.compactMap { group in
                let name = snapshot.choice.channelName(group.channel.id) ?? "Channel"
                let all = group.loose + group.folders.flatMap(\.files)
                var entries: [MacFileEntry]
                if searching {
                    // While searching, a file inside a folder is listed with the rest and says which folder.
                    entries = flat(all)
                } else {
                    entries = []
                    for (folder, files) in group.folders.sorted(by: { $0.folder.title.localizedStandardCompare($1.folder.title) == .orderedAscending }) {
                        entries.append(.folder(folder, files: files))
                        if openFolders.contains(folder.id) {
                            entries += files.sorted(by: ordered).map { .file($0, folder: folder, nested: true) }
                        }
                    }
                    entries += group.loose.sorted(by: ordered).map { .file($0, folder: nil, nested: false) }
                }
                guard !entries.isEmpty else { return nil }
                return MacFileGroup(id: group.channel.id, title: name, count: searching ? entries.count : all.count, entries: entries,
                                    mark: AnyView(Text("#").font(.amb(.subheadline)).foregroundStyle(Amb.faint)))
            }
        case .kind:
            let files = snapshot.groups.flatMap { $0.loose + $0.folders.flatMap(\.files) }.filter(matches)
            let byKind = Dictionary(grouping: files) { FileKind.word($0) }
            return byKind.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { kind in
                let entries = flat(byKind[kind] ?? [])
                return MacFileGroup(id: kind, title: kind, count: entries.count, entries: entries,
                                    mark: AnyView(Image(systemName: "doc").font(.amb(.caption)).foregroundStyle(Amb.faint)))
            }
        case .none:
            let entries = flat(snapshot.groups.flatMap { $0.loose + $0.folders.flatMap(\.files) })
            return entries.isEmpty ? [] : [MacFileGroup(id: "all", title: "All", count: entries.count, entries: entries, mark: AnyView(EmptyView()))]
        }
    }

    private func ordered(_ a: FileRecord, _ b: FileRecord) -> Bool {
        switch sort {
        case .updated: a.updatedAt > b.updatedAt
        case .name: a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
        case .size: (a.sizeBytes ?? 0) > (b.sizeBytes ?? 0)
        case .kind:
            FileKind.word(a) == FileKind.word(b)
                ? a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
                : FileKind.word(a).localizedStandardCompare(FileKind.word(b)) == .orderedAscending
        }
    }

    private var collapsed: Set<String> { Set(collapsedList.split(separator: ",").map(String.init)) }
    private func key(_ group: MacFileGroup) -> String { "\(grouping.rawValue):\(group.id)" }
    private func toggle(_ group: MacFileGroup) {
        var set = collapsed
        if set.contains(key(group)) { set.remove(key(group)) } else { set.insert(key(group)) }
        collapsedList = set.sorted().joined(separator: ",")
    }

    private var openFolders: Set<String> { Set(openList.split(separator: ",").map(String.init)) }
    private func toggleFolder(_ id: String) {
        var set = openFolders
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        openList = set.sorted().joined(separator: ",")
    }

    // MARK: Rows

    private func folderRow(_ folder: FolderRecord, files: [FileRecord]) -> some View {
        let open = openFolders.contains(folder.id)
        return HStack(spacing: Amb.ListLayout.rowGap) {
            Button { toggleFolder(folder.id) } label: {
                HStack(spacing: Amb.ListLayout.rowGap) {
                    HStack(spacing: Amb.Space.s) {
                        Image(systemName: open ? "chevron.down" : "chevron.right").font(.amb(.caption2).weight(.semibold))
                            .foregroundStyle(Amb.mutedForeground).frame(width: 12)
                        Image(systemName: open ? "folder.fill" : "folder").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                            .frame(width: 30)
                        Text(folder.title).font(.amb(.body)).foregroundStyle(Amb.foreground).lineLimit(1)
                        Text("\(files.count)").font(.amb(.footnote)).foregroundStyle(Amb.faint).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if columns.contains(.kind) { Text("Folder").lineLimit(1).frame(width: Self.kindColumn, alignment: .leading) }
                    if columns.contains(.size) { Color.clear.frame(width: Self.sizeColumn, height: 1) }
                    if columns.contains(.channel) { channelCell(folder.channelId) }
                    if columns.contains(.updated) {
                        HStack(spacing: 0) { Spacer(minLength: 0); MessageTimeText(iso: folder.updatedAt) }.frame(width: Amb.ListLayout.timeColumn)
                    }
                }
                .font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground)
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(open ? "Close" : "Open") folder \(folder.title)")
            .accessibilityIdentifier("folder.\(folder.title)")
            Color.clear.frame(width: Amb.ListLayout.actionColumn, height: 1)
        }
        .padding(.leading, AmbTable.gutter + nameIndent - 20).padding(.trailing, Amb.ListLayout.trailing)
        .frame(minHeight: Amb.ListLayout.rowHeight)
        .modifier(AmbTableRule())
    }

    private func fileRow(_ file: FileRecord, folder: FolderRecord?, nested: Bool) -> some View {
        HStack(spacing: Amb.ListLayout.rowGap) {
            WorkRecordLink(route: WorkRoute.file(workspaceId: workspace.id, fileId: file.id)) {
                HStack(spacing: Amb.ListLayout.rowGap) {
                    HStack(spacing: Amb.Space.s) {
                        FileBadge(text: FileKind.badge(file))
                        Text(file.displayName).font(.amb(.body)).foregroundStyle(Amb.foreground).lineLimit(1)
                        if let folder, !nested {
                            Text("in \(folder.title)").font(.amb(.footnote)).foregroundStyle(Amb.faint).lineLimit(1).fixedSize()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if columns.contains(.kind) { Text(FileKind.word(file)).lineLimit(1).frame(width: Self.kindColumn, alignment: .leading) }
                    if columns.contains(.size) {
                        HStack(spacing: 0) { Spacer(minLength: 0); Text(byteLabel(file.sizeBytes)).lineLimit(1).monospacedDigit() }
                            .padding(.trailing, Self.sizeGap).frame(width: Self.sizeColumn)
                    }
                    if columns.contains(.channel) { channelCell(file.channelId) }
                    if columns.contains(.updated) {
                        HStack(spacing: 0) { Spacer(minLength: 0); MessageTimeText(iso: file.updatedAt) }.frame(width: Amb.ListLayout.timeColumn)
                    }
                }
                .font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground)
            }
            .accessibilityIdentifier("file.\(file.displayName)")
            NativeMessageActions(items: actions(file), identifier: "file.actions.\(file.displayName)", label: "File actions", help: "More actions")
                .frame(width: Amb.ListLayout.actionColumn, height: 24)
                .ambRevealOnHover()
        }
        .padding(.leading, AmbTable.gutter + nameIndent + (nested ? 26 : 0)).padding(.trailing, Amb.ListLayout.trailing)
        .frame(minHeight: Amb.ListLayout.rowHeight)
        .modifier(AmbTableRule())
        .contextMenu { AmbTableMenuItems(items: actions(file)) }
    }

    private func channelCell(_ id: String) -> some View {
        Text(snapshot.choice.channelName(id).map { "#\($0)" } ?? "").lineLimit(1)
            .frame(width: Amb.ListLayout.placeColumn, alignment: .leading)
    }

    /// An upload still on its way: its name, and its progress where Updated sits.
    private func uploadRow(_ item: WriteItem) -> some View {
        HStack(spacing: Amb.ListLayout.rowGap) {
            HStack(spacing: Amb.Space.s) {
                Image(systemName: "arrow.up.doc").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground).frame(width: 30)
                Text(item.string("display_name") ?? "File").font(.amb(.body)).foregroundStyle(Amb.foreground).lineLimit(1)
            }
            Spacer(minLength: 0)
            WriteStatusLine(item: item, label: "Upload")
        }
        .padding(.leading, AmbTable.gutter + nameIndent).padding(.trailing, Amb.ListLayout.trailing)
        .frame(minHeight: Amb.ListLayout.rowHeight)
        .modifier(AmbTableRule())
        .accessibilityIdentifier("upload.row")
    }

    /// One file's ••• and right-click menu.
    private func actions(_ file: FileRecord) -> [NativeMessageAction] {
        var items = [NativeMessageAction("Open", "arrow.up.right.square") { pushRoute(WorkRoute.file(workspaceId: workspace.id, fileId: file.id)) }]
        if let url = model.fileCache?.cached(file) {
            items.append(NativeMessageAction("Quick Look", "eye") { preview = url })
        }
        if model.isUnlocked {
            items.append(NativeMessageAction("Download", "arrow.down.circle") { download(file) })
        }
        items.append(NativeMessageAction("Copy reference", "link") { Pasteboard.copy(FileKind.reference(file)) })
        return items
    }

    /// The same download as the file's screen: a checked copy in Downloads, then shown in Finder.
    private func download(_ file: FileRecord) {
        notice = "Downloading \(file.displayName)…"
        Task { @MainActor in
            do {
                let source = try await model.fileForExport(file, in: workspace)
                let destination = try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                let saved = try await Task.detached { try DownloadCopy.save(source, name: file.displayName, directory: destination) }.value
                notice = "Saved \(saved.lastPathComponent) to Downloads."
                NSWorkspace.shared.activateFileViewerSelecting([saved])
            } catch {
                notice = "Could not download \(file.displayName). Try again from its screen."
            }
        }
    }
}

enum MacFileEntry: Identifiable {
    case folder(FolderRecord, files: [FileRecord])
    case file(FileRecord, folder: FolderRecord?, nested: Bool)
    var id: String {
        switch self {
        case .folder(let folder, _): "folder:\(folder.id)"
        case .file(let file, _, _): "file:\(file.id)"
        }
    }
}

struct MacFileGroup: Identifiable {
    let id: String
    let title: String
    let count: Int
    let entries: [MacFileEntry]
    let mark: AnyView
}

enum MacFileSort: String, CaseIterable {
    case updated, name, size, kind
    var label: String { rawValue.capitalized }
    var ascending: Bool { self == .name || self == .kind }
}

enum MacFileGrouping: String, CaseIterable {
    case channel, kind, none
    var label: String { rawValue.capitalized }
}

/// The Files toolbar: search, sort and group, as Tasks' and Docs'.
struct MacFileListControls: View {
    @Binding var search: String
    @Binding var sort: MacFileSort
    @Binding var grouping: MacFileGrouping

    var body: some View {
        HStack(spacing: Amb.Space.m) {
            AmbTableSearchField(prompt: "Search files", text: $search, identifier: "files.search")
            AmbTableToolbarMenu(symbol: "arrow.up.arrow.down", title: "Sort", values: MacFileSort.allCases, label: \.label,
                                selection: $sort, identifier: "files.sort")
            AmbTableToolbarMenu(symbol: "rectangle.grid.1x2", title: "Group", values: MacFileGrouping.allCases, label: \.label,
                                selection: $grouping, identifier: "files.group")
        }
    }
}

/// A small type badge before a file's name ("PNG", "CSV"), in place of a coloured icon.
private struct FileBadge: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 8.5, weight: .semibold)).foregroundStyle(Amb.mutedForeground)
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(width: 30, height: 16)
            .background(Amb.muted, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// How the table names a file's type.
enum FileKind {
    private static func type(_ file: FileRecord) -> UTType? {
        if let mime = file.contentType, let type = UTType(mimeType: mime) { return type }
        let ext = (file.displayName as NSString).pathExtension
        return ext.isEmpty ? nil : UTType(filenameExtension: ext)
    }

    /// A plain word for the Kind column: "PNG image", "Plain text".
    static func word(_ file: FileRecord) -> String {
        guard let description = type(file)?.localizedDescription, !description.isEmpty else {
            let ext = (file.displayName as NSString).pathExtension
            return ext.isEmpty ? "File" : ext.uppercased() + " file"
        }
        return description.prefix(1).uppercased() + description.dropFirst()
    }

    /// The badge: the file's extension, at most four letters.
    static func badge(_ file: FileRecord) -> String {
        let ext = (file.displayName as NSString).pathExtension
        let text = ext.isEmpty ? (type(file)?.preferredFilenameExtension ?? "file") : ext
        return String(text.uppercased().prefix(4))
    }

    /// A reference to paste into a message or document, as Copy reference on a document.
    static func reference(_ file: FileRecord) -> String {
        let label = file.displayName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "[", with: "\\[")
        return "@[\(label)](mention:file:\(file.id))"
    }
}
#endif
