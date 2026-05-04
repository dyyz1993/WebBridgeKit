//
//  WebAccessPage.swift
//  DemoAppUITests
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest
import os.log

/// Page object for the web browser and caching screen
class WebAccessPage: BasePage {

    private let logger = OSLog(subsystem: "com.webbridgekit.demo.ui.tests", category: "WebAccessPage")

    // MARK: - Tab Bar Navigation

    var webAccessTab: XCUIElement {
        return app.tabBars.buttons["网页"]
    }

    /// Navigate to WebAccess page via tab bar
    func navigateViaTab() -> Bool {
        // First check if tab bar exists
        let tabBar = app.tabBars.firstMatch
        if !tabBar.waitForExistence(timeout: 5) {
            print("❌ Tab bar not found")
            return false
        }

        print("✅ Tab bar found")

        // Check if the web access tab exists
        if !webAccessTab.exists {
            print("❌ WebAccess tab button not found")
            print("Available tabs: \(tabBar.buttons.allElementsBoundByIndex.map { $0.label })")
            return false
        }

        print("✅ WebAccess tab button found, tapping it")
        tapElement(webAccessTab)

        // Wait a moment for the tap to register and view to load
        Thread.sleep(forTimeInterval: 1)

        // Verify the tab was selected (value should be 1)
        let tabSelected = webAccessTab.value as? String == "1"
        print("Tab selected: \(tabSelected)")

        // Wait for page to load - try multiple indicators
        let navBar = app.navigationBars["网页访问"]
        let navBarExists = navBar.waitForExistence(timeout: 5)

        if navBarExists {
            print("✅ Navigation bar found - page loaded")
            return true
        }

        print("❌ Navigation bar not found")

        // Try alternative indicators
        let cacheButtonExists = cacheCountButton.waitForExistence(timeout: 2)
        if cacheButtonExists {
            print("✅ Cache button found - page loaded")
            return true
        }

        // Try to find any static text with "网页"
        let webText = app.staticTexts["网页"]
        if webText.exists {
            print("✅ Found '网页' text - page may have loaded")
            return true
        }

        // Check what navigation bars exist
        let allNavBars = app.navigationBars.allElementsBoundByIndex
        print("Available nav bars: \(allNavBars.map { $0.identifier })")

        // Check what buttons exist
        let allButtons = app.buttons.allElementsBoundByIndex.map { $0.identifier }
        print("Available buttons (first 10): \(Array(allButtons.prefix(10)))")

        return false
    }

    // MARK: - UI Elements

    var webView: XCUIElement {
        return app.otherElements["webAccess.webView"]
    }

    var urlInputView: XCUIElement {
        return app.otherElements["webAccess.urlInputView"]
    }

    var webAccessViewController: XCUIElement {
        return app.otherElements["WebAccessViewController"]
    }

    var cacheCountButton: XCUIElement {
        return app.buttons["webAccess.cacheCountButton"]
    }

    var navigationBar: XCUIElement {
        return app.navigationBars.firstMatch
    }

    var backButton: XCUIElement {
        return navigationBar.buttons.firstMatch
    }

    var forwardButton: XCUIElement {
        return navigationBar.buttons.element(boundBy: 1)
    }

    // MARK: - URL Input Elements

    var urlTextField: XCUIElement {
        return urlInputView.textFields.firstMatch
    }

    var cacheSwitch: XCUIElement {
        return urlInputView.switches.firstMatch
    }

    var cacheActionButton: XCUIElement {
        return urlInputView.buttons.firstMatch
    }

    // MARK: - Page Verification

    func verifyPageLoaded() -> Bool {
        // Wait for urlInputView first as it's more reliable than webView for accessibility
        return waitForElementToAppear(urlInputView, timeout: 15)
    }

    func verifyWebViewLoaded() -> Bool {
        // Wait for urlInputView to confirm page is loaded
        // WKWebView content is not directly accessible, so we check the container
        return waitForElementToAppear(urlInputView, timeout: 15)
    }

    // MARK: - Actions

    func tapBackButton() {
        if backButton.isEnabled && backButton.exists {
            tapElement(backButton)
        }
    }

    func tapForwardButton() {
        if forwardButton.isEnabled && forwardButton.exists {
            tapElement(forwardButton)
        }
    }

    func tapCacheCountButton() {
        if cacheCountButton.exists {
            tapElement(cacheCountButton)
        }
    }

    func enterURL(_ url: String) {
        tapElement(urlTextField)
        // Clear any existing text
        if let currentValue = urlTextField.value as? String, !currentValue.isEmpty {
            let clearButton = urlTextField.buttons["Clear text"]
            if clearButton.exists {
                tapElement(clearButton)
            }
        }
        typeText(url, into: urlTextField)

        // Press Go/Enter to load the URL
        let goButton = app.keyboards.buttons["Go"]
        if goButton.exists {
            tapElement(goButton)
        } else {
            urlTextField.typeText("\n")
        }
    }

    // MARK: - Cache Operations

    func initiateCache() {
        // Tap the cache button in the URL input view
        if cacheActionButton.exists && cacheActionButton.isEnabled {
            tapElement(cacheActionButton)
        }
    }

    func toggleCacheMode() -> Bool {
        if cacheSwitch.exists {
            let currentValue = cacheSwitch.value as? String == "1"
            tapElement(cacheSwitch)
            // Wait for toggle to complete
            Thread.sleep(forTimeInterval: 0.5)
            let newValue = cacheSwitch.value as? String == "1"
            return currentValue != newValue
        }
        return false
    }

    func isCacheModeEnabled() -> Bool {
        return cacheSwitch.value as? String == "1"
    }

    func openCacheResources() {
        tapCacheCountButton()
    }

    func getCacheCount() -> String? {
        if cacheCountButton.exists {
            return cacheCountButton.label
        }
        return nil
    }

    func getCacheActionButtonTitle() -> String? {
        if cacheActionButton.exists {
            return cacheActionButton.label
        }
        return nil
    }

    func isPageCached() -> Bool {
        // Check if cache button shows "删除" (Delete) instead of "缓存" (Cache)
        guard let title = getCacheActionButtonTitle() else { return false }
        return title.contains("删除")
    }

    // MARK: - Web Content Interaction

    func tapLink(withText text: String) {
        let link = webView.links[text].firstMatch
        if link.exists {
            tapElement(link)
        }
    }

    func tapLink(containing text: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let link = webView.links.element(matching: predicate)
        if link.exists {
            tapElement(link)
            return true
        }
        return false
    }

    func waitForWebViewToContain(_ text: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let element = webView.staticTexts.element(matching: predicate)
        return waitForElementToAppear(element, timeout: timeout)
    }

    func waitForWebViewToContainAny(of texts: [String], timeout: TimeInterval = 10) -> Bool {
        let startTime = Date()
        let deadline = startTime.addingTimeInterval(timeout)

        while Date() < deadline {
            for text in texts {
                let predicate = NSPredicate(format: "label CONTAINS %@", text)
                let element = webView.staticTexts.element(matching: predicate)
                if element.exists {
                    return true
                }
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    // MARK: - Verification

    func verifyURLEntry(_ url: String) -> Bool {
        guard let currentValue = urlTextField.value as? String else { return false }
        return currentValue.contains(url)
    }

    func verifyCacheCountVisible() -> Bool {
        return cacheCountButton.exists
    }

    func verifyCacheCount(_ expectedCount: Int) -> Bool {
        if cacheCountButton.exists {
            let label = cacheCountButton.label
            return label.contains("\(expectedCount)")
        }
        return false
    }

    func verifyURLInputViewVisible() -> Bool {
        return waitForElementToAppear(urlInputView, timeout: 5)
    }

    func verifyCacheButtonEnabled() -> Bool {
        return cacheActionButton.isEnabled
    }

    // MARK: - Navigation

    func refreshPage() {
        // Pull to refresh on the web view
        webView.swipeDown()
    }

    func navigateBack() {
        tapBackButton()
    }

    func navigateForward() {
        tapForwardButton()
    }

    // MARK: - Status Checks

    func canGoBack() -> Bool {
        return backButton.exists && backButton.isEnabled
    }

    func canGoForward() -> Bool {
        return forwardButton.exists && forwardButton.isEnabled
    }

    func getCurrentURL() -> String? {
        if let currentValue = urlTextField.value as? String {
            return currentValue
        }
        return nil
    }

    // MARK: - Wait Helpers

    func waitForPageToLoad(timeout: TimeInterval = 15) -> Bool {
        return verifyPageLoaded()
    }

    func waitForCacheToComplete(timeout: TimeInterval = 30) -> Bool {
        // Wait for cache button to change state or loading to complete
        let deadline = Date().addingTimeInterval(timeout)
        var previousTitle = getCacheActionButtonTitle()

        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
            let currentTitle = getCacheActionButtonTitle()

            // Check if button title changed (indicates cache operation completed)
            if currentTitle != previousTitle {
                return true
            }

            previousTitle = currentTitle
        }

        return false
    }

    // MARK: - Content Interaction

    func scrollWebView(to direction: CSToDirection, amount: CGFloat = 0.5) {
        let start = webView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end: XCUICoordinate

        switch direction {
        case .up:
            end = webView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5 - amount))
        case .down:
            end = webView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5 + amount))
        case .left:
            end = webView.coordinate(withNormalizedOffset: CGVector(dx: 0.5 - amount, dy: 0.5))
        case .right:
            end = webView.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + amount, dy: 0.5))
        }

        start.press(forDuration: 0.1, thenDragTo: end)
    }

    func scrollToTopOfWebView() {
        webView.swipeDown()
    }

    func scrollToBottomOfWebView() {
        webView.swipeUp()
    }

    // MARK: - Performance Measurement

    /// Measure page load time for a given URL
    func measurePageLoadTime(url: String) -> TimeInterval {
        let startTime = Date()

        navigateToPage(url)
        let loaded = waitForPageToLoad(timeout: 30)

        let loadTime = Date().timeIntervalSince(startTime)

        if loaded {
            os_log("Page loaded successfully in %.3f seconds", log: logger, type: .info, loadTime)
        } else {
            os_log("Page failed to load", log: logger, type: .error)
        }

        return loadTime
    }

    /// Measure cached page load time (reload)
    func measureCachedLoadTime() -> TimeInterval {
        let startTime = Date()

        reloadPage()
        let loaded = waitForPageToLoad(timeout: 10)

        let loadTime = Date().timeIntervalSince(startTime)

        if loaded {
            os_log("Cached page loaded in %.3f seconds", log: logger, type: .info, loadTime)
        }

        return loadTime
    }

    /// Navigate to a specific URL
    func navigateToPage(_ url: String) {
        // Ensure we're on the WebAccess page
        if !urlInputView.exists {
            _ = navigateViaTab()
        }

        // Wait for URL input to be available
        if waitForElementToAppear(urlTextField, timeout: 5) {
            enterURL(url)
        } else {
            os_log("URL text field not available", log: logger, type: .error)
        }
    }

    /// Reload the current page
    func reloadPage() {
        // Pull to refresh on the web view
        refreshPage()
    }

    /// Get current cache status
    func getCacheStatus() -> CacheStatus {
        let isCacheEnabled = isCacheModeEnabled()
        let cacheCount = getCacheCount()
        let isPageCached = isPageCached()

        return CacheStatus(
            isCacheEnabled: isCacheEnabled,
            cacheCount: cacheCount,
            isCurrentPageCached: isPageCached
        )
    }

    /// Collect performance metrics for current page
    func collectPerformanceMetrics() -> PerformanceMetrics {
        let startTime = Date()

        // Measure memory usage
        let memoryUsage = getCurrentMemoryUsage()

        // Get cache status
        let cacheStatus = getCacheStatus()

        // Check if page is loaded
        let isPageLoaded = verifyPageLoaded()

        let collectionTime = Date().timeIntervalSince(startTime)

        return PerformanceMetrics(
            memoryUsageMB: memoryUsage,
            cacheStatus: cacheStatus,
            isPageLoaded: isPageLoaded,
            collectionTime: collectionTime
        )
    }

    /// Clear all caches
    func clearAllCaches() {
        // Navigate to cache resources if needed
        if !cacheCountButton.exists {
            return
        }

        // Open cache management
        tapCacheCountButton()

        // Look for clear all button
        let clearButton = app.buttons["清除全部"]
        if clearButton.exists {
            tapElement(clearButton)
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Go back
        if backButton.exists {
            tapBackButton()
        }
    }

    /// Clear specific resource type cache
    func clearResourceCache(type: ResourceType) {
        // Navigate to cache resources
        tapCacheCountButton()

        // Look for specific cache clear button
        let buttonTitle: String
        switch type {
        case .image:
            buttonTitle = "清除图片"
        case .css:
            buttonTitle = "清除CSS"
        case .javascript:
            buttonTitle = "清除JS"
        case .html:
            buttonTitle = "清除HTML"
        case .all:
            buttonTitle = "清除全部"
        }

        let clearButton = app.buttons[buttonTitle]
        if clearButton.exists {
            tapElement(clearButton)
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Go back
        if backButton.exists {
            tapBackButton()
        }
    }

    /// Get current cache size in bytes
    func getCacheSize() -> Int {
        // Try to get cache size from cache count button
        if let cacheCount = getCacheCount() {
            // Parse the count to estimate size
            // This is a simplified approach - real implementation would need more info
            if let count = Int(cacheCount.replacingOccurrences(of: "缓存: ", with: "")) {
                // Assume average resource size of 10KB
                return count * 10240
            }
        }

        return 0
    }

    /// Get current memory usage in MB
    func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0  // Convert to MB
        }

        return 0
    }

    /// Wait for page load with timeout
    func waitForPageLoad(timeout: TimeInterval) -> Bool {
        return waitForPageToLoad(timeout: timeout)
    }
}

// MARK: - Performance Types

/// Cache status information
struct CacheStatus {
    let isCacheEnabled: Bool
    let cacheCount: String?
    let isCurrentPageCached: Bool
}

/// Performance metrics
struct PerformanceMetrics {
    let memoryUsageMB: Double
    let cacheStatus: CacheStatus
    let isPageLoaded: Bool
    let collectionTime: TimeInterval
}

/// Resource type for cache clearing
enum ResourceType {
    case image
    case css
    case javascript
    case html
    case all
}

// MARK: - Supporting Types

enum CSToDirection {
    case up
    case down
    case left
    case right
}
