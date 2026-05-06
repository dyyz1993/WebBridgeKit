import XCTest
@testable import WebBridgeKit

final class CommandDecoderTests: XCTestCase {

    // MARK: - Base64CommandDecoder

    func testBase64CanDecodeValidInput() {
        let decoder = Base64CommandDecoder()
        let payload: [String: Any] = ["appid": "shop", "title": "Test"]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()
        XCTAssertTrue(decoder.canDecode(base64))
    }

    func testBase64CannotDecodeShort() {
        let decoder = Base64CommandDecoder()
        XCTAssertFalse(decoder.canDecode("abc"))
    }

    func testBase64CannotDecodeEmpty() {
        let decoder = Base64CommandDecoder()
        XCTAssertFalse(decoder.canDecode(""))
    }

    func testBase64DecodeValidPayload() throws {
        let decoder = Base64CommandDecoder()
        let payload: [String: Any] = ["appid": "shop", "url": "https://example.com", "sig": "abcdef"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        let result = try decoder.decode(base64)
        XCTAssertEqual(result.json["appid"] as? String, "shop")
        XCTAssertEqual(result.json["url"] as? String, "https://example.com")
        XCTAssertEqual(result.signature, "abcdef")
    }

    func testBase64DecodeBase64URL() throws {
        let decoder = Base64CommandDecoder()
        let payload: [String: Any] = ["appid": "test"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64url = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let result = try decoder.decode(base64url)
        XCTAssertEqual(result.json["appid"] as? String, "test")
    }

    func testBase64DecodeInvalidBase64() {
        let decoder = Base64CommandDecoder()
        XCTAssertThrowsError(try decoder.decode("!!!invalid!!!"))
    }

    // MARK: - URLSchemeCommandDecoder

    func testURLSchemeCanDecode() {
        let decoder = URLSchemeCommandDecoder()
        XCTAssertTrue(decoder.canDecode("wbsk://command?data=dGVzdA=="))
    }

    func testURLSchemeCannotDecodeOther() {
        let decoder = URLSchemeCommandDecoder()
        XCTAssertFalse(decoder.canDecode("https://example.com"))
        XCTAssertFalse(decoder.canDecode("【WebBridgeKit】test"))
    }

    func testURLSchemeDecodeValid() throws {
        let decoder = URLSchemeCommandDecoder()
        let payload: [String: Any] = ["appid": "myapp", "title": "My App"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()
        let urlString = "wbsk://command?data=\(base64)&sig=abc123"

        let result = try decoder.decode(urlString)
        XCTAssertEqual(result.json["appid"] as? String, "myapp")
        XCTAssertEqual(result.signature, "abc123")
    }

    func testURLSchemeDecodeMissingData() {
        let decoder = URLSchemeCommandDecoder()
        XCTAssertThrowsError(try decoder.decode("wbsk://command?sig=abc"))
    }

    // MARK: - PlainTextCommandDecoder

    func testPlainTextCanDecode() {
        let decoder = PlainTextCommandDecoder()
        XCTAssertTrue(decoder.canDecode("【WebBridgeKit】eyJ0ZXN0IjoiMSJ9"))
    }

    func testPlainTextCannotDecodeNoPrefix() {
        let decoder = PlainTextCommandDecoder()
        XCTAssertFalse(decoder.canDecode("eyJ0ZXN0IjoiMSJ9"))
    }

    func testPlainTextDecodeValid() throws {
        let decoder = PlainTextCommandDecoder()
        let payload: [String: Any] = ["appid": "shop"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()
        let input = "【WebBridgeKit】\(base64)"

        let result = try decoder.decode(input)
        XCTAssertEqual(result.json["appid"] as? String, "shop")
    }

    func testPlainTextDecodeEmptyAfterPrefix() {
        let decoder = PlainTextCommandDecoder()
        XCTAssertThrowsError(try decoder.decode("【WebBridgeKit】"))
    }

    // MARK: - DecoderRegistry

    func testRegistryFindsBase64Decoder() {
        let registry = CommandDecoderRegistry.shared
        let payload: [String: Any] = ["appid": "test"]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()
        let decoder = registry.findDecoder(for: base64)
        XCTAssertNotNil(decoder)
        XCTAssertEqual(decoder?.format, .base64)
    }

    func testRegistryFindsURLSchemeDecoder() {
        let registry = CommandDecoderRegistry.shared
        let decoder = registry.findDecoder(for: "wbsk://command?data=dGVzdA==")
        XCTAssertNotNil(decoder)
        XCTAssertEqual(decoder?.format, .urlScheme)
    }

    func testRegistryFindsPlainTextDecoder() {
        let registry = CommandDecoderRegistry.shared
        let decoder = registry.findDecoder(for: "【WebBridgeKit】dGVzdA==")
        XCTAssertNotNil(decoder)
        XCTAssertEqual(decoder?.format, .plainText)
    }

    func testRegistryReturnsNilForGarbage() {
        let registry = CommandDecoderRegistry.shared
        let decoder = registry.findDecoder(for: "random text that is not a command")
        XCTAssertNil(decoder)
    }

    func testRegistryGetDecoderByFormat() {
        let registry = CommandDecoderRegistry.shared
        XCTAssertNotNil(registry.getDecoder(format: .base64))
        XCTAssertNotNil(registry.getDecoder(format: .urlScheme))
        XCTAssertNotNil(registry.getDecoder(format: .plainText))
    }
}
