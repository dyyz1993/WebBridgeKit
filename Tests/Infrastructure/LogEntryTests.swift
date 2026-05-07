//
//  LogEntryTests.swift
//  InfrastructureTests
//

import XCTest
@testable import WebBridgeKit

final class LogEntryTests: XCTestCase {

    func testInitWithDefaults() {
        let entry = LogEntry(level: .info, category: .general, message: "test")
        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(entry.timestamp)
        XCTAssertEqual(entry.level, .info)
        XCTAssertEqual(entry.category, .general)
        XCTAssertEqual(entry.message, "test")
        XCTAssertNil(entry.file)
        XCTAssertNil(entry.function)
        XCTAssertNil(entry.line)
        XCTAssertNil(entry.context)
        XCTAssertNil(entry.action)
        XCTAssertNil(entry.durationMs)
        XCTAssertNil(entry.sessionId)
    }

    func testInitWithAllParameters() {
        let entry = LogEntry(
            level: .error,
            category: .network,
            message: "connection failed",
            file: "Test.swift",
            function: "testFunc()",
            line: 42,
            context: ["key": "value"],
            action: "fetchData",
            durationMs: 150.5,
            sessionId: "abc12345"
        )

        XCTAssertEqual(entry.level, .error)
        XCTAssertEqual(entry.category, .network)
        XCTAssertEqual(entry.message, "connection failed")
        XCTAssertEqual(entry.file, "Test.swift")
        XCTAssertEqual(entry.function, "testFunc()")
        XCTAssertEqual(entry.line, 42)
        XCTAssertEqual(entry.context?["key"], "value")
        XCTAssertEqual(entry.action, "fetchData")
        XCTAssertEqual(entry.durationMs, 150.5)
        XCTAssertEqual(entry.sessionId, "abc12345")
    }

    func testJsonDictContainsRequiredFields() {
        let entry = LogEntry(level: .info, category: .general, message: "test")
        let dict = entry.jsonDict

        XCTAssertNotNil(dict["id"])
        XCTAssertNotNil(dict["ts"])
        XCTAssertEqual(dict["level"] as? String, "INF")
        XCTAssertEqual(dict["category"] as? String, "general")
        XCTAssertEqual(dict["message"] as? String, "test")
    }

    func testJsonDictContainsOptionalFields() {
        let entry = LogEntry(
            level: .debug,
            category: .cache,
            message: "cache hit",
            file: "Cache.swift",
            line: 10,
            context: ["key": "val"],
            action: "lookup",
            durationMs: 5.0,
            sessionId: "sess1"
        )
        let dict = entry.jsonDict

        XCTAssertEqual(dict["file"] as? String, "Cache.swift")
        XCTAssertEqual(dict["line"] as? Int, 10)
        XCTAssertNotNil(dict["context"])
        XCTAssertEqual(dict["action"] as? String, "lookup")
        XCTAssertEqual(dict["duration_ms"] as? Double, 5.0)
        XCTAssertEqual(dict["session_id"] as? String, "sess1")
    }

    func testJsonDictOmitsNilFields() {
        let entry = LogEntry(level: .info, category: .general, message: "test")
        let dict = entry.jsonDict

        XCTAssertNil(dict["file"])
        XCTAssertNil(dict["action"])
        XCTAssertNil(dict["duration_ms"])
    }

    func testJsonStringIsValidJSON() {
        let entry = LogEntry(level: .info, category: .general, message: "test")
        let jsonString = entry.jsonString

        let data = jsonString.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(parsed)
    }

    func testConsoleStringContainsLevelTag() {
        let entry = LogEntry(level: .warning, category: .general, message: "test")
        XCTAssertTrue(entry.consoleString.contains("WRN"))
    }

    func testConsoleStringContainsCategory() {
        let entry = LogEntry(level: .info, category: .network, message: "test")
        XCTAssertTrue(entry.consoleString.contains("network"))
    }

    func testConsoleStringContainsMessage() {
        let entry = LogEntry(level: .info, category: .general, message: "Hello World")
        XCTAssertTrue(entry.consoleString.contains("Hello World"))
    }

    func testConsoleStringContainsActionWhenSet() {
        let entry = LogEntry(level: .info, category: .general, message: "test", action: "fetchData")
        XCTAssertTrue(entry.consoleString.contains("fetchData"))
    }

    func testConsoleStringContainsDurationWhenSet() {
        let entry = LogEntry(level: .info, category: .general, message: "test", durationMs: 42.5)
        XCTAssertTrue(entry.consoleString.contains("42.5ms"))
    }

    func testConsoleStringNoActionWhenNil() {
        let entry = LogEntry(level: .info, category: .general, message: "test")
        XCTAssertFalse(entry.consoleString.contains("[nil]"))
    }

    func testDebugStringContainsAllInfo() {
        let entry = LogEntry(
            level: .error,
            category: .network,
            message: "timeout",
            file: "Net.swift",
            line: 99,
            context: ["url": "http://example.com"],
            action: "request",
            durationMs: 10000.0
        )
        let debug = entry.debugString

        XCTAssertTrue(debug.contains("ERR"))
        XCTAssertTrue(debug.contains("network"))
        XCTAssertTrue(debug.contains("timeout"))
        XCTAssertTrue(debug.contains("request"))
        XCTAssertTrue(debug.contains("10000"))
        XCTAssertTrue(debug.contains("Net.swift"))
        XCTAssertTrue(debug.contains("url"))
    }

    func testLogLevelOrdering() {
        XCTAssertTrue(LogLevel.verbose < LogLevel.debug)
        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.warning)
        XCTAssertTrue(LogLevel.warning < LogLevel.error)
    }

    func testLogLevelComparable() {
        let levels: [LogLevel] = [.error, .verbose, .warning, .debug, .info]
        let sorted = levels.sorted()
        XCTAssertEqual(sorted, [.verbose, .debug, .info, .warning, .error])
    }

    func testLogLevelRawValues() {
        XCTAssertEqual(LogLevel.verbose.rawValue, 0)
        XCTAssertEqual(LogLevel.debug.rawValue, 1)
        XCTAssertEqual(LogLevel.info.rawValue, 2)
        XCTAssertEqual(LogLevel.warning.rawValue, 3)
        XCTAssertEqual(LogLevel.error.rawValue, 4)
    }

    func testLogLevelEmoji() {
        XCTAssertFalse(LogLevel.verbose.emoji.isEmpty)
        XCTAssertFalse(LogLevel.debug.emoji.isEmpty)
        XCTAssertFalse(LogLevel.info.emoji.isEmpty)
        XCTAssertFalse(LogLevel.warning.emoji.isEmpty)
        XCTAssertFalse(LogLevel.error.emoji.isEmpty)
    }

    func testLogLevelTags() {
        XCTAssertEqual(LogLevel.verbose.tag, "VRB")
        XCTAssertEqual(LogLevel.debug.tag, "DBG")
        XCTAssertEqual(LogLevel.info.tag, "INF")
        XCTAssertEqual(LogLevel.warning.tag, "WRN")
        XCTAssertEqual(LogLevel.error.tag, "ERR")
    }

    func testLogCategoryAllCases() {
        XCTAssertEqual(LogCategory.allCases.count, 12)
        XCTAssertTrue(LogCategory.allCases.contains(.general))
        XCTAssertTrue(LogCategory.allCases.contains(.bridge))
        XCTAssertTrue(LogCategory.allCases.contains(.cache))
        XCTAssertTrue(LogCategory.allCases.contains(.network))
        XCTAssertTrue(LogCategory.allCases.contains(.handler))
        XCTAssertTrue(LogCategory.allCases.contains(.performance))
    }

    func testLogCategoryEmoji() {
        for category in LogCategory.allCases {
            XCTAssertFalse(category.emoji.isEmpty)
        }
    }

    func testLogCategoryRawValues() {
        XCTAssertEqual(LogCategory.general.rawValue, "general")
        XCTAssertEqual(LogCategory.bridge.rawValue, "bridge")
        XCTAssertEqual(LogCategory.cache.rawValue, "cache")
        XCTAssertEqual(LogCategory.network.rawValue, "network")
        XCTAssertEqual(LogCategory.handler.rawValue, "handler")
        XCTAssertEqual(LogCategory.performance.rawValue, "perf")
    }

    func testLogEntryIDIsUnique() {
        let entry1 = LogEntry(level: .info, category: .general, message: "a")
        let entry2 = LogEntry(level: .info, category: .general, message: "b")
        XCTAssertNotEqual(entry1.id, entry2.id)
    }

    func testLogEntryTimestampIsRecent() {
        let before = Date()
        let entry = LogEntry(level: .info, category: .general, message: "test")
        let after = Date()

        XCTAssertGreaterThanOrEqual(entry.timestamp, before)
        XCTAssertLessThanOrEqual(entry.timestamp, after)
    }

    func testLogLevelCodable() throws {
        let original = LogLevel.warning
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LogLevel.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testLogCategoryCodable() throws {
        let original = LogCategory.cache
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LogCategory.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
