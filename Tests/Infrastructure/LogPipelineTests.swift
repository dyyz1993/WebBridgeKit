//
//  LogPipelineTests.swift
//  InfrastructureTests
//

import XCTest
@testable import WebBridgeKit

final class LogPipelineTests: XCTestCase {

    // MARK: - ConsoleLogOutput

    func testConsoleLogOutputWriteDoesNotCrash() {
        let output = ConsoleLogOutput()
        let entry = LogEntry(level: .info, category: .general, message: "console test")
        XCTAssertNoThrow(output.write(entry))
    }

    func testConsoleLogOutputFlush() {
        let output = ConsoleLogOutput()
        XCTAssertNoThrow(output.flush())
    }

    // MARK: - MemoryLogOutput

    func testMemoryLogOutputWrite() {
        let output = MemoryLogOutput(maxCapacity: 100)
        let entry = LogEntry(level: .info, category: .general, message: "test")
        output.write(entry)

        XCTAssertEqual(output.entries.count, 1)
        XCTAssertEqual(output.entries.first?.message, "test")
    }

    func testMemoryLogOutputMaxCapacity() {
        let output = MemoryLogOutput(maxCapacity: 3)
        for i in 0..<5 {
            output.write(LogEntry(level: .info, category: .general, message: "msg\(i)"))
        }

        XCTAssertEqual(output.entries.count, 3)
        XCTAssertEqual(output.entries.first?.message, "msg2")
        XCTAssertEqual(output.entries.last?.message, "msg4")
    }

    func testMemoryLogOutputQueryByCategory() {
        let output = MemoryLogOutput()
        output.write(LogEntry(level: .info, category: .bridge, message: "bridge1"))
        output.write(LogEntry(level: .info, category: .cache, message: "cache1"))
        output.write(LogEntry(level: .info, category: .bridge, message: "bridge2"))

        let bridgeResults = output.query(category: .bridge)
        XCTAssertEqual(bridgeResults.count, 2)

        let cacheResults = output.query(category: .cache)
        XCTAssertEqual(cacheResults.count, 1)
    }

    func testMemoryLogOutputQueryByMinLevel() {
        let output = MemoryLogOutput()
        output.write(LogEntry(level: .debug, category: .general, message: "debug"))
        output.write(LogEntry(level: .info, category: .general, message: "info"))
        output.write(LogEntry(level: .error, category: .general, message: "error"))

        let results = output.query(minLevel: .info)
        XCTAssertEqual(results.count, 2)
    }

    func testMemoryLogOutputQueryByAction() {
        let output = MemoryLogOutput()
        output.write(LogEntry(level: .info, category: .general, message: "msg1", action: "fetch"))
        output.write(LogEntry(level: .info, category: .general, message: "msg2", action: "save"))
        output.write(LogEntry(level: .info, category: .general, message: "msg3", action: "fetch"))

        let fetchResults = output.query(action: "fetch")
        XCTAssertEqual(fetchResults.count, 2)
    }

    func testMemoryLogOutputQueryBySearch() {
        let output = MemoryLogOutput()
        output.write(LogEntry(level: .info, category: .general, message: "Hello World"))
        output.write(LogEntry(level: .info, category: .general, message: "Goodbye World"))
        output.write(LogEntry(level: .info, category: .general, message: "Hello Swift"))

        let results = output.query(search: "hello")
        XCTAssertEqual(results.count, 2)
    }

    func testMemoryLogOutputQueryBySearchCaseInsensitive() {
        let output = MemoryLogOutput()
        output.write(LogEntry(level: .info, category: .general, message: "UPPERCASE message"))

        let results = output.query(search: "uppercase")
        XCTAssertEqual(results.count, 1)
    }

    func testMemoryLogOutputQueryBySince() {
        let output = MemoryLogOutput()
        let oldDate = Date().addingTimeInterval(-3600)
        output.write(LogEntry(level: .info, category: .general, message: "old", timestamp: oldDate))

        let since = Date().addingTimeInterval(-60)
        output.write(LogEntry(level: .info, category: .general, message: "recent"))

        let results = output.query(since: since)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.message, "recent")
    }

    func testMemoryLogOutputQueryWithLimit() {
        let output = MemoryLogOutput()
        for i in 0..<10 {
            output.write(LogEntry(level: .info, category: .general, message: "msg\(i)"))
        }

        let results = output.query(limit: 3)
        XCTAssertEqual(results.count, 3)
    }

    func testMemoryLogOutputQueryReturnsMostRecentFirst() {
        let output = MemoryLogOutput()
        output.write(LogEntry(level: .info, category: .general, message: "first"))
        output.write(LogEntry(level: .info, category: .general, message: "second"))
        output.write(LogEntry(level: .info, category: .general, message: "third"))

        let results = output.query()
        XCTAssertEqual(results.first?.message, "third")
        XCTAssertEqual(results.last?.message, "first")
    }

    func testMemoryLogOutputClear() {
        let output = MemoryLogOutput()
        output.write(LogEntry(level: .info, category: .general, message: "test"))
        XCTAssertEqual(output.entries.count, 1)

        output.clear()
        XCTAssertTrue(output.entries.isEmpty)
    }

    func testMemoryLogOutputExportJSON() {
        let output = MemoryLogOutput()
        output.write(LogEntry(level: .info, category: .general, message: "entry1"))
        output.write(LogEntry(level: .error, category: .network, message: "entry2"))

        let json = output.exportJSON()
        XCTAssertTrue(json.hasPrefix("["))
        XCTAssertTrue(json.contains("entry1"))
        XCTAssertTrue(json.contains("entry2"))
    }

    func testMemoryLogOutputExportEmptyJSON() {
        let output = MemoryLogOutput()
        let json = output.exportJSON()
        XCTAssertTrue(json.hasPrefix("[") && json.hasSuffix("]"))
        let data = json.data(using: .utf8)
        let arr = try? JSONSerialization.jsonObject(with: data!) as? [Any]
        XCTAssertNotNil(arr)
        XCTAssertEqual(arr?.count, 0)
    }

    func testMemoryLogOutputFlush() {
        let output = MemoryLogOutput()
        XCTAssertNoThrow(output.flush())
    }

    // MARK: - CallbackLogOutput

    func testCallbackLogOutputReceivesEntries() {
        let expectation = self.expectation(description: "callback received")
        var receivedEntry: LogEntry?

        let output = CallbackLogOutput { entry in
            receivedEntry = entry
            expectation.fulfill()
        }

        let entry = LogEntry(level: .info, category: .general, message: "callback test")
        output.write(entry)

        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(receivedEntry)
        XCTAssertEqual(receivedEntry?.message, "callback test")
    }

    func testCallbackLogOutputFlush() {
        let output = CallbackLogOutput()
        XCTAssertNoThrow(output.flush())
    }

    func testCallbackLogOutputWithNilCallback() {
        let output = CallbackLogOutput(onLog: nil)
        let entry = LogEntry(level: .info, category: .general, message: "test")
        XCTAssertNoThrow(output.write(entry))
    }

    // MARK: - FileLogOutput

    func testFileLogOutputCreatesFile() {
        let tempDir = NSTemporaryDirectory()
        let filePath = tempDir + "test_log_\(UUID().uuidString).log"

        let output = FileLogOutput(filePath: filePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))

        let entry = LogEntry(level: .info, category: .general, message: "file test")
        output.write(entry)
        output.flush()

        try? FileManager.default.removeItem(atPath: filePath)
    }

    func testFileLogOutputWritesToFile() {
        let tempDir = NSTemporaryDirectory()
        let filePath = tempDir + "test_log_write_\(UUID().uuidString).log"

        let output = FileLogOutput(filePath: filePath)
        let entry = LogEntry(level: .info, category: .general, message: "written content")
        output.write(entry)

        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            semaphore.signal()
        }
        semaphore.wait()

        output.flush()

        let content = try? String(contentsOfFile: filePath)
        XCTAssertNotNil(content)
        XCTAssertTrue(content?.contains("written content") ?? false)

        try? FileManager.default.removeItem(atPath: filePath)
    }

    func testFileLogOutputFlush() {
        let tempDir = NSTemporaryDirectory()
        let filePath = tempDir + "test_log_flush_\(UUID().uuidString).log"

        let output = FileLogOutput(filePath: filePath)
        XCTAssertNoThrow(output.flush())

        try? FileManager.default.removeItem(atPath: filePath)
    }

    func testFileLogOutputDefaultPath() {
        let output = FileLogOutput()
        XCTAssertTrue(output.filePath.hasSuffix("webbridgekit.log"))
    }

    func testFileLogOutputMaxFileSize() {
        let output = FileLogOutput(maxFileSize: 10)
        XCTAssertEqual(output.maxFileSize, 10)
    }

    // MARK: - Combined Pipeline

    func testMultipleOutputsReceiveSameEntry() {
        let output1 = MemoryLogOutput()
        let output2 = MemoryLogOutput()
        let entry = LogEntry(level: .info, category: .general, message: "broadcast")

        output1.write(entry)
        output2.write(entry)

        XCTAssertEqual(output1.entries.count, 1)
        XCTAssertEqual(output2.entries.count, 1)
        XCTAssertEqual(output1.entries.first?.message, "broadcast")
        XCTAssertEqual(output2.entries.first?.message, "broadcast")
    }
}
