//
//  NetworkHelperTests.swift
//  UtilsTests
//

import XCTest
@testable import WebBridgeKit

final class NetworkHelperTests: XCTestCase {

    func testSharedSingleton() {
        XCTAssertNotNil(NetworkHelper.shared)
        XCTAssertTrue(NetworkHelper.shared === NetworkHelper.shared)
    }

    func testFetchWithInvalidURLThrowsAsync() async {
        do {
            let invalidURL = URL(string: "http://0.0.0.0:1/nonexistent")!
            _ = try await NetworkHelper.shared.fetch(url: invalidURL)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is WebBridgeError)
        }
    }

    func testFetchWithHTTPErrorCodeThrowsAsync() async {
        do {
            let url = URL(string: "https://httpbin.org/status/404")!
            _ = try await NetworkHelper.shared.fetch(url: url)
            XCTFail("Should have thrown for 404")
        } catch {
            XCTAssertTrue(error is WebBridgeError)
        }
    }

    func testFetchSuccessReturnsDataAsync() async {
        do {
            let url = URL(string: "https://httpbin.org/get")!
            let data = try await NetworkHelper.shared.fetch(url: url)
            XCTAssertGreaterThan(data.count, 0)
        } catch {
            XCTFail("Should not throw for valid URL: \(error)")
        }
    }
}
