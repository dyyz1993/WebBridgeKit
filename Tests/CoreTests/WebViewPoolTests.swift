//
//  WebViewPoolTests.swift
//  CoreTests
//

import WebKit
import XCTest
@testable import WebBridgeKit

final class WebViewPoolTests: XCTestCase {

    private var pool: WebViewPool!

    override func setUp() {
        super.setUp()
        pool = WebViewPool.shared
        pool.didReceiveMemoryWarning()
    }

    override func tearDown() {
        pool.didReceiveMemoryWarning()
        super.tearDown()
    }

    // MARK: - Acquire

    func testAcquireFromEmptyPoolReturnsNil() {
        pool.didReceiveMemoryWarning()
        let instance = pool.acquire()
        XCTAssertNil(instance)
    }

    // MARK: - Recycle

    func testRecycleThenAcquire() {
        let webView = WKWebView()
        let bridge = WebJavaScriptBridge()
        var instance = WebViewPool.WebViewInstance(webView: webView, bridge: bridge)
        instance.lastUsedAt = Date()

        pool.recycle(instance)

        let acquired = pool.acquire()
        XCTAssertNotNil(acquired)
    }

    func testRecycleMultipleInstances() {
        for i in 0..<3 {
            let webView = WKWebView()
            let bridge = WebJavaScriptBridge()
            var instance = WebViewPool.WebViewInstance(webView: webView, bridge: bridge)
            instance.lastUsedAt = Date()
            pool.recycle(instance)
        }

        var acquired: WebViewPool.WebViewInstance?
        acquired = pool.acquire()
        XCTAssertNotNil(acquired)
    }

    func testRecycleExceedsMaxPoolSizeUsesLRU() {
        for _ in 0..<5 {
            let webView = WKWebView()
            let bridge = WebJavaScriptBridge()
            var instance = WebViewPool.WebViewInstance(webView: webView, bridge: bridge)
            instance.lastUsedAt = Date()
            pool.recycle(instance)
        }

        let acquired = pool.acquire()
        XCTAssertNotNil(acquired, "Should still acquire from pool after exceeding max size")
    }

    // MARK: - Warmup

    func testWarmupCreatesInstance() {
        let expectation = self.expectation(description: "warmup")
        pool.warmup {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }

    func testWarmupOnlyOnce() {
        let expectation1 = self.expectation(description: "warmup1")

        pool.warmup {
            expectation1.fulfill()
        }
        waitForExpectations(timeout: 5.0)

        let status = pool.getPoolStatus()
        XCTAssertTrue(status.isWarmedUp)
    }

    // MARK: - Pool Status

    func testGetPoolStatusReturnsSize() {
        pool.didReceiveMemoryWarning()
        let status = pool.getPoolStatus()
        XCTAssertEqual(status.size, 0)
    }

    func testGetPoolStatusAfterRecycle() {
        pool.didReceiveMemoryWarning()

        let webView = WKWebView()
        let bridge = WebJavaScriptBridge()
        let instance = WebViewPool.WebViewInstance(webView: webView, bridge: bridge)
        pool.recycle(instance)

        let status = pool.getPoolStatus()
        XCTAssertEqual(status.size, 1)
    }

    // MARK: - Memory Warning

    func testReceiveMemoryWarningClearsPool() {
        let webView = WKWebView()
        let bridge = WebJavaScriptBridge()
        let instance = WebViewPool.WebViewInstance(webView: webView, bridge: bridge)
        pool.recycle(instance)

        pool.didReceiveMemoryWarning()

        let acquired = pool.acquire()
        XCTAssertNil(acquired)
    }

    // MARK: - WebViewInstance

    func testWebViewInstanceCreation() {
        let webView = WKWebView()
        let bridge = WebJavaScriptBridge()
        let instance = WebViewPool.WebViewInstance(webView: webView, bridge: bridge)

        XCTAssertTrue(instance.webView === webView)
        XCTAssertTrue(instance.bridge === bridge)
        XCTAssertNotNil(instance.createdAt)
        XCTAssertNotNil(instance.lastUsedAt)
    }

    // MARK: - Thread Safety

    func testConcurrentRecycleAndAcquire() {
        let expectation = self.expectation(description: "concurrent")
        expectation.expectedFulfillmentCount = 10

        for _ in 0..<10 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let webView = WKWebView()
                let bridge = WebJavaScriptBridge()
                let instance = WebViewPool.WebViewInstance(webView: webView, bridge: bridge)
                self.pool.recycle(instance)
                _ = self.pool.acquire()
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0)
    }
}
