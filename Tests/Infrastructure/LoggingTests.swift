//
//  LoggingTests.swift
//  WebBridgeKitTests
//

import XCTest
@testable import WebBridgeKit

final class LoggingTests: XCTestCase {

    var logger: StructuredLogger!
    var memoryOutput: MemoryLogOutput!

    override func setUp() {
        super.setUp()
        logger = StructuredLogger()
        memoryOutput = MemoryLogOutput(maxCapacity: 100)
        logger.setOutputs([memoryOutput])
    }

    override func tearDown() {
        logger = nil
        memoryOutput = nil
        super.tearDown()
    }

    // MARK: - Basic Logging

    func testLogLevels() {
        logger.minLevel = .verbose
        logger.verbose("verbose msg", category: .general)
        logger.debug("debug msg", category: .general)
        logger.info("info msg", category: .general)
        logger.warning("warning msg", category: .general)
        logger.error("error msg", category: .general)

        let entries = memoryOutput.entries
        XCTAssertEqual(entries.count, 5)
        XCTAssertEqual(entries[0].level, .verbose)
        XCTAssertEqual(entries[1].level, .debug)
        XCTAssertEqual(entries[2].level, .info)
        XCTAssertEqual(entries[3].level, .warning)
        XCTAssertEqual(entries[4].level, .error)
    }

    func testMinLevelFiltering() {
        logger.minLevel = .warning
        logger.info("should be filtered", category: .general)
        logger.warning("should pass", category: .general)
        logger.error("should pass", category: .general)

        XCTAssertEqual(memoryOutput.entries.count, 2)
    }

    func testLogCategories() {
        logger.info("bridge msg", category: .bridge)
        logger.info("cache msg", category: .cache)
        logger.info("network msg", category: .network)

        let entries = memoryOutput.entries
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].category, .bridge)
        XCTAssertEqual(entries[1].category, .cache)
        XCTAssertEqual(entries[2].category, .network)
    }

    // MARK: - Query

    func testQueryByCategory() {
        logger.info("bridge1", category: .bridge)
        logger.info("cache1", category: .cache)
        logger.info("bridge2", category: .bridge)

        let bridgeLogs = memoryOutput.query(category: .bridge)
        XCTAssertEqual(bridgeLogs.count, 2)

        let cacheLogs = memoryOutput.query(category: .cache)
        XCTAssertEqual(cacheLogs.count, 1)
    }

    func testQueryByLevel() {
        logger.info("info1", category: .general)
        logger.error("error1", category: .general)
        logger.info("info2", category: .general)
        logger.warning("warn1", category: .general)

        let errorsAndAbove = memoryOutput.query(minLevel: .error)
        XCTAssertEqual(errorsAndAbove.count, 1)

        let warningsAndAbove = memoryOutput.query(minLevel: .warning)
        XCTAssertEqual(warningsAndAbove.count, 2)
    }

    func testQueryByAction() {
        logger.info("msg1", category: .handler, action: "camera")
        logger.info("msg2", category: .handler, action: "location")
        logger.info("msg3", category: .handler, action: "camera")

        let cameraLogs = memoryOutput.query(action: "camera")
        XCTAssertEqual(cameraLogs.count, 2)
    }

    func testQueryBySearch() {
        logger.info("User tapped button", category: .general)
        logger.info("Network request started", category: .network)
        logger.info("Button was pressed again", category: .general)

        let results = memoryOutput.query(search: "button")
        XCTAssertEqual(results.count, 2)
    }

    func testQueryWithLimit() {
        for i in 0..<50 {
            logger.info("msg \(i)", category: .general)
        }

        let limited = memoryOutput.query(limit: 10)
        XCTAssertEqual(limited.count, 10)
    }

    // MARK: - LogEntry Format

    func testLogEntryJSON() {
        logger.info("test message", category: .bridge, action: "camera")
        let entry = memoryOutput.entries.first!

        let json = entry.jsonDict
        XCTAssertEqual(json["level"] as? String, "INF")
        XCTAssertEqual(json["category"] as? String, "bridge")
        XCTAssertEqual(json["action"] as? String, "camera")
        XCTAssertNotNil(json["ts"])
        XCTAssertNotNil(json["id"])
    }

    func testLogEntryConsoleString() {
        logger.info("hello world", category: .bridge, action: "test")
        let entry = memoryOutput.entries.first!

        let console = entry.consoleString
        XCTAssertTrue(console.contains("INF"))
        XCTAssertTrue(console.contains("bridge"))
        XCTAssertTrue(console.contains("hello world"))
    }

    func testLogEntryDebugString() {
        logger.error("something broke", category: .handler, action: "camera", context: ["key": "value"])
        let entry = memoryOutput.entries.first!

        let debug = entry.debugString
        XCTAssertTrue(debug.contains("=== Log Entry ==="))
        XCTAssertTrue(debug.contains("something broke"))
        XCTAssertTrue(debug.contains("camera"))
        XCTAssertTrue(debug.contains("key: value"))
    }

    // MARK: - Memory Buffer

    func testMemoryBufferCapacity() {
        let buffer = MemoryLogOutput(maxCapacity: 5)

        for i in 0..<10 {
            let entry = LogEntry(level: .info, category: .general, message: "msg \(i)")
            buffer.write(entry)
        }

        XCTAssertEqual(buffer.entries.count, 5)
        XCTAssertEqual(buffer.entries.first?.message, "msg 5")
        XCTAssertEqual(buffer.entries.last?.message, "msg 9")
    }

    func testMemoryBufferClear() {
        let buffer = MemoryLogOutput()
        buffer.write(LogEntry(level: .info, category: .general, message: "test"))
        XCTAssertEqual(buffer.entries.count, 1)

        buffer.clear()
        XCTAssertEqual(buffer.entries.count, 0)
    }

    func testExportJSON() {
        logger.info("msg1", category: .bridge)
        logger.error("msg2", category: .cache)

        let json = logger.exportJSON()
        XCTAssertTrue(json.contains("msg1"))
        XCTAssertTrue(json.contains("msg2"))
        XCTAssertTrue(json.hasPrefix("["))
    }

    // MARK: - Measure

    func testMeasure() {
        let result = logger.measure(category: .performance, action: "test_op") {
            return 42
        }
        XCTAssertEqual(result, 42)

        let entries = memoryOutput.query(category: .performance)
        XCTAssertEqual(entries.count, 1)
        XCTAssertNotNil(entries.first?.durationMs)
    }

    // MARK: - Stats

    func testGetStats() {
        logger.info("info", category: .general)
        logger.error("error", category: .general)
        logger.error("error2", category: .general)
        logger.warning("warn", category: .general)

        let stats = logger.getStats()
        XCTAssertEqual(stats.totalEntries, 4)
        XCTAssertEqual(stats.errorCount, 2)
        XCTAssertEqual(stats.warningCount, 1)
    }

    // MARK: - Compatibility Bridge

    func testBridgeModeForwarding() {
        let oldLogger = WebBridgeLogger.shared
        oldLogger.useStructuredLogger = true

        StructuredLogger.shared.clearBuffer()
        StructuredLogger.shared.minLevel = .verbose
        StructuredLogger.shared.setOutputs([memoryOutput])

        oldLogger.bridgedInfo("bridge info test", category: .general)
        oldLogger.bridgedError("bridge error test", category: .network)
        oldLogger.bridgedDebug("bridge debug test", category: .cache)
        oldLogger.bridgedWarning("bridge warn test", category: .ui)

        let entries = memoryOutput.entries
        XCTAssertEqual(entries.count, 4)
        XCTAssertEqual(entries[0].level, .info)
        XCTAssertEqual(entries[1].level, .error)
        XCTAssertEqual(entries[2].level, .debug)
        XCTAssertEqual(entries[3].level, .warning)

        oldLogger.useStructuredLogger = false
    }

    func testBridgeCategoryMapping() {
        let oldLogger = WebBridgeLogger.shared
        oldLogger.useStructuredLogger = true

        StructuredLogger.shared.clearBuffer()
        StructuredLogger.shared.minLevel = .verbose
        StructuredLogger.shared.setOutputs([memoryOutput])

        oldLogger.bridgedInfo("browser msg", category: .browser)
        oldLogger.bridgedInfo("cache msg", category: .cache)

        let entries = memoryOutput.entries
        XCTAssertEqual(entries[0].category, .bridge)
        XCTAssertEqual(entries[1].category, .cache)

        oldLogger.useStructuredLogger = false
    }

    func testBridgeRequestResponse() {
        let oldLogger = WebBridgeLogger.shared
        oldLogger.useStructuredLogger = true

        StructuredLogger.shared.clearBuffer()
        StructuredLogger.shared.minLevel = .verbose
        StructuredLogger.shared.setOutputs([memoryOutput])

        let token = oldLogger.bridgedLogRequest(action: "camera", params: ["mode": "photo"], module: "Media")
        oldLogger.bridgedLogResponse(token: token, result: nil, error: nil)

        let entries = memoryOutput.entries
        XCTAssertGreaterThanOrEqual(entries.count, 2)

        let hasRequest = entries.contains { $0.message.contains("Request") }
        let hasResponse = entries.contains { $0.message.contains("Response") }
        XCTAssertTrue(hasRequest)
        XCTAssertTrue(hasResponse)

        oldLogger.useStructuredLogger = false
    }

    func testBridgeLogGeneric() {
        let oldLogger = WebBridgeLogger.shared
        oldLogger.useStructuredLogger = true

        StructuredLogger.shared.clearBuffer()
        StructuredLogger.shared.minLevel = .verbose
        StructuredLogger.shared.setOutputs([memoryOutput])

        oldLogger.bridgedLog(.warning, category: .performance, message: "generic bridge log")

        let entries = memoryOutput.entries
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].level, .warning)
        XCTAssertEqual(entries[0].category, .performance)

        oldLogger.useStructuredLogger = false
    }

    func testBridgeEventForwarding() {
        let oldLogger = WebBridgeLogger.shared
        oldLogger.useStructuredLogger = true

        StructuredLogger.shared.clearBuffer()
        StructuredLogger.shared.minLevel = .verbose
        StructuredLogger.shared.setOutputs([memoryOutput])

        oldLogger.bridgedLogEvent(event: "page_loaded", data: "test", module: "Core")

        let entries = memoryOutput.entries
        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].message.contains("page_loaded"))

        oldLogger.useStructuredLogger = false
    }

    func testEnableDisableStructuredBridge() {
        XCTAssertFalse(WebBridgeLogger.shared.useStructuredLogger)

        WebBridgeLogger.enableStructuredBridge()
        XCTAssertTrue(WebBridgeLogger.shared.useStructuredLogger)

        WebBridgeLogger.disableStructuredBridge()
        XCTAssertFalse(WebBridgeLogger.shared.useStructuredLogger)
    }

    func testBridgeFallbackToOriginal() {
        let oldLogger = WebBridgeLogger.shared
        oldLogger.useStructuredLogger = false

        StructuredLogger.shared.clearBuffer()
        StructuredLogger.shared.minLevel = .verbose
        StructuredLogger.shared.setOutputs([memoryOutput])

        oldLogger.bridgedInfo("should use old logger", category: .general)

        let entries = memoryOutput.entries
        XCTAssertEqual(entries.count, 0, "When bridge is off, StructuredLogger should NOT receive entries")
    }
}
