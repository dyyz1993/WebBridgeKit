import Foundation
import UserNotifications
import WebBridgeKit

/// NSE glue for end-to-end encrypted pushes: reads the shared key from the
/// app-group defaults, decrypts via the framework's PushCipher contract,
/// and publishes the plaintext through both the notification content and
/// the plist recorder — so banners, taps, and inbox imports all see the
/// same decrypted fields while the server only ever relayed ciphertext.
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

        guard let keyData = sharedKeyValue() else {
            return failure(content, reason: "密钥未在本机配置")
        }

        let plain: [String: Any]
        do {
            plain = try PushCipher.decrypt(ciphertextBase64: ciphertext, keyData: keyData)
        } catch {
            return failure(content, reason: "无法解密这条加密推送（密钥不匹配或载荷损坏）")
        }

        let decrypted = PushCipher.merging(plaintext: plain, onto: userInfo)

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
        // Do NOT set content.sound here: an NSE-assigned named sound makes
        // SpringBoard drop the whole notification on iOS 18.7.3 (same family
        // as the call=1 respring crash — server-assigned named sounds are
        // fine, NSE-assigned ones are not). The decrypted sound still reaches
        // the inbox payload for display; delivery plays the original.

        // Publish the decrypted fields through userInfo too: the app's
        // willPresent/didReceive recorders read userInfo (not title/body),
        // so without this the banner shows plaintext while the inbox row
        // lands with the raw empty fields.
        content.userInfo = decrypted
        return (content, decrypted)
    }

    private static func failure(
        _ content: UNMutableNotificationContent,
        reason: String
    ) -> (content: UNMutableNotificationContent, recordedUserInfo: [AnyHashable: Any]) {
        content.title = "解密失败"
        content.body = reason
        return (content, ["title": content.title, "body": content.body])
    }

    private static func sharedKeyValue() -> Data? {
        UserDefaults(suiteName: "group.com.webbridgekit.superapp")?
            .data(forKey: sharedDefaultsKey)
    }
}
