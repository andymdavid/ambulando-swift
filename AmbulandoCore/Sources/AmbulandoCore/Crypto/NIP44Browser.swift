import Foundation
import P256K

/// What a page may ask `window.nostr.nip44` to do. The page's values are untrusted: pubkeys and payloads are checked
/// against the NIP-44 v2 limits before any key material is touched.
public enum NIP44Operation: Equatable, Sendable {
    case encrypt(peer: String, plaintext: String)
    case decrypt(peer: String, payload: String)

    public var peer: String {
        switch self {
        case .encrypt(let peer, _), .decrypt(let peer, _): peer
        }
    }
}

extension NIP44 {
    /// NIP-44 v2 limits: plaintext 1…65535 bytes, payload 132…87472 base64 characters.
    public static let maxPlaintextBytes = 65535
    public static let payloadLengthRange = 132...87472

    /// A 32-byte x-only public key as 64 lowercase hex characters (NIP-01).
    public static func isHexPublicKey(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }
    }

    /// The conversation key for `secret` and an x-only `peer` public key (shared x coordinate run through HKDF-extract
    /// with the `nip44-v2` salt). Throws if the peer is not a point on the curve or the secret is not a valid scalar.
    public static func conversationKey(secret: Data, peer: String) throws -> Data {
        guard isHexPublicKey(peer), let x = Data(hex: peer) else { throw TowerError.malformed("Invalid public key.") }
        let privateKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: secret)
        let publicKey: P256K.KeyAgreement.PublicKey
        do { publicKey = try P256K.KeyAgreement.PublicKey(dataRepresentation: Data([2]) + x, format: .compressed) } catch {
            throw TowerError.malformed("Invalid public key.")
        }
        let shared = privateKey.sharedSecretFromKeyAgreement(with: publicKey)
        return hmac(Data("nip44-v2".utf8), Data(shared.bytes).suffix(32))
    }

    /// Spec-strict encryption for pages: refuses the larger payloads the internal index format allows.
    public static func encryptStrict(_ plaintext: String, key: Data, nonce: Data? = nil) throws -> String {
        let data = Data(plaintext.utf8)
        guard (1...maxPlaintextBytes).contains(data.count) else { throw TowerError.malformed("Invalid encrypted payload size.") }
        return try encrypt(data, key: key, nonce: nonce)
    }

    /// Spec-strict decryption for pages: no `#` future-version marker, bounded length, plaintext at most 65535 bytes.
    public static func decryptStrict(_ payload: String, key: Data) throws -> String {
        guard payloadLengthRange.contains(payload.utf8.count), !payload.hasPrefix("#") else {
            throw TowerError.malformed("Invalid NIP-44 payload.")
        }
        let clear = try decrypt(payload, key: key)
        guard clear.count <= maxPlaintextBytes, let text = String(data: clear, encoding: .utf8) else {
            throw TowerError.malformed("Invalid encrypted text.")
        }
        return text
    }
}
