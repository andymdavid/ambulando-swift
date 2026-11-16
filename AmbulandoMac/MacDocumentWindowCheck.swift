#if DEBUG
import AppKit
import WebKit
import AmbulandoCore

extension MacThreadRegression {
    static func documentWindowCheck(_ main: NSWindow, model: AppModel) async throws {
        guard let store = model.store, let workspace = model.selectedWorkspace, let connection = model.connection,
              let fixture = model.fixture else { throw Failure(description: "Missing isolated fixture") }
        model.selectContext(.home)
        try press(main, "section.docs"); await settle(); await settle()
        model.docsPath = []
        try await waitFor(main, "doc.Native app plan", "document list")
        try press(main, "doc.Native app plan"); await settle(); await settle()
        try await waitFor(main, "doc.edit", "document reader")
        let docs = try await store.reader.docs(workspaceId: workspace.id)
        guard let doc = docs.first(where: { $0.title == "Native app plan" }),
              let key = MacDocumentWindows.shared.key(model, workspace: workspace, docId: doc.id),
              let session = MacDocumentWindows.shared.sessions[key] else { throw Failure(description: "Missing document host") }
        try press(main, "doc.window.open"); await settle(); await settle()
        guard let window = session.window else { throw Failure(description: "No detached window") }
        try await waitFor(main, "doc.window.focus", "main focus placeholder")
        try await waitFor(window, "doc.edit", "detached reader")
        try press(window, "doc.edit"); try await waitFor(window, "editor.title", "detached editor")
        for _ in 0..<60 {
            if WikiEditors.editor(connectionId: connection.id, workspaceId: workspace.id, docId: doc.id)?.pageReady == true { break }
            await settle()
        }
        guard let editor = WikiEditors.editor(connectionId: connection.id, workspaceId: workspace.id, docId: doc.id),
              let detachedPage = editor.page?.webView else { throw Failure(description: "Missing detached editor") }
        try require(find(window, "doc.window.finishEditing") != nil, "active edit explains finish-first pop-out rule")
        guard let openControl = find(window, "doc.window.open") else { throw Failure(description: "Missing pop-out action") }
        let enabledSelector = NSSelectorFromString("isAccessibilityEnabled")
        typealias Enabled = @convention(c) (AnyObject, Selector) -> Bool
        guard openControl.responds(to: enabledSelector) else { throw Failure(description: "Missing enabled accessibility state") }
        let enabled = unsafeBitCast(openControl.method(for: enabledSelector), to: Enabled.self)
        try require(!enabled(openControl, enabledSelector), "pop-out is disabled during editing")
        let typed = try await detachedPage.evaluateJavaScript("(()=>{const e=document.querySelector('.ProseMirror').editor;e.view.dom.dispatchEvent(new InputEvent('beforeinput',{bubbles:true,inputType:'insertText',data:'fixture typing'}));e.commands.focus();e.commands.setTextSelection(e.state.doc.content.size-1);e.commands.insertContent(' Popout unsent sentinel');return e.getText()})()") as? String
        try require(typed?.contains("Popout unsent sentinel") == true, "input exists in owning detached page")
        try require(window.title.contains(doc.title) && window.styleMask.contains(.resizable), "useful title and resizable window")
        try require(find(window, "editor.save") != nil, "existing Save remains available")
        try press(main, "doc.window.focus"); await settle()
        try require(session.window === window && MacDocumentWindows.shared.detached.count == 1, "repeat open focuses single window")
        model.mode = .tasks; model.selectContext(.home); await settle()
        try require(editor.page?.webView === detachedPage && editor.dirty, "main section/context navigation keeps dirty editor")
        window.setContentSize(NSSize(width: 800, height: 650)); await settle()
        try require(find(window, "editor.save") != nil, "resize retains edit controls")
        // Open a distinct real fixture document in a second native window.
        let secondId = fixture.tower.work.seedDoc(scope: doc.scopeId!, channel: doc.channelId, title: "Second detached document", body: Data("Second body".utf8), contentType: "text/markdown")
        _ = try await model.saver?.latest(connection, workspace, docId: secondId)
        model.mode = .docs; model.docsPath = [.doc(workspaceId: workspace.id, docId: secondId)]
        try await waitFor(main, "doc.window.open", "second document reader")
        try press(main, "doc.window.open"); await settle()
        try require(MacDocumentWindows.shared.detached.count == 2, "two distinct documents coexist")
        guard let secondKey = MacDocumentWindows.shared.key(model, workspace: workspace, docId: secondId),
              let secondSession = MacDocumentWindows.shared.sessions[secondKey], let secondWindow = secondSession.window else {
            throw Failure(description: "Missing second window")
        }
        try require(secondWindow !== window && secondWindow.title.contains("Second detached"), "distinct titles and windows")
        let protectedClose = secondSession.beforeClose
        secondSession.beforeClose = { false }
        secondWindow.performClose(nil); await settle()
        try require(secondSession.window === secondWindow && secondWindow.isVisible, "failed close checkpoint keeps window open")
        secondSession.beforeClose = protectedClose
        secondWindow.performClose(nil); await settle(); await settle()
        try require(!MacDocumentWindows.shared.detached.contains(secondKey), "close retires second window")

        if let original = model.workspaceEntries.first(where: { $0.workspace.id == workspace.id }),
           let other = model.workspaceEntries.first(where: { $0.workspace.id != workspace.id }) {
            model.setWorkspaceEnabled(other, true)
            for _ in 0..<50 { if other.runtime != nil { break }; await settle() }
            model.openWorkspace(other, context: .home); await settle(); await settle()
            try require(find(window, "doc.window.inactive") != nil && session.key.workspace == workspace.id, "workspace change shows fixed-scope notice")
            try require(!(await editor.save()), "inactive original document cannot save through another workspace")
            model.openWorkspace(original, context: .home); await settle(); await settle()
            try require(find(window, "doc.window.inactive") == nil && editor.page?.webView === detachedPage, "return restores same page")
        } else { throw Failure(description: "Missing second workspace fixture") }

        try press(window, "editor.save"); await settle(); await settle()
        let saved = try await store.reader.docBody(workspaceId: workspace.id, docId: doc.id)
        try require(saved.map { String(decoding: $0.bytes, as: UTF8.self).contains("Popout unsent sentinel") } == true, "detached Save persists original document")

        try press(window, "doc.edit"); try await waitFor(window, "editor.title", "edit again after Save")
        for _ in 0..<60 {
            if WikiEditors.editor(connectionId: connection.id, workspaceId: workspace.id, docId: doc.id)?.pageReady == true { break }
            await settle()
        }
        guard let closingEditor = WikiEditors.editor(connectionId: connection.id, workspaceId: workspace.id, docId: doc.id), let closingPage = closingEditor.page?.webView else { throw Failure(description: "Missing closing editor") }
        _ = try await closingPage.evaluateJavaScript("(()=>{const e=document.querySelector('.ProseMirror').editor;e.view.dom.dispatchEvent(new InputEvent('beforeinput',{bubbles:true,inputType:'insertText',data:'fixture typing'}));e.commands.insertContent(' Close offline sentinel');return true})()")
        fixture.offline = true
        window.performClose(nil); await settle(); await settle(); await settle()
        try require(session.window == nil && !MacDocumentWindows.shared.detached.contains(key), "close retires document window")
        let draft = try await store.reader.docDraft(key: editor.draftKey)
        try require(draft.map { String(decoding: $0.body, as: UTF8.self).contains("Close offline sentinel") } == true, "offline close preserves immediate input as durable draft")
        fixture.offline = false
        model.mode = .docs; model.docsPath = [.doc(workspaceId: workspace.id, docId: doc.id)]
        try await waitFor(main, "doc.edit", "reopened document reader")
        try press(main, "doc.edit"); try await waitFor(main, "editor.title", "recovered editor")
        for _ in 0..<30 {
            if let recovered = WikiEditors.editor(connectionId: connection.id, workspaceId: workspace.id, docId: doc.id),
               recovered.pageReady && recovered.content.contains("Close offline sentinel") { break }
            await settle()
        }
        try require(WikiEditors.editor(connectionId: connection.id, workspaceId: workspace.id, docId: doc.id)?.content.contains("Close offline sentinel") == true, "reopening recovers unsaved local input")
        try require(find(main, "doc.window.finishEditing") != nil, "inline editing offers finish-first guidance")
        try press(main, "editor.save"); await settle(); await settle()
        try await waitFor(main, "doc.edit", "saved reader")
        try press(main, "doc.window.open"); await settle(); await settle()
        guard let lockedSession = MacDocumentWindows.shared.sessions[key], let lockedWindow = lockedSession.window else { throw Failure(description: "Missing reopened window") }
        await model.lock(); await settle()
        try require(containsText(lockedWindow, "Document workspace is inactive"), "lock hides document behind identity notice")
        try require(find(lockedWindow, "doc.edit") == nil, "locked document controls are absent from accessibility")
        print("DOCUMENT_POPOUT_PASS readerFirst singleEditor repeatFocus independentNavigation twoDocuments resize save workspaceFence closeVeto offlineCloseDraft recovery identityLock")
    }
}
#endif
