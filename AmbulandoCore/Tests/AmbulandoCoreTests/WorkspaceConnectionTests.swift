import XCTest
@testable import AmbulandoCore

final class WorkspaceConnectionTests: XCTestCase {
    struct Fixture: Decodable { let now: Int; let envelope: String; let nonce: String; let request_url: String; let proof: NostrEvent; let rejected_envelopes: [String]; let rejected_proofs: [NostrEvent] }
    func fixture() throws -> Fixture {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/workspace-connection-v3.json")
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }
    func testTowerBytesAndNonceProofInteroperate() throws {
        let f = try fixture(); let qr = try WorkspaceConnection.parse(f.envelope, now: f.now)
        XCTAssertEqual(qr.workspace_id, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(qr.policy.preferred, "fips")
        XCTAssertEqual(try qr.origin(mode: "https").description, "https://tower.example")
        XCTAssertThrowsError(try qr.origin(mode: "fips"))
        for envelope in f.rejected_envelopes { XCTAssertThrowsError(try WorkspaceConnection.parse(envelope, now: f.now)) }
        for proof in f.rejected_proofs { XCTAssertThrowsError(try qr.verifyProof(proof, nonce: f.nonce, url: f.request_url, now: f.now)) }
        try qr.verifyProof(f.proof, nonce: f.nonce, url: f.request_url, now: f.now)
        XCTAssertThrowsError(try qr.verifyProof(f.proof, nonce: String(repeating: "cd", count: 32), url: f.request_url, now: f.now))
        XCTAssertThrowsError(try qr.verifyProof(f.proof, nonce: f.nonce, url: f.request_url + "x", now: f.now))
        XCTAssertThrowsError(try qr.verifyProof(f.proof, nonce: f.nonce, url: f.request_url, now: f.now + 60))
    }
    func testMalformedSignatureAndCanonicalShape() throws {
        let f = try fixture()
        for s in [f.envelope + "=", "nstack:workspace:v2:abc", WorkspaceConnection.prefix + String(repeating: "a", count: 8192)] {
            XCTAssertThrowsError(try WorkspaceConnection.parse(s, now: f.now))
        }
        let b64 = String(f.envelope.dropFirst(WorkspaceConnection.prefix.count)).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let raw = String(data: Data(base64Encoded: b64 + String(repeating: "=", count: (4 - b64.count % 4) % 4))!, encoding: .utf8)!
        func encode(_ s: String) -> String { WorkspaceConnection.prefix + Data(s.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
        for replacement in ["{ ", "{\"kind\":30383,", "{\"extra\":true,"] {
            let altered = raw.replacingCharacters(in: raw.startIndex...raw.startIndex, with: replacement)
            XCTAssertThrowsError(try WorkspaceConnection.parse(encode(altered), now: f.now))
        }
        XCTAssertThrowsError(try WorkspaceConnection.parse(encode(raw.replacingOccurrences(of: "\"sig\":\"", with: "\"sig\":\"00")), now: f.now))
    }
    func testDeniedChallengeUsesOwnIdentityAndNeverCreatesAnything() async throws {
        let f = try fixture(); let qr = try WorkspaceConnection.parse(f.envelope, now: f.now)
        let identity = try await makeIdentity()
        let transport = StubTransport { _ in (403, ["code": "forbidden"]) }
        let api = TowerAPI(client: TowerClient(origin: try qr.origin(mode: "https"), transport: transport, signer: identity))
        do { _ = try await api.connectionWorkspace(qr); XCTFail("Expected denial") } catch { XCTAssertEqual((error as? TowerError), .http(status: 403, code: "forbidden", stage: nil)) }
        XCTAssertEqual(transport.recorded.count, 1)
        let request = transport.recorded[0]
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url!.absoluteString.contains("/" + qr.workspace_id + "/connection-proof?nonce="))
        XCTAssertNil(request.value(forHTTPHeaderField: "x-flightdeck-pg-app-npub"))
        let auth = try decodeAuthorization(request)
        XCTAssertEqual(auth.pubkey, TestKeys.pubkeyHex)
        XCTAssertTrue(auth.tags.contains(["u", request.url!.absoluteString]))
    }

}
