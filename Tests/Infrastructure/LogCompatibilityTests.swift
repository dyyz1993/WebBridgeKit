//
//  LogCompatibilityTests.swift
//  InfrastructureTests
//

import XCTest
@testable import WebBridgeKit

final class LogCompatibilityTests: XCTestCase {

    private var logger: WebBridgeLogger!

    override func setUp() {
        super.setUp()
        logger = WebBridgeLogger.shared
        WebBridgeLogger.disableStructuredBridge()
    }

    override func tearDown() {
        WebBridgeLogger.disableStructuredBridge()
        logger = nil
        super.tearDown()
    }

    func testBridgedInfoWithoutStructuredBridge() {
        WebBridgeLogger.disableStructuredBridge()
        XCTAssertFalse(logger.useStructuredLogger)
        XCTAssertNoThrow(logger.bridgedInfo("test info message", category: .general))
    }

    func testBridgedDebugWithoutStructuredBridge() {
        WebBridgeLogger.disableStructuredBridge()
        XCTAssertNoThrow(logger.bridgedDebug("test debug message", category: .general))
    }

    func testBridgedWarningWithoutStructuredBridge() {
        WebBridgeLogger.disableStructuredBridge()
        XCTAssertNoThrow(logger.bridgedWarning("test warning message", category: .general))
    }

    func testBridgedErrorWithoutStructuredBridge() {
        WebBridgeLogger.disableStructuredBridge()
        XCTAssertNoThrow(logger.bridgedError("test error message", category: .general))
    }

    func testBridgedInfoWithStructuredBridge() {
        WebBridgeLogger.enableStructuredBridge()
        XCTAssertTrue(logger.useStructuredLogger)
        XCTAssertNoThrow(logger.bridgedInfo("structured info", category: .general))
        WebBridgeLogger.disableStructuredBridge()
    }

    func testEnableStructuredBridge() {
        WebBridgeLogger.enableStructuredBridge()
        XCTAssertTrue(logger.useStructuredLogger)
    }

    func testDisableStructuredBridge() {
        WebBridgeLogger.enableStructuredBridge()
        WebBridgeLogger.disableStructuredBridge()
        XCTAssertFalse(logger.useStructuredLogger)
    }

    func testBridgedLogWithAllLevels() {
        WebBridgeLogger.disableStructuredBridge()
        XCTAssertNoThrow(logger.bridgedLog(.debug, category: .general, message: "debug"))
        XCTAssertNoThrow(logger.bridgedLog(.info, category: .general, message: "info"))
        XCTAssertNoThrow(logger.bridgedLog(.warning, category: .general, message: "warning"))
        XCTAssertNoThrow(logger.bridgedLog(.error, category: .general, message: "error"))
    }

    func testBridgedLogWithStructuredBridgeEnabled() {
        WebBridgeLogger.enableStructuredBridge()
        XCTAssertNoThrow(logger.bridgedLog(.info, category: .general, message: "bridged"))
        WebBridgeLogger.disableStructuredBridge()
    }

    func testBridgedLogRequest() {
        let params: [String: Any] = ["url": "https://example.com"]
        let token = logger.bridgedLogRequest(action: "fetchData", params: params, module: "Test")
        XCTAssertEqual(token.action, "fetchData")
        XCTAssertEqual(token.module, "Test")
    }

    func testBridgedLogRequestWithStructuredBridge() {
        WebBridgeLogger.enableStructuredBridge()
        let token = logger.bridgedLogRequest(action: "fetchData", params: [:], module: "Test")
        XCTAssertEqual(token.action, "fetchData")
        WebBridgeLogger.disableStructuredBridge()
    }

    func testBridgedLogResponse() {
        let token = WebBridgeLogToken(action: "test", input: [:], module: "Test")
        XCTAssertNoThrow(logger.bridgedLogResponse(token: token, result: "success", error: nil))
    }

    func testBridgedLogResponseWithError() {
        let token = WebBridgeLogToken(action: "test", input: [:], module: "Test")
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        XCTAssertNoThrow(logger.bridgedLogResponse(token: token, result: nil, error: error))
    }

    func testBridgedLogEvent() {
        XCTAssertNoThrow(logger.bridgedLogEvent(event: "pageLoad", data: "data", module: "Browser"))
    }

    func testBridgedLogEventWithStructuredBridge() {
        WebBridgeLogger.enableStructuredBridge()
        XCTAssertNoThrow(logger.bridgedLogEvent(event: "pageLoad", data: "data", module: "Browser"))
        WebBridgeLogger.disableStructuredBridge()
    }

    func testBridgedLogWithAllCategories() {
        let categories: [WebBridgeLogger.LogCategory] = [
            .general, .cache, .network, .browser, .manifest, .realm, .ui, .performance
        ]
        for category in categories {
            XCTAssertNoThrow(logger.bridgedInfo("test", category: category))
        }
    }

    func testWebBridgeLogTokenProperties() {
        let token = WebBridgeLogToken(
            action: "testAction",
            input: ["key": "value"],
            module: "TestModule"
        )

        XCTAssertEqual(token.action, "testAction")
        XCTAssertEqual(token.module, "TestModule")
        XCTAssertNotNil(token.timestamp)
    }
}
