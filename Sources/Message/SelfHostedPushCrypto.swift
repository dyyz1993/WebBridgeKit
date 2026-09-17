import CryptoKit
import Foundation

/// The Drel self-hosted push envelope. A server encrypts one envelope for one
/// paired installation; the APNs payload therefore carries no message
/// plaintext, URL, verification code, or device secret.
///
/// The private X25519 key lives in the Drel App Group so the notification
/// service extension can decrypt while the host app is not running. The file
/// is protected with `CompleteUntilFirstUserAuthentication`, which is the
/// strongest protection compatible with a locked-device notification after
/// the user has unlocked the phone once since boot.
public enum SelfHostedPushCrypto {

    public enum EnvelopeError: Error, Equatable {
        case invalidEnvelope
        case expired
        case decryptionFailed
        case invalidPayload
    }

    public struct Identity: Equatable, Sendable {
        /// Base64url X25519 public key. This is safe to send to a paired
        /// server; the matching private key never leaves the iPhone.
        public let publicKey: String

        fileprivate let privateKey: Curve25519.KeyAgreement.PrivateKey

        fileprivate init(privateKey: Curve25519.KeyAgreement.PrivateKey) {
            self.privateKey = privateKey
            self.publicKey = SelfHostedPushCrypto.base64URLEncoded(privateKey.publicKey.rawRepresentation)
        }

        public static func == (lhs: Identity, rhs: Identity) -> Bool {
            lhs.publicKey == rhs.publicKey
        }
    }

    private struct Envelope: Codable {
        let schema: String
        let messageID: String
        let createdAt: Int
        let expiresAt: Int
        let ephemeralPublicKey: String
        let ciphertext: String
    }

    public static let schema = "drel.push-envelope.v1"
    public static let sharedDefaultsSuite = "group.com.webbridgekit.superapp"
    public static let privateKeyFileSubpath = "drel-selfhosted-push.x25519-private-key"
    private static let privateKeyDefaultsKey = "drel.selfhosted-push.x25519-private-key"
    private static let uiTestingPrivateKeyDefaultsKey = "drel.selfhosted-push.x25519-private-key.ui-testing"

    /// Creates a per-installation encryption identity exactly once. The
    /// result is intentionally device-scoped: copying a server address to a
    /// second iPhone creates a second public key and a second envelope.
    public static func currentOrCreateIdentity() throws -> Identity {
        if let privateKey = sharedPrivateKey() {
            return Identity(privateKey: privateKey)
        }
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        try storePrivateKey(privateKey.rawRepresentation)
        return Identity(privateKey: privateKey)
    }

    /// Permanently removes this installation's self-hosted recipient key.
    /// Use this when disconnecting a server so an old registration cannot keep
    /// producing envelopes this device will decrypt.
    public static func discardIdentity() {
        UserDefaults(suiteName: sharedDefaultsSuite)?.removeObject(forKey: privateKeyDefaultsKey)
        #if DEBUG
        if isUITestingProcess {
            UserDefaults.standard.removeObject(forKey: uiTestingPrivateKeyDefaultsKey)
        }
        #endif
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: sharedDefaultsSuite
        ) else { return }
        try? FileManager.default.removeItem(at: container.appendingPathComponent(privateKeyFileSubpath))
    }

    /// Rotates the recipient identity before connecting to a different server.
    /// Servers are intentionally not allowed to share a stable recipient key.
    public static func rotateIdentity() throws -> Identity {
        discardIdentity()
        return try currentOrCreateIdentity()
    }

    /// Decrypts a self-hosted Drel envelope to the exact JSON object the
    /// regular push mapper consumes.
    public static func decrypt(envelopeBase64URL: String, privateKeyData: Data, now: Date = Date()) throws -> [String: Any] {
        guard let privateKey = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData),
              let data = base64URLDecoded(envelopeBase64URL),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.schema == schema,
              let ephemeralData = base64URLDecoded(envelope.ephemeralPublicKey),
              let ephemeral = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralData),
              let combined = base64URLDecoded(envelope.ciphertext),
              let sealed = try? AES.GCM.SealedBox(combined: combined)
        else {
            throw EnvelopeError.invalidEnvelope
        }
        guard envelope.expiresAt > Int(now.timeIntervalSince1970) else {
            throw EnvelopeError.expired
        }

        do {
            let secret = try privateKey.sharedSecretFromKeyAgreement(with: ephemeral)
            let key = secret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: Data(),
                sharedInfo: associatedData(
                    messageID: envelope.messageID,
                    createdAt: envelope.createdAt,
                    expiresAt: envelope.expiresAt
                ),
                outputByteCount: 32
            )
            let plaintext = try AES.GCM.open(sealed, using: key)
            guard let object = try JSONSerialization.jsonObject(with: plaintext) as? [String: Any] else {
                throw EnvelopeError.invalidPayload
            }
            return object
        } catch let error as EnvelopeError {
            throw error
        } catch {
            throw EnvelopeError.decryptionFailed
        }
    }

    /// Returns the normal Drel userInfo after decrypting a Drel envelope. A
    /// nil result means no self-hosted envelope was present; callers can then
    /// continue through the legacy ciphertext path unchanged.
    public static func decryptingUserInfoIfPresent(_ userInfo: [AnyHashable: Any]) -> [AnyHashable: Any]? {
        guard let envelope = userInfo["drelEnvelope"] as? String, !envelope.isEmpty else {
            return nil
        }
        guard let privateKey = sharedPrivateKey(),
              let plaintext = try? decrypt(envelopeBase64URL: envelope, privateKeyData: privateKey.rawRepresentation)
        else {
            return nil
        }
        return PushCipher.merging(
            plaintext: plaintext,
            onto: userInfo,
            removingEnvelopeFields: ["drelEnvelope"]
        )
    }

    private static func sharedPrivateKey() -> Curve25519.KeyAgreement.PrivateKey? {
        if let data = UserDefaults(suiteName: sharedDefaultsSuite)?.data(forKey: privateKeyDefaultsKey),
           let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data) {
            ensureFileMirror(data)
            return key
        }
        #if DEBUG
        // UI tests use an unsigned simulator build, which intentionally has no
        // App Group container. Keep this fallback out of every normal app
        // process; it is only a test harness for exercising the pairing UI.
        if isUITestingProcess,
           let data = UserDefaults.standard.data(forKey: uiTestingPrivateKeyDefaultsKey),
           let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data) {
            return key
        }
        #endif
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: sharedDefaultsSuite
        ) else { return nil }
        let url = container.appendingPathComponent(privateKeyFileSubpath)
        guard let data = try? Data(contentsOf: url),
              let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data) else {
            return nil
        }
        UserDefaults(suiteName: sharedDefaultsSuite)?.set(data, forKey: privateKeyDefaultsKey)
        return key
    }

    private static func storePrivateKey(_ data: Data) throws {
        UserDefaults(suiteName: sharedDefaultsSuite)?.set(data, forKey: privateKeyDefaultsKey)
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: sharedDefaultsSuite
        ) else {
            #if DEBUG
            if isUITestingProcess {
                UserDefaults.standard.set(data, forKey: uiTestingPrivateKeyDefaultsKey)
                return
            }
            #endif
            throw EnvelopeError.invalidPayload
        }
        let url = container.appendingPathComponent(privateKeyFileSubpath)
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes(
            [.protectionKey: "NSFileProtectionCompleteUntilFirstUserAuthentication"],
            ofItemAtPath: url.path
        )
    }

    private static func ensureFileMirror(_ data: Data) {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: sharedDefaultsSuite
        ) else { return }
        let url = container.appendingPathComponent(privateKeyFileSubpath)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? data.write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.protectionKey: "NSFileProtectionCompleteUntilFirstUserAuthentication"],
            ofItemAtPath: url.path
        )
    }

    private static func associatedData(messageID: String, createdAt: Int, expiresAt: Int) -> Data {
        Data("\(schema)|\(messageID)|\(createdAt)|\(expiresAt)".utf8)
    }

    private static var isUITestingProcess: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-UITesting") || arguments.contains("--UITesting") || arguments.contains("--ui-testing")
    }

    fileprivate static func base64URLEncoded(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    fileprivate static func base64URLDecoded(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64)
    }
}
