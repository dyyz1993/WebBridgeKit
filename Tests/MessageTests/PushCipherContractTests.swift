import XCTest
@testable import WebBridgeKit

/// Automated end-to-end decryption contract: a ciphertext produced by the
/// documented sender stack (python cryptography / browser WebCrypto, same
/// layout as CryptoKit's SealedBox.combined) must decrypt, merge, and map
/// into a stored inbox message with full plaintext fidelity — the exact
/// chain the NSE + importer run on device.
final class PushCipherContractTests: XCTestCase {

    /// Fixed vector: key 3ODfqVpzY+MOyn+i0oOMPg== , nonce 00..0B,
    /// plaintext JSON with title/body/sound/contentType/verificationCode.
    private static let vectorCiphertext =
        "AAECAwQFBgcICQoL7QDIFoZ2P6lWoEsVFVFYzVxila6Rec5+C0q8x+kwTCkNOsIhCxFuhfqZ3P+GuOYD3iEISSGd2htF5q+9+fNRT29e/FhX4BBTrQBYM1bCHi7IszRfzMicW3YBReqSin7q/pel0sdX87KKBi4CM9x9OwiSzQZtm2BVQQ6xBrKV9GxuCspMbnUzoVQhNYPu8E6bl/S9Vs4="
    private static let vectorKey = Data(base64Encoded: "3ODfqVpzY+MOyn+i0oOMPg==")!

    func testDecryptFixedVector() throws {
        let plain = try PushCipher.decrypt(
            ciphertextBase64: Self.vectorCiphertext,
            keyData: Self.vectorKey
        )
        XCTAssertEqual(plain["title"] as? String, "🔐 契约向量")
        XCTAssertEqual(plain["body"] as? String, "自动化解密验证")
        XCTAssertEqual(plain["verificationCode"] as? String, "135790")
    }

    func testDecryptRejectsWrongKeyAndGarbage() {
        let wrongKey = Data(repeating: 0x41, count: 16)
        XCTAssertThrowsError(
            try PushCipher.decrypt(ciphertextBase64: Self.vectorCiphertext, keyData: wrongKey)
        ) { error in
            XCTAssertEqual(error as? PushCipher.CipherError, .decryptionFailed)
        }
        XCTAssertThrowsError(
            try PushCipher.decrypt(ciphertextBase64: "!!!not-base64!!!", keyData: Self.vectorKey)
        ) { error in
            XCTAssertEqual(error as? PushCipher.CipherError, .invalidBase64)
        }
    }

    func testMergingRemovesEnvelopeAndOverlaysPlaintext() {
        let wire: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "加密消息"]],
            "title": "",
            "body": "",
            "ciphertext": "AAAA",
            "messageId": "vec-1"
        ]
        let plain: [String: Any] = ["title": "🔐 契约向量", "body": "自动化解密验证", "sound": "alarm"]
        let merged = PushCipher.merging(plaintext: plain, onto: wire)

        XCTAssertNil(merged["ciphertext"])
        XCTAssertEqual(merged["title"] as? String, "🔐 契约向量")
        XCTAssertEqual(merged["body"] as? String, "自动化解密验证")
        XCTAssertEqual(merged["messageId"] as? String, "vec-1")
        XCTAssertNotNil(merged["aps"])  // untouched envelope fields survive
    }

    /// The full device chain: wire userInfo → decrypt → merge → payload
    /// mapper → engine receive → stored message retains plaintext.
    func testFullChainStoresPlaintextMessage() async throws {
        let store = UserDefaultsMessageStore(
            suiteName: "test-pushcipher-contract",
            key: "PushCipherContractTests",
            maxMessages: 10
        )
        await store.deleteAll()

        let wire: [AnyHashable: Any] = [
            "title": "",
            "body": "",
            "ciphertext": Self.vectorCiphertext,
            "messageId": "vec-full-1"
        ]
        let plain = try PushCipher.decrypt(ciphertextBase64: Self.vectorCiphertext, keyData: Self.vectorKey)
        let decrypted = PushCipher.merging(plaintext: plain, onto: wire)

        // This is precisely what PendingMessageImporter does with the plist
        let payload = NotificationPayloadMapper.makePayload(
            identifier: "msg-vec.plist",
            userInfo: decrypted
        )
        XCTAssertEqual(payload.title, "🔐 契约向量")
        XCTAssertEqual(payload.verificationCode, "135790")

        try await store.save(StoredMessage(payload: payload))
        let stored = await store.getAll()
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.payload.title, "🔐 契约向量")
        XCTAssertEqual(stored.first?.payload.verificationCode, "135790")
        await store.deleteAll()
    }

    /// Consumer-side rule: a RAW wire userInfo (as delivered when the NSE's
    /// modified userInfo does not survive) must still decrypt in place.
    func testConsumerDecryptsRawWireUserInfoInPlace() throws {
        UserDefaults(suiteName: PushCipher.sharedDefaultsSuite)?
            .set(Self.vectorKey, forKey: "wbk.push-crypto.aes-key")

        let raw: [AnyHashable: Any] = [
            "title": "",
            "body": "",
            "ciphertext": Self.vectorCiphertext,
            "messageId": "vec-consumer-1"
        ]
        let healed = PushCipher.decryptingUserInfoIfEncrypted(raw)
        XCTAssertEqual(healed["title"] as? String, "🔐 契约向量")
        XCTAssertEqual(healed["body"] as? String, "自动化解密验证")
        XCTAssertNil(healed["ciphertext"])
        XCTAssertEqual(healed["messageId"] as? String, "vec-consumer-1")

        // 无信封时原样返回
        let plain: [AnyHashable: Any] = ["title": "普通消息"]
        let unchanged = PushCipher.decryptingUserInfoIfEncrypted(plain)
        XCTAssertEqual(unchanged["title"] as? String, "普通消息")
    }

    /// Dual-channel key storage: defaults mirror plus a protected file the
    /// NSE can read even when the shared UserDefaults plist is unavailable.
    func testDualChannelKeyStorageRoundTrip() {
        let suite = UserDefaults(suiteName: PushCipher.sharedDefaultsSuite)
        suite?.removeObject(forKey: "wbk.push-crypto.aes-key")
        suite?.set(Self.vectorKey, forKey: "wbk.push-crypto.aes-key")

        // defaults mirror hit
        XCTAssertEqual(PushCipher.sharedKey(), Self.vectorKey)

        // defaults empty → file mirror serves and heals defaults
        suite?.removeObject(forKey: "wbk.push-crypto.aes-key")
        PushCipher.storeSharedKey(Self.vectorKey)
        suite?.removeObject(forKey: "wbk.push-crypto.aes-key")
        XCTAssertEqual(PushCipher.sharedKey(), Self.vectorKey)
        XCTAssertEqual(suite?.data(forKey: "wbk.push-crypto.aes-key"), Self.vectorKey)
    }
}
