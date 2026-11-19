import Foundation
import CoreFoundation

/// Shared actor/workspace preference. Keep the original JSON so newer clients' fields survive a toggle.
public struct AttentionTypes: Sendable, Equatable {
    public static let key = "ambulando.attention-types"
    public static let kinds = ["chat", "document", "task", "file", "other"]
    public let value: String?
    private let disabled: Set<String>
    private let compatible: Bool
    public init(_ value: String? = nil) {
        self.value = value
        let object = Self.decode(value)
        self.disabled = Set(object?["disabled"] as? [String] ?? [])
        self.compatible = value == nil || object != nil
    }
    private static func decode(_ value: String?) -> [String: Any]? {
        guard let value, let data = value.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = o["version"] as? NSNumber, CFGetTypeID(version) != CFBooleanGetTypeID(), version.doubleValue == 1,
              o["disabled"] is [String] else { return nil }
        return o
    }
    public var editable: Bool { compatible }
    public func allows(_ kind: String) -> Bool {
        guard Self.kinds.contains(kind) else { return true }
        return !disabled.contains(kind)
    }
    public func setting(_ kind: String, on: Bool) throws -> AttentionTypes {
        guard editable, Self.kinds.contains(kind) else { throw AttentionPreferenceError.incompatible }
        var o = Self.decode(value) ?? ["version": 1, "disabled": [String]()]
        var disabled = (o["disabled"] as? [String] ?? []).filter { $0 != kind }
        if !on { disabled.append(kind) }
        o["disabled"] = disabled
        return AttentionTypes(String(decoding: try JSONSerialization.data(withJSONObject: o, options: [.sortedKeys]), as: UTF8.self))
    }
    public func allows(_ state: ViewStateRecord) -> Bool {
        allows(state.resourceType == .thread ? "chat" : state.resourceType.rawValue)
    }
    /// Historical notification target spellings share the same attention family across clients.
    public static func targetKind(_ kind: String) -> String {
        switch kind {
        case "thread", "message", "channel", "dm", "chat": "chat"
        case "doc", "doc_comment", "document", "document_comment": "document"
        case "task", "task_comment": "task"
        case "file", "file_comment": "file"
        default: "other"
        }
    }
    public func allows(_ item: NotificationItem) -> Bool {
        let kind: String = switch item.target {
        case .thread, .channel: "chat"
        case .task: "task"
        case .doc: "document"
        case .file: "file"
        case .generic(let kind): Self.targetKind(kind)
        default: "other"
        }
        return allows(kind)
    }
    public func deck(_ items: [DeckActivity.Item]) -> [DeckActivity.Item] {
        items.filter { !$0.isUnread || allows($0.kind.rawValue) }
    }
}

public enum AttentionPreferenceError: LocalizedError {
    case incompatible, changedElsewhere, pending
    public var errorDescription: String? {
        switch self {
        case .incompatible: "This saved preference uses an unsupported format. All types remain visible; update Ambulando to change it."
        case .changedElsewhere: "This choice changed on another device. The latest choice is shown; review it and choose again."
        case .pending: "The previous save is not confirmed. Retry it before changing another switch."
        }
    }
}

public struct AttentionPreferenceState: Codable, Sendable, Equatable {
    public struct Mutation: Codable, Sendable, Equatable {
        public let value: String
        public let expectedRowVersion: Int
        public let id: String
    }
    public var value: String? = nil
    public var rowVersion = 0
    public var loaded = false
    public var pending: Mutation? = nil
    public var error: String? = nil
    public init() {}
    public var types: AttentionTypes { AttentionTypes(value) }
    public static func cacheKey(_ boundary: WorkspaceBoundary) -> String { "attention-types.v1:" + boundary.id }
    public func encoded() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
}

extension TowerAPI {
    func attentionPreference(workspaceId: String, appNpub: String, mutation: AttentionPreferenceState.Mutation? = nil) async throws -> AttentionPreferenceState {
        guard lowerUUID(workspaceId) != nil else { throw TowerError.unsafePath }
        let path = "/api/v4/flightdeck-pg/workspaces/\(workspaceId.lowercased())/me/preferences/\(AttentionTypes.key)"
        let body = try mutation.map { try rawJSON(["value": $0.value, "expected_row_version": $0.expectedRowVersion, "mutation_id": $0.id]) }
        let (status, data) = try await client.exchange(method: mutation == nil ? "GET" : "PUT", path: path, appNpub: appNpub, jsonBody: body)
        let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(status) else { throw TowerError.http(status: status, code: o["code"] as? String ?? o["error"] as? String, stage: "attention types") }
        if let identity = o["identity"] as? [String: Any], let w = identity["workspace_id"] as? String, w.lowercased() != workspaceId.lowercased() { throw TowerError.malformed("attention preference workspace") }
        var state = AttentionPreferenceState()
        if let row = o["preference"] as? [String: Any] {
            guard let value = row["value"] as? String, let version = flexibleInt(row["row_version"]), version > 0,
                  row["preference_key"] as? String == AttentionTypes.key,
                  (row["workspace_id"] as? String)?.lowercased() == workspaceId.lowercased() else { throw TowerError.malformed("attention preference") }
            state.value = value; state.rowVersion = version
        } else if !(o["preference"] is NSNull) { throw TowerError.malformed("attention preference") }
        state.loaded = true
        return state
    }
}

extension StoreReader {
    public func attentionPreference(_ boundary: WorkspaceBoundary) throws -> AttentionPreferenceState {
        guard let text = try state(AttentionPreferenceState.cacheKey(boundary)) else { return AttentionPreferenceState() }
        return (try? JSONDecoder().decode(AttentionPreferenceState.self, from: Data(text.utf8))) ?? AttentionPreferenceState()
    }
    /// Partition stores normally contain exactly one actor/app. Ambiguous legacy stores fail open, never borrow another account's choice.
    public func attentionTypes(workspaceId: String, connectionId: String? = nil) throws -> AttentionTypes {
        var boundaries: [WorkspaceBoundary] = []
        for c in try connections() where connectionId == nil || c.id == connectionId {
            for w in try workspaces(connectionId: c.id) where w.id == workspaceId { boundaries.append(try WorkspaceBoundary(connection: c, workspace: w)) }
        }
        guard boundaries.count == 1, let boundary = boundaries.first else { return AttentionTypes() }
        return try attentionPreference(boundary).types
    }
}

extension WorkspaceSync {
    public static func attentionTypesKey(_ workspaceId: String) -> String { "attention-types:\(workspaceId)" }
    public func refreshAttentionTypes(_ connection: ConnectionRecord, _ workspace: WorkspaceRecord, force: Bool = false) async {
        let sync = self
        await engine.enqueue(Self.attentionTypesKey(workspace.id), priority: .visible, force: force, retries: SyncBackoff.readRetries) {
            do { try await sync.synchronizeAttentionTypes(connection, workspace) }
            catch TowerError.http(let status, _, _) where status == 404 || status == 501 {
                // Older Towers keep their cached/default projection. Settings retains the explicit local error;
                // an optional unsupported preference must not turn healthy inbox synchronization into an error.
            }
        }
    }
    public func setAttentionType(_ connection: ConnectionRecord, _ workspace: WorkspaceRecord, kind: String, on: Bool) async throws {
        let sync = self
        try await engine.perform(Self.attentionTypesKey(workspace.id)) {
            let boundary = try WorkspaceBoundary(connection: connection, workspace: workspace)
            try await sync.attentionAccess.perform(boundary.id) {
                try await sync.identity.requireSigner(npub: connection.signerNpub)
                var state = try await sync.store.reader.attentionPreference(boundary)
                guard state.pending == nil else { throw AttentionPreferenceError.pending }
                if !state.loaded { try await sync.synchronizeAttentionTypesUnlocked(connection, workspace); state = try await sync.store.reader.attentionPreference(boundary) }
                let value = try state.types.setting(kind, on: on).value!
                state.pending = .init(value: value, expectedRowVersion: state.rowVersion, id: UUID().uuidString.lowercased())
                try await sync.store.writer.setAttentionPreference(boundary, state)
                try await sync.synchronizeAttentionTypesUnlocked(connection, workspace)
            }
        }
    }
    /// Retry uncertain writes byte-for-byte before reading; CAS conflicts never silently rebase a stale choice.
    func synchronizeAttentionTypes(_ connection: ConnectionRecord, _ workspace: WorkspaceRecord) async throws {
        let key = try WorkspaceBoundary(connection: connection, workspace: workspace).id
        let sync = self
        try await attentionAccess.perform(key) { try await sync.synchronizeAttentionTypesUnlocked(connection, workspace) }
    }

    private func synchronizeAttentionTypesUnlocked(_ connection: ConnectionRecord, _ workspace: WorkspaceRecord) async throws {
        try await identity.requireReader(npub: connection.signerNpub)
        let boundary = try WorkspaceBoundary(connection: connection, workspace: workspace)
        var state = try await store.reader.attentionPreference(boundary)
        let api = api(origin: try TowerOrigin(connection.origin))
        do {
            if let pending = state.pending {
                try await identity.requireSigner(npub: connection.signerNpub)
                do { state = try await api.attentionPreference(workspaceId: workspace.id, appNpub: workspace.appNpub, mutation: pending) }
                catch TowerError.http(let status, let code, _) where status == 409 && ["preference_conflict", "mutation_id_reused"].contains(code ?? "") {
                    state = try await api.attentionPreference(workspaceId: workspace.id, appNpub: workspace.appNpub)
                    state.error = AttentionPreferenceError.changedElsewhere.localizedDescription
                    try await store.writer.setAttentionPreference(boundary, state)
                    throw AttentionPreferenceError.changedElsewhere
                }
            }
            // An idempotent acknowledgement may be older than a subsequent write on another device.
            let latest = try await api.attentionPreference(workspaceId: workspace.id, appNpub: workspace.appNpub)
            state = latest
            try await store.writer.setAttentionPreference(boundary, state)
        } catch {
            state.error = error.localizedDescription
            try await store.writer.setAttentionPreference(boundary, state)
            throw error
        }
    }
}


extension StoreWriter {
    /// Compare the complete decoded state, including pending/error/loaded/version transitions.
    @discardableResult
    public func setAttentionPreference(_ boundary: WorkspaceBoundary, _ state: AttentionPreferenceState) async throws -> Bool {
        let key = AttentionPreferenceState.cacheKey(boundary)
        let query = try db.prepare("SELECT value FROM app_state WHERE key = ?")
        try query.bind([.text(key)])
        if try query.step(), let text = query.text(0),
           let old = try? JSONDecoder().decode(AttentionPreferenceState.self, from: Data(text.utf8)), old == state { return false }
        try db.prepare("INSERT INTO app_state(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value")
            .run([.text(key), .text(try state.encoded())])
        await emit([ChangeKey(.appState), ChangeKey(.attentionPreferences, boundary.workspaceId)])
        return true
    }
}

/// Serializes event reads with the entire durable mutation sequence without nesting SyncEngine slots.
actor AttentionPreferenceAccess {
    private var tails: [String: (UUID, Task<Void, Error>)] = [:]
    func perform(_ key: String, work: @escaping @Sendable () async throws -> Void) async throws {
        let previous = tails[key]?.1
        let id = UUID()
        let task = Task {
            _ = try? await previous?.value
            try Task.checkCancellation()
            try await work()
        }
        tails[key] = (id, task)
        defer { if tails[key]?.0 == id { tails[key] = nil } }
        try await withTaskCancellationHandler {
            try await task.value
            try Task.checkCancellation()
        } onCancel: { task.cancel() }
    }
}
