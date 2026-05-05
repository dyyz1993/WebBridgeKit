//
//  WebBridgeLoggerTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class WebBridgeLoggerTests: XCTestCase {

    private var logger: WebBridgeLogger!

    override func setUp() {
        super.setUp()
        logger = WebBridgeLogger.shared
        logger.isEnabled = true
        logger.minLogLevel = .debug
        logger.includeFileLocation = false
    }

    override func tearDown() {
        logger.minLogLevel = .info
        logger.includeFileLocation = false
        logger.isEnabled = true
        super.tearDown()
    }

    // MARK: - Singleton

    func testSharedInstance() {
        XCTAssertIdentical(WebBridgeLogger.shared, WebBridgeLogger.shared)
    }

    // MARK: - LogLevel

    func testLogLevelRawValues() {
        XCTAssertEqual(WebBridgeLogger.LogLevel.debug.rawValue, 0)
        XCTAssertEqual(WebBridgeLogger.LogLevel.info.rawValue, 1)
        XCTAssertEqual(WebBridgeLogger.LogLevel.warning.rawValue, 2)
        XCTAssertEqual(WebBridgeLogger.LogLevel.error.rawValue, 3)
    }

    func testLogLevelEmojis() {
        XCTAssertEqual(WebBridgeLogger.LogLevel.debug.emoji, "🔍")
        XCTAssertEqual(WebBridgeLogger.LogLevel.info.emoji, "ℹ️")
        XCTAssertEqual(WebBridgeLogger.LogLevel.warning.emoji, "⚠️")
        XCTAssertEqual(WebBridgeLogger.LogLevel.error.emoji, "❌")
    }

    func testLogLevelPrefixes() {
        XCTAssertEqual(WebBridgeLogger.LogLevel.debug.prefix, "DEBUG")
        XCTAssertEqual(WebBridgeLogger.LogLevel.info.prefix, "INFO")
        XCTAssertEqual(WebBridgeLogger.LogLevel.warning.prefix, "WARN")
        XCTAssertEqual(WebBridgeLogger.LogLevel.error.prefix, "ERROR")
    }

    // MARK: - LogCategory

    func testLogCategoryRawValues() {
        XCTAssertEqual(WebBridgeLogger.LogCategory.general.rawValue, "General")
        XCTAssertEqual(WebBridgeLogger.LogCategory.cache.rawValue, "Cache")
        XCTAssertEqual(WebBridgeLogger.LogCategory.network.rawValue, "Network")
        XCTAssertEqual(WebBridgeLogger.LogCategory.browser.rawValue, "Browser")
        XCTAssertEqual(WebBridgeLogger.LogCategory.manifest.rawValue, "Manifest")
        XCTAssertEqual(WebBridgeLogger.LogCategory.realm.rawValue, "Realm")
        XCTAssertEqual(WebBridgeLogger.LogCategory.ui.rawValue, "UI")
        XCTAssertEqual(WebBridgeLogger.LogCategory.performance.rawValue, "Performance")
    }

    // MARK: - Log Level Filtering

    func testMinLogLevelFiltersDebug() {
        logger.minLogLevel = .info
        logger.debug("should be filtered")
    }

    func testMinLogLevelAllowsEqualAndAbove() {
        logger.minLogLevel = .warning
        logger.log(.warning, category: .general, message: "test warning")
        logger.log(.error, category: .general, message: "test error")
    }

    func testDisabledLoggerDoesNotLog() {
        logger.isEnabled = false
        logger.log(.error, category: .general, message: "should not log")
    }

    // MARK: - Convenience Methods

    func testDebugConvenienceMethod() {
        logger.debug("debug message", category: .cache)
    }

    func testInfoConvenienceMethod() {
        logger.info("info message", category: .network)
    }

    func testWarningConvenienceMethod() {
        logger.warning("warning message", category: .browser)
    }

    func testErrorConvenienceMethod() {
        logger.error("error message", category: .manifest)
    }

    // MARK: - Log Token

    func testLogTokenCreation() {
        let token = WebBridgeLogToken(
            action: "loadPage",
            input: ["url": "https://example.com"],
            module: "Browser"
        )

        XCTAssertEqual(token.action, "loadPage")
        XCTAssertEqual(token.input["url"] as? String, "https://example.com")
        XCTAssertEqual(token.module, "Browser")
    }

    func testLogTokenHasTimestamp() {
        let before = Date()
        let token = WebBridgeLogToken(action: "test", input: [:], module: "Test")
        let after = Date()

        XCTAssertTrue(token.timestamp >= before)
        XCTAssertTrue(token.timestamp <= after)
    }

    // MARK: - Request/Response Logging

    func testLogRequestCreatesToken() {
        let token = logger.logRequest(
            action: "fetchData",
            params: ["id": 123],
            module: "API"
        )

        XCTAssertEqual(token.action, "fetchData")
        XCTAssertEqual(token.input["id"] as? Int, 123)
        XCTAssertEqual(token.module, "API")
    }

    func testLogRequestWithExistingToken() {
        let token = WebBridgeLogToken(action: "test", input: [:], module: "Test")
        logger.logRequest(token: token)
    }

    func testLogResponseSuccess() {
        let token = WebBridgeLogToken(action: "test", input: [:], module: "Test")
        logger.logResponse(token: token, result: "success", error: nil)
    }

    func testLogResponseError() {
        let token = WebBridgeLogToken(action: "test", input: [:], module: "Test")
        let error = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        logger.logResponse(token: token, result: nil, error: error)
    }

    // MARK: - Event Logging

    func testLogEvent() {
        logger.logEvent(event: "pageLoaded", data: "test data", module: "Browser")
    }

    // MARK: - File Location

    func testIncludeFileLocation() {
        logger.includeFileLocation = true
        logger.info("test with file location")
    }

    // MARK: - Global Log Access

    func testGlobalLogAccess() {
        XCTAssertIdentical(Log, WebBridgeLogger.shared)
    }
}
