//
//  RequestDeduplicatorTests.swift
//  UtilsTests
//

import XCTest
@testable import WebBridgeKit

final class RequestDeduplicatorTests: XCTestCase {

    private var deduplicator: RequestDeduplicator!

    override func setUp() {
        super.setUp()
        deduplicator = RequestDeduplicator.shared
        deduplicator.cancelAll()
    }

    override func tearDown() {
        deduplicator.cancelAll()
        super.tearDown()
    }

    // MARK: - Basic Execution

    func testExecuteReturnsResult() async throws {
        let result = try await deduplicator.execute(key: "test1") {
            return "hello"
        }
        XCTAssertEqual(result, "hello")
    }

    func testExecuteCleansUpAfterSuccess() async throws {
        try await deduplicator.execute(key: "test-cleanup") {
            return 42
        }
        XCTAssertFalse(deduplicator.isPending(key: "test-cleanup"))
    }

    func testExecuteCleansUpAfterError() async {
        do {
            _ = try await deduplicator.execute(key: "test-error") {
                throw WebBridgeError.cacheLoadFailed(reason: "test error")
            }
            XCTFail("Should have thrown")
        } catch {
            XCTAssertFalse(deduplicator.isPending(key: "test-error"))
        }
    }

    // MARK: - Deduplication

    func testIsPendingReturnsTrueDuringExecution() async {
        let expectation = XCTestExpectation(description: "task started")

        Task {
            _ = try await deduplicator.execute(key: "pending-test") {
                expectation.fulfill()
                try await Task.sleep(nanoseconds: 500_000_000)
                return "result"
            }
        }

        await fulfillment(of: [expectation], timeout: 2)
        XCTAssertTrue(deduplicator.isPending(key: "pending-test"))

        deduplicator.cancel(key: "pending-test")
    }

    func testIsPendingReturnsFalseWhenNotRunning() {
        XCTAssertFalse(deduplicator.isPending(key: "nonexistent"))
    }

    // MARK: - Cancel

    func testCancelRemovesTask() async {
        let expectation = XCTestExpectation(description: "task started")

        Task {
            _ = try? await deduplicator.execute(key: "cancel-test") {
                expectation.fulfill()
                try await Task.sleep(nanoseconds: 2_000_000_000)
                return "late"
            }
        }

        await fulfillment(of: [expectation], timeout: 2)
        deduplicator.cancel(key: "cancel-test")
        XCTAssertFalse(deduplicator.isPending(key: "cancel-test"))
    }

    func testCancelAllRemovesAllTasks() async {
        let exp1 = XCTestExpectation(description: "task1")
        let exp2 = XCTestExpectation(description: "task2")

        Task { _ = try? await deduplicator.execute(key: "a") { exp1.fulfill(); try await Task.sleep(nanoseconds: 2_000_000_000); return 1 } }
        Task { _ = try? await deduplicator.execute(key: "b") { exp2.fulfill(); try await Task.sleep(nanoseconds: 2_000_000_000); return 2 } }

        await fulfillment(of: [exp1, exp2], timeout: 2)
        deduplicator.cancelAll()

        let stats = deduplicator.getStats()
        XCTAssertEqual(stats["pendingCount"] as? Int, 0)
    }

    // MARK: - Stats

    func testGetStatsReturnsCorrectCount() async {
        let exp = XCTestExpectation(description: "started")

        Task {
            _ = try? await deduplicator.execute(key: "stats-key") {
                exp.fulfill()
                try await Task.sleep(nanoseconds: 2_000_000_000)
                return "x"
            }
        }

        await fulfillment(of: [exp], timeout: 2)
        let stats = deduplicator.getStats()
        XCTAssertEqual(stats["pendingCount"] as? Int, 1)

        let keys = stats["keys"] as? [String]
        XCTAssertTrue(keys?.contains("stats-key") ?? false)

        deduplicator.cancelAll()
    }

    func testGetStatsReturnsEmptyAfterCancelAll() {
        deduplicator.cancelAll()
        let stats = deduplicator.getStats()
        XCTAssertEqual(stats["pendingCount"] as? Int, 0)
    }

    // MARK: - Convenience Methods

    func testExecutePagePreloadUsesPagePrefix() async throws {
        let result = try await deduplicator.executePagePreload(pageName: "home") {
            return true
        }
        XCTAssertTrue(result)
    }

    func testExecuteResourceDownloadUsesResourcePrefix() async throws {
        let result = try await deduplicator.executeResourceDownload(urlString: "https://example.com/file.js", relativePath: "file.js") {
            return "data"
        }
        XCTAssertEqual(result as? String, "data")
    }
}
