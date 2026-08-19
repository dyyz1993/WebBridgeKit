import CryptoKit
import Foundation
import UserNotifications

/// End-to-end encrypted push decryption (NSE side).
///
/// Contract (v1):
/// - The sender encrypts the full message-field JSON object with AES-GCM
///   using the 128-bit key shared out-of-band (shown in PushEncryptionView).
/// - The push carries only `{"ciphertext": "<base64(nonce||ct||tag)>"}`.
/// - The NSE decrypts with the key mirrored into the app-group defaults,
///   applies the plaintext fields to the notification, and records the
///   DECRYPTED payload so the inbox stores the readable message — the
///   server never sees plaintext, matching Bark's ciphertext flow.
enum PushCrypto {

    static let ciphertextField = "ciphertext"

    private static let sharedDefaultsKey = "wbk.push-crypto.aes-key"

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

        guard let keyData = sharedKeyValue(),
              let key = try? AES.GCM.Key(keyData: keyData),
              let sealed = try? AES.GCM.SealedBox(combined: Data(base64Encoded: ciphertext)),
              let plainData = try? AES.GCM.open(sealed, using: key),
              let plain = (try? JSONSerialization.jsonObject(with: plainData)) as? [String: Any]
        else {
            content.title = "解密失败"
            content.body = "无法解密这条加密推送（密钥不匹配或载荷损坏）"
            return (content, ["title": content.title, "body": content.body])
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
        if let soundName = plain["sound"] as? String {
            var name = soundName
            if !name.hasSuffix(".caf") { name += ".caf" }
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: name))
        }

        return (content, decrypted)
    }

    private static func sharedKeyValue() -> Data? {
        UserDefaults(suiteName: "group.com.webbridgekit.superapp")?
            .data(forKey: sharedDefaultsKey)
    }
}
