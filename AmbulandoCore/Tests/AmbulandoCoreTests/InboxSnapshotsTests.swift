import XCTest
@testable import AmbulandoCore

private actor SnapshotGate {
    var calls = 0
    var blocked: CheckedContinuation<Void, Never>?
    func work() async {
        calls += 1
        if calls == 1 { await withCheckedContinuation { blocked = $0 } }
    }
    func release() { blocked?.resume(); blocked = nil }
    func waitForFirst() async { while blocked == nil { await Task.yield() } }
}

final class InboxSnapshotsTests: XCTestCase {
    func testNavigationJoinsSnapshotAndReusesBaselineButReconciliationRuns() async throws {
        let owner = InboxSnapshots(), gate = SnapshotGate()
        let initial = Task { try await owner.refresh("boundary", reuseBaseline: true) { await gate.work() } }
        await gate.waitForFirst()
        let visible = Task { try await owner.refresh("boundary", reuseBaseline: true) { await gate.work() } }
        await Task.yield()
        await gate.release()
        try await initial.value; try await visible.value
        try await owner.refresh("boundary", reuseBaseline: true) { await gate.work() }
        var count = await gate.calls; XCTAssertEqual(count, 1)
        try await owner.refresh("boundary", reuseBaseline: false) { await gate.work() }
        count = await gate.calls; XCTAssertEqual(count, 2)
        try await owner.refresh("other boundary", reuseBaseline: true) { await gate.work() }
        count = await gate.calls; XCTAssertEqual(count, 3)
    }

    func testMidflightEventRerunsBeforeWaitersComplete() async throws {
        let owner = InboxSnapshots(), gate = SnapshotGate()
        let initial = Task { try await owner.refresh("boundary", reuseBaseline: true) { await gate.work() } }
        await gate.waitForFirst()
        let event = Task { try await owner.refresh("boundary", reuseBaseline: false) { await gate.work() } }
        // An actor barrier proves the event has registered its dirty request before releasing the fetch.
        while !(await owner.isDirty("boundary")) { await Task.yield() }
        await gate.release()
        try await event.value; try await initial.value
        let count = await gate.calls; XCTAssertEqual(count, 2)
    }

    func testAccessInvalidatesSuccessfulBaseline() async throws {
        let owner = InboxSnapshots()
        actor Count { var value = 0; func add() { value += 1 } }
        let count = Count()
        try await owner.refresh("boundary", reuseBaseline: true) { await count.add() }
        await owner.invalidate("boundary")
        try await owner.refresh("boundary", reuseBaseline: true) { await count.add() }
        let value = await count.value; XCTAssertEqual(value, 2)
    }

    func testPreferenceAccessSerializesReadWithMutationWithoutEngineSlots() async throws {
        let access = AttentionPreferenceAccess(), gate = SnapshotGate()
        let mutation = Task { try await access.perform("boundary") { await gate.work() } }
        await gate.waitForFirst()
        let event = Task { try await access.perform("boundary") { await gate.work() } }
        try await Task.sleep(for: .milliseconds(20))
        var calls = await gate.calls; XCTAssertEqual(calls, 1)
        await gate.release()
        try await mutation.value; try await event.value
        calls = await gate.calls; XCTAssertEqual(calls, 2)
    }

    func testFailureDoesNotEstablishBaseline() async throws {
        struct FailedPage: Error {}
        let owner = InboxSnapshots(), gate = SnapshotGate()
        do {
            try await owner.refresh("boundary", reuseBaseline: true) { throw FailedPage() }
            XCTFail("failed snapshot must propagate")
        } catch is FailedPage {}
        await gate.release()
        let retry = Task { try await owner.refresh("boundary", reuseBaseline: true) { await gate.work() } }
        await gate.waitForFirst(); await gate.release(); try await retry.value
        let count = await gate.calls; XCTAssertEqual(count, 1)
    }
}
