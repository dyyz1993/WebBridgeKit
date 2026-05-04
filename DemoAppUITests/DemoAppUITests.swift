//
//  DemoAppUITests.swift
//  DemoAppUITests
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest
import os.log

/// UI tests for WebBridgeKit Bridge API - P0 Tests Part 1 & 2 (Tests 1-10)
final class DemoAppUITests: XCTestCase {

    let logger = OSLog(subsystem: "com.webbridgekit.demo.ui.tests", category: "BridgeApiTests_P0")
    var app: XCUIApplication!
    var webAccessPage: WebAccessPage!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Create screenshots directory
        let fileManager = FileManager.default
        let screenshotsDir = "/tmp/uitest_verification/screenshots"
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
    }

    override func tearDownWithError() throws {
        // Take screenshot at the end of each test for verification
        let screenshot = app.screenshot()
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let screenshotPath = "/tmp/uitest_verification/screenshots/\(timestamp)_final.png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: screenshotPath))
    }

    // MARK: - App Launch Verification

    func test00_AppLaunchVerification() throws {
        os_log("Verifying app launch and WebAccess Tab as default", log: logger, type: .info)

        // Wait for app to fully launch
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 10) else {
            os_log("Tab bar not found - app may not have launched properly", log: logger, type: .error)

            // Take failure screenshot
            let failureScreenshot = app.screenshot()
            let failurePath = "/tmp/uitest_verification/screenshots/test00_app_launch_failure.png"
            try? failureScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: failurePath))

            XCTFail("App launch verification failed - tab bar not found")
            return
        }

        os_log("Tab bar found successfully", log: logger, type: .info)

        // Verify WebAccess tab is selected (should be default in DEBUG mode)
        let webAccessTab = app.tabBars.buttons["网页"]
        if webAccessTab.exists {
            let isSelected = webAccessTab.value as? String == "1"
            os_log("WebAccess tab found, selected: %@", log: logger, type: .info, String(isSelected))

            // Take success screenshot
            let screenshot = app.screenshot()
            let path = "/tmp/uitest_verification/screenshots/test00_app_launch_success.png"
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
            os_log("App launch screenshot saved to: %@", log: logger, type: .info, path)

            // Verify we can see the URL input field
            let urlInputView = app.otherElements["webAccess.urlInputView"]
            if urlInputView.waitForExistence(timeout: 5) {
                os_log("URL input view found - app launched successfully with WebAccess Tab", log: logger, type: .info)
            } else {
                os_log("URL input view not found - may need to tap WebAccess tab", log: logger, type: .default)

                // Tap the tab if needed
                webAccessTab.tap()
                Thread.sleep(forTimeInterval: 1.0)

                if urlInputView.waitForExistence(timeout: 5) {
                    os_log("URL input view found after tapping WebAccess tab", log: logger, type: .info)

                    // Take screenshot after tap
                    let tappedScreenshot = app.screenshot()
                    let tappedPath = "/tmp/uitest_verification/screenshots/test00_after_tab_tap.png"
                    try? tappedScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: tappedPath))
                }
            }
        } else {
            os_log("WebAccess tab not found", log: logger, type: .error)

            // Log all available tabs
            let allTabs = tabBar.buttons.allElementsBoundByIndex.map { $0.label }
            os_log("Available tabs: %@", log: logger, type: .error, allTabs.description)

            XCTFail("WebAccess tab not found")
        }
    }

    // MARK: - Test #1: Share

    func test01_share() throws {
        os_log("Testing #1: share (分享)", log: logger, type: .info)

        guard webAccessPage.navigateViaTab() else {
            os_log("Failed to navigate to WebAccess page", log: logger, type: .error)
            throw TestError.navigationFailed
        }

        webAccessPage.enterURL("http://localhost:8080/js_bridge_test.html")

        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            os_log("Test page failed to load", log: logger, type: .error)
            throw TestError.pageLoadFailed
        }

        os_log("Page loaded successfully, waiting for content to render", log: logger, type: .info)
        Thread.sleep(forTimeInterval: 3.0)

        // Take initial screenshot
        let initialScreenshot = app.screenshot()
        let initialPath = "/tmp/uitest_verification/screenshots/test01_share_initial.png"
        try? initialScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: initialPath))
        os_log("Initial screenshot saved to: %@", log: logger, type: .info, initialPath)

        // Look for share button and tap it
        let shareButton = app.webViews.buttons["分享测试"]
        if shareButton.exists {
            shareButton.tap()
            os_log("Share button tapped", log: logger, type: .info)
        } else {
            let predicate = NSPredicate(format: "label CONTAINS '分享' OR label CONTAINS 'share'")
            let altButton = app.webViews.buttons.element(matching: predicate)
            if altButton.exists {
                altButton.tap()
                os_log("Alternative share button tapped", log: logger, type: .info)
            } else {
                os_log("Share button not found", log: logger, type: .error)
                throw TestError.elementNotFound
            }
        }

        Thread.sleep(forTimeInterval: 2.0)

        // Verify share sheet appeared
        let shareSheet = app.sheets.firstMatch
        if shareSheet.waitForExistence(timeout: 3) {
            os_log("Share sheet appeared successfully", log: logger, type: .info)
        } else {
            os_log("Share sheet did not appear", log: logger, type: .default)
        }

        // Take result screenshot
        let resultScreenshot = app.screenshot()
        let resultPath = "/tmp/uitest_verification/screenshots/test01_share_result.png"
        try? resultScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: resultPath))
        os_log("Result screenshot saved to: %@", log: logger, type: .info, resultPath)

        // Dismiss share sheet if present
        if shareSheet.exists {
            // Tap outside or cancel button
            if app.buttons["取消"].exists {
                app.buttons["取消"].tap()
            } else {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
            }
        }
    }

    // MARK: - Test #2: Get Location

    func test02_getLocation() throws {
        os_log("Testing #2: getLocation (获取位置)", log: logger, type: .info)

        guard webAccessPage.navigateViaTab() else {
            throw TestError.navigationFailed
        }

        webAccessPage.enterURL("http://localhost:8080/js_bridge_test.html")

        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            throw TestError.pageLoadFailed
        }

        Thread.sleep(forTimeInterval: 3.0)

        // Take initial screenshot
        let initialScreenshot = app.screenshot()
        let initialPath = "/tmp/uitest_verification/screenshots/test02_location_initial.png"
        try? initialScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: initialPath))
        os_log("Initial screenshot saved to: %@", log: logger, type: .info, initialPath)

        // Look for location button and tap it
        let locationButton = app.webViews.buttons["位置测试"]
        if locationButton.exists {
            locationButton.tap()
            os_log("Location button tapped", log: logger, type: .info)
        } else {
            let predicate = NSPredicate(format: "label CONTAINS '位置' OR label CONTAINS 'location' OR label CONTAINS 'getLocation'")
            let altButton = app.webViews.buttons.element(matching: predicate)
            if altButton.exists {
                altButton.tap()
                os_log("Alternative location button tapped", log: logger, type: .info)
            } else {
                os_log("Location button not found", log: logger, type: .error)
                throw TestError.elementNotFound
            }
        }

        Thread.sleep(forTimeInterval: 2.0)

        // Check for location permission dialog
        let permissionDialog = app.alerts.firstMatch
        if permissionDialog.waitForExistence(timeout: 3) {
            os_log("Location permission dialog appeared", log: logger, type: .info)

            // Allow location access
            if permissionDialog.buttons["允许一次"].exists {
                permissionDialog.buttons["允许一次"].tap()
                os_log("Allowed location access once", log: logger, type: .info)
            } else if permissionDialog.buttons["允许"].exists {
                permissionDialog.buttons["允许"].tap()
                os_log("Allowed location access", log: logger, type: .info)
            }
        }

        Thread.sleep(forTimeInterval: 2.0)

        // Take result screenshot
        let resultScreenshot = app.screenshot()
        let resultPath = "/tmp/uitest_verification/screenshots/test02_location_result.png"
        try? resultScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: resultPath))
        os_log("Result screenshot saved to: %@", log: logger, type: .info, resultPath)
    }

    // MARK: - Test #3: Get System Info

    func test03_getSystemInfo() throws {
        os_log("Testing #3: getSystemInfo (获取系统信息)", log: logger, type: .info)

        guard webAccessPage.navigateViaTab() else {
            throw TestError.navigationFailed
        }

        webAccessPage.enterURL("http://localhost:8080/js_bridge_test.html")

        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            throw TestError.pageLoadFailed
        }

        Thread.sleep(forTimeInterval: 3.0)

        // Take initial screenshot
        let initialScreenshot = app.screenshot()
        let initialPath = "/tmp/uitest_verification/screenshots/test03_systeminfo_initial.png"
        try? initialScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: initialPath))
        os_log("Initial screenshot saved to: %@", log: logger, type: .info, initialPath)

        // Look for system info button and tap it
        let systemInfoButton = app.webViews.buttons["系统信息测试"]
        if systemInfoButton.exists {
            systemInfoButton.tap()
            os_log("System info button tapped", log: logger, type: .info)
        } else {
            let predicate = NSPredicate(format: "label CONTAINS '系统信息' OR label CONTAINS 'system' OR label CONTAINS 'getSystemInfo'")
            let altButton = app.webViews.buttons.element(matching: predicate)
            if altButton.exists {
                altButton.tap()
                os_log("Alternative system info button tapped", log: logger, type: .info)
            } else {
                os_log("System info button not found", log: logger, type: .error)
                throw TestError.elementNotFound
            }
        }

        Thread.sleep(forTimeInterval: 2.0)

        // Take result screenshot
        let resultScreenshot = app.screenshot()
        let resultPath = "/tmp/uitest_verification/screenshots/test03_systeminfo_result.png"
        try? resultScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: resultPath))
        os_log("Result screenshot saved to: %@", log: logger, type: .info, resultPath)
    }

    // MARK: - Test #4: Get Network Info

    func test04_getNetworkInfo() throws {
        os_log("Testing #4: getNetworkInfo (获取网络信息)", log: logger, type: .info)

        guard webAccessPage.navigateViaTab() else {
            throw TestError.navigationFailed
        }

        webAccessPage.enterURL("http://localhost:8080/js_bridge_test.html")

        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            throw TestError.pageLoadFailed
        }

        Thread.sleep(forTimeInterval: 3.0)

        // Take initial screenshot
        let initialScreenshot = app.screenshot()
        let initialPath = "/tmp/uitest_verification/screenshots/test04_networkinfo_initial.png"
        try? initialScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: initialPath))
        os_log("Initial screenshot saved to: %@", log: logger, type: .info, initialPath)

        // Look for network info button and tap it
        let networkInfoButton = app.webViews.buttons["网络信息测试"]
        if networkInfoButton.exists {
            networkInfoButton.tap()
            os_log("Network info button tapped", log: logger, type: .info)
        } else {
            let predicate = NSPredicate(format: "label CONTAINS '网络信息' OR label CONTAINS 'network' OR label CONTAINS 'getNetworkInfo'")
            let altButton = app.webViews.buttons.element(matching: predicate)
            if altButton.exists {
                altButton.tap()
                os_log("Alternative network info button tapped", log: logger, type: .info)
            } else {
                os_log("Network info button not found", log: logger, type: .error)
                throw TestError.elementNotFound
            }
        }

        Thread.sleep(forTimeInterval: 2.0)

        // Take result screenshot
        let resultScreenshot = app.screenshot()
        let resultPath = "/tmp/uitest_verification/screenshots/test04_networkinfo_result.png"
        try? resultScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: resultPath))
        os_log("Result screenshot saved to: %@", log: logger, type: .info, resultPath)
    }

    // MARK: - Test #5: Haptic

    func test05_haptic() throws {
        os_log("Testing #5: haptic (触觉反馈)", log: logger, type: .info)

        guard webAccessPage.navigateViaTab() else {
            throw TestError.navigationFailed
        }

        webAccessPage.enterURL("http://localhost:8080/js_bridge_test.html")

        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            throw TestError.pageLoadFailed
        }

        Thread.sleep(forTimeInterval: 3.0)

        // Take initial screenshot
        let initialScreenshot = app.screenshot()
        let initialPath = "/tmp/uitest_verification/screenshots/test05_haptic_initial.png"
        try? initialScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: initialPath))
        os_log("Initial screenshot saved to: %@", log: logger, type: .info, initialPath)

        // Look for haptic button and tap it
        let hapticButton = app.webViews.buttons["触觉反馈测试"]
        if hapticButton.exists {
            hapticButton.tap()
            os_log("Haptic button tapped", log: logger, type: .info)
        } else {
            let predicate = NSPredicate(format: "label CONTAINS '触觉' OR label CONTAINS 'haptic'")
            let altButton = app.webViews.buttons.element(matching: predicate)
            if altButton.exists {
                altButton.tap()
                os_log("Alternative haptic button tapped", log: logger, type: .info)
            } else {
                os_log("Haptic button not found", log: logger, type: .error)
                throw TestError.elementNotFound
            }
        }

        Thread.sleep(forTimeInterval: 1.0)

        // Take result screenshot
        let resultScreenshot = app.screenshot()
        let resultPath = "/tmp/uitest_verification/screenshots/test05_haptic_result.png"
        try? resultScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: resultPath))
        os_log("Result screenshot saved to: %@", log: logger, type: .info, resultPath)
    }

    // MARK: - Test #6: Vibrate

    func test06_vibrate() throws {
        os_log("Testing #6: vibrate (震动)", log: logger, type: .info)

        guard webAccessPage.navigateViaTab() else {
            os_log("Failed to navigate to WebAccess page", log: logger, type: .error)
            throw TestError.navigationFailed
        }

        webAccessPage.enterURL("http://localhost:8080/main_test.html")

        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            os_log("Test page failed to load", log: logger, type: .error)
            throw TestError.pageLoadFailed
        }

        Thread.sleep(forTimeInterval: 2.0)

        let initialScreenshot = app.screenshot()
        let initialPath = "/tmp/uitest_verification/screenshots/test06_vibrate_initial.png"
        try? initialScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: initialPath))
        os_log("Initial screenshot saved to: %@", log: logger, type: .info, initialPath)

        let vibrateButton = app.webViews.buttons["震动测试"]
        if vibrateButton.exists {
            vibrateButton.tap()
            os_log("Vibrate button tapped", log: logger, type: .info)
            Thread.sleep(forTimeInterval: 1.0)
        } else {
            let predicate = NSPredicate(format: "label CONTAINS '震动' OR label CONTAINS 'vibrate'")
            let altButton = app.webViews.buttons.element(matching: predicate)
            if altButton.exists {
                altButton.tap()
                os_log("Alternative vibrate button tapped", log: logger, type: .info)
                Thread.sleep(forTimeInterval: 1.0)
            } else {
                os_log("Vibrate button not found", log: logger, type: .error)
                throw TestError.elementNotFound
            }
        }

        let resultScreenshot = app.screenshot()
        let resultPath = "/tmp/uitest_verification/screenshots/test06_vibrate_result.png"
        try? resultScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: resultPath))
        os_log("Result screenshot saved to: %@", log: logger, type: .info, resultPath)
    }

    // MARK: - Test #7: Scan (QR Code)

    func test07_scan() throws {
        os_log("Testing #7: scan (扫码)", log: logger, type: .info)

        guard webAccessPage.navigateViaTab() else {
            throw TestError.navigationFailed
        }

        webAccessPage.enterURL("http://localhost:8080/main_test.html")

        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            throw TestError.pageLoadFailed
        }

        Thread.sleep(forTimeInterval: 2.0)

        let initialScreenshot = app.screenshot()
        let initialPath = "/tmp/uitest_verification/screenshots/test07_scan_initial.png"
        try? initialScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: initialPath))
        os_log("Initial screenshot saved to: %@", log: logger, type: .info, initialPath)

        let scanButton = app.webViews.buttons["扫码测试"]
        if scanButton.exists {
            scanButton.tap()
            os_log("Scan button tapped", log: logger, type: .info)
        } else {
            let predicate = NSPredicate(format: "label CONTAINS '扫码' OR label CONTAINS 'scan'")
            let altButton = app.webViews.buttons.element(matching: predicate)
            if altButton.exists {
                altButton.tap()
                os_log("Alternative scan button tapped", log: logger, type: .info)
            } else {
                os_log("Scan button not found", log: logger, type: .error)
                throw TestError.elementNotFound
            }
        }

        Thread.sleep(forTimeInterval: 2.0)

        let scannerView = app.otherElements["QRScannerViewController"]
        if scannerView.waitForExistence(timeout: 5) {
            os_log("QR Scanner view appeared successfully", log: logger, type: .info)
        } else {
            os_log("QR Scanner view did not appear", log: logger, type: .error)
        }

        let resultScreenshot = app.screenshot()
        let resultPath = "/tmp/uitest_verification/screenshots/test07_scan_result.png"
        try? resultScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: resultPath))
        os_log("Result screenshot saved to: %@", log: logger, type: .info, resultPath)

        if scannerView.exists {
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    // MARK: - Test #8: Camera (Photo)

    func test08_cameraPhoto() throws {
        os_log("Testing #8: camera (photo)", log: logger, type: .info)

        guard webAccessPage.navigateViaTab() else {
            throw TestError.navigationFailed
        }

        webAccessPage.enterURL("http://localhost:8080/main_test.html")

        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            throw TestError.pageLoadFailed
        }

        Thread.sleep(forTimeInterval: 2.0)

        let initialScreenshot = app.screenshot()
        let initialPath = "/tmp/uitest_verification/screenshots/test08_camera_initial.png"
        try? initialScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: initialPath))
        os_log("Initial screenshot saved to: %@", log: logger, type: .info, initialPath)

        let cameraButton = app.webViews.buttons["拍照测试"]
        if cameraButton.exists {
            cameraButton.tap()
            os_log("Camera button tapped", log: logger, type: .info)
        } else {
            let predicate = NSPredicate(format: "label CONTAINS '拍照' OR label CONTAINS 'camera'")
            let altButton = app.webViews.buttons.element(matching: predicate)
            if altButton.exists {
                altButton.tap()
                os_log("Alternative camera button tapped", log: logger, type: .info)
            } else {
                os_log("Camera button not found", log: logger, type: .error)
                throw TestError.elementNotFound
            }
        }

        Thread.sleep(forTimeInterval: 2.0)

        let permissionDialog = app.alerts.firstMatch
        if permissionDialog.waitForExistence(timeout: 3) {
            os_log("Camera permission dialog appeared", log: logger, type: .info)
        }

        let resultScreenshot = app.screenshot()
        let resultPath = "/tmp/uitest_verification/screenshots/test08_camera_result.png"
        try? resultScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: resultPath))
        os_log("Result screenshot saved to: %@", log: logger, type: .info, resultPath)

        if permissionDialog.exists {
            permissionDialog.buttons["取消"].tap()
        }
    }

    // MARK: - Test #9: Photo (Select Photo)

    func test09_selectPhoto() throws {
        os_log("Testing #9: photo (select photo)", log: logger, type: .info)

        guard webAccessPage.navigateViaTab() else {
            throw TestError.navigationFailed
        }

        webAccessPage.enterURL("http://localhost:8080/main_test.html")

        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            throw TestError.pageLoadFailed
        }

        Thread.sleep(forTimeInterval: 2.0)

        let initialScreenshot = app.screenshot()
        let initialPath = "/tmp/uitest_verification/screenshots/test09_photo_initial.png"
        try? initialScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: initialPath))
        os_log("Initial screenshot saved to: %@", log: logger, type: .info, initialPath)

        let photoButton = app.webViews.buttons["选照片测试"]
        if photoButton.exists {
            photoButton.tap()
            os_log("Select photo button tapped", log: logger, type: .info)
        } else {
            let predicate = NSPredicate(format: "label CONTAINS '选照片' OR label CONTAINS 'photo' OR label CONTAINS '选图'")
            let altButton = app.webViews.buttons.element(matching: predicate)
            if altButton.exists {
                altButton.tap()
                os_log("Alternative select photo button tapped", log: logger, type: .info)
            } else {
                os_log("Select photo button not found", log: logger, type: .error)
                throw TestError.elementNotFound
            }
        }

        Thread.sleep(forTimeInterval: 2.0)

        let photoPicker = app.sheets.firstMatch
        if photoPicker.waitForExistence(timeout: 3) {
            os_log("Photo picker appeared", log: logger, type: .info)
        }

        let resultScreenshot = app.screenshot()
        let resultPath = "/tmp/uitest_verification/screenshots/test09_photo_result.png"
        try? resultScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: resultPath))
        os_log("Result screenshot saved to: %@", log: logger, type: .info, resultPath)

        if photoPicker.exists {
            photoPicker.buttons["取消"].tap()
        }
    }

    // MARK: - Test #10: Speech (Speech Recognition)

    func test10_speech() throws {
        os_log("Testing #10: speech (speech recognition)", log: logger, type: .info)

        guard webAccessPage.navigateViaTab() else {
            throw TestError.navigationFailed
        }

        webAccessPage.enterURL("http://localhost:8080/main_test.html")

        guard webAccessPage.waitForPageToLoad(timeout: 15) else {
            throw TestError.pageLoadFailed
        }

        Thread.sleep(forTimeInterval: 2.0)

        let initialScreenshot = app.screenshot()
        let initialPath = "/tmp/uitest_verification/screenshots/test10_speech_initial.png"
        try? initialScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: initialPath))
        os_log("Initial screenshot saved to: %@", log: logger, type: .info, initialPath)

        let speechButton = app.webViews.buttons["语音识别测试"]
        if speechButton.exists {
            speechButton.tap()
            os_log("Speech recognition button tapped", log: logger, type: .info)
        } else {
            let predicate = NSPredicate(format: "label CONTAINS '语音' OR label CONTAINS 'speech' OR label CONTAINS '识别'")
            let altButton = app.webViews.buttons.element(matching: predicate)
            if altButton.exists {
                altButton.tap()
                os_log("Alternative speech button tapped", log: logger, type: .info)
            } else {
                os_log("Speech recognition button not found", log: logger, type: .error)
                throw TestError.elementNotFound
            }
        }

        Thread.sleep(forTimeInterval: 2.0)

        let permissionDialog = app.alerts.firstMatch
        if permissionDialog.waitForExistence(timeout: 3) {
            os_log("Microphone permission dialog appeared", log: logger, type: .info)
        }

        let resultScreenshot = app.screenshot()
        let resultPath = "/tmp/uitest_verification/screenshots/test10_speech_result.png"
        try? resultScreenshot.pngRepresentation.write(to: URL(fileURLWithPath: resultPath))
        os_log("Result screenshot saved to: %@", log: logger, type: .info, resultPath)

        if permissionDialog.exists {
            permissionDialog.buttons["取消"].tap()
        }
    }
}

// MARK: - Test Error

enum TestError: Error {
    case navigationFailed
    case pageLoadFailed
    case elementNotFound
}
