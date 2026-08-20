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
    private static let suiteName = "group.com.webbridgekit.superapp"
    private static let defaultsKey = "wbk.push-crypto.aes-key"
    private static let keyFile = "push-crypto.key"

    /// Decrypts and applies the payload when `ciphertext` is present.
    /// Returns the content to deliver plus the userInfo dict the plist
    /// recorder should persist (decrypted fields when encryption applied).
    static func process(
        _ content: UNMutableNotificationContent,
        userInfo: [AnyHashable: Any]
    ) -> (content: UNMutableNotificationContent, recordedUserInfo: [AnyHashable: Any]) {
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

        var decrypted = userInfo
        decrypted.removeValue(forKey: ciphertextField)
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

    private static func failure(
        _ content: UNMutableNotificationContent,
        reason: String
    ) -> (content: UNMutableNotificationContent, recordedUserInfo: [AnyHashable: Any]) {
        content.title = "解密失败"
        content.body = reason
        return (content, ["title": content.title, "body": content.body])
    }
}
