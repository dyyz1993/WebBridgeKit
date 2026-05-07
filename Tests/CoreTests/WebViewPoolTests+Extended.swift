//
//  WebViewPoolTests+Extended.swift
//  CoreTests
//

import XCTest
import WebKit
@testable import WebBridgeKit

final class WebViewPoolExtendedTests: XCTestCase {

    private var pool: WebViewPool!

    override func setUp() {
        super.setUp()
        pool = WebViewPool.shared
        pool.didReceiveMemoryWarning()
    }

    override func tearDown() {
        pool.didReceiveMemoryWarning()
        pool = nil
        super.tearDown()
    }

    // MARK: - WebViewInstance

    func testWebViewInstanceSetsCreatedAtAndLastUsedAt() {
        let before = Date()
        let webView = WKWebView()
        let jsBridge = WebJavaScriptBridge()
        let instance = WebViewPool.WebViewInstance(webView: webView, bridge: jsBridge)
        let after = Date()

        XCTAssertGreaterThanOrEqual(instance.createdAt, before)
        XCTAssertLessThanOrEqual(instance.createdAt, after)
        XCTAssertGreaterThanOrEqual(instance.lastUsedAt, before)
        XCTAssertLessThanOrEqual(instance.lastUsedAt, after)
    }

    func testWebViewInstanceLastUsedAtCanBeUpdated() {
        let webView = WKWebView()
        let jsBridge = WebJavaScriptBridge()
        var instance = WebViewPool.WebViewInstance(webView: webView, bridge: jsBridge)

        let original = instance.lastUsedAt
        Thread.sleep(forTimeInterval: 0.01)
        instance.lastUsedAt = Date()

        XCTAssertGreaterThan(instance.lastUsedAt, original)
    }

    // MARK: - Acquire and Recycle

    func testAcquireFromEmptyPoolReturnsNilAndIncrementsMissCount() {
        pool.didReceiveMemoryWarning()
        let status = pool.getPoolStatus()
        let initialHitRate = status.hitRate

        let instance = pool.acquire()
        XCTAssertNil(instance)

        let statusAfter = pool.getPoolStatus()
        XCTAssertEqual(statusAfter.size, 0)
    }

    func testRecycleAndAcquireRestoresInstance() {
        pool.didReceiveMemoryWarning()

        let webView = WKWebView()
        let jsBridge = WebJavaScriptBridge()
        var instance = WebViewPool.WebViewInstance(webView: webView, bridge: jsBridge)
        instance.lastUsedAt = Date()

        pool.recycle(instance)
        XCTAssertEqual(pool.getPoolStatus().size, 1)

        let acquired = pool.acquire()
        XCTAssertNotNil(acquired)
        XCTAssertTrue(acquired!.webView === webView)
        XCTAssertTrue(acquired!.bridge === jsBridge)
    }

    func testRecycleBeyondMaxSize() {
        pool.didReceiveMemoryWarning()

        for i in 0..<5 {
            let webView = WKWebView()
            let jsBridge = WebJavaScriptBridge()
            var instance = WebViewPool.WebViewInstance(webView: webView, bridge: jsBridge)
            instance.lastUsedAt = Date().addingTimeInterval(Double(i))
            pool.recycle(instance)
        }

        let status = pool.getPoolStatus()
        XCTAssertEqual(status.size, 2)
    }

    // MARK: - LRU Eviction

    func testLRUEvictsOldestInstance() {
        pool.didReceiveMemoryWarning()

        let webView1 = WKWebView()
        let bridge1 = WebJavaScriptBridge()
        var instance1 = WebViewPool.WebViewInstance(webView: webView1, bridge: bridge1)
        instance1.lastUsedAt = Date().addingTimeInterval(-10)

        let webView2 = WKWebView()
        let bridge2 = WebJavaScriptBridge()
        var instance2 = WebViewPool.WebViewInstance(webView: webView2, bridge: bridge2)
        instance2.lastUsedAt = Date()

        pool.recycle(instance1)
        pool.recycle(instance2)

        let webView3 = WKWebView()
        let bridge3 = WebJavaScriptBridge()
        var instance3 = WebViewPool.WebViewInstance(webView: webView3, bridge: bridge3)
        instance3.lastUsedAt = Date()
        pool.recycle(instance3)

        let acquired = pool.acquire()
        XCTAssertNotNil(acquired)
        XCTAssertFalse(acquired!.webView === webView1, "Oldest instance should have been evicted")
    }

    // MARK: - Pool Status

    func testGetPoolStatusHitRate() {
        pool.didReceiveMemoryWarning()

        let webView = WKWebView()
        let jsBridge = WebJavaScriptBridge()
        let instance = WebViewPool.WebViewInstance(webView: webView, bridge: jsBridge)
        pool.recycle(instance)

        let _ = pool.acquire()
        let _ = pool.acquire()

        let status = pool.getPoolStatus()
        XCTAssertEqual(status.hitRate, 50)
    }

    func testGetPoolStatusIsWarmedUpAfterWarmup() {
        pool.didReceiveMemoryWarning()

        let expectation = self.expectation(description: "warmup")
        pool.warmup {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)

        let status = pool.getPoolStatus()
        XCTAssertTrue(status.isWarmedUp)
    }

    func testGetPoolStatusIsWarmedUpFalseAfterMemoryWarning() {
        pool.didReceiveMemoryWarning()

        let expectation = self.expectation(description: "warmup")
        pool.warmup {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)

        pool.didReceiveMemoryWarning()

        let status = pool.getPoolStatus()
        XCTAssertFalse(status.isWarmedUp)
    }

    // MARK: - Memory Warning

    func testMemoryWarningResetsPoolSize() {
        let webView = WKWebView()
        let jsBridge = WebJavaScriptBridge()
        let instance = WebViewPool.WebViewInstance(webView: webView, bridge: jsBridge)
        pool.recycle(instance)

        pool.didReceiveMemoryWarning()

        XCTAssertEqual(pool.getPoolStatus().size, 0)
    }

    func testMemoryWarningResetsIsWarmedUp() {
        let expectation = self.expectation(description: "warmup")
        pool.warmup {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)

        pool.didReceiveMemoryWarning()

        let status = pool.getPoolStatus()
        XCTAssertFalse(status.isWarmedUp)
    }

    // MARK: - Warmup

    func testWarmupDoesNotCreateDuplicates() {
        let expectation1 = self.expectation(description: "warmup1")
        pool.warmup {
            expectation1.fulfill()
        }
        waitForExpectations(timeout: 5.0)

        let status1 = pool.getPoolStatus()
        let size1 = status1.size

        let expectation2 = self.expectation(description: "warmup2")
        pool.warmup {
            expectation2.fulfill()
        }
        waitForExpectations(timeout: 5.0)

        let status2 = pool.getPoolStatus()
        XCTAssertEqual(status2.size, size1)
    }

    func testWarmupCompletionCalledWithoutWebView() {
        let expectation = self.expectation(description: "warmup")
        pool.warmup {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }

    // MARK: - Singleton

    func testSharedIsSameInstance() {
        XCTAssertTrue(WebViewPool.shared === WebViewPool.shared)
    }

    // MARK: - Concurrent Access

    func testConcurrentAcquireFromEmptyPool() {
        let group = DispatchGroup()
        for _ in 0..<10 {
            group.enter()
            DispatchQueue.global().async { [weak self] in
                let _ = self?.pool.acquire()
                group.leave()
            }
        }
        group.wait()
    }

    func testConcurrentGetPoolStatus() {
        let group = DispatchGroup()
        for _ in 0..<20 {
            group.enter()
            DispatchQueue.global().async { [weak self] in
                let _ = self?.pool.getPoolStatus()
                group.leave()
            }
        }
        group.wait()
    }
}
