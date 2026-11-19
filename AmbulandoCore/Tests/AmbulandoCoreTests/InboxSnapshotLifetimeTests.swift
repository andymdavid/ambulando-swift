import Foundation
import XCTest
@testable import AmbulandoCore

private actor InboxLatch {
    private var open = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async { if !open { await withCheckedContinuation { waiters.append($0) } } }
    func release() { open = true; for waiter in waiters { waiter.resume() }; waiters.removeAll() }
}

private struct HeldInbox: HTTPTransport {
    let base: StubTransport
    let entered: InboxLatch
    let release: InboxLatch
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if request.url!.path.hasSuffix("/resource-view-states") {
            await entered.release()
            await release.wait() // Deliberately ignores cancellation, like a late network completion.
            return (Data("{\"states\":[],\"has_more\":false}".utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        return try await base.send(request)
    }
}

final class InboxSnapshotLifetimeTests: XCTestCase {
    func testIncompletePageCannotEstablishNavigationBaseline() async throws {
        let h = try await WorkHarness.make()
        defer { try? FileManager.default.removeItem(at: h.chat.directory) }
        let transport = StubTransport { request in
            if request.url!.path.hasSuffix("/resource-view-states") { return (200, ["states": [], "has_more": true]) }
            return try h.transport.handlerResult(request)
        }
        let sync = WorkspaceSync(store: h.store, engine: h.engine, identity: h.chat.identity, transport: transport)
        for _ in 0..<2 {
            do { try await sync.synchronizeInbox(h.connection, h.workspace, reuseBaseline: true); XCTFail("incomplete page") }
            catch TowerError.malformed { }
        }
        XCTAssertEqual(transport.recorded.filter { $0.url!.path.hasSuffix("/resource-view-states") }.count, 2)
    }

    func testCancelledOrPausedSnapshotCannotDeleteCacheAfterImmediateResume() async throws {
        for pause in [false, true] {
            let h = try await WorkHarness.make(), activity = WorkspaceActivity()
            defer { try? FileManager.default.removeItem(at: h.chat.directory) }
            await h.store.writer.bindWorkspaceActivity(activity)
            let engine = SyncEngine(parent: h.engine, namespace: "snapshot-lifetime", activity: activity)
            let entered = InboxLatch(), release = InboxLatch()
            let sync = WorkspaceSync(store: h.store, engine: engine, identity: h.chat.identity,
                transport: HeldInbox(base: h.transport, entered: entered, release: release))
            try await h.store.writer.upsertViewStates(workspaceId: h.workspace.id, [.init(workspaceId: h.workspace.id,
                resourceType: .task, resourceId: "cached", scopeId: nil, channelId: Fixtures.channel1,
                activityVersion: 9, viewedActivityVersion: 8, updatedAt: "today")])
            await sync.refreshInbox(h.connection, h.workspace)
            await entered.wait()
            if pause { await engine.pause(); await engine.resume() }
            else { await engine.cancel(WorkspaceSync.inboxKey(h.workspace.id)) }
            await release.release()
            await h.engine.waitUntilIdle()
            let rows = try await h.store.reader.viewStates(workspaceId: h.workspace.id)
            XCTAssertEqual(rows.map(\.resourceId), ["cached"])
            XCTAssertEqual(rows.first?.viewedActivityVersion, 8)
            // A cancelled snapshot cannot establish a reusable navigation baseline.
            try await sync.synchronizeInbox(h.connection, h.workspace, reuseBaseline: true)
            let repaired = try await h.store.reader.viewStates(workspaceId: h.workspace.id)
            XCTAssertTrue(repaired.isEmpty)
        }
    }
}
