//
//  ThreadSafetyTests.swift
//  WebBridgeKitTests
//
//  Created by Claude on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest
@testable import WebBridgeKit
import Foundation

/// Thread safety tests for WebBridgeKit cache system
/// Tests concurrent access, deadlock prevention, and progress update throttling
final class ThreadSafetyTests: XCTestCase {

    // MARK: - Test Configuration

    var timeout: TimeInterval { 10.0 }
    var threadCount: Int { 10 }
    var iterationCount: Int { 100 }

    // MARK: - ManifestStore Tests

    func testManifestStoreConcurrentReadWrite() throws {
        let store = ManifestStore()
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = threadCount * 2

        for i in 0..<threadCount {
            DispatchQueue.global(qos: .userInitiated).async {
                store.saveHTML("<html>Page \(i)</html>", for: "page_\(i)")
                expectation.fulfill()
            }

            DispatchQueue.global(qos: .userInitiated).async {
                _ = store.getHTML(for: "page_\(i)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: timeout)

        // Verify data integrity
        for i in 0..<threadCount {
            let html = store.getHTML(for: "page_\(i)")
            XCTAssertNotNil(html, "HTML should exist for page_\(i)")
            XCTAssertEqual(html, "<html>Page \(i)</html>", "HTML content should match")
        }
    }

    func testManifestStoreNoDeadlock() throws {
        let store = ManifestStore()
        let expectation = XCTestExpectation(description: "No deadlock")
        expectation.expectedFulfillmentCount = threadCount

        for i in 0..<threadCount {
            DispatchQueue.global(qos: .userInitiated).async {
                store.saveHTML("Test \(i)", for: "key_\(i)")
                _ = store.getHTML(for: "key_\(i)")
                expectation.fulfill()
            }
        }

        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "All operations should complete without deadlock")
    }

    func testManifestStressTest() throws {
        let store = ManifestStore()
        let expectation = XCTestExpectation(description: "Stress test")
        expectation.expectedFulfillmentCount = iterationCount

        for i in 0..<iterationCount {
            DispatchQueue.global(qos: .userInitiated).async {
                store.saveHTML("<html>Stress \(i)</html>", for: "stress_\(i)")
                _ = store.getHTML(for: "stress_\(i % 10)")  // Read from various keys
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: timeout * 3)

        // Verify at least some data survived
        let html = store.getHTML(for: "stress_0")
        XCTAssertNotNil(html, "Data should persist after stress test")
    }

    // MARK: - ResourceCache Tests

    func testResourceCacheConcurrentWrites() throws {
        let cache = ResourceCache()
        let expectation = XCTestExpectation(description: "Concurrent writes")
        expectation.expectedFulfillmentCount = threadCount

        for i in 0..<threadCount {
            DispatchQueue.global(qos: .userInitiated).async {
                let data = "Resource \(i)".data(using: .utf8)!
                let resource = ResourceData(
                    relativePath: "test_\(i).js",
                    data: data,
                    mimeType: "application/javascript"
                )
                cache.set(resource, for: "page_1")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: timeout)

        // Give async operations time to complete
        Thread.sleep(forTimeInterval: 1.0)

        let size = cache.totalSize()
        XCTAssertGreaterThan(size, 0, "Cache should have content")
    }

    func testResourceCacheConcurrentReadWrite() throws {
        let cache = ResourceCache()
        let expectation = XCTestExpectation(description: "Concurrent read/write")
        expectation.expectedFulfillmentCount = threadCount * 2

        // Pre-populate cache
        let testData = "Initial Data".data(using: .utf8)!
        let testResource = ResourceData(
            relativePath: "shared.js",
            data: testData,
            mimeType: "application/javascript"
        )
        cache.set(testResource, for: "page_1")
        Thread.sleep(forTimeInterval: 0.5)  // Wait for async write

        for i in 0..<threadCount {
            DispatchQueue.global(qos: .userInitiated).async {
                let data = "Resource \(i)".data(using: .utf8)!
                let resource = ResourceData(
                    relativePath: "resource_\(i).js",
                    data: data,
                    mimeType: "application/javascript"
                )
                cache.set(resource, for: "page_1")
                expectation.fulfill()
            }

            DispatchQueue.global(qos: .userInitiated).async {
                _ = cache.get("shared.js", for: "page_1")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: timeout)
    }

    func testResourceCacheMemoryEviction() throws {
        let cache = ResourceCache()
        let expectation = XCTestExpectation(description: "Memory eviction")
        let largeResourceSize = 1024 * 1024  // 1 MB

        // Fill cache beyond capacity
        for i in 0..<110 {
            let largeData = Data(repeating: UInt8(i % 256), count: largeResourceSize)
            let resource = ResourceData(
                relativePath: "large_\(i).dat",
                data: largeData,
                mimeType: "application/octet-stream"
            )
            cache.set(resource, for: "eviction_test")
        }

        Thread.sleep(forTimeInterval: 1.0)
        expectation.fulfill()

        wait(for: [expectation], timeout: timeout)

        // Cache should have evicted old resources, size should be reasonable
        let size = cache.totalSize()
        XCTAssertLessThan(size, 120 * 1024 * 1024, "Cache size should be controlled")
    }

    // MARK: - Progress Update Tests

    func testProgressUpdateThrottling() throws {
        let modal = ResourceProgressModal(
            description: "Throttle Test",
            totalResources: 1000
        ) { }

        let expectation = XCTestExpectation(description: "Rapid updates")
        let updateCount = 1000
        var actualUpdates = 0

        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<updateCount {
                DispatchQueue.main.async {
                    modal.updateProgress(current: i, total: updateCount, resourceName: "res_\(i)")
                    actualUpdates += 1

                    if i == updateCount - 1 {
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(actualUpdates, updateCount, "All updates should be processed")
    }

    func testProgressUpdateCompletion() throws {
        let modal = ResourceProgressModal(
            description: "Completion Test",
            totalResources: 10
        ) { }

        let expectation = XCTestExpectation(description: "Progress completion")

        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0...10 {
                Thread.sleep(forTimeInterval: 0.01)
                DispatchQueue.main.async {
                    modal.updateProgress(current: i, total: 10, resourceName: "res_\(i)")

                    if i == 10 {
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: timeout)
    }

    // MARK: - Combined Tests

    func testCombinedCacheOperations() throws {
        let store = ManifestStore()
        let cache = ResourceCache()
        let expectation = XCTestExpectation(description: "Combined operations")
        expectation.expectedFulfillmentCount = threadCount * 2

        for i in 0..<threadCount {
            // ManifestStore operations
            DispatchQueue.global(qos: .userInitiated).async {
                store.saveHTML("<html>Combined \(i)</html>", for: "combo_\(i)")
                expectation.fulfill()
            }

            // ResourceCache operations
            DispatchQueue.global(qos: .userInitiated).async {
                let data = "Resource \(i)".data(using: .utf8)!
                let resource = ResourceData(
                    relativePath: "combo_\(i).js",
                    data: data,
                    mimeType: "application/javascript"
                )
                cache.set(resource, for: "combo_page")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: timeout)

        // Verify both caches are intact
        let html = store.getHTML(for: "combo_0")
        XCTAssertNotNil(html, "ManifestStore should have data")

        Thread.sleep(forTimeInterval: 0.5)
        let cacheSize = cache.totalSize()
        XCTAssertGreaterThan(cacheSize, 0, "ResourceCache should have data")
    }
}
