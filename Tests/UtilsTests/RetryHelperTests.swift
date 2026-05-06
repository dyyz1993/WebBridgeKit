//
//  RetryHelperTests.swift
//  UtilsTests
//

import XCTest
@testable import WebBridgeKit

final class RetryHelperTests: XCTestCase {

    // MARK: - execute (sync)

    func testExecuteSucceedsOnFirstTry() async throws {
        let result = try await RetryHelper.execute {
            return 42
        }
        XCTAssertEqual(result, 42)
    }

    func testExecuteSucceedsAfterRetries() async throws {
        var attempt = 0
        let result = try await RetryHelper.execute(maxRetries: 3, delay: 0.01) {
            attempt += 1
            if attempt < 3 {
                throw WebBridgeError.cacheLoadFailed(reason: "not yet")
            }
            return "success"
        }
        XCTAssertEqual(result, "success")
        XCTAssertEqual(attempt, 3)
    }

    func testExecuteThrowsAfterMaxRetries() async {
        var attempt = 0
        do {
            _ = try await RetryHelper.execute(maxRetries: 2, delay: 0.01) {
                attempt += 1
                throw WebBridgeError.networkRequestFailed(reason: "fail")
            }
            XCTFail("Should have thrown")
        } catch let error as WebBridgeError {
            if case .networkRequestFailed(let reason) = error {
                XCTAssertEqual(reason, "fail")
            } else {
                XCTFail("Wrong error type")
            }
            XCTAssertEqual(attempt, 2)
        } catch {
            XCTFail("Expected WebBridgeError but got \(error)")
        }
    }

    func testExecuteWithSingleRetry() async throws {
        var attempt = 0
        let result = try await RetryHelper.execute(maxRetries: 1, delay: 0.01) {
            attempt += 1
            return "ok"
        }
        XCTAssertEqual(result, "ok")
        XCTAssertEqual(attempt, 1)
    }

    // MARK: - executeAsync

    func testExecuteAsyncSucceedsOnFirstTry() async throws {
        let result = try await RetryHelper.executeAsync {
            return "async-ok"
        }
        XCTAssertEqual(result, "async-ok")
    }

    func testExecuteAsyncSucceedsAfterRetries() async throws {
        var attempt = 0
        let result = try await RetryHelper.executeAsync(maxRetries: 3, delay: 0.01) {
            attempt += 1
            if attempt < 2 {
                throw WebBridgeError.timeout(operation: "test")
            }
            return "recovered"
        }
        XCTAssertEqual(result, "recovered")
        XCTAssertEqual(attempt, 2)
    }

    func testExecuteAsyncThrowsAfterMaxRetries() async {
        do {
            _ = try await RetryHelper.executeAsync(maxRetries: 2, delay: 0.01) {
                throw WebBridgeError.networkUnavailable(reason: "offline")
            }
            XCTFail("Should have thrown")
        } catch let error as WebBridgeError {
            if case .networkUnavailable(let reason) = error {
                XCTAssertEqual(reason, "offline")
            }
        } catch {
            XCTFail("Expected WebBridgeError but got \(error)")
        }
    }

    // MARK: - executeWithExponentialBackoff

    func testExponentialBackoffSucceeds() async throws {
        var attempt = 0
        let result = try await RetryHelper.executeWithExponentialBackoff(maxRetries: 3, baseDelay: 0.01) {
            attempt += 1
            if attempt < 2 { throw WebBridgeError.cacheLoadFailed(reason: "retry") }
            return "backoff-ok"
        }
        XCTAssertEqual(result, "backoff-ok")
        XCTAssertEqual(attempt, 2)
    }

    func testExponentialBackoffThrowsAfterAllRetries() async {
        do {
            _ = try await RetryHelper.executeWithExponentialBackoff(maxRetries: 2, baseDelay: 0.01) {
                throw WebBridgeError.cacheLoadFailed(reason: "always fail")
            }
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is WebBridgeError)
        }
    }

    // MARK: - Default Parameters

    func testDefaultMaxRetriesIsThree() async throws {
        var attempt = 0
        do {
            _ = try await RetryHelper.execute(delay: 0.01) {
                attempt += 1
                throw WebBridgeError.cacheLoadFailed(reason: "test")
            }
        } catch {}
        XCTAssertEqual(attempt, 3)
    }
}
