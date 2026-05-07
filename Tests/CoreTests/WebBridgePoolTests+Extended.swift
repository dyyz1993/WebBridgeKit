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
        pool.clearCache()
    }

    override func tearDown() {
        pool.clearCache()
        pool = nil
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

    func testAcquireConfigurationHasUserScripts() {
        let config = pool.acquireConfiguration()
        XCTAssertFalse(config.userContentController.userScripts.isEmpty)
    }

    func testAcquireConfigurationAfterClearReturnsDefault() {
        pool.clearCache()
        let config = pool.acquireConfiguration()
        XCTAssertNotNil(config)
        XCTAssertTrue(config.allowsInlineMediaPlayback)
    }

    func testAcquireConfigurationReturnsSameInstanceBeforeClear() {
        let config1 = pool.acquireConfiguration()
        let config2 = pool.acquireConfiguration()
        XCTAssertTrue(config1 === config2)
    }

    // MARK: - Recycle Thread Safety

    func testConcurrentRecycleAndAcquire() {
        let group = DispatchGroup()
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { group.leave(); return }
                let bridge = WebJavaScriptBridge()
                self.pool.recycleBridge(bridge)
                let _ = self.pool.acquireBridge()
                group.leave()
            }
        }
        group.wait()
    }

    func testRecycleAfterClear() {
        pool.clearCache()
        let bridge = WebJavaScriptBridge()
        pool.recycleBridge(bridge)
        let acquired = pool.acquireBridge()
        XCTAssertTrue(acquired === bridge)
    }

    func testClearCacheThenAcquireCreatesNew() {
        pool.clearCache()
        let bridge = pool.acquireBridge()
        XCTAssertNotNil(bridge)
        let bridge2 = pool.acquireBridge()
        XCTAssertNotNil(bridge2)
        XCTAssertFalse(bridge === bridge2)
    }

    // MARK: - Warmup Handler Registration

    func testWarmupCreatesHandlersForCommonActions() {
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

    func testWarmupCalledMultipleTimes() {
        let expectation1 = self.expectation(description: "warmup1")
        let expectation2 = self.expectation(description: "warmup2")

        pool.warmup {
            expectation1.fulfill()
        }
        waitForExpectations(timeout: 5.0)

        pool.warmup {
            expectation2.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }

    // MARK: - Memory Warning

    func testDidReceiveMemoryWarningClearsWarmBridge() {
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

    func testDidReceiveMemoryWarningAllowsNewWarmup() {
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

    func testMultipleAcquireConfigurationCalls() {
        var configs: [WKWebViewConfiguration] = []
        for _ in 0..<5 {
            configs.append(pool.acquireConfiguration())
        }
        let first = configs.first
        for config in configs {
            XCTAssertTrue(config === first)
        }
    }
}
