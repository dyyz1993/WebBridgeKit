//
//  ErrorContextTests.swift
//  InfrastructureTests
//

import XCTest
@testable import WebBridgeKit

final class ErrorContextTests: XCTestCase {

    func testInitWithRequiredFields() {
        let error = NSError(domain: "Test", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server Error"])
        let context = ErrorContext(error: error)

        XCTAssertEqual(context.error.localizedDescription, "Server Error")
        XCTAssertNotNil(context.timestamp)
        XCTAssertNil(context.action)
        XCTAssertNil(context.params)
        XCTAssertNil(context.currentURL)
        XCTAssertNil(context.customContext)
        XCTAssertNotNil(context.environment)
    }

    func testInitWithOptionalFields() {
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let context = ErrorContext(
            error: error,
            action: "fetchData",
            params: ["url": "https://example.com"],
            currentURL: "https://example.com/page",
            customContext: ["retryCount": "3"]
        )

        XCTAssertEqual(context.action, "fetchData")
        XCTAssertEqual(context.params?["url"] as? String, "https://example.com")
        XCTAssertEqual(context.currentURL, "https://example.com/page")
        XCTAssertEqual(context.customContext?["retryCount"], "3")
    }

    func testDebugStringContainsErrorDescription() {
        let error = NSError(domain: "Test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Test Error Message"])
        let context = ErrorContext(error: error)

        XCTAssertTrue(context.debugString.contains("Test Error Message"))
    }

    func testDebugStringContainsActionWhenProvided() {
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let context = ErrorContext(error: error, action: "loadPage")

        XCTAssertTrue(context.debugString.contains("loadPage"))
    }

    func testDebugStringDoesNotContainActionWhenNil() {
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let context = ErrorContext(error: error)

        XCTAssertFalse(context.debugString.contains("Action:"))
    }

    func testDebugStringContainsURLWhenProvided() {
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let context = ErrorContext(error: error, currentURL: "https://example.com")

        XCTAssertTrue(context.debugString.contains("https://example.com"))
    }

    func testDebugStringContainsCustomContext() {
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let context = ErrorContext(error: error, customContext: ["userId": "12345"])

        XCTAssertTrue(context.debugString.contains("userId"))
        XCTAssertTrue(context.debugString.contains("12345"))
    }

    func testDebugStringContainsEnvironment() {
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let context = ErrorContext(error: error)

        XCTAssertTrue(context.debugString.contains("Environment"))
    }

    func testDebugStringContainsTimestamp() {
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let context = ErrorContext(error: error)

        let formatter = ISO8601DateFormatter()
        XCTAssertTrue(context.debugString.contains(formatter.string(from: context.timestamp).prefix(10)))
    }

    func testJsonDictContainsRequiredFields() {
        let error = NSError(domain: "Test", code: 0, userInfo: [NSLocalizedDescriptionKey: "json test"])
        let context = ErrorContext(error: error)
        let dict = context.jsonDict

        XCTAssertNotNil(dict["timestamp"])
        XCTAssertNotNil(dict["error"])
        XCTAssertEqual(dict["error"] as? String, "json test")
        XCTAssertNotNil(dict["environment"])
    }

    func testJsonDictContainsOptionalFields() {
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let context = ErrorContext(
            error: error,
            action: "doAction",
            currentURL: "https://example.com",
            customContext: ["key": "value"]
        )
        let dict = context.jsonDict

        XCTAssertEqual(dict["action"] as? String, "doAction")
        XCTAssertEqual(dict["url"] as? String, "https://example.com")
        XCTAssertEqual(dict["custom_context"] as? [String: String], ["key": "value"])
    }

    func testJsonDictOmitsNilFields() {
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let context = ErrorContext(error: error)
        let dict = context.jsonDict

        XCTAssertNil(dict["action"])
        XCTAssertNil(dict["url"])
        XCTAssertNil(dict["custom_context"])
    }

    func testJsonStringIsValidJSON() {
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let context = ErrorContext(error: error)
        let jsonString = context.jsonString

        let data = jsonString.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(parsed)
    }

    func testTimestampIsRecent() {
        let before = Date()
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let context = ErrorContext(error: error)
        let after = Date()

        XCTAssertGreaterThanOrEqual(context.timestamp, before)
        XCTAssertLessThanOrEqual(context.timestamp, after)
    }

    func testRecentLogsIsIncluded() {
        let error = NSError(domain: "Test", code: 0, userInfo: nil)
        let context = ErrorContext(error: error)

        XCTAssertNotNil(context.recentLogs)
    }
}
