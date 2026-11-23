import AmbulandoCore
import AppKit
import SwiftUI

/// One detached window per identity/connection/workspace/app/document boundary.
/// Reader-mode pop-outs reuse the existing document UI; editing begins within its owning window.
@MainActor
@Observable
final class MacDocumentWindows {
    static let shared = MacDocumentWindows()
    struct Key: Hashable {
        let signer: String
        let connection: String
        let workspace: String
        let app: String
        let document: String
    }
    var detached: Set<Key> = []
    @ObservationIgnored var sessions: [Key: MacDocumentSession] = [:]

    func key(_ model: AppModel, workspace: WorkspaceRecord, docId: String) -> Key? {
        guard let connection = model.connection else { return nil }
        return Key(signer: connection.signerNpub, connection: connection.id, workspace: workspace.id,
                   app: workspace.appNpub, document: docId)
    }
}

struct MacDocumentSurface: View {
    @Environment(AppModel.self) private var model
    let docId: String
    let workspace: WorkspaceRecord
    let store: LocalStore
    @State private var session: MacDocumentSession?
    @State private var surfaceId = UUID()
    /// The document's channel, for the crumb row.
    @State private var place: String?

    var body: some View {
        Group {
            if let session {
                if MacDocumentWindows.shared.detached.contains(session.key) {
                    ContentUnavailableView {
                        Label("Document is open in its own window", systemImage: "macwindow")
                    } actions: {
                        Button("Show Document Window") { Task { await session.show() } }
                            .accessibilityIdentifier("doc.window.focus")
                    }
                } else {
                    // UX lab: the record's crumb row in the main window (a document window has no back). Esc stays
                    // with the editor.
                    VStack(spacing: 0) {
                        MacRecordCrumbs(place: place, escape: false) {
                            PinToggleButton(type: .document, id: docId, workspace: workspace).buttonStyle(.plain).ambTooltip("Pin to Deck")
                        }
                        DocumentView(docId: docId, workspace: workspace, store: store)
                            .environment(\.macDocumentSession, session)
                    }
                }
            } else { ProgressView() }
        }
        .task(id: docId) {
            let channel = try? await store.reader.doc(workspaceId: workspace.id, id: docId)?.channelId
            place = model.navigation.value.channel(channel).map { "#" + model.navigation.value.label($0) }
        }
        .task {
            guard !Task.isCancelled, let key = MacDocumentWindows.shared.key(model, workspace: workspace, docId: docId) else { return }
            let registry = MacDocumentWindows.shared
            let found = registry.sessions[key] ?? MacDocumentSession(key: key, model: model, workspace: workspace, store: store)
            registry.sessions[key] = found
            found.surfaces.insert(surfaceId)
            session = found
        }
        .onDisappear {
            if let session {
                session.surfaces.remove(surfaceId)
                if session.window == nil && session.surfaces.isEmpty {
                    session.beforeClose = nil
                    MacDocumentWindows.shared.sessions[session.key] = nil
                }
            }
        }
    }
}

@MainActor
@Observable
final class MacDocumentSession: NSObject, NSWindowDelegate {
    let key: MacDocumentWindows.Key
    let model: AppModel
    let workspace: WorkspaceRecord
    let store: LocalStore
    var window: NSWindow?
    @ObservationIgnored var beforeClose: (@MainActor () async -> Bool)?
    var closing = false
    var editingSurfaces: Set<UUID> = []
    var surfaces: Set<UUID> = []
    var retired = false
    @ObservationIgnored var host: NSHostingView<AnyView>?

    init(key: MacDocumentWindows.Key, model: AppModel, workspace: WorkspaceRecord, store: LocalStore) {
        self.key = key; self.model = model; self.workspace = workspace; self.store = store
        super.init()
    }

    func show() async {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        guard !closing, editingSurfaces.isEmpty else { return }
        closing = true
        let allowed = await beforeClose?() ?? true
        closing = false
        guard allowed else { return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 800),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 640, height: 480)
        window.title = "Document — \(workspace.label)"
        window.delegate = self
        self.window = window
        retired = false
        MacDocumentWindows.shared.sessions[key] = self
        MacDocumentWindows.shared.detached.insert(key)
        let host = NSHostingView(rootView: AnyView(MacDocumentContent(session: self).environment(model).tint(Amb.primary).appTextSize()))
        self.host = host
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if retired { return true }
        guard !closing else { return false }
        closing = true
        Task { @MainActor in
            let allowed = await beforeClose?() ?? true
            closing = false
            guard allowed else { return }
            retire()
            sender.close()
        }
        return false
    }

    func retire() { retired = true; beforeClose = nil; host?.rootView = AnyView(EmptyView()) }

    func windowWillClose(_ notification: Notification) {
        window = nil
        MacDocumentWindows.shared.sessions[key] = nil
        MacDocumentWindows.shared.detached.remove(key)
    }
}

private struct MacDocumentContent: View {
    let session: MacDocumentSession
    @Environment(AppModel.self) private var model
    @AppStorage("appearance") private var appearance = AppearancePreference.system.rawValue
    private var available: Bool {
        model.isUnlocked && model.identity.npub == session.key.signer && model.connection?.id == session.key.connection &&
        model.connection?.signerNpub == session.key.signer && model.selectedWorkspaceId == session.key.workspace &&
        model.selectedWorkspace?.appNpub == session.key.app
    }
    private var sameIdentity: Bool {
        model.isUnlocked && model.identity.npub == session.key.signer && model.connection?.signerNpub == session.key.signer
    }
    var body: some View {
        // Keep the document mounted when its workspace is inactive: its durable editor and page
        // are retained, but cannot make a write through the main window's newly selected services.
        Group {
            DocumentView(docId: session.key.document, workspace: session.workspace, store: session.store)
                .environment(\.macDocumentSession, session)
                .disabled(!available)
                .opacity(sameIdentity ? 1 : 0)
                .accessibilityHidden(!sameIdentity)
                .overlay(alignment: .top) {
                    if !sameIdentity {
                        ContentUnavailableView("Document workspace is inactive", systemImage: "lock.doc",
                            description: Text("Unlock and select \(session.workspace.label) in the main window to continue. Your document stays in this window."))
                    } else if !available {
                        Text("Select \(session.workspace.label) in the main window to continue editing. This window keeps its original document.")
                            .padding().frame(maxWidth: .infinity).background(Amb.card)
                            .accessibilityIdentifier("doc.window.inactive")
                    }
                }
        }
        .preferredColorScheme(AppearancePreference(rawValue: appearance)?.colorScheme)
        .imageLightboxHost()
        .environment(\.openURL, OpenURLAction { model.browser.handleLink($0) })
        .environment(\.openMention, OpenMentionAction { kind, id in model.openRecord(kind: kind, id: id) })
    }
}

extension EnvironmentValues {
    @Entry var macDocumentSession: MacDocumentSession? = nil
}
