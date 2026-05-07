//
//  TestLoggerTests.swift
//  UtilsTests
//

import XCTest
@testable import WebBridgeKit

final class TestLoggerTests: XCTestCase {

    private var sut: TestLogger!

    override func setUp() {
        super.setUp()
        sut = TestLogger(testName: "UnitTest")
    }

    override func tearDown() {
        TestLogger.clearAllLogs()
        sut = nil
        super.tearDown()
    }

    func testInitCreatesLogger() {
        XCTAssertNotNil(sut)
    }

    func testGenerateTimestamp() {
        let timestamp = TestLogger.generateTimestamp()
        XCTAssertFalse(timestamp.isEmpty)
        XCTAssertTrue(timestamp.contains("_"))
    }

    func testGenerateTimestampFormat() {
        let timestamp = TestLogger.generateTimestamp()
        let regex = try? NSRegularExpression(pattern: "^\\d{8}_\\d{6}$")
        let range = NSRange(timestamp.startIndex..., in: timestamp)
        XCTAssertNotNil(regex?.firstMatch(in: timestamp, range: range))
    }

    func testLogAddsEntry() {
        sut.log("Test message")
        let logs = sut.readAllLogs()
        XCTAssertTrue(logs.contains("Test message"))
    }

    func testLogSuccessAddsEntry() {
        sut.logSuccess("Operation succeeded")
        let logs = sut.readAllLogs()
        XCTAssertTrue(logs.contains("Operation succeeded"))
        XCTAssertTrue(logs.contains("✅"))
    }

    func testLogErrorAddsEntry() {
        sut.logError("Operation failed")
        let logs = sut.readAllLogs()
        XCTAssertTrue(logs.contains("Operation failed"))
        XCTAssertTrue(logs.contains("❌"))
    }

    func testLogWarningAddsEntry() {
        sut.logWarning("Warning issued")
        let logs = sut.readAllLogs()
        XCTAssertTrue(logs.contains("Warning issued"))
        XCTAssertTrue(logs.contains("⚠️"))
    }

    func testLogInfoAddsEntry() {
        sut.logInfo("Information message")
        let logs = sut.readAllLogs()
        XCTAssertTrue(logs.contains("Information message"))
        XCTAssertTrue(logs.contains("ℹ️"))
    }

    func testLogSeparator() {
        sut.logSeparator()
        let logs = sut.readAllLogs()
        XCTAssertTrue(logs.contains(String(repeating: "-", count: 50)))
    }

    func testLogDownloadProgress() {
        sut.logDownloadProgress(resource: "index.html", progress: 75)
        let logs = sut.readAllLogs()
        XCTAssertTrue(logs.contains("index.html"))
        XCTAssertTrue(logs.contains("75%"))
        XCTAssertTrue(logs.contains("📥"))
    }

    func testLogCacheHit() {
        sut.logCacheHit(resource: "style.css", size: 1024)
        let logs = sut.readAllLogs()
        XCTAssertTrue(logs.contains("style.css"))
        XCTAssertTrue(logs.contains("💾"))
    }

    func testLogResult() {
        sut.logResult(success: true, duration: 1.5, cacheSize: 2048)
        let logs = sut.readAllLogs()
        XCTAssertTrue(logs.contains("成功"))
        XCTAssertTrue(logs.contains("1.50秒"))
    }

    func testLogResultFailure() {
        sut.logResult(success: false, duration: 0.5, cacheSize: 0)
        let logs = sut.readAllLogs()
        XCTAssertTrue(logs.contains("失败"))
    }

    func testSaveCreatesFile() {
        sut.log("Test entry")
        sut.save()
        let fileURL = sut.getLogFileURL()
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testReadAllLogs() {
        sut.log("Line 1")
        sut.log("Line 2")
        sut.log("Line 3")
        let logs = sut.readAllLogs()
        XCTAssertTrue(logs.contains("Line 1"))
        XCTAssertTrue(logs.contains("Line 2"))
        XCTAssertTrue(logs.contains("Line 3"))
    }

    func testMultipleLogEntriesOrder() {
        sut.log("First")
        sut.log("Second")
        let logs = sut.readAllLogs()
        let firstRange = logs.range(of: "First")
        let secondRange = logs.range(of: "Second")
        XCTAssertNotNil(firstRange)
        XCTAssertNotNil(secondRange)
        XCTAssertTrue(firstRange!.lowerBound < secondRange!.lowerBound)
    }

    func testGetLogFileURL() {
        let url = sut.getLogFileURL()
        XCTAssertTrue(url.path.hasSuffix(".log"))
        XCTAssertTrue(url.path.contains("TestLogs"))
    }

    func testCreateBatchLogger() {
        let batchLogger = TestLogger.createBatchLogger(batchName: "TestBatch")
        XCTAssertNotNil(batchLogger)
        let logs = batchLogger.readAllLogs()
        XCTAssertTrue(logs.contains("Batch_TestBatch"))
    }

    func testListAllLogFiles() {
        sut.save()
        let files = TestLogger.listAllLogFiles()
        XCTAssertFalse(files.isEmpty)
    }

    func testClearAllLogs() {
        sut.save()
        TestLogger.clearAllLogs()
        let files = TestLogger.listAllLogFiles()
        XCTAssertTrue(files.isEmpty)
    }

    func testReadLogFileReturnsNilForNonExistent() {
        let content = TestLogger.readLogFile(fileName: "nonexistent.log")
        XCTAssertNil(content)
    }
}
