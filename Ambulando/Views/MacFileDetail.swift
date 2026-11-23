import AmbulandoCore
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import PDFKit
import QuickLookThumbnailing
/// UX lab (round 7, layout A): the Mac file screen. The crumb row (‹ Files / #channel, ••• with the rest); the file's
/// badge, name and kind; Download, Quick Look and Open in <app>; then the file itself (`FilePreview`); the
/// properties in a rail at 900pt and wider (a grid under the name when narrower). The preview needs the file on this
/// Mac: up to 25 MB it is fetched on opening (the same checked download as Download, kept in the app's cache), above
/// that it waits for Show preview. iPhone and iPad keep `FileDetailView`'s list.
struct MacFileDetail: View {
    @Environment(AppModel.self) private var model
    let fileId: String
    let workspace: WorkspaceRecord
    let store: LocalStore

    @State private var snapshot = LiveQuery<MacFileSnapshot>(initial: MacFileSnapshot())
    /// The checked copy on this Mac, once fetched here (the stored snapshot only knows what was cached when it loaded).
    @State private var local: URL?
    @State private var loading = false
    @State private var previewError: String?
    @State private var quickLook: URL?
    @State private var downloadTask: Task<Void, Never>?
    @State private var downloading = false
    @State private var downloadError: String?
    @State private var savedDownload: URL?

    /// Files up to this size are fetched for the preview when the screen opens.
    static let autoPreviewBytes = 25 * 1024 * 1024
    private static let railWidth: CGFloat = 900

    private var cached: URL? { local ?? snapshot.value.cached }

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= Self.railWidth
            VStack(spacing: 0) {
                MacRecordCrumbs(place: place) {
                    if let file = snapshot.value.file {
                        NativeMessageActions(items: menu(file), identifier: "file.actions", label: "File actions", help: "More actions")
                            .frame(width: 28, height: 24)
                    }
                }
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        main(wide: wide)
                            .padding(.horizontal, 32).padding(.vertical, 20)
                            .frame(maxWidth: 900, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if wide, let file = snapshot.value.file {
                        Rectangle().fill(Amb.border).frame(width: 0.5)
                        ScrollView { rail(file).padding(20) }.frame(width: 280)
                    }
                }
            }
        }
        .background(Amb.background)
        .fixtureLabel()
        .navigationTitle(snapshot.value.file?.displayName ?? "File")
        .quickLookPreview($quickLook)
        .task { start() }
        .onChange(of: snapshot.value.file?.id) { _, _ in autoPreview() }
        .onDisappear { downloadTask?.cancel() }
    }

    private var place: String? {
        guard let file = snapshot.value.file, let channel = snapshot.value.choice.channelName(file.channelId) else { return nil }
        return "#\(channel)"
    }

    // MARK: Main column

    @ViewBuilder private func main(wide: Bool) -> some View {
        if let file = snapshot.value.file {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Text(FileKind.badge(file)).font(.amb(.caption2).weight(.semibold)).foregroundStyle(Amb.secondaryForeground)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(width: 40, height: 40)
                        .background(Amb.muted, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.displayName).font(Amb.editorial).foregroundStyle(Amb.foreground).textSelection(.enabled)
                            .accessibilityIdentifier("file.name")
                        Text([FileKind.word(file), byteLabel(file.sizeBytes)].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                    }
                }
                if let description = file.description, !description.isEmpty {
                    Text(description).font(.amb(.subheadline)).foregroundStyle(Amb.secondaryForeground).textSelection(.enabled)
                }
                if !wide { grid(file) }
                actions(file)
                preview(file)
            }
        } else if snapshot.loaded {
            SyncNote(text: "This file is not on this \(Device.name).")
        }
    }

    // MARK: Actions

    @ViewBuilder private func actions(_ file: FileRecord) -> some View {
        HStack(spacing: 8) {
            if downloading {
                ProgressView().controlSize(.small)
                Text("Downloading…").font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground)
                Button("Cancel") { downloadTask?.cancel() }.buttonStyle(.ambSecondary)
            } else {
                Button { beginDownload(file) } label: { Label(downloadError == nil ? "Download" : "Try again", systemImage: "arrow.down") }
                    .buttonStyle(.ambPrimary)
                    .disabled(!model.isUnlocked)
                    .accessibilityIdentifier("file.download")
                Button { if let cached { quickLook = cached } } label: { Label("Quick Look", systemImage: "eye") }
                    .buttonStyle(.ambSecondary)
                    .keyboardShortcut(.space, modifiers: [])
                    .disabled(cached == nil || !FileKind.previewable(file))
                    .ambTooltip("Quick Look (Space)")
                    .accessibilityIdentifier("file.preview")
                Button { openExternally(file) } label: { Label("Open in \(appName(file))", systemImage: "arrow.up.forward.app") }
                    .buttonStyle(.ambSecondary)
                    .disabled(cached == nil && !model.isUnlocked)
                    .accessibilityIdentifier("file.openExternally")
            }
        }
        if let savedDownload {
            HStack(spacing: 6) {
                Image(systemName: "checkmark").foregroundStyle(Amb.taskStatus("done"))
                Text("Saved \(savedDownload.lastPathComponent) to Downloads").accessibilityIdentifier("file.saved")
                Text("·").foregroundStyle(Amb.faint)
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([savedDownload]) }.buttonStyle(.plain)
                    .foregroundStyle(Amb.foreground).underline()
            }
            .font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground)
        }
        if let downloadError {
            Text(downloadError).font(.amb(.footnote)).foregroundStyle(Amb.destructive).accessibilityIdentifier("file.downloadError")
        }
        if !model.isUnlocked {
            Text("Unlock to download or preview this file.").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
        }
    }

    /// The ••• menu: what's left of the old screen's actions.
    private func menu(_ file: FileRecord) -> [NativeMessageAction] {
        var items: [NativeMessageAction] = []
        if let cached {
            items.append(NativeMessageAction("Save As…", "square.and.arrow.down") { MacFiles.saveCopy(of: cached, suggestedName: file.displayName) })
            items.append(NativeMessageAction("Share…", "square.and.arrow.up") { share(cached) })
        }
        items.append(NativeMessageAction("Copy reference", "link") { Pasteboard.copy(FileKind.reference(file)) })
        if let savedDownload {
            items.append(NativeMessageAction("Show in Finder", "folder") { NSWorkspace.shared.activateFileViewerSelecting([savedDownload]) })
        }
        return items
    }

    private func share(_ url: URL) {
        guard let window = NSApp.keyWindow, let view = window.contentView else { return }
        NSSharingServicePicker(items: [url]).show(relativeTo: CGRect(x: view.bounds.midX, y: view.bounds.maxY - 60, width: 1, height: 1),
                                                  of: view, preferredEdge: .minY)
    }

    /// The Mac's default app for this kind of file ("Preview", "TextEdit").
    private func appName(_ file: FileRecord) -> String {
        let app = cached.flatMap { NSWorkspace.shared.urlForApplication(toOpen: $0) }
            ?? FileKind.type(file).flatMap { NSWorkspace.shared.urlForApplication(toOpen: $0) }
        guard let app else { return "default app" }
        return FileManager.default.displayName(atPath: app.path).replacingOccurrences(of: ".app", with: "")
    }

    private func openExternally(_ file: FileRecord) {
        if let cached { NSWorkspace.shared.open(cached); return }
        fetch(file) { NSWorkspace.shared.open($0) }
    }

    // MARK: Preview

    @ViewBuilder private func preview(_ file: FileRecord) -> some View {
        let stage = RoundedRectangle(cornerRadius: Amb.radiusPanel, style: .continuous)
        Group {
            if !FileKind.previewable(file) {
                note(badge: FileKind.badge(file), "No preview for \(FileKind.word(file).lowercased()) files. Download it, then open it from Finder.")
            } else if let cached {
                FilePreview(url: cached)
                    .overlay(alignment: .bottomLeading) {
                        if let size = Self.pixelSize(cached) {
                            Text(size).font(.amb(.caption2)).foregroundStyle(Amb.faint).padding(10)
                        }
                    }
                    .accessibilityIdentifier("file.previewView")
            } else if loading {
                VStack(spacing: 10) { ProgressView().controlSize(.small); Text("Loading preview…") }
                    .font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
            } else if !model.isUnlocked {
                note(badge: FileKind.badge(file), "Unlock to preview this file.")
            } else if let previewError {
                VStack(spacing: 10) {
                    Text(previewError).font(.amb(.footnote)).foregroundStyle(Amb.destructive).multilineTextAlignment(.center)
                    Button("Try again") { fetch(file) { _ in } }.buttonStyle(.ambSecondary)
                }
            } else {
                VStack(spacing: 10) {
                    badgeView(FileKind.badge(file))
                    Button("Show preview") { fetch(file) { _ in } }.buttonStyle(.ambSecondary).accessibilityIdentifier("file.showPreview")
                    Text("Downloads \(byteLabel(file.sizeBytes)) to this Mac first.").font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320, maxHeight: 520)
        .background(Amb.canvas, in: stage)
        .clipShape(stage)
        .overlay(stage.stroke(Amb.border, lineWidth: 1))
    }

    private func note(badge: String, _ text: String) -> some View {
        VStack(spacing: 10) {
            badgeView(badge)
            Text(text).font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground).multilineTextAlignment(.center).frame(maxWidth: 280)
        }
    }

    private func badgeView(_ text: String) -> some View {
        Text(text).font(.amb(.footnote).weight(.semibold)).foregroundStyle(Amb.secondaryForeground)
            .frame(width: 60, height: 60)
            .background(Amb.muted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    static func pixelSize(_ url: URL) -> String? {
        guard let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
              let rep = NSImageRep(contentsOf: url), rep.pixelsWide > 0 else { return nil }
        return "\(rep.pixelsWide) × \(rep.pixelsHigh) px"
    }

    /// Up to 25 MB, the preview is fetched when the screen opens.
    private func autoPreview() {
        guard let file = snapshot.value.file, cached == nil, model.isUnlocked, FileKind.previewable(file),
              (file.sizeBytes ?? Int.max) <= Self.autoPreviewBytes else { return }
        fetch(file) { _ in }
    }

    /// The checked copy, from the cache or Tower (the same route as Download).
    private func fetch(_ file: FileRecord, then: @escaping (URL) -> Void) {
        guard !loading else { return }
        loading = true
        previewError = nil
        Task { @MainActor in
            defer { loading = false }
            do {
                let url = try await model.fileForExport(file, in: workspace)
                local = url
                then(url)
            } catch is CancellationError {
            } catch {
                previewError = "Couldn't load the preview: \(error.localizedDescription)"
            }
        }
    }

    // MARK: Properties

    private func rail(_ file: FileRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Properties").font(.amb(.footnote).weight(.semibold)).foregroundStyle(Amb.mutedForeground)
            ForEach(properties(file), id: \.0) { name, value in
                if name.isEmpty {
                    Rectangle().fill(Amb.border).frame(height: 0.5)
                } else {
                    HStack(alignment: .center, spacing: 10) {
                        Text(name).font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground).frame(width: 82, alignment: .leading)
                        value
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func grid(_ file: FileRecord) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            ForEach(Array(properties(file).filter { !$0.0.isEmpty }.prefix(4).enumerated()), id: \.offset) { _, property in
                GridRow {
                    Text(property.0).font(.amb(.footnote)).foregroundStyle(Amb.mutedForeground)
                    property.1
                }
            }
        }
    }

    /// Kind, Size, Channel, Folder; who uploaded it (only when Tower says), when; the checksum. "" is a divider.
    private func properties(_ file: FileRecord) -> [(String, AnyView)] {
        func plain(_ text: String, mono: Bool = false) -> AnyView {
            AnyView(Text(text).font(mono ? .amb(.caption, design: .monospaced) : .amb(.footnote)).foregroundStyle(Amb.secondaryForeground)
                .lineLimit(1).textSelection(.enabled))
        }
        var out: [(String, AnyView)] = [("Kind", plain(FileKind.word(file)))]
        if let size = file.sizeBytes { out.append(("Size", plain(byteLabel(size)))) }
        if let place { out.append(("Channel", plain(place))) }
        out.append(("Folder", plain(snapshot.value.folder ?? "None")))
        out.append(("", AnyView(EmptyView())))
        if let uploader = snapshot.value.uploader {
            out.append(("Uploaded by", AnyView(HStack(spacing: 6) {
                PersonAvatar(person: snapshot.value.people.person(uploader), size: 18, agent: snapshot.value.people.isAgent(uploader))
                Text(snapshot.value.people.name(uploader))
            }.font(.amb(.footnote)).foregroundStyle(Amb.secondaryForeground))))
        }
        out.append(("Uploaded", plain(ChatTime.label(file.createdAt))))
        out.append(("Updated", plain(ChatTime.label(file.updatedAt))))
        if let sha = file.sha256, sha.count > 12 {
            out.append(("", AnyView(EmptyView())))
            out.append(("Checksum", plain("\(sha.prefix(4)) \(sha.dropFirst(4).prefix(4)) … \(sha.suffix(4))", mono: true)))
        }
        return out
    }

    // MARK: Download (as the shared screen: a checked copy into Downloads)

    private func beginDownload(_ file: FileRecord) {
        guard !downloading else { return }
        downloading = true
        downloadError = nil
        savedDownload = nil
        downloadTask = Task { @MainActor in
            defer { downloading = false; downloadTask = nil }
            let operation = Task { try await model.fileForExport(file, in: workspace) }
            let deadline = Task { try? await Task.sleep(for: .seconds(120)); if !Task.isCancelled { operation.cancel() } }
            defer { deadline.cancel() }
            do {
                let source = try await withTaskCancellationHandler { try await operation.value } onCancel: { operation.cancel() }
                try Task.checkCancellation()
                local = source
                let destination = try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                savedDownload = try await Task.detached { try DownloadCopy.save(source, name: file.displayName, directory: destination) }.value
            } catch is CancellationError {
                downloadError = "Download cancelled or timed out. Try again."
            } catch {
                downloadError = "Couldn't download: \(error.localizedDescription)"
            }
        }
    }

    private func start() {
        let w = workspace.id, id = fileId, store = store, cache = model.fileCache
        snapshot.start(store: store, matches: { ($0.workspaceId == w && [.files, .channels, .folders, .members].contains($0.table)) || $0.table == .profiles }) {
            let file = try await store.reader.file(workspaceId: w, id: id)
            var value = MacFileSnapshot(file: file, cached: file.flatMap { cache?.cached($0) }, choice: try await scopeChoice(store, w))
            if let file, let folder = file.folderId {
                value.folder = try await store.reader.folders(workspaceId: w, channelId: file.channelId).first { $0.id == folder }?.title
            }
            value.uploader = file.flatMap(MacFileSnapshot.uploader)
            value.people = try await store.reader.people(workspaceId: w)
            return value
        }
    }
}

struct MacFileSnapshot: Sendable, Equatable {
    var file: FileRecord?
    var cached: URL?
    var choice = ScopeChoice()
    var folder: String?
    var uploader: String?
    var people = PeopleDirectory()

    /// Who uploaded the file, only when Tower's record names them (the app has no other source).
    static func uploader(_ file: FileRecord) -> String? {
        guard let o = try? JSONSerialization.jsonObject(with: file.raw) as? [String: Any] else { return nil }
        for key in ["created_by_actor_npub", "created_by_npub", "uploaded_by_npub"] {
            if let npub = o[key] as? String, !npub.isEmpty { return npub }
        }
        return nil
    }
}

/// The file drawn inline: an image on a checkerboard (so transparency shows), a PDF's pages, the text of a text, CSV or
/// code file with line numbers, or else the system's Quick Look thumbnail (video, Office and iWork files). Quick Look's
/// own inline view (`QLPreviewView`) draws blank when hosted in SwiftUI, so the common kinds are drawn here.
private struct FilePreview: View {
    let url: URL
    @State private var thumbnail: NSImage?
    @State private var text: [String]?

    private var type: UTType? { UTType(filenameExtension: url.pathExtension) }

    var body: some View {
        Group {
            if let type, type.conforms(to: .image), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                    .frame(maxWidth: min(image.size.width, 640), maxHeight: min(image.size.height, 440))
                    .padding(14).background(Checkerboard()).clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .padding(28)
            } else if let type, type.conforms(to: .pdf) {
                PDFPreview(url: url)
            } else if let text {
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(text.enumerated()), id: \.offset) { index, line in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("\(index + 1)").foregroundStyle(Color(white: 0.6)).frame(width: 28, alignment: .trailing)
                                Text(line.isEmpty ? " " : line).foregroundStyle(Color(white: 0.11)).textSelection(.enabled)
                            }
                        }
                    }
                    .font(.amb(.caption, design: .monospaced))
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .padding(24)
            } else if let thumbnail {
                Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fit).frame(maxWidth: 420, maxHeight: 400).padding(28)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let type else { return }
        if type.conforms(to: .image) || type.conforms(to: .pdf) { return }
        if [.text, .sourceCode, .json, .commaSeparatedText, .xml, .yaml].contains(where: type.conforms) {
            let url = url
            text = await Task.detached {
                guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return [String]() }
                let head = String(decoding: data.prefix(256 * 1024), as: UTF8.self)
                return Array(head.components(separatedBy: .newlines).prefix(2000))
            }.value
            return
        }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 420, height: 400), scale: 2, representationTypes: .thumbnail)
        if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail = rep.nsImage }
    }
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 7
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            for row in 0..<Int(size.height / cell) + 1 {
                for column in 0..<Int(size.width / cell) + 1 where (row + column) % 2 == 0 {
                    context.fill(Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)),
                                 with: .color(Color(white: 0.91)))
                }
            }
        }
    }
}

private struct PDFPreview: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        return view
    }
    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url { view.document = PDFDocument(url: url) }
    }
}

extension FileKind {
    /// Whether Quick Look can draw it: images, PDFs, text and code, audio and video, documents, spreadsheets, slides.
    /// Archives, apps and disk images can't be previewed.
    static func previewable(_ file: FileRecord) -> Bool {
        guard let type = type(file) else { return false }
        if [.archive, .executable, .diskImage, .application].contains(where: type.conforms) { return false }
        return [.image, .pdf, .text, .audiovisualContent, .presentation, .spreadsheet, .compositeContent, .rtf, .json]
            .contains(where: type.conforms)
    }
}
#endif
