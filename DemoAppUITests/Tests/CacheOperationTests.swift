//
//  CacheOperationTests.swift
//  DemoAppUITests
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest
@testable import WebBridgeKit

final class CacheOperationTests: XCTestCase {

    var app: XCUIApplication!
    var webAccessPage: WebAccessPage!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = AppLauncher.shared.launchApp()
        webAccessPage = WebAccessPage(app: app)

        // Navigate to web access page (from main page)
        let mainPage = MainPage(app: app)
        if mainPage.verifyPageLoaded() {
            // Prepare and tap first cell
            TestDataManager.shared.prepareMockData()

            let expectation = XCTestExpectation(description: "Wait for data")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5)

            if mainPage.getCellCount() > 0 {
                mainPage.tapCell(at: 0)
            }
        }
    }

    override func tearDownWithError() throws {
        TestDataManager.shared.cleanupTestData()
        AppLauncher.shared.terminateApp(app)
        app = nil
        webAccessPage = nil
    }

    // MARK: - Test Cases

    func testWebAccessPageLoads() {
        // Verify web access page loads
        XCTAssertTrue(webAccessPage.verifyPageLoaded(), "Web access page should load within 15 seconds")
    }

    func testEnterURL() {
        // Test URL entry
        let testURL = "https://example.com"
        webAccessPage.enterURL(testURL)

        // Verify URL was entered
        XCTAssertTrue(webAccessPage.verifyURLEntry(testURL), "URL should be visible in input field")
    }

    func testWebViewLoadsContent() {
        // Enter a URL
        webAccessPage.enterURL("https://example.com")

        // Wait for web view to load
        XCTAssertTrue(webAccessPage.verifyWebViewLoaded(), "Web view should load content")

        // Verify some content loaded
        XCTAssertTrue(webAccessPage.waitForWebViewToContain("Example", timeout: 15), "Web view should contain expected content")
    }

    func testCacheModeToggle() {
        // Test cache mode switch
        let initialState = webAccessPage.isCacheModeEnabled()
        webAccessPage.toggleCacheMode()

        let newState = webAccessPage.isCacheModeEnabled()
        XCTAssertNotEqual(initialState, newState, "Cache mode should toggle state")
    }

    func testInitiateCache() {
        // Navigate to a page first
        webAccessPage.enterURL("https://example.com")
        _ = webAccessPage.verifyWebViewLoaded()

        // Get initial cache count
        let initialCount = webAccessPage.getCacheCount()

        // Toggle cache mode and initiate cache
        webAccessPage.toggleCacheMode()
        webAccessPage.initiateCache()

        // Wait for cache to complete
        let cacheCompleted = webAccessPage.waitForCacheToComplete(timeout: 30)
        XCTAssertTrue(cacheCompleted, "Cache operation should complete")

        // Verify cache count increased
        let finalCount = webAccessPage.getCacheCount()

        // Extract numeric values from cache count labels
        let initialNumber = extractNumber(from: initialCount)
        let finalNumber = extractNumber(from: finalCount)

        if let initial = initialNumber, let final = finalNumber {
            XCTAssertGreaterThan(final, initial, "Cache count should increase after caching")
        } else {
            // If we can't parse numbers, at least verify the button still exists
            XCTAssertTrue(webAccessPage.verifyCacheCountVisible(), "Cache count button should remain visible")
        }
    }

    // MARK: - Helper Methods

    /// 从缓存计数字符串中提取数字
    private func extractNumber(from string: String?) -> Int? {
        guard let string = string else { return nil }
        let numbers = string.components(separatedBy: CharacterSet.decimalDigits.inverted)
        let numberString = numbers.joined()
        return Int(numberString)
    }

    func testCacheCountButtonVisible() {
        // Verify cache count button is displayed
        XCTAssertTrue(webAccessPage.verifyCacheCountVisible(), "Cache count button should be visible")
    }

    func testOpenCacheResources() {
        // Navigate to a cached page
        webAccessPage.enterURL("https://example.com")
        webAccessPage.toggleCacheMode()
        webAccessPage.initiateCache()
        _ = webAccessPage.waitForCacheToComplete(timeout: 30)

        // Open cache resources
        webAccessPage.openCacheResources()

        // Verify cache resources page opens
        let cacheResourcesTitle = app.navigationBars["Cache Resources"].firstMatch
        XCTAssertTrue(cacheResourcesTitle.waitForExistence(timeout: 5), "Cache resources page should open")
    }

    func testWebViewScrolling() {
        // Load content first
        webAccessPage.enterURL("https://example.com")
        _ = webAccessPage.verifyWebViewLoaded()

        // Test scrolling
        webAccessPage.scrollWebView(to: .down, amount: 500)

        // Scroll back to top
        webAccessPage.scrollToTopOfWebView()

        // Verify still on page
        XCTAssertTrue(webAccessPage.webView.exists, "Web view should still exist after scrolling")
    }

    func testNavigationControls() {
        // Load a page with links
        webAccessPage.enterURL("https://example.com")
        _ = webAccessPage.verifyWebViewLoaded()

        // Test back button (should be disabled initially)
        XCTAssertFalse(webAccessPage.canGoBack(), "Should not be able to go back on first page")

        // Note: Forward button testing would require navigation history
    }

    func testCacheAccessibility() {
        // Verify accessibility identifiers
        XCTAssertTrue(app.otherElements["webAccess.webView"].exists, "Web view accessibility identifier should exist")
        XCTAssertTrue(app.otherElements["webAccess.urlInputView"].exists, "URL input accessibility identifier should exist")
        XCTAssertTrue(app.buttons["webAccess.cacheCountButton"].exists, "Cache count button accessibility identifier should exist")
    }
}
