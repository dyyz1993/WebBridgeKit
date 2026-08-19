import CryptoKit
import Security
import Foundation

/// Pure end-to-end encryption primitives for push payloads.
///
/// Wire contract (v1): the sender encrypts the message-field JSON object
/// with AES-GCM using a shared 128-bit key; the push carries only
/// `ciphertext = base64(nonce || encrypted || tag)` — exactly CryptoKit's
/// `AES.GCM.SealedBox.combined` layout, so browser WebCrypto and python
/// cryptography produce interchangeable ciphertexts.
///
/// Kept free of UserNotifications dependencies so the contract is unit
/// testable inside the framework; the NSE supplies the content glue.
public enum PushCipher {

    public enum CipherError: Error, Equatable {
        case invalidBase64
        case keyNotAvailable
        case decryptionFailed
        case invalidJSON
    }

    /// Decrypts a wire ciphertext into the plaintext message-field dictionary.
    public static func decrypt(ciphertextBase64: String, keyData: Data) throws -> [String: Any] {
        guard let combined = Data(base64Encoded: ciphertextBase64) else {
            throw CipherError.invalidBase64
        }
        let key = SymmetricKey(data: keyData)
        guard let sealed = try? AES.GCM.SealedBox(combined: combined),
              let plainData = try? AES.GCM.open(sealed, using: key) else {
            throw CipherError.decryptionFailed
        }
        guard let json = (try? JSONSerialization.jsonObject(with: plainData)) as? [String: Any] else {
            throw CipherError.invalidJSON
        }
        return json
    }

    /// Merges decrypted plaintext fields onto the raw wire userInfo,
    /// removing the ciphertext envelope. This is the exact dictionary the
    /// NSE publishes via content.userInfo and the plist recorder persists.
    public static func merging(
        plaintext: [String: Any],
        onto userInfo: [AnyHashable: Any],
        removingEnvelopeFields: Set<String> = ["ciphertext"]
    ) -> [AnyHashable: Any] {
        var merged = userInfo
        for field in removingEnvelopeFields {
            merged.removeValue(forKey: field)
        }
        for (rawKey, value) in plaintext {
            guard let key = rawKey as? String else { continue }
            merged[key] = value
        }
        return merged
    }

    /// App-group container shared by the app and the notification service
    /// extension, where the symmetric key is mirrored for both processes.
    public static let sharedDefaultsSuite = "group.com.webbridgekit.superapp"
    private static let sharedDefaultsKey = "wbk.push-crypto.aes-key"
    /// File mirror of the key inside the app-group container. The service
    /// extension sometimes cannot read the shared UserDefaults plist while
    /// the device is locked (file protection); a plain file with
    /// until-first-unlock protection is readable in every push scenario.
    public static let keyFileSubpath = "push-crypto.key"

    /// Reads the shared key from both mirrors (defaults first, file second).
    public static func sharedKey() -> Data? {
        if let data = UserDefaults(suiteName: sharedDefaultsSuite)?
            .data(forKey: sharedDefaultsKey) {
            // Bidirectional healing: a defaults hit must also guarantee the
            // file mirror exists — the NSE falls back to the file when the
            // defaults plist is unreadable while locked, and nothing else
            // would ever create it for keys written before the mirror.
            ensureFileMirror(data)
            return data
        }
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: sharedDefaultsSuite)
        else { return nil }
        let url = container.appendingPathComponent(keyFileSubpath)
        if let data = try? Data(contentsOf: url) {
            // Heal the defaults mirror from the file.
            UserDefaults(suiteName: sharedDefaultsSuite)?
                .set(data, forKey: sharedDefaultsKey)
            return data
        }
        // Third tier: the keychain original survives app deletion (iOS
        // platform behavior), so after a delete+reinstall the key
        // resurrects from here into both mirrors — the user never loses
        // their key by reinstalling.
        if let data = keychainCopy() {
            storeSharedKey(data)
            return data
        }
        return nil
    }

    /// Reads the keychain original written by PushEncryptionView. Keychain
    /// items outlive the app itself; only the main app can read this item
    /// (default access group), which is exactly who performs resurrection.
    private static func keychainCopy() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.webbridgekit.superapp.push-crypto",
            kSecAttrAccount as String: "shared-aes-key",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func ensureFileMirror(_ data: Data) {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: sharedDefaultsSuite)
        else { return }
        let url = container.appendingPathComponent(keyFileSubpath)
        if FileManager.default.fileExists(atPath: url.path) { return }
        try? data.write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.protectionKey: "NSFileProtectionCompleteUntilFirstUserUnlock"],
            ofItemAtPath: url.path
        )
    }

    /// Writes the key to both mirrors with until-first-unlock protection.
    public static func storeSharedKey(_ data: Data) {
        UserDefaults(suiteName: sharedDefaultsSuite)?
            .set(data, forKey: sharedDefaultsKey)
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: sharedDefaultsSuite)
        else { return }
        let url = container.appendingPathComponent(keyFileSubpath)
        try? data.write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.protectionKey: "NSFileProtectionCompleteUntilFirstUserUnlock"],
            ofItemAtPath: url.path
        )
    }

    /// Consumer-side decryption: given ANY wire userInfo dict (from a
    /// notification handler or a replayed plist), decrypt it in place if it
    /// still carries a ciphertext envelope. First-principles rule: every
    /// consumer decrypts for itself instead of trusting the NSE's modified
    /// content.userInfo to survive delivery — so the banner path, the tap
    /// path, and both replay tiers all converge on plaintext no matter
    /// which hop dropped the decryption. Returns the input unchanged when
    /// no envelope is present.
    public static func decryptingUserInfoIfEncrypted(
        _ userInfo: [AnyHashable: Any]
    ) -> [AnyHashable: Any] {
        guard let ciphertext = userInfo["ciphertext"] as? String,
              !ciphertext.isEmpty
        else { return userInfo }
        guard let keyData = sharedKey() else { return userInfo }
        guard let plain = try? decrypt(ciphertextBase64: ciphertext, keyData: keyData)
        else { return userInfo }
        return merging(plaintext: plain, onto: userInfo)
    }
}
