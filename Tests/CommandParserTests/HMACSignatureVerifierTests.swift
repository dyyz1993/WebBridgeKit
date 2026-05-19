import XCTest
import CryptoKit
@testable import WebBridgeKit

final class HMACSignatureVerifierTests: XCTestCase {

    private func makeTestKey() -> Data {
        Data(repeating: 0xAB, count: 32)
    }

    private func computeHMAC(data: Data, key: Data) -> String {
        let symmetricKey = SymmetricKey(data: key)
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(hmac).map { String(format: "%02x", $0) }.joined()
    }

    private func makePayload(data: Data) -> CommandRawPayload {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return CommandRawPayload(data: data, json: json)
    }

    // MARK: - HMACSignatureVerifier

    func testVerify_withCorrectKeyAndSignature_returnsTrue() {
        let key = makeTestKey()
        let verifier = HMACSignatureVerifier(secretKey: key)
        let payloadData = try! JSONSerialization.data(withJSONObject: ["appid": "test"])
        let signature = computeHMAC(data: payloadData, key: key)
        let payload = makePayload(data: payloadData)

        let result = verifier.verify(payload: payload, signature: signature)
        XCTAssertTrue(result)
    }

    func testVerify_withCorrectKeyButWrongSignature_returnsFalse() {
        let key = makeTestKey()
        let verifier = HMACSignatureVerifier(secretKey: key)
        let payloadData = try! JSONSerialization.data(withJSONObject: ["appid": "test"])
        let payload = makePayload(data: payloadData)

        let result = verifier.verify(payload: payload, signature: "0000000000000000000000000000000000000000000000000000000000000000")
        XCTAssertFalse(result)
    }

    func testVerify_withMalformedHexSignature_returnsFalse() {
        let key = makeTestKey()
        let verifier = HMACSignatureVerifier(secretKey: key)
        let payloadData = try! JSONSerialization.data(withJSONObject: ["appid": "test"])
        let payload = makePayload(data: payloadData)

        let result = verifier.verify(payload: payload, signature: "not-valid-hex!")
        XCTAssertFalse(result)
    }

    func testVerify_withEmptySignature_returnsFalse() {
        let key = makeTestKey()
        let verifier = HMACSignatureVerifier(secretKey: key)
        let payloadData = try! JSONSerialization.data(withJSONObject: ["appid": "test"])
        let payload = makePayload(data: payloadData)

        let result = verifier.verify(payload: payload, signature: "")
        XCTAssertFalse(result)
    }

    func testVerify_withOddLengthHexSignature_returnsFalse() {
        let key = makeTestKey()
        let verifier = HMACSignatureVerifier(secretKey: key)
        let payloadData = try! JSONSerialization.data(withJSONObject: ["appid": "test"])
        let payload = makePayload(data: payloadData)

        let result = verifier.verify(payload: payload, signature: "abc")
        XCTAssertFalse(result)
    }

    func testInitWithHexKey_producesWorkingVerifier() {
        let hexKey = "abababababababababababababababababababababababababababababababab"
        let verifier = HMACSignatureVerifier(secretKeyHex: hexKey)
        let keyData = Data(hex: hexKey)
        let payloadData = try! JSONSerialization.data(withJSONObject: ["appid": "test"])
        let signature = computeHMAC(data: payloadData, key: keyData)
        let payload = makePayload(data: payloadData)

        let result = verifier.verify(payload: payload, signature: signature)
        XCTAssertTrue(result)
    }

    func testVerify_withDifferentKey_returnsFalse() {
        let key1 = makeTestKey()
        let key2 = Data(repeating: 0xCD, count: 32)
        let verifier = HMACSignatureVerifier(secretKey: key2)
        let payloadData = try! JSONSerialization.data(withJSONObject: ["appid": "test"])
        let signature = computeHMAC(data: payloadData, key: key1)
        let payload = makePayload(data: payloadData)

        let result = verifier.verify(payload: payload, signature: signature)
        XCTAssertFalse(result)
    }

    func testVerify_withEmptyData_returnsConsistentResult() {
        let key = makeTestKey()
        let verifier = HMACSignatureVerifier(secretKey: key)
        let payloadData = Data()
        let signature = computeHMAC(data: payloadData, key: key)
        let payload = CommandRawPayload(data: payloadData, json: [:])

        let result = verifier.verify(payload: payload, signature: signature)
        XCTAssertTrue(result)
    }

    // MARK: - CommandParser with Signature Verification

    func testParser_withVerificationEnabledAndValidHMAC_succeeds() async throws {
        let key = makeTestKey()
        let parser = CommandParser()
        let verifier = HMACSignatureVerifier(secretKey: key)
        await parser.registerSignatureVerifier(verifier)

        let config = CommandParserConfiguration(
            enableSignatureVerification: true,
            enableTimestampValidation: false
        )
        await parser.setConfiguration(config)

        var payload: [String: Any] = ["appid": "signedapp"]
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        payload["sig"] = computeHMAC(data: payloadData, key: key)

        let signedData = try JSONSerialization.data(withJSONObject: payload)
        let base64 = signedData.base64EncodedString()

        let result = try await parser.parse(base64)
        XCTAssertEqual(result.appid, "signedapp")
    }

    func testParser_withVerificationEnabledButNoSignature_throwsError() async throws {
        let key = makeTestKey()
        let parser = CommandParser()
        let verifier = HMACSignatureVerifier(secretKey: key)
        await parser.registerSignatureVerifier(verifier)

        let config = CommandParserConfiguration(
            enableSignatureVerification: true,
            enableTimestampValidation: false
        )
        await parser.setConfiguration(config)

        let payload: [String: Any] = ["appid": "unsigned"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        do {
            _ = try await parser.parse(base64)
            XCTFail("Should throw signatureVerificationFailed")
        } catch let error as CommandError {
            guard case .signatureVerificationFailed = error else {
                XCTFail("Wrong error: \(error)")
                return
            }
        }
    }

    func testParser_withVerificationEnabledButWrongSignature_throwsError() async throws {
        let key = makeTestKey()
        let parser = CommandParser()
        let verifier = HMACSignatureVerifier(secretKey: key)
        await parser.registerSignatureVerifier(verifier)

        let config = CommandParserConfiguration(
            enableSignatureVerification: true,
            enableTimestampValidation: false
        )
        await parser.setConfiguration(config)

        var payload: [String: Any] = ["appid": "tampered"]
        payload["sig"] = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        do {
            _ = try await parser.parse(base64)
            XCTFail("Should throw signatureVerificationFailed")
        } catch let error as CommandError {
            guard case .signatureVerificationFailed = error else {
                XCTFail("Wrong error: \(error)")
                return
            }
        }
    }

    func testParser_withVerificationDisabled_succeedsWithoutSignature() async throws {
        let parser = CommandParser()
        let config = CommandParserConfiguration(
            enableSignatureVerification: false,
            enableTimestampValidation: false
        )
        await parser.setConfiguration(config)

        let payload: [String: Any] = ["appid": "nosig"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        let result = try await parser.parse(base64)
        XCTAssertEqual(result.appid, "nosig")
    }

    func testParser_withVerificationEnabledButNoVerifierRegistered_skipsVerification() async throws {
        let parser = CommandParser()
        let config = CommandParserConfiguration(
            enableSignatureVerification: true,
            enableTimestampValidation: false
        )
        await parser.setConfiguration(config)

        let payload: [String: Any] = ["appid": "noverifier"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        let result = try await parser.parse(base64)
        XCTAssertEqual(result.appid, "noverifier")
    }
}
