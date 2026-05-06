import XCTest
@testable import WebBridgeKit

final class CommandParserTests: XCTestCase {

    private var parser: CommandParser!

    override func setUp() async throws {
        parser = CommandParser()
        let config = CommandParserConfiguration(
            enableSignatureVerification: false,
            enableTimestampValidation: false
        )
        await parser.setConfiguration(config)
    }

    override func tearDown() async throws {
        await parser.clearNonceCache()
    }

    // MARK: - Base64 Format Parsing

    func testParseBase64MinimalPayload() async throws {
        let payload: [String: Any] = ["appid": "shop"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        let result = try await parser.parse(base64)
        XCTAssertEqual(result.appid, "shop")
        XCTAssertNil(result.url)
        XCTAssertNil(result.title)
    }

    func testParseBase64FullPayload() async throws {
        let payload: [String: Any] = [
            "appid": "myapp",
            "url": "https://example.com/page",
            "title": "My App",
            "icon": "https://example.com/icon.png",
            "token": "secret123",
            "extra": ["mode": "immersive", "theme": "dark"],
            "nonce": "unique-1"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        let result = try await parser.parse(base64)
        XCTAssertEqual(result.appid, "myapp")
        XCTAssertEqual(result.url, "https://example.com/page")
        XCTAssertEqual(result.title, "My App")
        XCTAssertEqual(result.icon, "https://example.com/icon.png")
        XCTAssertEqual(result.token, "secret123")
        XCTAssertEqual(result.extra?["mode"], "immersive")
        XCTAssertEqual(result.extra?["theme"], "dark")
        XCTAssertEqual(result.nonce, "unique-1")
    }

    // MARK: - URL Scheme Format Parsing

    func testParseURLScheme() async throws {
        let payload: [String: Any] = ["appid": "game", "url": "https://game.com"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()
        let input = "wbsk://command?data=\(base64)"

        let result = try await parser.parse(input)
        XCTAssertEqual(result.appid, "game")
        XCTAssertEqual(result.url, "https://game.com")
    }

    // MARK: - Plain Text Format Parsing

    func testParsePlainText() async throws {
        let payload: [String: Any] = ["appid": "news", "title": "Breaking News"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()
        let input = "【WebBridgeKit】\(base64)"

        let result = try await parser.parse(input)
        XCTAssertEqual(result.appid, "news")
        XCTAssertEqual(result.title, "Breaking News")
    }

    // MARK: - Error Cases

    func testParseEmptyInput() async throws {
        do {
            _ = try await parser.parse("")
            XCTFail("Should throw")
        } catch let error as CommandError {
            guard case .emptyInput = error else {
                XCTFail("Wrong error: \(error)")
                return
            }
        }
    }

    func testParseWhitespaceOnly() async throws {
        do {
            _ = try await parser.parse("   ")
            XCTFail("Should throw")
        } catch let error as CommandError {
            guard case .emptyInput = error else {
                XCTFail("Wrong error: \(error)")
                return
            }
        }
    }

    func testParsePayloadTooLarge() async throws {
        let config = CommandParserConfiguration(
            maxPayloadSize: 50,
            enableSignatureVerification: false,
            enableTimestampValidation: false
        )
        await parser.setConfiguration(config)

        do {
            _ = try await parser.parse(String(repeating: "a", count: 100))
            XCTFail("Should throw")
        } catch let error as CommandError {
            guard case .payloadTooLarge = error else {
                XCTFail("Wrong error: \(error)")
                return
            }
        }
    }

    func testParseMissingAppid() async throws {
        let payload: [String: Any] = ["url": "https://example.com"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        do {
            _ = try await parser.parse(base64)
            XCTFail("Should throw")
        } catch let error as CommandError {
            guard case .invalidPayload = error else {
                XCTFail("Wrong error: \(error)")
                return
            }
        }
    }

    func testParseEmptyAppid() async throws {
        let payload: [String: Any] = ["appid": ""]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        do {
            _ = try await parser.parse(base64)
            XCTFail("Should throw")
        } catch let error as CommandError {
            guard case .invalidPayload = error else {
                XCTFail("Wrong error: \(error)")
                return
            }
        }
    }

    func testParseInvalidAppid() async throws {
        let payload: [String: Any] = ["appid": "has spaces!"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        do {
            _ = try await parser.parse(base64)
            XCTFail("Should throw")
        } catch let error as CommandError {
            guard case .invalidAppid = error else {
                XCTFail("Wrong error: \(error)")
                return
            }
        }
    }

    func testParseInvalidURL() async throws {
        let payload: [String: Any] = ["appid": "app", "url": "ftp://bad.com"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        do {
            _ = try await parser.parse(base64)
            XCTFail("Should throw")
        } catch let error as CommandError {
            guard case .invalidURL = error else {
                XCTFail("Wrong error: \(error)")
                return
            }
        }
    }

    // MARK: - Timestamp Validation

    func testParseExpiredCommand() async throws {
        let config = CommandParserConfiguration(
            maxAge: 60,
            enableSignatureVerification: false,
            enableTimestampValidation: true
        )
        await parser.setConfiguration(config)

        let expiredTimestamp = Date().timeIntervalSince1970 - 120
        let payload: [String: Any] = ["appid": "app", "ts": expiredTimestamp]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        do {
            _ = try await parser.parse(base64)
            XCTFail("Should throw")
        } catch let error as CommandError {
            guard case .expiredCommand = error else {
                XCTFail("Wrong error: \(error)")
                return
            }
        }
    }

    func testParseFreshCommand() async throws {
        let config = CommandParserConfiguration(
            maxAge: 300,
            enableSignatureVerification: false,
            enableTimestampValidation: true
        )
        await parser.setConfiguration(config)

        let freshTimestamp = Date().timeIntervalSince1970 - 10
        let payload: [String: Any] = ["appid": "app", "ts": freshTimestamp]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        let result = try await parser.parse(base64)
        XCTAssertEqual(result.appid, "app")
    }

    // MARK: - Nonce Deduplication

    func testParseDuplicateNonce() async throws {
        let nonce = "unique-nonce-\(UUID().uuidString)"
        let payload1: [String: Any] = ["appid": "app", "nonce": nonce]
        let data1 = try JSONSerialization.data(withJSONObject: payload1)
        let base641 = data1.base64EncodedString()

        _ = try await parser.parse(base641)

        let payload2: [String: Any] = ["appid": "app2", "nonce": nonce]
        let data2 = try JSONSerialization.data(withJSONObject: payload2)
        let base642 = data2.base64EncodedString()

        do {
            _ = try await parser.parse(base642)
            XCTFail("Should throw for duplicate nonce")
        } catch let error as CommandError {
            guard case .invalidPayload = error else {
                XCTFail("Wrong error: \(error)")
                return
            }
        }
    }

    func testParseDifferentNonces() async throws {
        let payload1: [String: Any] = ["appid": "app1", "nonce": "nonce-a"]
        let data1 = try JSONSerialization.data(withJSONObject: payload1)
        let base641 = data1.base64EncodedString()

        let payload2: [String: Any] = ["appid": "app2", "nonce": "nonce-b"]
        let data2 = try JSONSerialization.data(withJSONObject: payload2)
        let base642 = data2.base64EncodedString()

        let result1 = try await parser.parse(base641)
        let result2 = try await parser.parse(base642)
        XCTAssertEqual(result1.appid, "app1")
        XCTAssertEqual(result2.appid, "app2")
    }

    // MARK: - Route Tests

    func testRouterCachedApp() {
        let router = CommandRouter.shared
        let payload = CommandPayload(appid: "shop")
        let route = router.route(payload)
        XCTAssertEqual(route, .cachedApp(appid: "shop"))
    }

    func testRouterCachedAppWithURL() {
        let router = CommandRouter.shared
        let payload = CommandPayload(appid: "app", url: "https://example.com")
        let route = router.route(payload)
        XCTAssertEqual(route, .cachedApp(appid: "app"))
    }

    func testRouterDeeplink() {
        let router = CommandRouter.shared
        let payload = CommandPayload(appid: "app", url: "myapp://deep/page")
        let route = router.route(payload)
        XCTAssertEqual(route, .cachedApp(appid: "app"))
    }

    // MARK: - ClipboardMonitor

    func testClipboardMonitorDetectsPrefix() {
        let monitor = ClipboardMonitor.shared
        XCTAssertTrue(monitor.looksLikeCommand("【WebBridgeKit】dGVzdA=="))
    }

    func testClipboardMonitorDetectsURLScheme() {
        let monitor = ClipboardMonitor.shared
        XCTAssertTrue(monitor.looksLikeCommand("wbsk://command?data=dGVzdA=="))
    }

    func testClipboardMonitorRejectsNormalText() {
        let monitor = ClipboardMonitor.shared
        XCTAssertFalse(monitor.looksLikeCommand("Hello, this is normal text"))
        XCTAssertFalse(monitor.looksLikeCommand(""))
        XCTAssertFalse(monitor.looksLikeCommand("  "))
    }

    // MARK: - URL Scheme Validation

    func testParseAllowsHTTP() async throws {
        let payload: [String: Any] = ["appid": "app", "url": "http://example.com"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        let result = try await parser.parse(base64)
        XCTAssertEqual(result.url, "http://example.com")
    }

    func testParseAllowsHTTPS() async throws {
        let payload: [String: Any] = ["appid": "app", "url": "https://example.com"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let base64 = data.base64EncodedString()

        let result = try await parser.parse(base64)
        XCTAssertEqual(result.url, "https://example.com")
    }

    // MARK: - CommandFormat

    func testCommandFormatAllCases() {
        XCTAssertEqual(CommandFormat.allCases.count, 3)
        XCTAssertEqual(CommandFormat.base64.rawValue, "base64")
        XCTAssertEqual(CommandFormat.urlScheme.rawValue, "urlScheme")
        XCTAssertEqual(CommandFormat.plainText.rawValue, "plainText")
    }
}
