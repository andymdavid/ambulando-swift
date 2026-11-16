import Foundation

/// Public signed locator only. Membership and app consent remain Tower-owned.
public struct WorkspaceConnection: Decodable, Sendable, Equatable {
    public struct Transports: Decodable, Sendable, Equatable {
        public struct HTTPS: Decodable, Sendable, Equatable { public let url: String }
        public struct FIPS: Decodable, Sendable, Equatable { public let peer_npub: String; public let host: String; public let port: Int }
        public let https: HTTPS?; public let fips: FIPS?
    }
    public struct Policy: Decodable, Sendable, Equatable { public let preferred: String; public let fallback: String }
    public let type: String; public let version: Int; public let service_npub: String
    public let workspace_id: String; public let workspace_service_npub: String; public let name: String?
    public let transports: Transports; public let policy: Policy
    public static let prefix = "nstack:workspace:v3:"
    public var modes: [String] { (transports.https == nil ? [] : ["https"]) + (transports.fips == nil ? [] : ["fips"]) }
    public func origin(mode: String) throws -> TowerOrigin {
        guard modes.contains(mode) else { throw TowerError.descriptor("unsupported transport") }
        if mode == "fips" { throw TowerError.fipsNotSupported }
        return try TowerOrigin(transports.https!.url)
    }
    public static func parse(_ envelope: String, now: Int = Int(Date().timeIntervalSince1970)) throws -> Self {
        guard envelope.utf8.count <= 8192, envelope.hasPrefix(prefix) else { throw TowerError.descriptor("unsupported workspace envelope") }
        let encoded = String(envelope.dropFirst(prefix.count))
        guard encoded.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { throw TowerError.descriptor("invalid encoding") }
        let base = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: base + String(repeating: "=", count: (4 - base.count % 4) % 4)),
              data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") == encoded else { throw TowerError.descriptor("invalid encoding") }
        let object = try CanonicalConnectionJSON.object(data)
        try shape(object, ["kind", "created_at", "tags", "content", "pubkey", "id", "sig"])
        let event = try JSONDecoder().decode(NostrEvent.self, from: data)
        let content = try signed(event, kind: 30383, tag: "nstack-workspace-connection-v3", now: now)
        let required: Set<String> = ["type", "version", "service_npub", "workspace_id", "workspace_service_npub", "transports", "policy"]
        try shape(content, required.union(["name"]), required: required)
        if content["name"] != nil, !(content["name"] is String) { throw TowerError.descriptor("invalid name") }
        let p = try JSONDecoder().decode(Self.self, from: Data(event.content.utf8))
        guard p.type == "nstack-workspace", p.version == 3, validNpub(p.service_npub), validNpub(p.workspace_service_npub),
              NostrKeys.npub(publicKeyHex: event.pubkey) == p.service_npub,
              p.workspace_id.range(of: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", options: .regularExpression) != nil,
              (p.name?.utf16.count ?? 0) <= 128 else { throw TowerError.descriptor("invalid workspace identity or version") }
        let t = content["transports"] as? [String: Any] ?? [:]
        try shape(t, ["https", "fips"], required: [])
        guard !t.isEmpty else { throw TowerError.descriptor("transport required") }
        if let h = p.transports.https {
            try shape(t["https"] as? [String: Any] ?? [:], ["url"])
            guard try TowerOrigin(h.url).description == h.url else { throw TowerError.descriptor("noncanonical HTTPS origin") }
        } else if t["https"] != nil { throw TowerError.descriptor("invalid HTTPS transport") }
        if let f = p.transports.fips {
            try shape(t["fips"] as? [String: Any] ?? [:], ["peer_npub", "host", "port"])
            guard validNpub(f.peer_npub), f.host == f.peer_npub + ".fips", (1...65535).contains(f.port) else { throw TowerError.descriptor("FIPS peer/host mismatch") }
        } else if t["fips"] != nil { throw TowerError.descriptor("invalid FIPS transport") }
        try shape(content["policy"] as? [String: Any] ?? [:], ["preferred", "fallback"])
        guard p.modes.contains(p.policy.preferred), p.policy.fallback == "none" else { throw TowerError.descriptor("invalid transport policy") }
        return p
    }
    static func validNpub(_ value: String) -> Bool {
        guard let hex = NostrKeys.publicKeyHex(npub: value) else { return false }
        return NostrKeys.npub(publicKeyHex: hex) == value
    }
    static func shape(_ object: [String: Any], _ allowed: Set<String>, required: Set<String>? = nil) throws {
        let keys = Set(object.keys)
        guard keys.isSubset(of: allowed), (required ?? allowed).isSubset(of: keys) else { throw TowerError.descriptor("invalid connection shape") }
    }
    static func signed(_ event: NostrEvent, kind: Int, tag: String, now: Int) throws -> [String: Any] {
        guard event.kind == kind, event.created_at >= 0, event.created_at <= now + 300,
              event.tags == [["d", tag]], event.pubkey.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
              event.sig.range(of: "^[0-9a-f]{128}$", options: .regularExpression) != nil, SignatureVerifier.verify(event) else { throw TowerError.descriptor("invalid signed connection proof") }
        return try CanonicalConnectionJSON.object(Data(event.content.utf8))
    }
    public func verifyProof(_ event: NostrEvent, nonce: String, url: String, now: Int = Int(Date().timeIntervalSince1970)) throws {
        let p = try Self.signed(event, kind: 30384, tag: "nstack-connection-challenge-v1", now: now)
        try Self.shape(p, ["nonce", "service_npub", "workspace_id", "workspace_service_npub", "request_url", "expires_at"])
        struct Proof: Decodable { let nonce: String; let service_npub: String; let workspace_id: String; let workspace_service_npub: String; let request_url: String; let expires_at: Int }
        let proof = try JSONDecoder().decode(Proof.self, from: Data(event.content.utf8))
        guard nonce.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil, proof.nonce == nonce, proof.request_url == url,
              proof.service_npub == service_npub, NostrKeys.npub(publicKeyHex: event.pubkey) == service_npub,
              proof.workspace_id == workspace_id, proof.workspace_service_npub == workspace_service_npub,
              proof.expires_at > now, proof.expires_at <= now + 60, event.created_at <= now, event.created_at >= now - 60,
              proof.expires_at == event.created_at + 60 else { throw TowerError.descriptor("workspace proof mismatch or expired") }
    }
}

/// Strict compact JSON scanner preserves signer key order and rejects duplicates.
/// Only integers are used by this contract; other number spellings fail closed.
enum CanonicalConnectionJSON {
    static func object(_ data: Data) throws -> [String: Any] {
        var scanner = Scanner(bytes: Array(data))
        try scanner.value()
        guard scanner.i == data.count, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw TowerError.descriptor("invalid canonical JSON") }
        return object
    }
    struct Scanner {
        let bytes: [UInt8]; var i = 0
        mutating func fail() throws -> Never { throw TowerError.descriptor("noncanonical or duplicate JSON") }
        mutating func take(_ b: UInt8) throws { guard i < bytes.count, bytes[i] == b else { try fail() }; i += 1 }
        mutating func string() throws -> String {
            let start = i; try take(34)
            while i < bytes.count {
                if bytes[i] == 34 {
                    i += 1
                    let data = Data(bytes[start..<i]); let s = try JSONDecoder().decode(String.self, from: data)
                    guard Array(NostrSerialization.quote(s).utf8) == Array(data) else { try fail() }; return s
                }
                if bytes[i] == 92 { i += 1 }; i += 1
            }
            try fail()
        }
        mutating func value(depth: Int = 0) throws {
            guard depth <= 32 else { try fail() }
            guard i < bytes.count else { try fail() }
            switch bytes[i] {
            case 34: _ = try string()
            case 123:
                i += 1; var seen = Set<String>()
                if i < bytes.count, bytes[i] == 125 { i += 1; return }
                while true {
                    let key = try string(); guard seen.insert(key).inserted else { try fail() }; try take(58); try value(depth: depth + 1)
                    guard i < bytes.count else { try fail() }
                    if bytes[i] == 125 { i += 1; return }; try take(44)
                }
            case 91:
                i += 1; if i < bytes.count, bytes[i] == 93 { i += 1; return }
                while true { try value(depth: depth + 1); guard i < bytes.count else { try fail() }; if bytes[i] == 93 { i += 1; return }; try take(44) }
            default:
                let start = i
                while i < bytes.count, ![44, 93, 125].contains(bytes[i]) { i += 1 }
                let s = String(decoding: bytes[start..<i], as: UTF8.self)
                guard ["true", "false", "null"].contains(s) || Int64(s).map({ String($0) == s }) == true else { try fail() }
            }
        }
    }
}

extension TowerAPI {
    public func connectionWorkspace(_ connection: WorkspaceConnection) async throws -> WorkspaceRecord {
        let nonce = Data((0..<32).map { _ in UInt8.random(in: 0...255) }).hex
        let path = try Self.base(connection.workspace_id) + "/connection-proof"
        let query = [URLQueryItem(name: "nonce", value: nonce)]
        let url = try client.origin.url(path: path, query: query).absoluteString
        let data = try await client.request(path: path, query: query)
        struct Response: Decodable { let proof: NostrEvent }
        guard let body = try CanonicalConnectionJSON.object(data) as [String: Any]?, let proof = body["proof"] as? [String: Any] else { throw TowerError.malformed("connection proof") }
        try WorkspaceConnection.shape(proof, ["kind", "created_at", "tags", "content", "pubkey", "id", "sig"])
        try connection.verifyProof(JSONDecoder().decode(Response.self, from: data).proof, nonce: nonce, url: url)
        let candidates = try await workspaces().filter { $0.id == connection.workspace_id }
        guard candidates.count == 1, let workspace = candidates.first else { throw TowerError.descriptor("configure one authorized app namespace for this workspace, or use the existing namespace chooser") }
        guard let raw = try JSONSerialization.jsonObject(with: workspace.raw) as? [String: Any], let identity = raw["identity"] as? [String: Any],
              identity["workspace_service_npub"] as? String == connection.workspace_service_npub,
              identity["tower_service_npub"] as? String == connection.service_npub else { throw TowerError.descriptor("workspace authority mismatch") }
        let me = try await client.request(path: Self.base(workspace.id) + "/me", appNpub: workspace.appNpub)
        guard let body = try JSONSerialization.jsonObject(with: me) as? [String: Any], let i = body["identity"] as? [String: Any],
              i["workspace_id"] as? String == connection.workspace_id, i["workspace_service_npub"] as? String == connection.workspace_service_npub,
              i["tower_service_npub"] as? String == connection.service_npub, i["app_npub"] as? String == workspace.appNpub else { throw TowerError.descriptor("workspace membership identity mismatch") }
        return workspace
    }
}
