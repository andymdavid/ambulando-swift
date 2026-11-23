import AmbulandoCore
import SwiftUI

/// The Mac's main window: a sidebar with the sections and the shared Workspace → Scope → Channel navigation (the same
/// content as the iPhone's drawer), and the current section beside it. Each section keeps its navigation path in the
/// model, so switching sections returns to the same record; only the visible section is drawn, so its toolbar is the
/// window's toolbar.
struct MacWorkspaceShell: View {
    @Environment(AppModel.self) private var model
    @Environment(MacUI.self) private var ui
    @Environment(\.openWindow) private var openWindow
    @SceneStorage("shell.tab") private var storedMode = AppMode.chat.rawValue
    @AppStorage(AppMode.agentsPreference) private var showAgents = false
    @AppStorage(AppMode.contextPreference) private var showContext = false
    @AppStorage("ux.sidebarWidth") private var sidebarWidth = MacSidebarResizer.defaultWidth

    var body: some View {
        let _ = MacHangDiagnostics.shared.mark("shell.body")
        @Bindable var ui = ui
        // Keep membership and the detail hosting view stable while the sidebar is hidden.
        // Removing/reinserting a child during a resize churns AppKit's constraint hierarchy and the live naplets.
        // UX lab: a row with a stored sidebar width, not `HSplitView`, which ignored the ideal width and always opened
        // the sidebar at its widest. Drag the edge to resize (MacSidebarResizer); the width is remembered.
        // The content pane keeps its 580pt minimum: in a window too narrow for both, the sidebar shows narrower (never
        // under its own minimum) instead of pushing the layout past the window's edges. The stored width is kept.
        GeometryReader { geometry in
        HStack(spacing: 0) {
            MacSidebar()
                .frame(width: ui.sidebarVisible ? MacSidebarResizer.fitted(sidebarWidth, window: geometry.size.width) : 0)
                .clipped()
                .opacity(ui.sidebarVisible ? 1 : 0)
                .allowsHitTesting(ui.sidebarVisible)
                .accessibilityHidden(!ui.sidebarVisible)
            MacSidebarResizer(width: $sidebarWidth, visible: ui.sidebarVisible)
            VStack(spacing: 0) {
                // UX lab: the place's name and its tabs (MacPlaceHeader) instead of a section bar and context strip.
                MacPlaceHeader(sections: AppMode.visible(agents: showAgents, context: showContext))
                sectionView(model.mode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: MacSidebarResizer.contentMinimum, maxWidth: .infinity, maxHeight: .infinity)
            // UX lab: the content is a rounded panel on the window chrome, inset on every side, so the title bar and
            // sidebar read as one frame around the working area (as Ari). The gap at its left is the resize handle.
            .background(Amb.background)
            .clipShape(RoundedRectangle(cornerRadius: Amb.radiusPanel, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Amb.radiusPanel, style: .continuous).strokeBorder(Amb.border, lineWidth: 0.5))
            .padding([.trailing, .bottom], Amb.contentInset)
            .environment(\.openMention, OpenMentionAction { kind, id in model.openRecord(kind: kind, id: id) })
        }
        .background(Amb.sidebar)
        // UX lab: nothing behind the command menu reacts to the pointer while it is open: no clicks, and no hover
        // fills (hover reaches the section screens' own hosting views regardless, so they are paused).
        .allowsHitTesting(!ui.showSearch)
        .environment(\.ambHoverPaused, ui.showSearch)
        }
        // HTTPS links open as tabs in the browser window; record mentions open the record in its section.
        .environment(\.openURL, OpenURLAction { model.browser.handleLink($0) })
        .environment(\.openMention, OpenMentionAction { kind, id in model.openRecord(kind: kind, id: id) })
        .onChange(of: model.browser.presentationRequest) { _, _ in openWindow(id: MacWindow.browser) }
        .onChange(of: model.canvasWindowRequest) { _, request in
            guard let request else { return }
            model.canvasWindowRequest = nil
            openWindow(id: MacWindow.canvas, value: request)
        }
        // The context bar's "open navigation" on the Mac reveals the sidebar column.
        .onChange(of: model.sidebarOpen) { _, open in
            guard open else { return }
            ui.sidebarVisible = true
            model.sidebarOpen = false
        }
        .onAppear {
            // UX lab: `-UXStartTab deck` opens the sample app on a given tab (`board`: Tasks as a board), for screen captures.
            let lab = FixtureEnvironment.requested ? UserDefaults.standard.string(forKey: "UXStartTab") : nil
            let stored = AppMode(stored: lab == "board" ? "tasks" : lab ?? storedMode)
            if model.mode != stored { model.mode = stored }
            if MacCommandMenu.labRequest != nil { ui.showSearch = true }
        }
        // UX lab: Search as a field centred in the title bar (as Ari); the window toolbar drops centred SwiftUI items.
        .background(MacTitleBarSearchInstaller { [ui] in ui.showSearch = true })
        .onChange(of: model.mode) { _, mode in storedMode = mode.rawValue }
        .onChange(of: showAgents) { _, on in if !on && model.mode == .agents { model.mode = .deck } }
        .onChange(of: showContext) { _, on in if !on && model.mode == .context { model.mode = .deck } }
        .onChange(of: model.contextSelections) { _, _ in model.resetContextSections() }
        .onChange(of: model.navigation.value) { _, _ in model.validateContext() }
        .sheet(isPresented: $ui.showSettings) {
            // No taller minimum than the smallest window: the form scrolls inside the sheet.
            SettingsView().frame(minWidth: 560, idealWidth: 640, minHeight: 420, idealHeight: 760)
        }
        // UX lab: Search is a command menu over the window (as Ari's ⌘K), not a sheet.
        .overlay { if ui.showSearch, model.selectedWorkspace != nil { MacCommandMenu() } }
        .sheet(isPresented: $ui.showNotifications) {
            if let workspace = model.selectedWorkspace, let store = model.store {
                NotificationsView(workspace: workspace, store: store).frame(minWidth: 520, idealWidth: 600, minHeight: 480, idealHeight: 680)
            }
        }
        .sheet(isPresented: $ui.showUnlock) {
            NavigationStack {
                Group {
                    if case .none = model.identity { ImportIdentityView() } else { UnlockView(embedded: true) }
                }
                .background(Amb.background)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { ui.showUnlock = false } } }
            }
            .frame(minWidth: 480, minHeight: 420)
        }
        .onChange(of: model.identity) { _, state in if case .unlocked = state { ui.showUnlock = false } }
    }

    @ViewBuilder private func sectionView(_ section: AppMode) -> some View {
        @Bindable var model = model
        @Bindable var ui = ui
        switch section {
        case .chat:
            ChatStack(showSettings: $ui.showSettings) { banners }
        case .deck:
            SectionStack(section: section, path: $model.deckPath, showSettings: $ui.showSettings, banner: { banners }) {
                workspaceSurface { DeckView(workspace: $0, store: $1) }
            }
        case .tasks:
            SectionStack(section: section, path: $model.tasksPath, showSettings: $ui.showSettings, banner: { banners }) {
                workspaceSurface { TasksView(workspace: $0, store: $1) }
            }
        case .docs:
            SectionStack(section: section, path: $model.docsPath, showSettings: $ui.showSettings, banner: { banners }) {
                workspaceSurface { DocumentsView(workspace: $0, store: $1) }
            }
        case .files:
            SectionStack(section: section, path: $model.filesPath, showSettings: $ui.showSettings, banner: { banners }) {
                workspaceSurface { FilesView(workspace: $0, store: $1) }
            }
        case .agents:
            SectionStack(section: section, path: $model.agentsPath, showSettings: $ui.showSettings, banner: { banners }) {
                workspaceSurface { AgentsView(workspace: $0, store: $1) }
            }
        case .context:
            SectionStack(section: section, path: $model.contextPath, showSettings: $ui.showSettings, banner: { banners }) {
                workspaceSurface { ContextTreeView(workspace: $0, store: $1) }
            }
        case .toolbox:
            SectionStack(section: section, path: $model.toolboxPath, showSettings: $ui.showSettings, contextBar: false, banner: { banners }) {
                workspaceSurface { ToolboxView(workspace: $0, store: $1) }
            }
        case .activity:
            // UX lab: its rows open records in their own places, so it keeps no stack of its own.
            SectionStack(section: section, path: .constant([]), showSettings: $ui.showSettings, contextBar: false, banner: { banners }) {
                workspaceSurface { MacActivityView(workspace: $0, store: $1) }
            }
        }
    }

    @ViewBuilder private var banners: some View {
        FixtureBanner()
        IdentityBanner { ui.showUnlock = true }
    }

    /// A section's root for the selected workspace; a fresh view (and observer) per workspace, so no rows cross over.
    @ViewBuilder private func workspaceSurface<Content: View>(@ViewBuilder _ content: @escaping (WorkspaceRecord, LocalStore) -> Content) -> some View {
        if let workspace = model.selectedWorkspace, let store = model.store {
            content(workspace, store).id(model.selectedWorkspaceBoundary?.id ?? workspace.id)
        } else {
            ContentUnavailableView("No workspace", systemImage: "square.stack.3d.up.slash",
                                   description: Text(model.workspaces.loaded ? "No workspaces for this identity yet." : "Loading saved workspaces…"))
        }
    }
}

/// Workspace navigation stays in the sidebar; product sections sit above every detail surface.
struct MacSidebar: View {
    var body: some View { MacSidebarContent().background(Amb.sidebar) }   // UX lab: Mac-only sidebar rows
}

/// The section bar is a plain row, not a horizontal `ScrollView`: on macOS that scroll view swallowed real mouse clicks
/// on its plain buttons (accessibility presses still worked), so the bar looked dead. When the labelled row does not
/// fit, the same buttons show icons only (with the name as tooltip and accessibility label).
struct MacSectionBar: View {
    @Environment(AppModel.self) private var model
    let sections: [AppMode]
    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(labelled: true)
            row(labelled: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading).background(Amb.background)
        .accessibilityElement(children: .contain).accessibilityLabel("Sections").accessibilityIdentifier("section.bar")
    }

    private func row(labelled: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(sections, id: \.self) { section in
                let selected = model.mode == section
                Button {
                    if selected { model.popToRoot(section) } else { model.show(section) }
                } label: {
                    Group {
                        if labelled { Label(section.title, systemImage: section.systemImage) } else { Image(systemName: section.systemImage) }
                    }
                    .font(.amb(.subheadline).weight(selected ? .semibold : .regular))
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(selected ? Amb.selectedFill : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    .ambHover(radius: 6)
                    // The whole pill is clickable, not only the glyphs.
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .ambTooltip(section.title)
                .accessibilityLabel(section.title)
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier("section.\(section.rawValue)")
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(8)
    }
}

/// UX lab: the sidebar's right edge, the gap before the content panel. Dragging sets the sidebar's width between
/// `minWidth` and `maxWidth`; it opens at `defaultWidth`.
struct MacSidebarResizer: View {
    static let defaultWidth: Double = 248
    static let minWidth: Double = 200
    static let maxWidth: Double = 380
    static func clamp(_ width: Double) -> CGFloat { CGFloat(min(max(width, minWidth), maxWidth)) }
    /// The content pane's minimum width.
    static let contentMinimum: CGFloat = 580
    /// The stored width, narrowed so the content pane keeps its minimum in this window (not below the sidebar's own).
    static func fitted(_ width: Double, window: CGFloat) -> CGFloat {
        guard window > 0 else { return clamp(width) }
        return max(CGFloat(minWidth), min(clamp(width), window - contentMinimum - 2 * Amb.contentInset))
    }

    @Binding var width: Double
    let visible: Bool
    @State private var start: Double?

    var body: some View {
        // UX lab: no hairline; the gap before the content panel is the edge, and the place to grab.
        Color.clear.frame(width: Amb.contentInset)
            .overlay {
                if visible {
                    Color.clear.frame(width: Amb.contentInset).contentShape(Rectangle())
                        .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                        .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { value in
                                let base = start ?? Double(Self.clamp(width))
                                start = base
                                width = Double(Self.clamp(base + value.translation.width))
                            }
                            .onEnded { _ in start = nil })
                        .accessibilityHidden(true)
                }
            }
            .zIndex(1)
    }
}
