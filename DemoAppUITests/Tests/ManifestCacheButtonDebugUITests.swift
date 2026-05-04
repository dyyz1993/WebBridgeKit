//
//  ManifestCacheButtonDebugUITests.swift
//  DemoAppUITests
//
//  Created on 2025-02-03.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//
//  This test debugs the issue where buttons become unclickable after returning
//  from full screen WebView display.

import XCTest
import os.log

final class ManifestCacheButtonDebugUITests: XCTestCase {

    let logger = OSLog(subsystem: "com.webbridgekit.demo.ui.tests", category: "ManifestButtonDebug")
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Create screenshots directory
        let fileManager = FileManager.default
        let screenshotsDir = "/tmp/manifest_button_debug/screenshots"
        if !fileManager.fileExists(atPath: screenshotsDir) {
            try? fileManager.createDirectory(atPath: screenshotsDir,
                                           withIntermediateDirectories: true,
                                           attributes: nil)
        }

        // Create debug logs directory
        let logsDir = "/tmp/manifest_button_debug/logs"
        if !fileManager.fileExists(atPath: logsDir) {
            try? fileManager.createDirectory(atPath: logsDir,
                                           withIntermediateDirectories: true,
                                           attributes: nil)
        }

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--debug-buttons"]
        app.launchEnvironment = [
            "IS_UI_TESTING": "YES"
        ]
        app.launch()

        os_log("🚀 Test setup complete - app launched", log: logger, type: .info)
    }

    override func tearDownWithError() throws {
        // Take final screenshot
        let screenshot = app.screenshot()
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let screenshotPath = "/tmp/manifest_button_debug/screenshots/\(timestamp)_final.png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: screenshotPath))
        os_log("Final screenshot saved to: %@", log: logger, type: .info, screenshotPath)
    }

    // MARK: - Main Debug Test

    func testDebugButtonClickabilityAfterFullScreen() throws {
        os_log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", log: logger, type: .info)
        os_log("🔍 DEBUG TEST: Button Clickability After Full Screen", log: logger, type: .info)
        os_log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", log: logger, type: .info)

        // Step 1: Navigate to cache test page (Tab 2)
        os_log("\n📍 Step 1: Navigate to Manifest Cache Test Page", log: logger, type: .info)
        navigateToCacheTestPage()

        // Step 2: Take initial screenshot and log view hierarchy
        os_log("\n📍 Step 2: Capture initial state", log: logger, type: .info)
        takeScreenshot(name: "01_initial_state")
        logViewHierarchy(label: "Initial State")

        // Step 3: Verify all buttons are hittable BEFORE full screen
        os_log("\n📍 Step 3: Verify buttons are hittable BEFORE full screen", log: logger, type: .info)
        let buttonsBefore = verifyAllButtons(label: "Before Full Screen")

        // Step 4: Tap "开始测试" button to open full screen
        os_log("\n📍 Step 4: Tap Start Test button", log: logger, type: .info)
        let startButton = app.buttons["manifest_test.start_button"]
        guard startButton.waitForExistence(timeout: 5) else {
            os_log("❌ Start button not found!", log: logger, type: .error)
            XCTFail("Start button not found")
            return
        }

        logButtonInfo(startButton, label: "Start Button (Before Tap)")
        startButton.tap()
        os_log("✅ Start button tapped", log: logger, type: .info)

        // Wait for full screen page to appear
        Thread.sleep(forTimeInterval: 2.0)

        // Step 5: Take screenshot of full screen page
        os_log("\n📍 Step 5: Full screen page displayed", log: logger, type: .info)
        takeScreenshot(name: "02_full_screen")
        logViewHierarchy(label: "Full Screen Page")

        // Verify we're on the full screen page
        let closeButton = app.buttons["webview_display.close_button"]
        if closeButton.waitForExistence(timeout: 5) {
            os_log("✅ Full screen page confirmed - close button found", log: logger, type: .info)
        } else {
            os_log("⚠️ Full screen page may not have loaded properly", log: logger, type: .error)
        }

        // Step 6: Tap "关闭" button to return
        os_log("\n📍 Step 6: Tap Close button to return", log: logger, type: .info)
        closeButton.tap()
        os_log("✅ Close button tapped", log: logger, type: .info)

        // Wait for return animation
        Thread.sleep(forTimeInterval: 2.0)

        // Step 7: Take screenshot after returning
        os_log("\n📍 Step 7: State after returning from full screen", log: logger, type: .info)
        takeScreenshot(name: "03_after_return")
        logViewHierarchy(label: "After Return")

        // Step 8: Verify all buttons are hittable AFTER returning
        os_log("\n📍 Step 8: Verify buttons are hittable AFTER returning", log: logger, type: .info)
        let buttonsAfter = verifyAllButtons(label: "After Return")

        // Step 9: Compare results
        os_log("\n📍 Step 9: Compare button states", log: logger, type: .info)
        compareButtonStates(before: buttonsBefore, after: buttonsAfter)

        // Step 10: Attempt to tap each button to verify clickability
        os_log("\n📍 Step 10: Attempt to tap each button", log: logger, type: .info)
        testButtonTaps()

        os_log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", log: logger, type: .info)
        os_log("✅ DEBUG TEST COMPLETE", log: logger, type: .info)
        os_log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", log: logger, type: .info)
    }

    // MARK: - Helper Methods

    private func navigateToCacheTestPage() {
        // Wait for tab bar
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            os_log("❌ Tab bar not found", log: logger, type: .error)
            XCTFail("Tab bar not found")
            return
        }

        os_log("✅ Tab bar found", log: logger, type: .info)

        // Tab 2 is "Manifest 缓存测试" - use index 2 (0-based: 0=首页, 1=网页访问, 2=Manifest)
        let manifestTab = app.tabBars.buttons.element(boundBy: 2)
        if manifestTab.exists {
            os_log("📍 Tapping Manifest Cache Test tab (index 2)", log: logger, type: .info)
            manifestTab.tap()
            os_log("✅ Tapped Manifest Cache Test tab", log: logger, type: .info)
            Thread.sleep(forTimeInterval: 1.0)
        } else {
            os_log("⚠️ Manifest tab not found, trying alternative method", log: logger, type: .default)
            // Try by label
            let tabByLabel = app.tabBars.buttons["Manifest 缓存测试"]
            if tabByLabel.exists {
                tabByLabel.tap()
                os_log("✅ Tapped tab by label", log: logger, type: .info)
                Thread.sleep(forTimeInterval: 1.0)
            }
        }

        // Wait for cache test page to load
        let cacheTestPage = app.otherElements["ManifestCacheTestViewController"]
        if cacheTestPage.waitForExistence(timeout: 5) {
            os_log("✅ Cache test page loaded", log: logger, type: .info)
        } else {
            os_log("⚠️ Cache test page identifier not found, continuing anyway", log: logger, type: .default)
        }
    }

    private func takeScreenshot(name: String) {
        let screenshot = app.screenshot()
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let screenshotPath = "/tmp/manifest_button_debug/screenshots/\(timestamp)_\(name).png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: screenshotPath))
        os_log("📸 Screenshot saved: %@", log: logger, type: .info, screenshotPath)
    }

    private func logViewHierarchy(label: String) {
        os_log("🌳 View Hierarchy [%@]:", log: logger, type: .info, label)

        let debugDescription = app.debugDescription
        let logPath = "/tmp/manifest_button_debug/logs/\(label.replacingOccurrences(of: " ", with: "_"))_hierarchy.txt"

        if let data = debugDescription.data(using: .utf8) {
            try? data.write(to: URL(fileURLWithPath: logPath))
            os_log("📄 View hierarchy saved to: %@", log: logger, type: .info, logPath)
        }

        // Log key elements
        let startButton = app.buttons["manifest_test.start_button"]
        let clearCacheButton = app.buttons["manifest_test.clear_cache_button"]
        let copyLogButton = app.buttons["manifest_test.copy_log_button"]
        let clearLogButton = app.buttons["manifest_test.clear_log_button"]
        let webView = app.otherElements["manifest_test.webview"]

        os_log("Key elements found:", log: logger, type: .info)
        os_log("  - Start Button: %@", log: logger, type: .info, startButton.exists ? "YES" : "NO")
        os_log("  - Clear Cache Button: %@", log: logger, type: .info, clearCacheButton.exists ? "YES" : "NO")
        os_log("  - Copy Log Button: %@", log: logger, type: .info, copyLogButton.exists ? "YES" : "NO")
        os_log("  - Clear Log Button: %@", log: logger, type: .info, clearLogButton.exists ? "YES" : "NO")
        os_log("  - WebView: %@", log: logger, type: .info, webView.exists ? "YES" : "NO")
    }

    private func logButtonInfo(_ button: XCUIElement, label: String) {
        os_log("🔍 Button Info [%@]:", log: logger, type: .info, label)
        os_log("  - Exists: %@", log: logger, type: .info, button.exists ? "YES" : "NO")
        os_log("  - isHittable: %@", log: logger, type: .info, button.isHittable ? "YES" : "NO")
        os_log("  - isEnabled: %@", log: logger, type: .info, button.isEnabled ? "YES" : "NO")
        os_log("  - Frame: %@", log: logger, type: .info, String(describing: button.frame))

        if button.exists {
            // Note: snapshot() can throw but we use try? to handle it gracefully
            let snapshot = try? button.snapshot()
            os_log("  - Snapshot exists: %@", log: logger, type: .info, snapshot != nil ? "YES" : "NO")
        }
    }

    private func verifyAllButtons(label: String) -> [String: Bool] {
        var results: [String: Bool] = [:]

        let buttons = [
            ("Start Button", app.buttons["manifest_test.start_button"]),
            ("Clear Cache Button", app.buttons["manifest_test.clear_cache_button"]),
            ("Copy Log Button", app.buttons["manifest_test.copy_log_button"]),
            ("Clear Log Button", app.buttons["manifest_test.clear_log_button"])
        ]

        os_log("🔍 Verifying buttons [%@]:", log: logger, type: .info, label)

        for (name, button) in buttons {
            let exists = button.exists
            let isHittable = button.isHittable
            let isEnabled = button.isEnabled

            results[name] = isHittable

            os_log("  %@:", log: logger, type: .info, name)
            os_log("    Exists: %@", log: logger, type: .info, exists ? "✅" : "❌")
            os_log("    Hittable: %@", log: logger, type: .info, isHittable ? "✅" : "❌")
            os_log("    Enabled: %@", log: logger, type: .info, isEnabled ? "✅" : "❌")
            os_log("    Frame: %@", log: logger, type: .info, String(describing: button.frame))

            // Check if any element is covering the button
            if exists {
                let hitPoint = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                os_log("    Hit point: %@", log: logger, type: .info, String(describing: hitPoint))
            }
        }

        return results
    }

    private func compareButtonStates(before: [String: Bool], after: [String: Bool]) {
        os_log("📊 Comparing button states:", log: logger, type: .info)

        for (buttonName, beforeHittable) in before {
            let afterHittable = after[buttonName] ?? false

            if beforeHittable && !afterHittable {
                os_log("  ❌ %@: BECAME UNHIITTABLE!", log: logger, type: .error, buttonName)
            } else if !beforeHittable && afterHittable {
                os_log("  ⚠️ %@: Was not hittable before, is hittable now", log: logger, type: .default, buttonName)
            } else if beforeHittable && afterHittable {
                os_log("  ✅ %@: Still hittable", log: logger, type: .info, buttonName)
            } else {
                os_log("  ❌ %@: Not hittable in either state", log: logger, type: .error, buttonName)
            }
        }
    }

    private func testButtonTaps() {
        let buttons = [
            ("Start Button", app.buttons["manifest_test.start_button"]),
            ("Clear Cache Button", app.buttons["manifest_test.clear_cache_button"]),
            ("Copy Log Button", app.buttons["manifest_test.copy_log_button"]),
            ("Clear Log Button", app.buttons["manifest_test.clear_log_button"])
        ]

        for (name, button) in buttons {
            os_log("\n🎯 Testing tap on: %@", log: logger, type: .info, name)

            if !button.exists {
                os_log("  ❌ Button does not exist", log: logger, type: .error)
                continue
            }

            if !button.isHittable {
                os_log("  ❌ Button is not hittable", log: logger, type: .error)
                os_log("     Frame: %@", log: logger, type: .info, String(describing: button.frame))

                continue
            }

            // Attempt to tap
            let beforeScreenshot = app.screenshot()
            button.tap()
            Thread.sleep(forTimeInterval: 0.5)

            let afterScreenshot = app.screenshot()

            // Check if anything changed (button worked)
            // This is a simple heuristic - in a real test you'd check for specific changes
            os_log("  ✅ Tap attempted (check screenshots to verify)", log: logger, type: .info)

            // Save before/after screenshots
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let beforePath = "/tmp/manifest_button_debug/screenshots/\(timestamp)_\(name.replacingOccurrences(of: " ", with: "_"))_before.png"
            let afterPath = "/tmp/manifest_button_debug/screenshots/\(timestamp)_\(name.replacingOccurrences(of: " ", with: "_"))_after.png"

            try? beforeScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: beforePath))
            try? afterScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: afterPath))

            os_log("     Before: %@", log: logger, type: .info, beforePath)
            os_log("     After: %@", log: logger, type: .info, afterPath)

            Thread.sleep(forTimeInterval: 1.0)
        }
    }
}
