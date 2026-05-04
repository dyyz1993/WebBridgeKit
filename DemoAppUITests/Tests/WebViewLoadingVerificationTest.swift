//
//  WebViewLoadingVerificationTest.swift
//  DemoAppUITests
//
//  Created on 2025-01-31.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//
//  This test verifies that the WebView loads content correctly
//  with proper timing and wait conditions
//

import XCTest
@testable import WebBridgeKit

final class WebViewLoadingVerificationTest: XCTestCase {

    var app: XCUIApplication!
    var webAccessPage: WebAccessPage!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = AppLauncher.shared.launchApp()
        webAccessPage = WebAccessPage(app: app)

        // Navigate to web access page
        _ = webAccessPage.navigateViaTab()
    }

    override func tearDownWithError() throws {
        AppLauncher.shared.terminateApp(app)
        app = nil
        webAccessPage = nil
    }

    func testWebViewLoadsContentWithProperWait() {
        // Test URL that we know exists on localhost:8080
        let testURL = "http://localhost:8080/main_test.html"

        print("🧪 [TEST] Starting WebView load test with URL: \(testURL)")

        // Enter the URL
        webAccessPage.enterURL(testURL)

        print("🧪 [TEST] URL entered, waiting for content to load...")

        // Wait for WebView to load and show content
        // We wait for specific text that we know exists in the HTML
        let contentLoaded = webAccessPage.waitForWebViewToContainAny(
            of: ["WebBridgeKit 测试", "测试页面", "Main Test"],
            timeout: 15
        )

        print("🧪 [TEST] Content loaded: \(contentLoaded)")

        // Take screenshot AFTER content loads
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "WebView_Loaded_Content_\(Date().timeIntervalSince1970)"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Verify URL is still in the text field
        let urlVerified = webAccessPage.verifyURLEntry("localhost:8080")

        print("🧪 [TEST] URL verified: \(urlVerified)")

        // Assertions
        XCTAssertTrue(contentLoaded, "WebView should load and show content from \(testURL)")
        XCTAssertTrue(urlVerified, "URL should remain visible in input field")

        print("✅ [TEST] Test completed successfully")
    }

    func testWebViewLoadsExampleDotCom() {
        // Test with a public website that we know loads reliably
        let testURL = "https://example.com"

        print("🧪 [TEST] Testing with example.com")

        webAccessPage.enterURL(testURL)

        // Example.com shows "Example Domain" heading
        let contentLoaded = webAccessPage.waitForWebViewToContainAny(
            of: ["Example", "Domain", "example"],
            timeout: 15
        )

        print("🧪 [TEST] Example.com content loaded: \(contentLoaded)")

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "ExampleDotCom_Loaded_\(Date().timeIntervalSince1970)"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(contentLoaded, "WebView should load example.com content")
    }

    func testWebViewNavigationCallbacks() {
        // This test specifically checks that navigation callbacks are firing
        // by waiting extra time and taking multiple screenshots

        let testURL = "http://localhost:8080/main_test.html"

        print("🧪 [TEST] Testing navigation callbacks")

        webAccessPage.enterURL(testURL)

        // Take initial screenshot immediately
        var screenshot = app.screenshot()
        var attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Immediate_After_URL_Entry"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Wait 2 seconds, take another screenshot
        Thread.sleep(forTimeInterval: 2)
        screenshot = app.screenshot()
        attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "After_2_Seconds"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Wait 5 seconds, take another screenshot
        Thread.sleep(forTimeInterval: 3)
        screenshot = app.screenshot()
        attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "After_5_Seconds"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Wait 10 seconds total, take final screenshot
        Thread.sleep(forTimeInterval: 5)
        screenshot = app.screenshot()
        attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "After_10_Seconds_Final"
        attachment.lifetime = .keepAlways
        add(attachment)

        print("🧪 [TEST] Multiple screenshots taken for timing analysis")
    }

    func testWebViewWithExplicitWait() {
        // Test that explicitly waits for navigation to complete
        let testURL = "http://localhost:8080/navigation_test.html"

        print("🧪 [TEST] Testing with explicit wait for navigation")

        webAccessPage.enterURL(testURL)

        // Explicitly wait for page load
        let pageLoaded = webAccessPage.waitForPageToLoad(timeout: 15)

        // Additional wait for rendering
        Thread.sleep(forTimeInterval: 3)

        // Take screenshot
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Explicit_Wait_Test_\(Date().timeIntervalSince1970)"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(pageLoaded, "Page should load within 15 seconds")
        print("✅ [TEST] Explicit wait test completed")
    }
}
