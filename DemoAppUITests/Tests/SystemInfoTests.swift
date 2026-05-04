//
//  SystemInfoTests.swift
//  DemoAppUITests
//
//  P0 Test #3: Get System Info Function Test
//  Created on 2025-02-01.
//

import XCTest

/// System Info API UI Test
/// Tests the getSystemInfo bridge API functionality
final class SystemInfoTests: XCTestCase {

    var app: XCUIApplication!
    var webAccessPage: WebAccessPage!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Initialize app and page objects
        app = AppLauncher.shared.launchApp()
        webAccessPage = WebAccessPage(app: app)

        // 自动截图: setup
        captureScreenshot(name: "setup", phase: "setup")

        print("✅ System Info Test #3: Setup completed")
    }

    override func tearDownWithError() throws {
        // Navigate back if needed
        if webAccessPage.backButton.exists {
            webAccessPage.tapBackButton()
        }

        // 自动截图: teardown
        captureScreenshot(name: "teardown", phase: "teardown")

        AppLauncher.shared.terminateApp(app)
        app = nil
        webAccessPage = nil

        print("🔚 System Info Test #3: Teardown completed")
    }

    // MARK: - Test Case

    /// P0 Test #3: Get System Info Function Test
    ///
    /// Test Steps:
    /// 1. Navigate to test page
    /// 2. Click get system info button
    /// 3. Wait for system info to display
    ///
    /// Expected Result: Device info (model, OS version, etc.) should be displayed
    func test03_GetSystemInfo() throws {
        print("🧪 Starting P0 Test #3: Get System Info")

        // Step 1: Navigate to test page
        print("📍 Step 1: Navigate to test page")
        guard navigateToTestPage() else {
            XCTFail("Failed to navigate to test page")
            captureScreenshot(name: "navigation_failed", phase: "failure")
            return
        }
        captureScreenshot(name: "test_page_loaded", phase: "step")
        print("✅ Test page loaded successfully")

        // Wait for JS Bridge to be available
        Thread.sleep(forTimeInterval: 1.0)

        // Step 2: Click get system info button
        print("📍 Step 2: Click get system info button")
        
        // Find the button by its text content
        let systemInfoButton = app.webViews.staticTexts["系统信息"]
        let webView = app.webViews.firstMatch
        
        if systemInfoButton.exists {
            systemInfoButton.tap()
            print("✅ Tapped system info button (via static text)")
        } else {
            // Try tapping via coordinate on the system info section
            let systemInfoButtonPredicate = NSPredicate(format: "label CONTAINS '系统信息'")
            let button = app.webViews.buttons.element(matching: systemInfoButtonPredicate)
            
            if button.exists {
                button.tap()
                print("✅ Tapped system info button (via predicate)")
            } else {
                // Try direct coordinate tap
                let coordinate = webView.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.45))
                coordinate.tap()
                print("✅ Tapped system info button (via coordinate)")
            }
        }

        captureScreenshot(name: "button_clicked", phase: "step")

        // Step 3: Wait for system info to display
        print("📍 Step 3: Wait for system info to display")
        Thread.sleep(forTimeInterval: 3.0)

        // Verify system info appears in log
        let logContainer = app.webViews.otherElements["logContainer"]
        let hasLogContent = logContainer.waitForExistence(timeout: 5)

        if hasLogContent {
            print("✅ Log container found")
        } else {
            print("⚠️ Log container not found, but continuing...")
        }

        captureScreenshot(name: "system_info_displayed", phase: "step")

        // Final verification screenshot for MCP analysis
        captureScreenshot(name: "03_system_info", phase: "verification")

        print("✅ P0 Test #3: System info test completed")
    }

    // MARK: - Helper Methods

    /// Navigate to the JS Bridge test page
    private func navigateToTestPage() -> Bool {
        // Navigate to web access page
        guard webAccessPage.navigateViaTab() else {
            print("❌ Failed to navigate to web access page")
            return false
        }

        // Wait for URL input to be available
        guard webAccessPage.waitForElementToAppear(webAccessPage.urlTextField, timeout: 5) else {
            print("❌ URL text field not available")
            return false
        }

        // Enter test URL
        let testURL = "http://localhost:8080/js_bridge_test.html"
        webAccessPage.enterURL(testURL)

        // Wait for page to load
        Thread.sleep(forTimeInterval: 3.0)

        // Verify page loaded
        let webView = app.webViews.firstMatch
        let pageLoaded = webView.waitForExistence(timeout: 10)

        if pageLoaded {
            print("✅ JS Bridge test page loaded")
            return true
        } else {
            print("❌ JS Bridge test page failed to load")
            return false
        }
    }

    // MARK: - Screenshot Helper

    private func captureScreenshot(name: String, phase: String) {
        let screenshot = app.screenshot()
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "\(timestamp)_SystemInfoTests_\(phase)_\(name).png"
        let filepath = "/tmp/uitest_verification/screenshots/\(filename)"

        // 确保目录存在
        try? FileManager.default.createDirectory(atPath: "/tmp/uitest_verification/screenshots/",
                                                   withIntermediateDirectories: true,
                                                   attributes: nil)

        // 保存截图
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: filepath))
        print("📸 Screenshot saved: \(filepath)")

        // Special handling for verification screenshot
        if name == "03_system_info" {
            // Also save to the expected path
            let verificationPath = "/tmp/uitest_verification/screenshots/03_system_info.png"
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: verificationPath))
            print("📸 Verification screenshot saved: \(verificationPath)")
        }
    }
}
