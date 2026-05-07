//
//  WebBridgePoolTests.swift
//  CoreTests
//

import XCTest
@testable import WebBridgeKit

final class WebBridgePoolTests: XCTestCase {

    private var pool: WebBridgePool!

    override func setUp() {
        super.setUp()
        pool = WebBridgePool.shared
    }

    override func tearDown() {
        pool.clearCache()
        super.tearDown()
    }

    // MARK: - Warmup

    func testWarmupCreatesBridge() {
        let expectation = self.expectation(description: "warmup")
        pool.warmup {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }

    func testWarmupCompletionCalled() {
        let expectation = self.expectation(description: "warmup complete")
        pool.warmup {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }

    // MARK: - Acquire and Recycle

    func testAcquireWithoutWarmupCreatesNew() {
        let bridge = pool.acquireBridge()
        XCTAssertNotNil(bridge)
    }

    func testAcquireAfterWarmupReturnsWarmBridge() {
        let expectation = self.expectation(description: "warmup")
        pool.warmup { [weak self] in
            guard let self = self else { return }
            let bridge = self.pool.acquireBridge()
            XCTAssertNotNil(bridge)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }

    func testAcquireTwiceReturnsDifferentInstances() {
        let bridge1 = pool.acquireBridge()
        let bridge2 = pool.acquireBridge()
        XCTAssertFalse(bridge1 === bridge2)
    }

    func testRecycleBridgeAcceptsBridge() {
        let bridge = pool.acquireBridge()
        pool.recycleBridge(bridge)
    }

    func testRecycleThenAcquireReturnsRecycled() {
        let bridge = WebJavaScriptBridge()
        pool.recycleBridge(bridge)
        let acquired = pool.acquireBridge()
        XCTAssertTrue(acquired === bridge)
    }

    func testRecycleTwoBridgesOnlyKeepsOne() {
        let bridge1 = WebJavaScriptBridge()
        let bridge2 = WebJavaScriptBridge()
        pool.recycleBridge(bridge1)
        pool.recycleBridge(bridge2)

        let acquired = pool.acquireBridge()
        XCTAssertTrue(acquired === bridge1, "First recycled bridge should be kept")
    }

    // MARK: - Acquire Configuration

    func testAcquireConfigurationReturnsNonNull() {
        let config = pool.acquireConfiguration()
        XCTAssertNotNil(config)
    }

    // MARK: - Memory Warning

    func testDidReceiveMemoryWarning() {
        let expectation = self.expectation(description: "warmup")
        pool.warmup { [weak self] in
            guard let self = self else { return }
            self.pool.didReceiveMemoryWarning()
            let bridge = self.pool.acquireBridge()
            XCTAssertNotNil(bridge, "Should still create new bridge after memory warning")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }

    // MARK: - Clear Cache

    func testClearCache() {
        let config = pool.acquireConfiguration()
        XCTAssertNotNil(config)

        pool.clearCache()

        let newConfig = pool.acquireConfiguration()
        XCTAssertNotNil(newConfig, "Should return default config after clear")
    }

    // MARK: - Thread Safety

    func testConcurrentAcquireDoesNotCrash() {
        let group = DispatchGroup()
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async { [weak self] in
                _ = self?.pool.acquireBridge()
                group.leave()
            }
        }
        group.wait()
    }
}
