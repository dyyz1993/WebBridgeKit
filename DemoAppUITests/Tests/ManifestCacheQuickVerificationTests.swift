//
//  ManifestCacheQuickVerificationTests.swift
//  DemoAppUITests
//
//  Created on 2026-02-03.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//

import XCTest
import os.log

/// Quick verification test for Manifest Cache functionality in ManifestCacheTestViewController
/// This test simply navigates to the cache test tab and captures screenshots for MCP analysis
final class ManifestCacheQuickVerificationTests: XCTestCase {

    let logger = OSLog(subsystem: "com.webbridgekit.demo.ui.tests", category: "ManifestQuickVerify")
    var app: XCUIApplication!

    // Test configuration
    let testURL = "http://192.168.0.4:8080/manifest_cache_demo/"
    let outputDirectory = "/tmp/manifest_cache_verify"
    let screenshotsDirectory = "/tmp/manifest_cache_verify/screenshots"

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Create output directories
        let fileManager = FileManager.default
        try? fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(atPath: screenshotsDirectory, withIntermediateDirectories: true)

        os_log("📁 Output directory: %@", log: logger, type: .info, outputDirectory)

        // Launch app
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--disable-animations"]
        app.launchEnvironment = ["IS_UI_TESTING": "YES", "AUTO_TEST_ENABLED": "YES"]
        app.launch()

        os_log("✅ App launched", log: logger, type: .info)
    }

    override func tearDownWithError() throws {
        // Take final screenshot
        let screenshot = app.screenshot()
        let data = screenshot.pngRepresentation
        let path = "\(screenshotsDirectory)/final_state.png"
        try? data.write(to: URL(fileURLWithPath: path))

        app = nil
    }

    // MARK: - Helper Methods

    func saveScreenshot(named name: String) {
        let screenshot = app.screenshot()
        let data = screenshot.pngRepresentation
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "\(name)_\(timestamp).png"
        let path = "\(screenshotsDirectory)/\(filename)"

        try? data.write(to: URL(fileURLWithPath: path))
        os_log("📸 Screenshot saved: %@", log: logger, type: .info, filename)
    }

    // MARK: - Test Methods

    /// Test: Navigate to Manifest Cache Test tab and capture evidence
    func testQuickVerification() throws {
        os_log("=== Manifest Cache Quick Verification Test ===", log: logger, type: .info)

        // Wait for app to load
        Thread.sleep(forTimeInterval: 2.0)
        saveScreenshot(named: "01_initial_state")

        // TabBarController defaults to index 2 (缓存测试) in DEBUG mode
        // But let's verify and tap it explicitly if needed
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            // Try to find the "缓存测试" tab
            let cacheTestTab = tabBar.buttons["缓存测试"]
            if cacheTestTab.exists {
                os_log("📱 Tapping 缓存测试 tab", log: logger, type: .info)
                cacheTestTab.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }

        saveScreenshot(named: "02_cache_tab_loaded")

        // Wait for auto-test to start (DEBUG mode auto-starts after 1 second)
        // The ManifestCacheTestViewController has auto-test in DEBUG mode
        os_log("⏳ Waiting for auto-test to start...", log: logger, type: .info)

        // Wait for the test to load (up to 60 seconds)
        for i in 1...12 {
            Thread.sleep(forTimeInterval: 5.0)
            saveScreenshot(named: "03_progress_\(i)")
                print("⏳ Progress checkpoint \(i)/12")

            // Check for completion indicators
            if app.staticTexts["✅ 持久化加载成功"].exists ||
               app.staticTexts["✅ 懒加载启动成功"].exists {
                os_log("✅ Test completed successfully", log: logger, type: .info)
                break
            }
        }

        // Take final screenshots
        Thread.sleep(forTimeInterval: 2.0)
        saveScreenshot(named: "04_final_state")

        // Try to capture the WebView content
        let webView = app.webViews["manifest_test.webview"]
        if webView.exists {
            saveScreenshot(named: "05_webview_content")
            os_log("✅ WebView screenshot captured", log: logger, type: .info)
        }

        // Try to capture log content
        let logView = app.textViews["manifest_test.log_view"]
        if logView.exists {
            saveScreenshot(named: "06_log_content")
            os_log("✅ Log view screenshot captured", log: logger, type: .info)
        }

        os_log("=== Test Complete ===", log: logger, type: .info)
    }

    /// Generate summary report
    func testGenerateSummary() throws {
        // First run the main test
        try testQuickVerification()

        // Generate summary
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let summary = """
        # Manifest Cache Verification Test Summary

        **Date**: \(timestamp)
        **Test URL**: \(testURL)
        **Simulator**: iPhone 15 Pro (iOS 17.5)

        ## Test Results

        This test navigates to the Manifest Cache Test tab (缓存测试) in DemoApp
        and allows the auto-test to run in DEBUG mode.

        ## Screenshots Captured

        Screenshots saved to: \(screenshotsDirectory)

        - 01_initial_state: App launch state
        - 02_cache_tab_loaded: Cache test tab displayed
        - 03_progress_1-12: Loading progress checkpoints
        - 04_final_state: Final state after test
        - 05_webview_content: WebView content (if available)
        - 06_log_content: Log view content (if available)

        ## Expected Results

        If Manifest Cache is working correctly:
        - Images should load from wb-resource:// or custom:// schemes
        - No "未缓存" (Not Cached) warnings
        - Log should show cache hits

        ## Next Steps

        Use MCP to analyze screenshots and verify:
        1. Page content is displayed
        2. Images are visible
        3. Cache status indicators show success
        """

        let summaryPath = "\(outputDirectory)/SUMMARY.md"
        try? summary.write(toFile: summaryPath, atomically: true, encoding: .utf8)

        os_log("📄 Summary saved: %@", log: logger, type: .info, summaryPath)
    }
}
