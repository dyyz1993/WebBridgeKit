//
//  WebBridgePoolTests+Extended.swift
//  CoreTests
//

import XCTest
import WebKit
@testable import WebBridgeKit

final class WebBridgePoolExtendedTests: XCTestCase {

    private var pool: WebBridgePool!

    override func setUp() {
        super.setUp()
        pool = WebBridgePool.shared
    }

    override func tearDown() {
        pool.didReceiveMemoryWarning()
        super.tearDown()
    }

    // MARK: - Acquire Configuration Details

    func testAcquireConfigurationAllowsInlineMediaPlayback() {
        let config = pool.acquireConfiguration()
        XCTAssertTrue(config.allowsInlineMediaPlayback)
    }

    func testAcquireConfigurationHasDataDetectorsEmpty() {
        let config = pool.acquireConfiguration()
        XCTAssertTrue(config.dataDetectorTypes.isEmpty)
    }

    func testAcquireConfigurationReturnsNonNull() {
        let config = pool.acquireConfiguration()
        XCTAssertNotNil(config)
    }

    // MARK: - Recycle Thread Safety

    func testConcurrentRecycleAndAcquire() {
        let expectation = self.expectation(description: "concurrent")
        expectation.expectedFulfillmentCount = 20

        for _ in 0..<20 {
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { expectation.fulfill(); return }
                let bridge = WebJavaScriptBridge()
                self.pool.recycleBridge(bridge)
                let _ = self.pool.acquireBridge()
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 10.0)
    }

    func testRecycleAfterMemoryWarning() {
        pool.didReceiveMemoryWarning()
        let bridge = WebJavaScriptBridge()
        pool.recycleBridge(bridge)
        let acquired = pool.acquireBridge()
        XCTAssertTrue(acquired === bridge)
    }

    // MARK: - Warmup Handler Registration

    func testWarmupCreatesHandlersForCommonActions() {
        pool.didReceiveMemoryWarning()

        let expectation = self.expectation(description: "warmup")
        pool.warmup { [weak self] in
            guard let self = self else { expectation.fulfill(); return }
            let bridge = self.pool.acquireBridge()
            XCTAssertNotNil(bridge.getHandler(for: "getSystemInfo"))
            XCTAssertNotNil(bridge.getHandler(for: "share"))
            XCTAssertNotNil(bridge.getHandler(for: "clipboard"))
            XCTAssertNotNil(bridge.getHandler(for: "haptic"))
            XCTAssertNotNil(bridge.getHandler(for: "openPage"))
            XCTAssertNotNil(bridge.getHandler(for: "closePage"))
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }

    // MARK: - Memory Warning

    func testDidReceiveMemoryWarningClearsWarmBridge() {
        pool.didReceiveMemoryWarning()

        let expectation = self.expectation(description: "warmup")
        pool.warmup { [weak self] in
            guard let self = self else { expectation.fulfill(); return }
            self.pool.didReceiveMemoryWarning()
            let bridge = self.pool.acquireBridge()
            XCTAssertNotNil(bridge, "Should create new bridge after warning")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }

    func testDidReceiveMemoryWarningAllowsNewRecycle() {
        pool.didReceiveMemoryWarning()
        let bridge = pool.acquireBridge()
        XCTAssertNotNil(bridge)
        pool.recycleBridge(bridge)
        let acquired = pool.acquireBridge()
        XCTAssertNotNil(acquired)
    }

    // MARK: - Singleton

    func testSharedIsSameInstance() {
        XCTAssertTrue(WebBridgePool.shared === WebBridgePool.shared)
    }

    // MARK: - Acquire Bridge

    func testAcquireBridgeReturnsNonNull() {
        let bridge = pool.acquireBridge()
        XCTAssertNotNil(bridge)
    }

    func testAcquireBridgeReturnsNewInstanceEachTime() {
        let bridge1 = pool.acquireBridge()
        let bridge2 = pool.acquireBridge()
        XCTAssertFalse(bridge1 === bridge2)
    }

    // MARK: - Recycle Bridge

    func testRecycleBridgeThenAcquire() {
        pool.didReceiveMemoryWarning()
        let bridge = WebJavaScriptBridge()
        pool.recycleBridge(bridge)
        let acquired = pool.acquireBridge()
        XCTAssertTrue(acquired === bridge)
    }

    func testRecycleBridgePoolFullOnlyKeepsOne() {
        pool.didReceiveMemoryWarning()
        let bridge1 = WebJavaScriptBridge()
        let bridge2 = WebJavaScriptBridge()
        pool.recycleBridge(bridge1)
        pool.recycleBridge(bridge2)
        let acquired = pool.acquireBridge()
        XCTAssertTrue(acquired === bridge1, "First recycled bridge should be kept")
    }
}
