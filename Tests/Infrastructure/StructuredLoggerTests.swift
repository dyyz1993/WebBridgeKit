import XCTest
@testable import WebBridgeKit

final class StructuredLoggerTests: XCTestCase {

    var logger: StructuredLogger!

    override func setUp() {
        super.setUp()
        logger = StructuredLogger()
        logger.clearBuffer()
    }

    override func tearDown() {
        logger.clearBuffer()
        super.tearDown()
    }

    func testSharedIsSingleton() {
        let l1 = StructuredLogger.shared
        let l2 = StructuredLogger.shared
        XCTAssertTrue(l1 === l2)
    }

    func testSharedIsNotNil() {
        XCTAssertNotNil(StructuredLogger.shared)
    }

    func testSessionIdLengthIsEight() {
        XCTAssertEqual(logger.sessionId.count, 8)
    }

    func testSessionIdIsLowercase() {
        XCTAssertEqual(logger.sessionId, logger.sessionId.lowercased())
    }

    func testMinLevelDefaultIsDebug() {
        XCTAssertEqual(logger.minLevel, .debug)
    }

    func testMemoryBufferIsNotNil() {
        XCTAssertNotNil(logger.memoryBuffer)
    }

    func testAddOutputDoesNotCrash() {
        logger.addOutput(MemoryLogOutput(maxCapacity: 10))
    }

    func testRemoveOutputDoesNotCrash() {
        let output = MemoryLogOutput(maxCapacity: 10)
        logger.addOutput(output)
        logger.removeOutput(output)
    }

    func testSetOutputsReplacesOutputs() {
        let newOutputs: [LogOutput] = [MemoryLogOutput(maxCapacity: 5)]
        logger.setOutputs(newOutputs)
        logger.clearBuffer()
    }

    func testVerboseMethodCallable() {
        logger.minLevel = .verbose
        logger.verbose("verbose test message")
        let entries = logger.query()
        XCTAssertFalse(entries.isEmpty)
        XCTAssertEqual(entries.last?.level, .verbose)
    }

    func testDebugMethodCallable() {
        logger.minLevel = .debug
        logger.debug("debug test message")
        let entries = logger.query()
        XCTAssertFalse(entries.isEmpty)
        XCTAssertEqual(entries.last?.level, .debug)
    }

    func testInfoMethodCallable() {
        logger.minLevel = .debug
        logger.info("info test message")
        let entries = logger.query()
        XCTAssertFalse(entries.isEmpty)
        XCTAssertEqual(entries.last?.level, .info)
    }

    func testWarningMethodCallable() {
        logger.minLevel = .debug
        logger.warning("warning test message")
        let entries = logger.query()
        XCTAssertFalse(entries.isEmpty)
        XCTAssertEqual(entries.last?.level, .warning)
    }

    func testErrorMethodCallable() {
        logger.minLevel = .debug
        logger.error("error test message")
        let entries = logger.query()
        XCTAssertFalse(entries.isEmpty)
        XCTAssertEqual(entries.last?.level, .error)
    }

    func testMeasureReturnsCorrectResult() {
        logger.minLevel = .debug
        let result = logger.measure(action: "test-measure") {
            return 42
        }
        XCTAssertEqual(result, 42)
    }

    func testMeasureLogsPerformanceEntry() {
        logger.minLevel = .debug
        logger.clearBuffer()

        _ = logger.measure(action: "perf-test") {
            Thread.sleep(forTimeInterval: 0.01)
            return "done"
        }

        let entries = logger.query(action: "perf-test")
        XCTAssertFalse(entries.isEmpty)
        XCTAssertEqual(entries.last?.action, "perf-test")
        XCTAssertNotNil(entries.last?.durationMs)
    }

    func testQueryReturnsArray() {
        logger.minLevel = .debug
        logger.debug("query test")
        let results = logger.query()
        XCTAssertNotNil(results)
        XCTAssertTrue(results is [LogEntry])
    }

    func testQueryWithCategoryFilter() {
        logger.minLevel = .debug
        logger.clearBuffer()
        logger.debug("cat test", category: .cache)

        let results = logger.query(category: .cache)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.category, .cache)
    }

    func testQueryWithLimit() {
        logger.minLevel = .debug
        logger.clearBuffer()
        logger.debug("limit-1")
        logger.debug("limit-2")
        logger.debug("limit-3")

        let results = logger.query(limit: 2)
        XCTAssertLessThanOrEqual(results.count, 2)
    }

    func testQueryWithSearchFilter() {
        logger.minLevel = .debug
        logger.clearBuffer()
        logger.debug("unique-search-term-here")

        let results = logger.query(search: "unique-search-term-here")
        XCTAssertEqual(results.count, 1)
    }

    func testGetStatsReturnsLogStats() {
        logger.minLevel = .debug
        logger.clearBuffer()
        logger.debug("stat-1")
        logger.error("stat-error")
        logger.warning("stat-warn")

        let stats = logger.getStats()
        XCTAssertGreaterThanOrEqual(stats.totalEntries, 3)
        XCTAssertGreaterThanOrEqual(stats.errorCount, 1)
        XCTAssertGreaterThanOrEqual(stats.warningCount, 1)
        XCTAssertNotNil(stats.categories[.general])
    }

    func testClearBufferDoesNotCrash() {
        logger.debug("before clear")
        logger.clearBuffer()
        let entries = logger.query()
        XCTAssertEqual(entries.count, 0)
    }

    func testExportJSONReturnsString() {
        logger.minLevel = .debug
        logger.debug("export test")
        let json = logger.exportJSON()
        XCTAssertFalse(json.isEmpty)

        if let data = json.data(using: .utf8) {
            let parsed = try? JSONSerialization.jsonObject(with: data)
            XCTAssertNotNil(parsed)
            XCTAssertTrue(parsed is [Any])
        }
    }

    func testMinLevelFilterBlocksLowerLevels() {
        logger.minLevel = .error
        logger.clearBuffer()

        logger.debug("should be filtered")
        logger.info("should be filtered")
        logger.warning("should be filtered")
        logger.error("should pass")

        let entries = logger.query()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.level, .error)
    }

    func testMinLevelFilterWarningAndAbove() {
        logger.minLevel = .warning
        logger.clearBuffer()

        logger.verbose("filtered")
        logger.debug("filtered")
        logger.info("filtered")
        logger.warning("pass-1")
        logger.error("pass-2")

        let entries = logger.query()
        XCTAssertEqual(entries.count, 2)
    }

    func testIncludeFileLocationToggle() {
        logger.includeFileLocation = false
        XCTAssertFalse(logger.includeFileLocation)

        logger.includeFileLocation = true
        XCTAssertTrue(logger.includeFileLocation)
    }

    func testLogWithCategoryAndContext() {
        logger.minLevel = .debug
        logger.clearBuffer()
        logger.debug("context test", category: .network, context: ["url": "https://example.com"])

        let entries = logger.query(category: .network)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.context?["url"], "https://example.com")
    }

    func testLogWithActionParameter() {
        logger.minLevel = .debug
        logger.clearBuffer()
        logger.info("action test", action: "myAction")

        let entries = logger.query(action: "myAction")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.action, "myAction")
    }

    func testExportJSONEmptyBuffer() {
        logger.clearBuffer()
        let json = logger.exportJSON()
        XCTAssertFalse(json.isEmpty)

        if let data = json.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            XCTAssertEqual(parsed.count, 0)
        }
    }
}
