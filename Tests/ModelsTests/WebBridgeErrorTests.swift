//
//  WebBridgeErrorTests.swift
//  ModelsTests
//

import XCTest
@testable import WebBridgeKit

final class WebBridgeErrorTests: XCTestCase {

    // MARK: - errorDescription

    func testErrorDescriptionInvalidInput() {
        let error = WebBridgeError.invalidInput("bad param")
        let description = error.errorDescription
        XCTAssertTrue(description?.contains("bad param") ?? false)
        XCTAssertTrue(description?.contains("Invalid input") ?? false)
    }

    func testErrorDescriptionNetworkRequestFailed() {
        let error = WebBridgeError.networkRequestFailed(reason: "timeout")
        let description = error.errorDescription
        XCTAssertTrue(description?.contains("timeout") ?? false)
        XCTAssertTrue(description?.contains("Network request failed") ?? false)
    }

    func testErrorDescriptionCacheLoadFailed() {
        let error = WebBridgeError.cacheLoadFailed(reason: "file missing")
        let description = error.errorDescription
        XCTAssertTrue(description?.contains("file missing") ?? false)
        XCTAssertTrue(description?.contains("Cache load failed") ?? false)
    }

    func testErrorDescriptionCacheSaveFailed() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "disk full"])
        let error = WebBridgeError.cacheSaveFailed(underlying: underlying)
        let description = error.errorDescription
        XCTAssertTrue(description?.contains("disk full") ?? false)
        XCTAssertTrue(description?.contains("Cache save failed") ?? false)
    }

    func testErrorDescriptionDatabaseOperationFailed() {
        let underlying = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "corrupt db"])
        let error = WebBridgeError.databaseOperationFailed(underlying: underlying)
        let description = error.errorDescription
        XCTAssertTrue(description?.contains("corrupt db") ?? false)
        XCTAssertTrue(description?.contains("Database operation failed") ?? false)
    }

    func testErrorDescriptionTimeout() {
        let error = WebBridgeError.timeout(operation: "fetch data")
        let description = error.errorDescription
        XCTAssertTrue(description?.contains("fetch data") ?? false)
        XCTAssertTrue(description?.contains("timed out") ?? false)
    }

    func testErrorDescriptionNetworkUnavailable() {
        let error = WebBridgeError.networkUnavailable(reason: "airplane mode")
        let description = error.errorDescription
        XCTAssertTrue(description?.contains("airplane mode") ?? false)
        XCTAssertTrue(description?.contains("Network unavailable") ?? false)
    }

    func testErrorDescriptionBrowserOpenFailed() {
        let error = WebBridgeError.browserOpenFailed(reason: "no handler")
        let description = error.errorDescription
        XCTAssertTrue(description?.contains("no handler") ?? false)
        XCTAssertTrue(description?.contains("Browser open failed") ?? false)
    }

    // MARK: - failureReason

    func testFailureReasonInvalidInput() {
        let error = WebBridgeError.invalidInput("empty field")
        XCTAssertEqual(error.failureReason, "empty field")
    }

    func testFailureReasonNetworkRequestFailed() {
        let error = WebBridgeError.networkRequestFailed(reason: "DNS failure")
        XCTAssertEqual(error.failureReason, "DNS failure")
    }

    func testFailureReasonCacheLoadFailed() {
        let error = WebBridgeError.cacheLoadFailed(reason: "not found")
        XCTAssertEqual(error.failureReason, "not found")
    }

    func testFailureReasonCacheSaveFailedPropagatesUnderlying() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "write error"])
        let error = WebBridgeError.cacheSaveFailed(underlying: underlying)
        XCTAssertEqual(error.failureReason, "write error")
    }

    func testFailureReasonDatabaseOperationFailedPropagatesUnderlying() {
        let underlying = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "schema error"])
        let error = WebBridgeError.databaseOperationFailed(underlying: underlying)
        XCTAssertEqual(error.failureReason, "schema error")
    }

    func testFailureReasonTimeout() {
        let error = WebBridgeError.timeout(operation: "download")
        let reason = error.failureReason
        XCTAssertTrue(reason?.contains("download") ?? false)
        XCTAssertTrue(reason?.contains("time limit") ?? false)
    }

    func testFailureReasonNetworkUnavailable() {
        let error = WebBridgeError.networkUnavailable(reason: "no wifi")
        XCTAssertEqual(error.failureReason, "no wifi")
    }

    func testFailureReasonBrowserOpenFailed() {
        let error = WebBridgeError.browserOpenFailed(reason: "unsupported scheme")
        XCTAssertEqual(error.failureReason, "unsupported scheme")
    }

    // MARK: - CustomStringConvertible

    func testDescriptionMatchesErrorDescription() {
        let cases: [WebBridgeError] = [
            .invalidInput("x"),
            .networkRequestFailed(reason: "y"),
            .cacheLoadFailed(reason: "z"),
            .cacheSaveFailed(underlying: NSError(domain: "t", code: 0)),
            .databaseOperationFailed(underlying: NSError(domain: "t", code: 0)),
            .timeout(operation: "op"),
            .networkUnavailable(reason: "r"),
            .browserOpenFailed(reason: "b")
        ]
        for error in cases {
            XCTAssertEqual(error.description, error.errorDescription)
        }
    }

    // MARK: - Edge Cases

    func testErrorDescriptionWithEmptyString() {
        let error = WebBridgeError.invalidInput("")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.failureReason)
    }

    func testErrorConformsToLocalizedError() {
        let error = WebBridgeError.timeout(operation: "test")
        let localized: LocalizedError = error
        XCTAssertNotNil(localized.errorDescription)
        XCTAssertNotNil(localized.failureReason)
    }

    func testErrorConformsToError() {
        let error: Error = WebBridgeError.networkUnavailable(reason: "test")
        XCTAssertNotNil((error as? LocalizedError)?.errorDescription)
    }
}
