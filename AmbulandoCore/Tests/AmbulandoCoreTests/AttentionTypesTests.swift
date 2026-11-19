import Foundation
import XCTest
@testable import AmbulandoCore

final class AttentionTypesTests: XCTestCase {
    func testDefaultsFutureUnknownsAndAllCombinations() throws {
        for value in [nil, "no", "{}", "{\"version\":\"1\",\"disabled\":[\"task\"]}", "{\"version\":2,\"disabled\":[\"task\"]}", "{\"version\":true,\"disabled\":[\"task\"]}", "{\"version\":1,\"disabled\":[2]}"] as [String?] {
            XCTAssertTrue(AttentionTypes.kinds.allSatisfy { AttentionTypes(value).allows($0) })
        }
        XCTAssertThrowsError(try AttentionTypes("{\"version\":2,\"disabled\":[]}").setting("task", on: false))
        for mask in 0..<32 {
            var types = AttentionTypes("{\"version\":1,\"disabled\":[\"future-kind\"],\"extra\":{\"keep\":true}}")
            for (i, kind) in AttentionTypes.kinds.enumerated() { types = try types.setting(kind, on: mask & (1 << i) != 0) }
            for (i, kind) in AttentionTypes.kinds.enumerated() { XCTAssertEqual(types.allows(kind), mask & (1 << i) != 0) }
            XCTAssertTrue(types.allows("future-kind"))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(types.value!.utf8)) as? [String: Any])
            XCTAssertTrue((object["disabled"] as? [String])!.contains("future-kind"))
            XCTAssertEqual((object["extra"] as? [String: Bool])?["keep"], true)
        }
    }

    func testDeckFiltersOnlyUnreadAndDoesNotChangeReadPositions() throws {
        var sources = DeckActivity.Sources()
        sources.tasks = ["read", "unread"].map { id in
            TaskRecord(workspaceId: Fixtures.workspaceId, id: id, scopeId: Fixtures.scopeA, channelId: Fixtures.channel1,
                       title: id, description: nil, state: "ready", priority: "sand", assignedToNpub: nil, rowVersion: 1, createdAt: "2026-11-01", updatedAt: "2026-11-02")
        }
        let state = ViewStateRecord(workspaceId: Fixtures.workspaceId, resourceType: .task, resourceId: "unread", scopeId: Fixtures.scopeA,
                                    channelId: Fixtures.channel1, activityVersion: 8, viewedActivityVersion: 2, updatedAt: "2026-11-02")
        sources.viewStates = [state]
        let all = DeckActivity.inbox(sources, context: .home)
        let types = try AttentionTypes().setting("task", on: false)
        XCTAssertEqual(types.deck(all).map(\.recordId), ["read"])
        XCTAssertEqual(AttentionTypes().deck(all).count, 2)
        XCTAssertEqual(sources.viewStates[0].viewedActivityVersion, 2)
        func read(_ items: [DeckActivity.Item], query: String = "", limit: Int = 50) -> [ViewStateRecord] {
            DeckActivity.visibleReadResources(sources.viewStates, items: items, kinds: [.task], query: query, limit: limit, context: .home, channelScopes: [:])
        }
        XCTAssertTrue(read(types.deck(all)).isEmpty)
        XCTAssertTrue(read(all, query: "no match").isEmpty)
        XCTAssertTrue(read(all, limit: 0).isEmpty)
        XCTAssertEqual(read(all).map(\.resourceId), ["unread"])
    }

    func testCacheBoundaryAndSidebarPreserveHiddenReadStateAcrossRelaunch() async throws {
        let h = try await ChatHarness.make()
        defer { try? FileManager.default.removeItem(at: h.directory) }
        let boundary = try WorkspaceBoundary(connection: h.connection, workspace: h.workspace)
        var state = AttentionPreferenceState()
        state.value = try AttentionTypes().setting("task", on: false).value; state.loaded = true
        try await h.store.writer.setState(AttentionPreferenceState.cacheKey(boundary), state.encoded())
        try await h.store.writer.upsertViewStates(workspaceId: h.workspace.id, [.init(workspaceId: h.workspace.id, resourceType: .task, resourceId: "unread", scopeId: Fixtures.scopeA,
            channelId: Fixtures.channel1, activityVersion: 8, viewedActivityVersion: 2, mentionActivityVersion: 7, updatedAt: "2026-11-02")])
        let channels = try await h.store.reader.unreadChannelIds(workspaceId: h.workspace.id)
        XCTAssertTrue(channels.isEmpty)
        let states = try await h.store.reader.viewStates(workspaceId: h.workspace.id)
        XCTAssertEqual(states.first?.viewedActivityVersion, 2)
        XCTAssertEqual(states.first?.mentionActivityVersion, 7)
        let reopened = try await h.relaunch(unlock: true)
        let restored = try await reopened.store.reader.attentionPreference(boundary)
        XCTAssertFalse(restored.types.allows("task"))
        let other = try WorkspaceBoundary(connection: ConnectionRecord(origin: TowerOrigin("https://another-tower.example"), signerNpub: h.connection.signerNpub, towerNpub: nil), workspace: h.workspace)
        let otherState = try await h.store.reader.attentionPreference(other)
        XCTAssertTrue(otherState.types.allows("task"))
    }

    func testUncertainCommitRetriesSameMutationAndConflictReloadsWithoutClobber() async throws {
        let h = try await ChatHarness.make()
        defer { try? FileManager.default.removeItem(at: h.directory) }
        let fake = PreferenceTower(workspace: h.workspace.id)
        let sync = WorkspaceSync(store: h.store, engine: h.engine, identity: h.identity, transport: StubTransport(fake.handle))
        let boundary = try WorkspaceBoundary(connection: h.connection, workspace: h.workspace)
        do { try await sync.setAttentionType(h.connection, h.workspace, kind: "task", on: false); XCTFail("lost response") } catch {}
        var cached = try await h.store.reader.attentionPreference(boundary)
        let pending = try XCTUnwrap(cached.pending)
        for kind in ["file", "other"] {
            do { try await sync.setAttentionType(h.connection, h.workspace, kind: kind, on: false); XCTFail("pending edit must be resolved first") }
            catch { XCTAssertTrue(error is AttentionPreferenceError) }
        }
        let unchanged = try await h.store.reader.attentionPreference(boundary)
        XCTAssertEqual(unchanged.pending, pending, "offline sequential edits cannot mutate an uncertain request")
        XCTAssertTrue(cached.types.allows("task"), "last confirmed choice is retained offline")
        let reopened = try await h.relaunch(unlock: true)
        let restarted = WorkspaceSync(store: reopened.store, engine: reopened.engine, identity: reopened.identity, transport: StubTransport(fake.handle))
        try await restarted.synchronizeAttentionTypes(h.connection, h.workspace)
        cached = try await reopened.store.reader.attentionPreference(boundary)
        XCTAssertNil(cached.pending); XCTAssertFalse(cached.types.allows("task"))
        XCTAssertEqual(fake.bodies.count, 2); XCTAssertEqual(fake.bodies[0], fake.bodies[1])
        XCTAssertEqual(fake.mutations.first, pending.id)
        fake.changeElsewhere()
        do { try await restarted.setAttentionType(h.connection, h.workspace, kind: "chat", on: false); XCTFail("must conflict") } catch {}
        cached = try await reopened.store.reader.attentionPreference(boundary)
        XCTAssertNil(cached.pending); XCTAssertTrue(cached.types.allows("chat")); XCTAssertFalse(cached.types.allows("document"))
        XCTAssertNotNil(cached.error)
        fake.reset()
        try await restarted.synchronizeAttentionTypes(h.connection, h.workspace)
        cached = try await reopened.store.reader.attentionPreference(boundary)
        XCTAssertTrue(cached.loaded); XCTAssertNil(cached.value); XCTAssertEqual(cached.rowVersion, 0)
        XCTAssertTrue(AttentionTypes.kinds.allSatisfy { cached.types.allows($0) }, "authoritative null resets a stale cache")
    }

    func testNotificationUnreadMentionsAndBadgeFilterWithoutChangingStoredState() async throws {
        let h = try await NotificationHarness.make()
        defer { try? FileManager.default.removeItem(at: h.chat.directory) }
        let taskId = h.tower.put(title: "Task mention", target: ["kind": "task", "task_id": FakeNotificationTower.uuid()])
        h.tower.put(title: "Chat mention")
        h.tower.put(title: "Ordinary task assignment", category: "task_assignment", target: ["kind": "task", "task_id": FakeNotificationTower.uuid()])
        let genericId = h.tower.put(title: "Unclassified", target: ["kind": "future-target"])
        h.tower.put(title: "Task comment tag", category: "comment_tag", target: ["kind": "task", "task_id": FakeNotificationTower.uuid()])
        _ = try await h.run()
        await h.chat.engine.waitUntilIdle()
        let boundary = try WorkspaceBoundary(connection: h.connection, workspace: h.workspace)
        var state = AttentionPreferenceState()
        state.value = try AttentionTypes().setting("task", on: false).setting("other", on: false).value
        state.loaded = true
        try await h.store.writer.setState(AttentionPreferenceState.cacheKey(boundary), state.encoded())
        let unread = try await h.items(.unread)
        XCTAssertEqual(unread.map(\.title), ["Chat mention"])
        let count = try await h.unread()
        XCTAssertEqual(count, 1)
        let serverComparable = try await h.store.reader.notificationUnreadCount(connectionId: h.connection.id, workspaceId: h.workspace.id, attentionFiltered: false)
        XCTAssertEqual(serverComparable, 5, "sync drift detection compares server totals before personal presentation filters")
        let mentions = try await h.store.reader.notifications(connectionId: h.connection.id, workspaceId: h.workspace.id, filter: .all, category: "mention")
        XCTAssertEqual(mentions.count, 1)
        let tags = try await h.store.reader.notifications(connectionId: h.connection.id, workspaceId: h.workspace.id, filter: .all, category: "comment_tag")
        XCTAssertTrue(tags.isEmpty)
        let all = try await h.items(.all)
        XCTAssertEqual(Set(all.map(\.title)), ["Chat mention", "Ordinary task assignment"], "mixed All filters each mention category while ordinary task activity remains available")
        let limited = try await h.store.reader.notifications(connectionId: h.connection.id, workspaceId: h.workspace.id, filter: .unread, limit: 1)
        XCTAssertEqual(limited.map(\.title), ["Chat mention"], "hidden newer items must not exhaust the visible page")
        for id in [taskId, genericId] {
            let item = try await h.store.reader.notificationItem(connectionId: h.connection.id, workspaceId: h.workspace.id, id: id)
            XCTAssertEqual(item?.isUnread, true)
        }
        let writes = try await h.store.reader.writes(connectionId: h.connection.id, workspaceId: h.workspace.id)
        XCTAssertTrue(writes.isEmpty, "filters never submit read/dismiss writes")
    }

    func testHistoricalTargetAliasesUseTheSameSwitches() throws {
        let groups = ["chat": ["thread", "message", "channel", "dm", "chat"],
                      "document": ["doc", "doc_comment", "document", "document_comment"],
                      "task": ["task", "task_comment"], "file": ["file", "file_comment"], "other": ["future-target"]]
        for (kind, aliases) in groups {
            let types = try AttentionTypes().setting(kind, on: false)
            for alias in aliases {
                XCTAssertEqual(AttentionTypes.targetKind(alias), kind)
                let tower = FakeNotificationTower()
                let id = tower.put(target: ["kind": alias])
                let item = try XCTUnwrap(NotificationItem(json: tower.set(id, read: false), workspaceId: Fixtures.workspaceId))
                XCTAssertFalse(types.allows(item), "alias \(alias) belongs to \(kind)")
            }
        }
    }

    func testSidebarSQLMatchesRecordSemanticsForEverySwitchCombination() async throws {
        let h = try await ChatHarness.make()
        defer { try? FileManager.default.removeItem(at: h.directory) }
        let boundary = try WorkspaceBoundary(connection: h.connection, workspace: h.workspace)
        var rows: [ViewStateRecord] = []
        for type in [ViewStateRecord.ResourceType.thread, .task, .document] {
            for variant in 0..<6 {
                rows.append(.init(workspaceId: h.workspace.id, resourceType: type, resourceId: "\(type)-\(variant)", scopeId: nil,
                    channelId: "\(type)-\(variant)", activityVersion: variant == 0 ? 2 : 8, viewedActivityVersion: 3,
                    attentionActivityVersion: variant == 0 ? 9 : nil, mentionActivityVersion: variant == 3 ? 7 : nil,
                    channelMentionsOnly: variant >= 2, updatedAt: "today"))
            }
        }
        try await h.store.writer.upsertViewStates(workspaceId: h.workspace.id, rows)
        var values: [String?] = [nil, "bad", "{}", "{\"version\":2,\"disabled\":[\"chat\",\"task\",\"document\"]}"]
        for mask in 0..<32 {
            var types = AttentionTypes()
            for (i, kind) in AttentionTypes.kinds.enumerated() { types = try types.setting(kind, on: mask & (1 << i) != 0) }
            values.append(types.value)
        }
        for value in values {
            var preference = AttentionPreferenceState(); preference.value = value; preference.loaded = true
            try await h.store.writer.setAttentionPreference(boundary, preference)
            let types = AttentionTypes(value)
            let expected = Set(rows.filter { types.allows($0) && ($0.unread || $0.needsAttention) }.compactMap(\.channelId))
            let actual = try await h.store.reader.unreadChannelIds(workspaceId: h.workspace.id)
            XCTAssertEqual(actual, expected, "preference \(value ?? "nil")")
        }
        let retained = try await h.store.reader.viewStates(workspaceId: h.workspace.id)
        XCTAssertEqual(retained.count, rows.count)
        XCTAssertTrue(retained.allSatisfy { $0.viewedActivityVersion == 3 })
    }

    func testSidebarLifecycleExclusionsAndMissingParentsAcrossAllSwitches() async throws {
        let h = try await ChatHarness.make()
        defer { try? FileManager.default.removeItem(at: h.directory) }
        let w = h.workspace.id
        let boundary = try WorkspaceBoundary(connection: h.connection, workspace: h.workspace)
        for state in ["archived", "cancelled", "canceled"] {
            try await h.store.writer.upsertTasks(workspaceId: w, [.init(workspaceId: w, id: state, scopeId: nil,
                channelId: state, title: "Synthetic", description: nil, state: state, priority: "sand", assignedToNpub: nil,
                rowVersion: 1, createdAt: "today", updatedAt: "today")])
        }
        try await h.store.writer.upsertDocs(workspaceId: w, [.init(workspaceId: w, id: "doc", scopeId: nil,
            channelId: "doc", storageObjectId: nil, title: "Synthetic", summary: nil, archived: true,
            rowVersion: 1, createdAt: "today", updatedAt: "today")])
        for id in ["archived-thread", "deleted-thread"] {
            try await h.store.writer.upsertThreads(workspaceId: w, [.init(workspaceId: w, id: id, channelId: id,
                sourceMessageId: nil, title: "Synthetic", archived: id == "archived-thread", deleted: id == "deleted-thread", updatedAt: "today")])
        }
        let excluded: [(ViewStateRecord.ResourceType, String)] = [(.task, "archived"), (.task, "cancelled"), (.task, "canceled"),
            (.document, "doc"), (.thread, "archived-thread"), (.thread, "deleted-thread")]
        let missing: [(ViewStateRecord.ResourceType, String)] = [(.task, "absent-task"), (.document, "absent-doc"), (.thread, "absent-thread")]
        try await h.store.writer.upsertViewStates(workspaceId: w, (excluded + missing).map { type, id in
            .init(workspaceId: w, resourceType: type, resourceId: id, scopeId: nil, channelId: id,
                activityVersion: 9, viewedActivityVersion: 2, mentionActivityVersion: 8, channelMentionsOnly: true, updatedAt: "today")
        })
        for mask in 0..<32 {
            var types = AttentionTypes()
            for (i, kind) in AttentionTypes.kinds.enumerated() { types = try types.setting(kind, on: mask & (1 << i) != 0) }
            var state = AttentionPreferenceState(); state.value = types.value
            try await h.store.writer.setAttentionPreference(boundary, state)
            let actual = try await h.store.reader.unreadChannelIds(workspaceId: w)
            let expected = Set(missing.filter { types.allows($0.0 == .thread ? "chat" : $0.0.rawValue) }.map { $0.1 })
            XCTAssertEqual(actual, expected)
        }
    }

    func testPreferencePublicationRequiresSemanticStateChange() async throws {
        let h = try await ChatHarness.make()
        defer { try? FileManager.default.removeItem(at: h.directory) }
        let boundary = try WorkspaceBoundary(connection: h.connection, workspace: h.workspace)
        var state = AttentionPreferenceState()
        for step in 0..<7 {
            switch step {
            case 1: state.loaded = true
            case 2: state.value = try AttentionTypes().setting("task", on: false).value
            case 3: state.rowVersion = 2
            case 4: state.pending = .init(value: "pending", expectedRowVersion: 2, id: "mutation")
            case 5: state.error = "offline"
            case 6: state.pending = nil; state.error = nil
            default: break
            }
            let before = h.store.changes.revisions.value(of: [.appState, .attentionPreferences])
            let changed = try await h.store.writer.setAttentionPreference(boundary, state)
            XCTAssertTrue(changed)
            let after = h.store.changes.revisions.value(of: [.appState, .attentionPreferences])
            XCTAssertGreaterThan(after, before)
            let unchanged = try await h.store.writer.setAttentionPreference(boundary, state)
            XCTAssertFalse(unchanged)
            XCTAssertEqual(h.store.changes.revisions.value(of: [.appState, .attentionPreferences]), after)
        }
    }

    func testOtherDevicePreferenceEventUpdatesProjectionWithoutFetchingStates() async throws {
        let h = try await ChatHarness.make()
        defer { try? FileManager.default.removeItem(at: h.directory) }
        let fake = PreferenceTower(workspace: h.workspace.id)
        let sync = WorkspaceSync(store: h.store, engine: h.engine, identity: h.identity, transport: StubTransport(fake.handle))
        try await sync.synchronizeAttentionTypes(h.connection, h.workspace)
        let before = h.store.changes.revisions.value(of: [.appState])
        try await sync.synchronizeAttentionTypes(h.connection, h.workspace)
        XCTAssertEqual(h.store.changes.revisions.value(of: [.appState]), before)
        fake.changeElsewhere()
        let event = TowerEvent(rowVersion: 1, cursor: "x", workspaceId: h.workspace.id, entityType: "private_preference", entityId: nil, operation: "updated")
        try await sync.applyEvents([event], h.connection, h.workspace)
        let boundary = try WorkspaceBoundary(connection: h.connection, workspace: h.workspace)
        let state = try await h.store.reader.attentionPreference(boundary)
        XCTAssertFalse(state.types.allows("document"))
        XCTAssertGreaterThan(h.store.changes.revisions.value(of: [.appState]), before)
        // PreferenceTower asserts every request uses the preference route; any read-state fetch fails this test.
    }

    func testPrivatePreferenceEventsRefreshThroughSyncOwner() {
        let event = TowerEvent(rowVersion: 1, cursor: "x", workspaceId: Fixtures.workspaceId, entityType: "private_preference", entityId: nil, operation: "updated")
        XCTAssertTrue(EventPlan.make([event], workspaceId: Fixtures.workspaceId).refreshes.contains(.attentionPreferences))
        XCTAssertFalse(EventPlan.make([event], workspaceId: Fixtures.workspaceId).refreshes.contains(.inbox))
    }
}

private final class PreferenceTower: @unchecked Sendable {
    let lock = NSLock()
    let workspace: String
    var value: String? = nil
    var version = 0
    var loseResponse = true
    var receipts: Set<String> = []
    var bodies: [Data] = []
    var mutations: [String] = []
    init(workspace: String) { self.workspace = workspace }
    func reset() { lock.withLock { value = nil; version = 0 } }
    func changeElsewhere() { lock.withLock { value = "{\"version\":1,\"disabled\":[\"document\"]}"; version += 1 } }
    func handle(_ request: URLRequest) throws -> (Int, Any) {
        try lock.withLock {
            XCTAssertTrue(request.url!.path.hasSuffix("/me/preferences/ambulando.attention-types"))
            let signed = try decodeAuthorization(request)
            XCTAssertEqual(signed.kind, 27235)
            if request.httpMethod == "PUT" {
                let data = try XCTUnwrap(request.httpBody)
                bodies.append(data)
                let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                let id = try XCTUnwrap(body["mutation_id"] as? String); mutations.append(id)
                if !receipts.contains(id) {
                    guard body["expected_row_version"] as? Int == version else { return (409, ["code": "preference_conflict"]) }
                    value = body["value"] as? String; version += 1; receipts.insert(id)
                }
                if loseResponse { loseResponse = false; throw URLError(.networkConnectionLost) }
            }
            let row: Any = value.map { ["workspace_id": workspace, "preference_key": AttentionTypes.key, "value": $0, "row_version": version] as [String: Any] } ?? NSNull()
            return (200, ["preference": row])
        }
    }
}
