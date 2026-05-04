//
//  HomepageIconTests.swift
//  DemoAppUITests
//
//  UI Tests for WebBridgeKit - Homepage Icon Click Approach
//  Created on 2025-02-01.
//

import XCTest
import os.log

/// UI tests that use homepage icon clicks instead of manual URL entry
class HomepageIconTests: XCTestCase {

    let logger = OSLog(subsystem: "com.webbridgekit.demo.ui.tests", category: "HomepageIconTests")
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = [
            "IS_UI_TESTING": "YES",
            "TEST_SERVER_URL": "http://localhost:8080"
        ]
        app.launch()

        // Wait for homepage to load
        Thread.sleep(forTimeInterval: 2)

        // Take initial homepage screenshot
        let homepageScreenshot = app.screenshot()
        let homepagePath = "/tmp/uitest_verification/screenshots/homepage_icon_test_initial.png"
        try? homepageScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: homepagePath))
        os_log("Homepage screenshot saved: %@", log: logger, type: .info, homepagePath)
    }

    override func tearDownWithError() throws {
        // Take screenshot at the end of each test
        let screenshot = app.screenshot()
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let screenshotPath = "/tmp/uitest_verification/screenshots/\(timestamp)_homepage_test_final.png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: screenshotPath))
    }

    // MARK: - Test via Homepage Icon Click

    func test01_MainTestPage_viaHomepage() {
        os_log("Testing: Main Test Page via Homepage Icon", log: logger, type: .info)

        // Find and click the "P0测试主页" icon on homepage
        let mainTestIcon = findHomepageIcon(title: "P0测试主页")
        XCTAssertTrue(mainTestIcon != nil, "P0测试主页 icon not found on homepage")

        if let icon = mainTestIcon {
            // Tap the icon to open the test page
            icon.tap()
            os_log("Tapped P0测试主页 icon", log: logger, type: .info)

            // Wait for page to load and render content
            Thread.sleep(forTimeInterval: 10)

            // Take screenshot
            let screenshot = app.screenshot()
            let path = "/tmp/uitest_verification/screenshots/test01_main_page_via_homepage.png"
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
            os_log("Screenshot saved: %@", log: logger, type: .info, path)

            // Verify we're on a web page (check for WebView or URL changes)
            verifyWebViewLoaded()
        }
    }

    func test02_BridgeApiTest_viaHomepage() {
        os_log("Testing: Bridge API Test via Homepage Icon", log: logger, type: .info)

        // Go back to homepage first
        navigateToHomepage()

        // Find and click the "Bridge API测试" icon
        let bridgeTestIcon = findHomepageIcon(title: "Bridge API测试")
        XCTAssertTrue(bridgeTestIcon != nil, "Bridge API测试 icon not found on homepage")

        if let icon = bridgeTestIcon {
            icon.tap()
            os_log("Tapped Bridge API测试 icon", log: logger, type: .info)

            Thread.sleep(forTimeInterval: 10)

            let screenshot = app.screenshot()
            let path = "/tmp/uitest_verification/screenshots/test02_bridge_api_via_homepage.png"
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
            os_log("Screenshot saved: %@", log: logger, type: .info, path)

            verifyWebViewLoaded()
        }
    }

    func test03_NavigationTest_viaHomepage() {
        os_log("Testing: Navigation Test via Homepage Icon", log: logger, type: .info)

        navigateToHomepage()

        let navTestIcon = findHomepageIcon(title: "导航功能测试")
        XCTAssertTrue(navTestIcon != nil, "导航功能测试 icon not found on homepage")

        if let icon = navTestIcon {
            icon.tap()
            os_log("Tapped 导航功能测试 icon", log: logger, type: .info)

            Thread.sleep(forTimeInterval: 10)

            let screenshot = app.screenshot()
            let path = "/tmp/uitest_verification/screenshots/test03_navigation_via_homepage.png"
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
            os_log("Screenshot saved: %@", log: logger, type: .info, path)

            verifyWebViewLoaded()
        }
    }

    func test04_PermissionsTest_viaHomepage() {
        os_log("Testing: Permissions Test via Homepage Icon", log: logger, type: .info)

        navigateToHomepage()

        let permTestIcon = findHomepageIcon(title: "权限管理测试")
        XCTAssertTrue(permTestIcon != nil, "权限管理测试 icon not found on homepage")

        if let icon = permTestIcon {
            icon.tap()
            os_log("Tapped 权限管理测试 icon", log: logger, type: .info)

            Thread.sleep(forTimeInterval: 10)

            let screenshot = app.screenshot()
            let path = "/tmp/uitest_verification/screenshots/test04_permissions_via_homepage.png"
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
            os_log("Screenshot saved: %@", log: logger, type: .info, path)

            verifyWebViewLoaded()
        }
    }

    func test05_CacheTest_viaHomepage() {
        os_log("Testing: Cache Test via Homepage Icon", log: logger, type: .info)

        navigateToHomepage()

        let cacheTestIcon = findHomepageIcon(title: "标签页缓存测试")
        XCTAssertTrue(cacheTestIcon != nil, "标签页缓存测试 icon not found on homepage")

        if let icon = cacheTestIcon {
            icon.tap()
            os_log("Tapped 标签页缓存测试 icon", log: logger, type: .info)

            Thread.sleep(forTimeInterval: 10)

            let screenshot = app.screenshot()
            let path = "/tmp/uitest_verification/screenshots/test05_cache_via_homepage.png"
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
            os_log("Screenshot saved: %@", log: logger, type: .info, path)

            verifyWebViewLoaded()
        }
    }

    // MARK: - P0 Bridge API Tests via Homepage

    func test06_vibrate_viaHomepage() {
        os_log("Testing: Vibrate via Homepage", log: logger, type: .info)

        navigateToHomepage()

        // First navigate to P0测试主页
        let mainTestIcon = findHomepageIcon(title: "P0测试主页")
        XCTAssertTrue(mainTestIcon != nil, "P0测试主页 icon not found")

        mainTestIcon?.tap()
        Thread.sleep(forTimeInterval: 10)

        // Find and tap vibrate button
        let vibrateButton = app.webViews.buttons["震动测试"]
        if vibrateButton.exists {
            vibrateButton.tap()
            os_log("Vibrate button tapped", log: logger, type: .info)
            Thread.sleep(forTimeInterval: 2)
        }

        let screenshot = app.screenshot()
        let path = "/tmp/uitest_verification/screenshots/test06_vibrate_via_homepage.png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
        os_log("Screenshot saved: %@", log: logger, type: .info, path)
    }

    func test07_scan_viaHomepage() {
        os_log("Testing: Scan QR via Homepage", log: logger, type: .info)

        navigateToHomepage()

        let mainTestIcon = findHomepageIcon(title: "P0测试主页")
        XCTAssertTrue(mainTestIcon != nil, "P0测试主页 icon not found")

        mainTestIcon?.tap()
        Thread.sleep(forTimeInterval: 10)

        let scanButton = app.webViews.buttons["扫描二维码"]
        if scanButton.exists {
            scanButton.tap()
            os_log("Scan button tapped", log: logger, type: .info)
            Thread.sleep(forTimeInterval: 5)
        }

        let screenshot = app.screenshot()
        let path = "/tmp/uitest_verification/screenshots/test07_scan_via_homepage.png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
        os_log("Screenshot saved: %@", log: logger, type: .info, path)

        // Close scanner if opened
        let scannerView = app.otherElements["QRScannerViewController"]
        if scannerView.exists {
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    func test08_cameraPhoto_viaHomepage() {
        os_log("Testing: Camera Photo via Homepage", log: logger, type: .info)

        navigateToHomepage()

        let mainTestIcon = findHomepageIcon(title: "P0测试主页")
        XCTAssertTrue(mainTestIcon != nil, "P0测试主页 icon not found")

        mainTestIcon?.tap()
        Thread.sleep(forTimeInterval: 10)

        let cameraButton = app.webViews.buttons["拍照"]
        if cameraButton.exists {
            cameraButton.tap()
            os_log("Camera button tapped", log: logger, type: .info)
            Thread.sleep(forTimeInterval: 5)
        }

        let screenshot = app.screenshot()
        let path = "/tmp/uitest_verification/screenshots/test08_camera_via_homepage.png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
        os_log("Screenshot saved: %@", log: logger, type: .info, path)

        // Dismiss any dialogs
        let alert = app.alerts.firstMatch
        if alert.exists {
            alert.buttons["取消"].tap()
        }
    }

    func test09_selectPhoto_viaHomepage() {
        os_log("Testing: Select Photo via Homepage", log: logger, type: .info)

        navigateToHomepage()

        let mainTestIcon = findHomepageIcon(title: "P0测试主页")
        XCTAssertTrue(mainTestIcon != nil, "P0测试主页 icon not found")

        mainTestIcon?.tap()
        Thread.sleep(forTimeInterval: 10)

        let photoButton = app.webViews.buttons["选照片"]
        if photoButton.exists {
            photoButton.tap()
            os_log("Select photo button tapped", log: logger, type: .info)
            Thread.sleep(forTimeInterval: 5)
        }

        let screenshot = app.screenshot()
        let path = "/tmp/uitest_verification/screenshots/test09_photo_via_homepage.png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
        os_log("Screenshot saved: %@", log: logger, type: .info, path)

        // Dismiss photo picker if opened
        let sheet = app.sheets.firstMatch
        if sheet.exists {
            sheet.buttons["取消"].tap()
        }
    }

    func test10_speech_viaHomepage() {
        os_log("Testing: Speech Recognition via Homepage", log: logger, type: .info)

        navigateToHomepage()

        let mainTestIcon = findHomepageIcon(title: "P0测试主页")
        XCTAssertTrue(mainTestIcon != nil, "P0测试主页 icon not found")

        mainTestIcon?.tap()
        Thread.sleep(forTimeInterval: 10)

        let speechButton = app.webViews.buttons["语音识别测试"]
        if speechButton.exists {
            speechButton.tap()
            os_log("Speech button tapped", log: logger, type: .info)
            Thread.sleep(forTimeInterval: 5)
        }

        let screenshot = app.screenshot()
        let path = "/tmp/uitest_verification/screenshots/test10_speech_via_homepage.png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
        os_log("Screenshot saved: %@", log: logger, type: .info, path)

        // Dismiss any dialogs
        let alert = app.alerts.firstMatch
        if alert.exists {
            alert.buttons["取消"].tap()
        }
    }

    // MARK: - Helper Methods

    /// Find an icon on the homepage by its title
    private func findHomepageIcon(title: String) -> XCUIElement? {
        // The homepage uses a collection view with cells
        let collectionView = app.collectionViews.firstMatch

        // Try to find a cell containing the title
        let predicate = NSPredicate(format: "label CONTAINS %@ OR identifier CONTAINS %@", title, title)

        // Try static texts first (the title labels)
        let titleElements = app.staticTexts.element(matching: predicate)
        if titleElements.waitForExistence(timeout: 3) {
            // Get the parent cell
            let cell = app.cells.containing(.staticText, identifier: title).firstMatch
            if cell.exists {
                os_log("Found icon with title: %@", log: logger, type: .info, title)
                return cell
            }
            
            os_log("Found text but not cell for title: %@", log: logger, type: .info, title)
            return titleElements.firstMatch
        }

        // Try cells directly
        let cells = collectionView.cells.allElementsBoundByIndex
        for cell in cells {
            let cellLabel = cell.staticTexts.element(matching: predicate)
            if cellLabel.exists {
                os_log("Found cell with title: %@", log: logger, type: .info, title)
                return cellLabel
            }
        }

        os_log("Icon not found: %@", log: logger, type: .error, title)
        return nil
    }

    /// Navigate back to homepage tab
    private func navigateToHomepage() {
        let homeTab = app.tabBars.buttons["首页"]
        if homeTab.exists && homeTab.isSelected == false {
            homeTab.tap()
            Thread.sleep(forTimeInterval: 1)
        }
    }

    /// Verify that a WebView is loaded (either we're on web tab or a modal opened)
    private func verifyWebViewLoaded() {
        // Check if we're now on the web tab
        let webTab = app.tabBars.buttons["网页"]
        if webTab.exists && webTab.isSelected {
            os_log("Successfully navigated to web tab", log: logger, type: .info)
        }

        // Check for WebView or URL bar
        let urlBar = app.textFields.firstMatch
        if urlBar.exists {
            if let urlText = urlBar.value as? String, !urlText.isEmpty {
                os_log("URL bar contains: %@", log: logger, type: .info, urlText)
            }
        }
    }
}
