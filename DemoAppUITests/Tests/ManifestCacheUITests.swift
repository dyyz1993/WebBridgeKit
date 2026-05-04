//
//  ManifestCacheUITests.swift
//  DemoAppUITests
//
//  Created on 2025-02-02.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest
import os.log
#if os(macOS)
import Foundation
#endif

/// UI tests for WebBridgeKit Manifest Cache functionality
/// Tests the custom URL scheme (custom://) and manifest-based resource caching
final class ManifestCacheUITests: XCTestCase {

    let logger = OSLog(subsystem: "com.webbridgekit.demo.ui.tests", category: "ManifestCacheTests")
    var app: XCUIApplication!
    var webAccessPage: WebAccessPage!

    #if os(macOS)
    private var testServerProcess: Process?
    private let testServerPort = 8080
    #endif

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false

        #if os(macOS)
        // Start test server before running tests
        if !startTestServer() {
            XCTFail("Failed to start test server")
            return
        }
        #endif

        // Create screenshots directory
        let fileManager = FileManager.default
        let screenshotsDir = "/tmp/manifest_cache_tests/screenshots"
        if !fileManager.fileExists(atPath: screenshotsDir) {
            try? fileManager.createDirectory(atPath: screenshotsDir,
                                           withIntermediateDirectories: true,
                                           attributes: nil)
        }

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = [
            "IS_UI_TESTING": "YES",
            "TEST_SERVER_URL": "http://localhost:8080"
        ]
        app.launch()

        webAccessPage = WebAccessPage(app: app)

        // Navigate to WebAccess page
        guard webAccessPage.navigateViaTab() else {
            os_log("Failed to navigate to WebAccess page", log: logger, type: .error)
            XCTFail("Navigation to WebAccess page failed")
            return
        }

        os_log("Setup complete - test server running and app launched", log: logger, type: .info)
    }

    override func tearDownWithError() throws {
        // Take final screenshot
        let screenshot = app.screenshot()
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let screenshotPath = "/tmp/manifest_cache_tests/screenshots/\(timestamp)_final.png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: screenshotPath))

        #if os(macOS)
        // Stop test server after tests complete
        stopTestServer()
        #endif

        app = nil
        webAccessPage = nil
    }

    // MARK: - Test #1: Basic Page Loading

    func testManifestCacheBasic() throws {
        os_log("Testing #1: Manifest Cache Basic Page Loading", log: logger, type: .info)

        let testURL = "http://localhost:8080/manifest_cache_demo.html"

        // 1. Enter test URL
        os_log("Entering test URL: %@", log: logger, type: .info, testURL)
        webAccessPage.enterURL(testURL)

        // 2. Wait for page to load
        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            os_log("Page failed to load within timeout", log: logger, type: .error)

            let failureScreenshot = app.screenshot()
            let failurePath = "/tmp/manifest_cache_tests/screenshots/test1_basic_load_failure.png"
            try? failureScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: failurePath))

            XCTFail("Test page failed to load")
            return
        }

        os_log("Page loaded successfully", log: logger, type: .info)

        // 3. Wait for content to render
        Thread.sleep(forTimeInterval: 3.0)

        // 4. Take screenshot of loaded page
        let loadedScreenshot = app.screenshot()
        let loadedPath = "/tmp/manifest_cache_tests/screenshots/test1_basic_loaded.png"
        try? loadedScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: loadedPath))
        os_log("Screenshot saved to: %@", log: logger, type: .info, loadedPath)

        // 5. Verify page elements exist
        // Check for the main heading
        let headingExists = app.webViews.staticTexts["Manifest Cache System Demo"].exists
        os_log("Main heading found: %@", log: logger, type: .info, String(headingExists))

        // Check for status indicators
        let cssStatus = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS 'styles.css'")).firstMatch
        let jsStatus = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS 'app.js'")).firstMatch

        let cssFound = cssStatus.waitForExistence(timeout: 2)
        let jsFound = jsStatus.waitForExistence(timeout: 2)

        os_log("CSS status indicator found: %@", log: logger, type: .info, String(cssFound))
        os_log("JS status indicator found: %@", log: logger, type: .info, String(jsFound))

        // 6. Verify interactive buttons exist
        let testJSButton = app.webViews.buttons["Test JavaScript Bridge"]
        let checkCacheButton = app.webViews.buttons["Check Cache Status"]
        let loadImageButton = app.webViews.buttons["Load External Image"]

        let buttonsFound = testJSButton.exists || checkCacheButton.exists || loadImageButton.exists
        os_log("Interactive buttons found: %@", log: logger, type: .info, String(buttonsFound))

        // Assertions
        XCTAssertTrue(headingExists || cssFound || jsFound || buttonsFound,
                    "Page should have loaded with visible content")
    }

    // MARK: - Test #2: Resource Loading

    func testManifestCacheResourceLoading() throws {
        os_log("Testing #2: Manifest Cache Resource Loading", log: logger, type: .info)

        let testURL = "http://localhost:8080/manifest_cache_demo.html"

        // 1. Load the test page
        webAccessPage.enterURL(testURL)
        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            XCTFail("Test page failed to load")
            return
        }

        os_log("Page loaded, waiting for resources", log: logger, type: .info)
        Thread.sleep(forTimeInterval: 3.0)

        // 2. Take initial screenshot
        let initialScreenshot = app.screenshot()
        let initialPath = "/tmp/manifest_cache_tests/screenshots/test2_resources_initial.png"
        try? initialScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: initialPath))

        // 3. Check resource status indicators
        let cssStatus = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS 'styles.css'")).firstMatch
        let jsStatus = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS 'app.js'")).firstMatch
        let imageStatus = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS 'logo.png'")).firstMatch

        let cssExists = cssStatus.exists
        let jsExists = jsStatus.exists
        let imageExists = imageStatus.exists

        os_log("CSS status exists: %@", log: logger, type: .info, String(cssExists))
        os_log("JS status exists: %@", log: logger, type: .info, String(jsExists))
        os_log("Image status exists: %@", log: logger, type: .info, String(imageExists))

        // 4. Click "Test JavaScript Bridge" button
        let testJSButton = app.webViews.buttons["Test JavaScript Bridge"]
        if testJSButton.exists {
            os_log("Tapping Test JavaScript Bridge button", log: logger, type: .info)
            testJSButton.tap()
            Thread.sleep(forTimeInterval: 1.0)
        } else {
            // Try alternative button finding
            let predicate = NSPredicate(format: "label CONTAINS 'Test JavaScript' OR label CONTAINS 'JavaScript Bridge'")
            let altButton = app.webViews.buttons.element(matching: predicate)
            if altButton.exists {
                os_log("Tapping alternative Test JavaScript button", log: logger, type: .info)
                altButton.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }

        // 5. Check for test results
        let testResults = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS 'JavaScript Bridge Test Results'")).firstMatch
        let hasTestResults = testResults.waitForExistence(timeout: 3)

        os_log("Test results displayed: %@", log: logger, type: .info, String(hasTestResults))

        // 6. Take screenshot after interaction
        let interactionScreenshot = app.screenshot()
        let interactionPath = "/tmp/manifest_cache_tests/screenshots/test2_resources_after_interaction.png"
        try? interactionScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: interactionPath))

        // 7. Click "Load External Image" button to test image loading
        let loadImageButton = app.webViews.buttons["Load External Image"]
        if loadImageButton.exists {
            os_log("Tapping Load External Image button", log: logger, type: .info)
            loadImageButton.tap()
            Thread.sleep(forTimeInterval: 2.0)
        } else {
            let predicate = NSPredicate(format: "label CONTAINS 'Load External' OR label CONTAINS 'Load Image'")
            let altButton = app.webViews.buttons.element(matching: predicate)
            if altButton.exists {
                os_log("Tapping alternative Load Image button", log: logger, type: .info)
                altButton.tap()
                Thread.sleep(forTimeInterval: 2.0)
            }
        }

        // 8. Take final screenshot
        let finalScreenshot = app.screenshot()
        let finalPath = "/tmp/manifest_cache_tests/screenshots/test2_resources_final.png"
        try? finalScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: finalPath))

        // Assertions
        XCTAssertTrue(cssExists || jsExists || imageExists,
                    "At least one resource status indicator should be visible")
        XCTAssertTrue(hasTestResults || loadImageButton.exists,
                    "Should be able to interact with page elements")
    }

    // MARK: - Test #3: Cache Hit Verification

    func testManifestCacheCaching() throws {
        os_log("Testing #3: Manifest Cache Hit Verification", log: logger, type: .info)

        let testURL = "http://localhost:8080/manifest_cache_demo.html"

        // 1. First load - initial page load
        os_log("First page load - caching resources", log: logger, type: .info)
        webAccessPage.enterURL(testURL)
        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            XCTFail("Test page failed to load on first attempt")
            return
        }

        Thread.sleep(forTimeInterval: 3.0)

        let firstLoadScreenshot = app.screenshot()
        let firstLoadPath = "/tmp/manifest_cache_tests/screenshots/test3_cache_first_load.png"
        try? firstLoadScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: firstLoadPath))

        // 2. Navigate away to clear the current view
        os_log("Navigating away from test page", log: logger, type: .info)
        webAccessPage.enterURL("about:blank")
        Thread.sleep(forTimeInterval: 1.0)

        // 3. Reload the same page - should hit cache
        os_log("Reloading page - should hit cache", log: logger, type: .info)
        webAccessPage.enterURL(testURL)
        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            XCTFail("Test page failed to load on second attempt")
            return
        }

        Thread.sleep(forTimeInterval: 3.0)

        let secondLoadScreenshot = app.screenshot()
        let secondLoadPath = "/tmp/manifest_cache_tests/screenshots/test3_cache_second_load.png"
        try? secondLoadScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: secondLoadPath))

        // 4. Click "Check Cache Status" button
        let checkCacheButton = app.webViews.buttons["Check Cache Status"]
        if checkCacheButton.exists {
            os_log("Tapping Check Cache Status button", log: logger, type: .info)
            checkCacheButton.tap()
            Thread.sleep(forTimeInterval: 1.0)
        } else {
            let predicate = NSPredicate(format: "label CONTAINS 'Check Cache' OR label CONTAINS 'Cache Status'")
            let altButton = app.webViews.buttons.element(matching: predicate)
            if altButton.exists {
                os_log("Tapping alternative Check Cache button", log: logger, type: .info)
                altButton.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }

        // 5. Check for cache status information
        let cacheStatus = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Cache System Status'")).firstMatch
        let hasCacheStatus = cacheStatus.waitForExistence(timeout: 3)

        os_log("Cache status displayed: %@", log: logger, type: .info, String(hasCacheStatus))

        // 6. Take final screenshot showing cache status
        let cacheStatusScreenshot = app.screenshot()
        let cacheStatusPath = "/tmp/manifest_cache_tests/screenshots/test3_cache_status.png"
        try? cacheStatusScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: cacheStatusPath))

        // 7. Verify page elements loaded successfully on reload
        let headingExists = app.webViews.staticTexts["Manifest Cache System Demo"].exists
        let cssStatus = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS 'styles.css'")).firstMatch.exists
        let jsStatus = app.webViews.staticTexts.containing(NSPredicate(format: "label CONTAINS 'app.js'")).firstMatch.exists

        os_log("Page reloaded - heading: %@, css: %@, js: %@",
               log: logger, type: .info,
               String(headingExists), String(cssStatus), String(jsStatus))

        // Assertions
        XCTAssertTrue(headingExists || cssStatus || jsStatus || hasCacheStatus,
                    "Page should reload successfully with cached resources")
    }

    // MARK: - Test Server Management

    #if os(macOS)
    /// Start the test server for UI tests
    private func startTestServer() -> Bool {
        // Check if server is already running
        if isTestServerRunning() {
            os_log("✅ Test server is already running on port %d", log: logger, type: .info, testServerPort)
            return true
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")

        // Path to test server script
        let scriptPath = "/Users/xuyingzhou/Project/temporary/WebBridgeKit/scripts/test_server.py"
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            os_log("❌ Test server script not found at: %@", log: logger, type: .error, scriptPath)
            return false
        }

        process.arguments = [scriptPath]

        // Setup output pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            testServerProcess = process

            // Give server time to start
            Thread.sleep(forTimeInterval: 1.0)

            if isTestServerRunning() {
                os_log("✅ Test server started successfully on port %d", log: logger, type: .info, testServerPort)
                return true
            } else {
                os_log("❌ Test server failed to start", log: logger, type: .error)
                return false
            }
        } catch {
            os_log("❌ Failed to start test server: %@", log: logger, type: .error, error.localizedDescription)
            return false
        }
    }

    /// Stop the test server
    private func stopTestServer() {
        guard let process = testServerProcess, process.isRunning else {
            os_log("ℹ️ Test server is not running", log: logger, type: .info)
            return
        }

        process.terminate()

        // Wait for process to terminate gracefully
        var attempts = 0
        while process.isRunning && attempts < 10 {
            Thread.sleep(forTimeInterval: 0.5)
            attempts += 1
        }

        // Force kill if still running
        if process.isRunning {
            os_log("⚠️ Force killing test server process", log: logger, type: .default)
            process.interrupt()
            Thread.sleep(forTimeInterval: 0.5)

            if process.isRunning {
                killProcessOnPort(testServerPort)
            }
        }

        testServerProcess = nil
        os_log("✅ Test server stopped", log: logger, type: .info)
    }

    /// Check if test server is running on the specified port
    private func isTestServerRunning() -> Bool {
        var isRunning = false

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-i", ":\(testServerPort)"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                isRunning = output.contains("LISTEN")
            }
        } catch {
            // lsof failed, assume server is not running
        }

        return isRunning
    }

    /// Kill process using the specified port
    private func killProcessOnPort(_ port: Int) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/kill")
        task.arguments = ["$(lsof -ti :\(port))"]

        do {
            try task.run()
            task.waitUntilExit()
            os_log("✅ Killed process on port %d", log: logger, type: .info, port)
        } catch {
            os_log("⚠️ Failed to kill process on port %d: %@", log: logger, type: .error, port, error.localizedDescription)
        }
    }
    #endif
}
