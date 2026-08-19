import CryptoKit
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
}
