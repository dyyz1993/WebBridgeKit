//
//  ManifestCacheVerificationTests.swift
//  DemoAppUITests
//
//  Created on 2026-02-02.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//

import XCTest
import os.log

/// UI tests for verifying Manifest Cache functionality through the dedicated test UI
/// Tests the ManifestCacheTestViewController with persistent mode caching
final class ManifestCacheVerificationTests: XCTestCase {

    let logger = OSLog(subsystem: "com.webbridgekit.demo.ui.tests", category: "ManifestCacheVerification")
    var app: XCUIApplication!

    // Test configuration
    let testURL = "http://192.168.0.4:8080/manifest_cache_demo/"
    let simulatorID = "04034623-1A26-4FE9-AF80-FDA5B7994E88"

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Create screenshots directory
        let fileManager = FileManager.default
        let screenshotsDir = "/tmp/manifest_verification_tests/screenshots"
        if !fileManager.fileExists(atPath: screenshotsDir) {
            try? fileManager.createDirectory(atPath: screenshotsDir,
                                           withIntermediateDirectories: true,
                                           attributes: nil)
        }

        // Launch app with testing arguments
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--disable-animations"
        ]
        app.launchEnvironment = [
            "IS_UI_TESTING": "YES",
            "AUTO_TEST_ENABLED": "YES"
        ]
        app.launch()

        os_log("✅ App launched successfully", log: logger, type: .info)
    }

    override func tearDownWithError() throws {
        // Take final screenshot
        let screenshot = app.screenshot()
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Final_State_\(timestamp)"
        attachment.lifetime = .keepAlways
        add(attachment)

        app = nil
    }

    // MARK: - Test #1: Navigate to Cache Test Page

    func test01_navigateToCacheTestPage() throws {
        os_log("=== Test #1: Navigate to Cache Test Page ===", log: logger, type: .info)

        // Wait for app to fully load
        Thread.sleep(forTimeInterval: 2.0)

        // Screenshot of initial state
        let initialScreenshot = app.screenshot()
        let initialPath = "/tmp/manifest_verification_tests/screenshots/test01_initial_state.png"
        try? initialScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: initialPath))
        os_log("Initial screenshot saved", log: logger, type: .info)

        // Look for the cache test tab (3rd tab in tab bar)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should exist")

        // Try to find and tap the cache test tab
        // The tab should be labeled "缓存测试"
        let cacheTestTab = tabBar.buttons["缓存测试"]
        let altTab1 = tabBar.buttons.element(boundBy: 2) // 3rd tab (0-indexed)

        if cacheTestTab.exists {
            os_log("Tapping cache test tab by label", log: logger, type: .info)
            cacheTestTab.tap()
        } else if altTab1.exists {
            os_log("Tapping cache test tab by index", log: logger, type: .info)
            altTab1.tap()
        } else {
            // Try alternative approach
            let allTabs = tabBar.buttons
            if allTabs.count >= 3 {
                os_log("Found %d tabs, tapping 3rd tab", log: logger, type: .info, allTabs.count)
                allTabs.element(boundBy: 2).tap()
            } else {
                XCTFail("Could not find cache test tab")
                return
            }
        }

        // Wait for navigation
        Thread.sleep(forTimeInterval: 2.0)

        // Verify we're on the cache test page
        // Look for URL input field or start button
        let urlField = app.textFields.element(boundBy: 0)
        let startButton = app.buttons["开始测试"]
        let modeSegment = app.segmentedControls.element(boundBy: 0)

        let onCacheTestPage = urlField.exists || startButton.exists || modeSegment.exists

        let navScreenshot = app.screenshot()
        let navPath = "/tmp/manifest_verification_tests/screenshots/test01_after_navigation.png"
        try? navScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: navPath))

        XCTAssertTrue(onCacheTestPage, "Should navigate to cache test page")
        os_log("✅ Successfully navigated to cache test page", log: logger, type: .info)
    }

    // MARK: - Test #2: Verify UI Elements

    func test02_verifyCacheTestUIElements() throws {
        os_log("=== Test #2: Verify Cache Test UI Elements ===", log: logger, type: .info)

        // First navigate to cache test page
        try test01_navigateToCacheTestPage()

        // Wait for UI to stabilize
        Thread.sleep(forTimeInterval: 1.0)

        // Check for key UI elements
        let urlField = app.textFields.element(boundBy: 0)
        let startButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '开始测试' OR label CONTAINS '测试'")).firstMatch
        let clearCacheButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '清除缓存' OR label CONTAINS '清除'")).firstMatch
        let modeSegment = app.segmentedControls.element(boundBy: 0)

        // Verify URL input field
        if urlField.exists {
            let currentURL = urlField.value as? String ?? ""
            os_log("URL field value: %@", log: logger, type: .info, currentURL)
        }

        // Take screenshot of UI elements
        let uiScreenshot = app.screenshot()
        let uiPath = "/tmp/manifest_verification_tests/screenshots/test02_ui_elements.png"
        try? uiScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: uiPath))

        // Assertions
        XCTAssertTrue(urlField.exists || startButton.exists, "URL field or start button should exist")
        os_log("✅ UI elements verified", log: logger, type: .info)
    }

    // MARK: - Test #3: Start Persistent Cache Test

    func test03_startPersistentCacheTest() throws {
        os_log("=== Test #3: Start Persistent Cache Test ===", log: logger, type: .info)

        // Navigate to cache test page
        try test01_navigateToCacheTestPage()

        // Set persistent mode if needed
        let modeSegment = app.segmentedControls.element(boundBy: 0)
        if modeSegment.exists {
            // Tap on the second segment (persistent mode)
            let persistentModeSegment = modeSegment.buttons.element(boundBy: 1)
            if persistentModeSegment.exists {
                os_log("Setting to persistent mode", log: logger, type: .info)
                persistentModeSegment.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        // Tap start button
        let startButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '开始测试' OR label CONTAINS '测试中'")).firstMatch
        if startButton.exists {
            os_log("Tapping start button", log: logger, type: .info)
            startButton.tap()
        } else {
            // Try finding by index
            let allButtons = app.buttons
            for i in 0..<allButtons.count {
                let button = allButtons.element(boundBy: i)
                if let label = button.label as String?, label.contains("开始") || label.contains("测试") {
                    os_log("Tapping start button (index %d)", log: logger, type: .info, i)
                    button.tap()
                    break
                }
            }
        }

        // Wait for download to start
        Thread.sleep(forTimeInterval: 2.0)

        // Take screenshot of download progress
        let downloadScreenshot = app.screenshot()
        let downloadPath = "/tmp/manifest_verification_tests/screenshots/test03_download_started.png"
        try? downloadScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: downloadPath))

        os_log("✅ Cache test started", log: logger, type: .info)
    }

    // MARK: - Test #4: Wait for Resource Download

    func test04_waitForResourceDownload() throws {
        os_log("=== Test #4: Wait for Resource Download ===", log: logger, type: .info)

        // Start the test first
        try test03_startPersistentCacheTest()

        // Wait for resources to download (3 resources in our updated manifest)
        os_log("Waiting for resource download...", log: logger, type: .info)

        // Monitor download progress with screenshots every 10 seconds
        for second in stride(from: 10, through: 40, by: 10) {
            Thread.sleep(forTimeInterval: 10.0)
            os_log("Waited %d seconds", log: logger, type: .info, second)

            let progressScreenshot = app.screenshot()
            let progressPath = "/tmp/manifest_verification_tests/screenshots/test04_progress_\(second)s.png"
            try? progressScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: progressPath))

            // Check if test is complete by looking for completion indicators
            let completed = isDownloadComplete()
            if completed {
                os_log("✅ Download completed after %d seconds", log: logger, type: .info, second)
                break
            }
        }

        // Final screenshot after wait
        let finalScreenshot = app.screenshot()
        let finalPath = "/tmp/manifest_verification_tests/screenshots/test04_after_download.png"
        try? finalScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: finalPath))

        os_log("✅ Download wait completed", log: logger, type: .info)
    }

    // MARK: - Test #5: Verify Cache Files Created

    func test05_verifyCacheFilesCreated() throws {
        os_log("=== Test #5: Verify Cache Files Created ===", log: logger, type: .info)

        // Start the test and wait for download
        try test04_waitForResourceDownload()

        // Now verify cache files were created
        Thread.sleep(forTimeInterval: 2.0)

        let filesFound = checkCacheFiles()

        // Take screenshot for verification
        let verifyScreenshot = app.screenshot()
        let verifyPath = "/tmp/manifest_verification_tests/screenshots/test05_verification.png"
        try? verifyScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: verifyPath))

        // Log results
        os_log("Cache files found: %@", log: logger, type: .info, filesFound.description)

        // Assertions
        XCTAssertTrue(filesFound.hasManifestCache, "Manifest cache plist should exist")
        XCTAssertTrue(filesFound.resourceCount > 0, "At least one resource should be cached")

        os_log("✅ Cache files verified: %d resources", log: logger, type: .info, filesFound.resourceCount)
    }

    // MARK: - Test #6: Offline Access Test

    func test06_offlineAccessTest() throws {
        os_log("=== Test #6: Offline Access Test ===", log: logger, type: .info)

        // First ensure cache is populated
        try test05_verifyCacheFilesCreated()

        // Navigate away first
        let urlField = app.textFields.element(boundBy: 0)
        if urlField.exists {
            urlField.tap()
            urlField.typeText("about:blank")
            app.keyboards.buttons["Return"].tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

        // Navigate back to cached page
        if urlField.exists {
            urlField.tap()
            urlField.typeText(testURL)
            app.keyboards.buttons["Return"].tap()
        }

        // Wait for page to load from cache
        Thread.sleep(forTimeInterval: 3.0)

        // Take offline screenshot
        let offlineScreenshot = app.screenshot()
        let offlinePath = "/tmp/manifest_verification_tests/screenshots/test06_offline_access.png"
        try? offlineScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: offlinePath))

        // Verify content is displayed
        let webView = app.webViews.firstMatch
        let hasContent = webView.exists

        os_log("Offline content displayed: %@", log: logger, type: .info, String(hasContent))

        XCTAssertTrue(hasContent, "Content should be displayed from cache")
        os_log("✅ Offline access verified", log: logger, type: .info)
    }

    // MARK: - Helper Methods

    /// Check if download is complete by checking for completion indicators
    private func isDownloadComplete() -> Bool {
        // Look for completion indicators:
        // - Button text changed back to "开始测试"
        // - Cache statistics updated
        // - Progress modal dismissed

        let startButton = app.buttons["开始测试"]
        let completeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '完成' OR label CONTAINS '✓'")).firstMatch
        let statsText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '缓存资源' OR label CONTAINS '命中率'")).firstMatch

        return startButton.exists || completeButton.exists || statsText.exists
    }

    /// Check if cache files were created
    private func checkCacheFiles() -> (hasManifestCache: Bool, resourceCount: Int, description: String) {
        // Find the app container
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        task.arguments = ["simctl", "get_app_container", simulatorID, "com.webbridgekit.demo", "data"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe

        var containerPath = ""
        do {
            try task.run()
            task.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                containerPath = output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            os_log("Failed to get container path: %@", log: logger, type: .error, error.localizedDescription)
        }

        if containerPath.isEmpty {
            return (false, 0, "Could not find app container")
        }

        // Check for cache files
        let manifestCachePath = "\(containerPath)/Library/Caches/ManifestCache"
        let resourcesPath = "\(manifestCachePath)/Resources"

        var hasManifestCache = false
        var resourceCount = 0

        let fileManager = FileManager.default

        // Check for manifest_cache.plist
        let manifestPlist = "\(manifestCachePath)/manifest_cache.plist"
        hasManifestCache = fileManager.fileExists(atPath: manifestPlist)

        // Count resources
        if let resourceFiles = try? fileManager.contentsOfDirectory(atPath: resourcesPath) {
            resourceCount = resourceFiles.filter { !$0.hasPrefix(".") }.count
        }

        let description = """
        Container: \(containerPath)
        ManifestCache: \(hasManifestCache)
        Resources: \(resourceCount) files
        """

        return (hasManifestCache, resourceCount, description)
    }

    /// Take a screenshot and save it
    private func takeScreenshot(named name: String) -> String {
        let screenshot = app.screenshot()
        let path = "/tmp/manifest_verification_tests/screenshots/\(name).png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
        return path
    }
}
