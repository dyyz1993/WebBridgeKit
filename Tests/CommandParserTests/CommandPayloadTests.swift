import XCTest
@testable import WebBridgeKit

final class CommandPayloadTests: XCTestCase {

    // MARK: - Initialization

    func testDefaultInitialization() {
        let payload = CommandPayload(appid: "shop")
        XCTAssertEqual(payload.appid, "shop")
        XCTAssertNil(payload.url)
        XCTAssertNil(payload.title)
        XCTAssertNil(payload.icon)
        XCTAssertNil(payload.token)
        XCTAssertNil(payload.extra)
        XCTAssertNil(payload.timestamp)
        XCTAssertNil(payload.nonce)
    }

    func testFullInitialization() {
        let payload = CommandPayload(
            appid: "myapp",
            url: "https://example.com",
            title: "My App",
            icon: "https://example.com/icon.png",
            token: "abc123",
            extra: ["key": "value"],
            timestamp: 1000000,
            nonce: "n1"
        )
        XCTAssertEqual(payload.appid, "myapp")
        XCTAssertEqual(payload.url, "https://example.com")
        XCTAssertEqual(payload.title, "My App")
        XCTAssertEqual(payload.icon, "https://example.com/icon.png")
        XCTAssertEqual(payload.token, "abc123")
        XCTAssertEqual(payload.extra?["key"], "value")
        XCTAssertEqual(payload.timestamp, 1000000)
        XCTAssertEqual(payload.nonce, "n1")
    }

    // MARK: - Computed Properties

    func testHasURLTrue() {
        let payload = CommandPayload(appid: "app", url: "https://example.com")
        XCTAssertTrue(payload.hasURL)
    }

    func testHasURLFalseNil() {
        let payload = CommandPayload(appid: "app")
        XCTAssertFalse(payload.hasURL)
    }

    func testHasURLFalseEmpty() {
        let payload = CommandPayload(appid: "app", url: "")
        XCTAssertFalse(payload.hasURL)
    }

    func testHasTokenTrue() {
        let payload = CommandPayload(appid: "app", token: "tok")
        XCTAssertTrue(payload.hasToken)
    }

    func testHasTokenFalse() {
        let payload = CommandPayload(appid: "app")
        XCTAssertFalse(payload.hasToken)
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let payload = CommandPayload(
            appid: "shop",
            url: "https://example.com",
            title: "Shop",
            token: "tok",
            extra: ["k": "v"],
            timestamp: 1234,
            nonce: "n1"
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(CommandPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    // MARK: - Equatable

    func testEquality() {
        let p1 = CommandPayload(appid: "a", url: "u")
        let p2 = CommandPayload(appid: "a", url: "u")
        XCTAssertEqual(p1, p2)
    }

    func testInequality() {
        let p1 = CommandPayload(appid: "a")
        let p2 = CommandPayload(appid: "b")
        XCTAssertNotEqual(p1, p2)
    }

    // MARK: - CommandRoute

    func testCommandRouteEquality() {
        XCTAssertEqual(CommandRoute.cachedApp(appid: "a"), CommandRoute.cachedApp(appid: "a"))
        XCTAssertEqual(CommandRoute.url(url: "u"), CommandRoute.url(url: "u"))
        XCTAssertEqual(CommandRoute.deeplink(url: "d"), CommandRoute.deeplink(url: "d"))
        XCTAssertEqual(CommandRoute.none, CommandRoute.none)
    }

    func testCommandRouteInequality() {
        XCTAssertNotEqual(CommandRoute.cachedApp(appid: "a"), CommandRoute.cachedApp(appid: "b"))
        XCTAssertNotEqual(CommandRoute.url(url: "u"), CommandRoute.deeplink(url: "u"))
    }

    // MARK: - CommandError

    func testCommandErrorDescriptions() {
        XCTAssertFalse(CommandError.emptyInput.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(CommandError.signatureVerificationFailed.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(CommandError.expiredCommand(age: 100).errorDescription?.isEmpty ?? true)
        XCTAssertFalse(CommandError.invalidAppid("x").errorDescription?.isEmpty ?? true)
        XCTAssertFalse(CommandError.invalidURL("bad").errorDescription?.isEmpty ?? true)
    }

    // MARK: - Configuration

    func testDefaultConfiguration() {
        let config = CommandParserConfiguration.default
        XCTAssertEqual(config.maxPayloadSize, 4096)
        XCTAssertEqual(config.maxAge, 300)
        XCTAssertTrue(config.enableSignatureVerification)
        XCTAssertTrue(config.enableTimestampValidation)
        XCTAssertEqual(config.commandPrefix, "【WebBridgeKit】")
        XCTAssertEqual(config.urlSchemePrefix, "wbsk://command")
    }

    func testCustomConfiguration() {
        let config = CommandParserConfiguration(
            maxPayloadSize: 8192,
            maxAge: 600,
            enableSignatureVerification: false
        )
        XCTAssertEqual(config.maxPayloadSize, 8192)
        XCTAssertEqual(config.maxAge, 600)
        XCTAssertFalse(config.enableSignatureVerification)
    }
}
