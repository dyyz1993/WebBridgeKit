//
//  WebViewPoolPage.swift
//  DemoAppUITests
//
//  Created on 2025-01-31.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest
import WebKit
@testable import WebBridgeKit

/// Page Object for WebView Pool and Browser Manager testing
/// Provides methods to interact with and verify WebView pool states
class WebViewPoolPage: BasePage {

    // MARK: - UI Elements

    /// WebView instances in the pool
    var webViewInstances: XCUIElementQuery {
        return app.otherElements.containing(NSPredicate(format: "identifier CONTAINS 'webViewPool.instance.'"))
    }

    /// Pre-warmed WebView instance
    var prewarmedWebView: XCUIElement {
        return app.otherElements["webViewPool.instance.0"]
    }

    /// Modal browser view
    var modalBrowserView: XCUIElement {
        return app.otherElements["modalBrowser.view"]
    }

    /// Modal browser container
    var modalBrowserContainer: XCUIElement {
        return app.otherElements["modalBrowser.containerView"]
    }

    /// Modal browser mask
    var modalBrowserMask: XCUIElement {
        return app.otherElements["modalBrowser.maskView"]
    }

    /// Modal browser WebView
    var modalBrowserWebView: XCUIElement {
        return app.otherElements["modalBrowser.webView"]
    }

    /// Modal browser close button
    var modalBrowserCloseButton: XCUIElement {
        return app.buttons["modalBrowser.closeButton"]
    }

    /// Normal browser navigation elements
    var browserTitleLabel: XCUIElement {
        return app.staticTexts["browserManager.titleLabel"]
    }

    var browserCloseButton: XCUIElement {
        return app.buttons["browserManager.closeButton"]
    }

    var browserBackButton: XCUIElement {
        return app.buttons["browserManager.backButton"]
    }

    var browserMenuButton: XCUIElement {
        return app.buttons["browserManager.menuButton"]
    }

    // MARK: - Initialization

    override init(app: XCUIApplication) {
        super.init(app: app)
    }

    // MARK: - Verification Methods

    /// Verify that WebView pool is initialized
    func verifyPoolInitialized() -> Bool {
        let status = WebViewPool.shared.getPoolStatus()
        return status.isWarmedUp || status.size > 0
    }

    /// Verify pool size matches expected
    func verifyPoolSize(expectedSize: Int) -> Bool {
        let status = WebViewPool.shared.getPoolStatus()
        return status.size == expectedSize
    }

    /// Verify pre-warmed WebView exists
    func verifyPrewarmedWebViewExists() -> Bool {
        return prewarmedWebView.exists
    }

    /// Verify modal browser is displayed
    func verifyModalBrowserDisplayed() -> Bool {
        return modalBrowserView.exists && modalBrowserView.isHittable
    }

    /// Verify normal browser is displayed
    func verifyNormalBrowserDisplayed() -> Bool {
        return browserTitleLabel.exists || browserCloseButton.exists
    }

    /// Verify browser is in immersive mode
    func verifyImmersiveMode() -> Bool {
        // In immersive mode, navigation elements should be hidden
        return !browserTitleLabel.exists && !browserCloseButton.exists
    }

    // MARK: - Action Methods

    /// Trigger WebView pool warmup
    func warmupPool() {
        let expectation = XCTestExpectation(description: "Pool warmup completes")

        WebViewPool.shared.warmup {
            expectation.fulfill()
        }

        XCTWaiter().wait(for: [expectation], timeout: 5.0)
    }

    /// Simulate memory warning to clear pool
    func simulateMemoryWarning() {
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        // Wait for cleanup to complete
        let expectation = XCTestExpectation(description: "Memory warning processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 2.0)
    }

    /// Open browser with specific display mode
    func openBrowser(url: URL, displayMode: WebBrowserParams.DisplayMode) {
        var params = WebBrowserParams.from(url: url)

        // Modify display mode
        switch displayMode {
        case .normal:
            params = WebBrowserParams(displayMode: .normal)
        case .immersive:
            params = WebBrowserParams(displayMode: .immersive)
        case .modal:
            params = WebBrowserParams(displayMode: .modal)
        }

        WebBrowserManager.shared.openBrowser(url: url, params: params)

        // Wait for browser to appear
        let expectation = XCTestExpectation(description: "Browser opens")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }

    /// Close current browser
    func closeBrowser() {
        if modalBrowserView.exists {
            // Try tapping mask to close
            if modalBrowserMask.exists {
                modalBrowserMask.tap()
            }
            // Or try close button
            if modalBrowserCloseButton.exists {
                modalBrowserCloseButton.tap()
            }
        } else if browserCloseButton.exists {
            browserCloseButton.tap()
        }

        // Wait for browser to close
        let expectation = XCTestExpectation(description: "Browser closes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 3.0)
    }

    /// Navigate back in browser history
    func navigateBack() {
        if browserBackButton.exists && browserBackButton.isHittable {
            browserBackButton.tap()
        }
    }

    /// Open browser menu
    func openBrowserMenu() {
        if browserMenuButton.exists && browserMenuButton.isHittable {
            browserMenuButton.tap()
        }
    }

    /// Get pool status information
    func getPoolStatus() -> (size: Int, hitRate: Int, isWarmedUp: Bool) {
        return WebViewPool.shared.getPoolStatus()
    }

    /// Acquire WebView instance from pool
    func acquireWebView() -> WebViewPool.WebViewInstance? {
        return WebViewPool.shared.acquire()
    }

    /// Recycle WebView instance back to pool
    func recycleWebView(_ instance: WebViewPool.WebViewInstance) {
        WebViewPool.shared.recycle(instance)
    }

    /// Get navigation history from browser manager
    func getNavigationHistory() -> [WebBrowserManager.NavigationItem] {
        return WebBrowserManager.shared.getNavigationHistory()
    }

    /// Verify WebView reuse by checking instance count
    func verifyWebViewReuse(url: URL, iterations: Int = 3) -> Bool {
        let initialStatus = WebViewPool.shared.getPoolStatus()

        for i in 0..<iterations {
            // Open browser
            openBrowser(url: url, displayMode: .normal)

            // Close browser
            closeBrowser()

            // Small delay between iterations
            let expectation = XCTestExpectation(description: "Iteration \(i) complete")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
            XCTWaiter().wait(for: [expectation], timeout: 2.0)
        }

        let finalStatus = WebViewPool.shared.getPoolStatus()

        // Pool should have instances (showing reuse)
        return finalStatus.size >= initialStatus.size
    }

    /// Check LRU eviction by exceeding pool size
    func verifyLRUEviction() -> Bool {
        let maxPoolSize = 2 // Known from implementation

        // Acquire multiple instances to exceed pool size
        var instances: [WebViewPool.WebViewInstance?] = []
        for _ in 0...(maxPoolSize + 1) {
            let instance = acquireWebView()
            instances.append(instance)

            // Create new instance if pool is empty
            if instance == nil {
                let config = WebBridgePool.shared.acquireConfiguration()
                let webView = WKWebView(frame: CGRect.zero, configuration: config)
                let bridge = WebBridgePool.shared.acquireBridge()
                let newInstance = WebViewPool.WebViewInstance(webView: webView, bridge: bridge)
                instances.append(newInstance)
            }
        }

        // Recycle all instances
        for instance in instances.compactMap({ $0 }) {
            recycleWebView(instance)
        }

        let status = getPoolStatus()

        // Pool size should not exceed maxPoolSize
        return status.size <= maxPoolSize
    }

    /// Wait for modal browser to appear
    func waitForModalBrowser(timeout: TimeInterval = 5.0) -> Bool {
        return waitForElementToAppear(modalBrowserView, timeout: timeout)
    }

    /// Wait for modal browser to disappear
    func waitForModalBrowserToDisappear(timeout: TimeInterval = 5.0) -> Bool {
        return waitForElementToDisappear(modalBrowserView, timeout: timeout)
    }
}
