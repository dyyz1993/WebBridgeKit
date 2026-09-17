import CryptoKit
import Foundation
import UserNotifications

/// NSE glue for end-to-end encrypted pushes.
///
/// Deliberately SELF-CONTAINED (no WebBridgeKit import): the extension
/// target must not drag the framework's CocoaPods graph. The crypto logic
/// mirrors the framework's PushCipher contract — locked by
/// PushCipherContractTests — so keep the two in sync when the wire format
/// changes.
///
/// Key storage contract (all written by the app):
/// 1. App-group UserDefaults: wbk.push-crypto.aes-key
/// 2. App-group file "push-crypto.key" (until-first-unlock protection)
/// The app resurrects the key from the keychain on every launch, so both
/// mirrors are expected to exist by the time a push arrives.
enum PushCrypto {

    static let ciphertextField = "ciphertext"
    static let selfHostedEnvelopeField = "drelEnvelope"
    private static let suiteName = "group.com.webbridgekit.superapp"
    private static let defaultsKey = "wbk.push-crypto.aes-key"
    private static let keyFile = "push-crypto.key"
    private static let selfHostedPrivateKeyDefaultsKey = "drel.selfhosted-push.x25519-private-key"
    private static let selfHostedPrivateKeyFile = "drel-selfhosted-push.x25519-private-key"
    private static let selfHostedSchema = "drel.push-envelope.v1"

    private struct SelfHostedEnvelope: Codable {
        let schema: String
        let messageID: String
        let createdAt: Int
        let expiresAt: Int
        let ephemeralPublicKey: String
        let ciphertext: String
    }

    /// Decrypts and applies the payload when `ciphertext` is present.
    /// Returns the content to deliver plus the userInfo dict the plist
    /// recorder should persist (decrypted fields when encryption applied).
    static func process(
        _ content: UNMutableNotificationContent,
        userInfo: [AnyHashable: Any]
    ) -> (content: UNMutableNotificationContent, recordedUserInfo: [AnyHashable: Any]) {
        if let envelope = userInfo[selfHostedEnvelopeField] as? String, !envelope.isEmpty {
            guard let plain = decryptSelfHostedEnvelope(envelope) else {
                return failure(content, reason: "这是一条来自已配对私有服务器的加密消息，但本机密钥不可用或消息已过期。")
            }
            return applyDecrypted(plain, content: content, userInfo: userInfo, removing: selfHostedEnvelopeField)
        }

        guard let ciphertext = userInfo[ciphertextField] as? String,
              !ciphertext.isEmpty
        else {
            return (content, userInfo)
        }

        guard let keyData = readKey() else {
            return failure(content, reason: "这是一条加密消息。打开 App 的 设置 → 通知 → 推送加密 生成密钥后即可阅读。")
        }

        guard let plain = decrypt(ciphertextBase64: ciphertext, keyData: keyData) else {
            return failure(content, reason: "无法解密这条加密推送（密钥不匹配或载荷损坏）")
        }

        return applyDecrypted(plain, content: content, userInfo: userInfo, removing: ciphertextField)
    }

    private static func applyDecrypted(
        _ plain: [String: Any],
        content: UNMutableNotificationContent,
        userInfo: [AnyHashable: Any],
        removing field: String
    ) -> (content: UNMutableNotificationContent, recordedUserInfo: [AnyHashable: Any]) {
        var decrypted = userInfo
        decrypted.removeValue(forKey: field)
        for (rawKey, value) in plain {
            guard let key = rawKey as? String else { continue }
            decrypted[key] = value
        }

        let aps = plain["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]
        if let title = (plain["title"] as? String) ?? (alert?["title"] as? String) {
            content.title = title
        }
        if let subtitle = plain["subtitle"] as? String {
            content.subtitle = subtitle
        }
        if let body = (plain["body"] as? String) ?? (alert?["body"] as? String) {
            content.body = body
        }
        if let group = plain["group"] as? String {
            content.threadIdentifier = group
        }
        // Do NOT set content.sound: an NSE-assigned named sound makes
        // SpringBoard drop the whole notification on iOS 18.7.3. The
        // decrypted sound still reaches the inbox payload for display.

        content.userInfo = decrypted
        return (content, decrypted)
    }

    // MARK: - Crypto (mirrors PushCipher contract)

    private static func decrypt(ciphertextBase64: String, keyData: Data) -> [String: Any]? {
        guard let combined = Data(base64Encoded: ciphertextBase64),
              let sealed = try? AES.GCM.SealedBox(combined: combined),
              let plainData = try? AES.GCM.open(sealed, using: SymmetricKey(data: keyData)),
              let json = (try? JSONSerialization.jsonObject(with: plainData)) as? [String: Any]
        else { return nil }
        return json
    }

    private static func readKey() -> Data? {
        if let data = UserDefaults(suiteName: suiteName)?.data(forKey: defaultsKey) {
            return data
        }
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: suiteName)
        else { return nil }
        return try? Data(contentsOf: container.appendingPathComponent(keyFile))
    }

    private static func decryptSelfHostedEnvelope(_ encoded: String, now: Date = Date()) -> [String: Any]? {
        guard let privateKeyData = readSelfHostedPrivateKey(),
              let privateKey = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData),
              let envelopeData = base64URLDecoded(encoded),
              let envelope = try? JSONDecoder().decode(SelfHostedEnvelope.self, from: envelopeData),
              envelope.schema == selfHostedSchema,
              envelope.expiresAt > Int(now.timeIntervalSince1970),
              let ephemeralData = base64URLDecoded(envelope.ephemeralPublicKey),
              let ephemeral = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralData),
              let ciphertext = base64URLDecoded(envelope.ciphertext),
              let sealed = try? AES.GCM.SealedBox(combined: ciphertext)
        else { return nil }

        do {
            let secret = try privateKey.sharedSecretFromKeyAgreement(with: ephemeral)
            let associatedData = Data(
                "\(selfHostedSchema)|\(envelope.messageID)|\(envelope.createdAt)|\(envelope.expiresAt)".utf8
            )
            let key = secret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: Data(),
                sharedInfo: associatedData,
                outputByteCount: 32
            )
            let plaintext = try AES.GCM.open(sealed, using: key)
            return try JSONSerialization.jsonObject(with: plaintext) as? [String: Any]
        } catch {
            return nil
        }
    }

    private static func readSelfHostedPrivateKey() -> Data? {
        if let data = UserDefaults(suiteName: suiteName)?.data(forKey: selfHostedPrivateKeyDefaultsKey) {
            return data
        }
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: suiteName)
        else { return nil }
        return try? Data(contentsOf: container.appendingPathComponent(selfHostedPrivateKeyFile))
    }

    private static func base64URLDecoded(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64)
    }

    private static func failure(
        _ content: UNMutableNotificationContent,
        reason: String
    ) -> (content: UNMutableNotificationContent, recordedUserInfo: [AnyHashable: Any]) {
        content.title = "解密失败"
        content.body = reason
        return (content, ["title": content.title, "body": content.body])
    }
}
