//
//  MainFlowTests.swift
//  DemoAppUITests
//
//  Created on 2025-01-30.
//  Copyright © 2025年 WebBridgeKit. All rights reserved.
//

import XCTest
@testable import WebBridgeKit

/// Test suite for the main application flow - launching the app, viewing the main page, and navigating to web pages
/// Enhanced with automatic screenshot support
final class MainFlowTests: XCTestCase {

    var app: XCUIApplication!
    var mainPage: MainPage!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = AppLauncher.shared.launchApp()
        mainPage = MainPage(app: app)

        // 自动截图: setup
        captureScreenshot(name: "setup", phase: "setup")
    }

    override func tearDownWithError() throws {
        // 自动截图: teardown
        captureScreenshot(name: "teardown", phase: "teardown")

        AppLauncher.shared.terminateApp(app)
        app = nil
        mainPage = nil
    }

    // MARK: - Screenshot Helper

    private func captureScreenshot(name: String, phase: String) {
        let screenshot = app.screenshot()
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "\(timestamp)_MainFlowTests_\(phase)_\(name).png"
        let filepath = "/tmp/uitest_screenshots/\(filename)"

        // 确保目录存在
        try? FileManager.default.createDirectory(atPath: "/tmp/uitest_screenshots/",
                                                   withIntermediateDirectories: true,
                                                   attributes: nil)

        // 保存截图
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: filepath))
        print("📸 Screenshot: \(filepath)")
    }

    private func captureStepScreenshot(stepName: String) {
        captureScreenshot(name: stepName, phase: "step")
    }

    // MARK: - Test Cases

    func testMainPageLoads() {
        // Verify the main page loads successfully
        XCTAssertTrue(mainPage.verifyPageLoaded(), "Main page should load within 10 seconds")
    }

    func testCollectionViewExists() {
        // Verify the collection view is displayed
        XCTAssertTrue(mainPage.collectionView.exists, "Collection view should exist")
        XCTAssertTrue(mainPage.collectionView.isHittable, "Collection view should be hittable")
    }

    func testScanButtonExists() {
        // Verify the scan button is present
        XCTAssertTrue(mainPage.scanButton.exists, "Scan button should exist")
        XCTAssertTrue(mainPage.scanButton.isHittable, "Scan button should be hittable")
    }

    func testOpenURLFromMain() {
        // Prepare mock data
        TestDataManager.shared.prepareMockData()
        captureStepScreenshot(stepName: "01_mock_data_prepared")

        // Wait for data to load
        let expectation = XCTestExpectation(description: "Wait for cells to load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Verify page has content
        let cellCount = mainPage.getCellCount()
        XCTAssertGreaterThan(cellCount, 0, "Should have at least one cell")
        captureStepScreenshot(stepName: "02_cells_loaded")

        // Tap first cell
        mainPage.tapCell(at: 0)
        captureStepScreenshot(stepName: "03_after_cell_tap")

        // Verify navigation to web access page
        let webAccessPage = WebAccessPage(app: app)
        let navigated = webAccessPage.verifyPageLoaded()
        captureStepScreenshot(stepName: "04_web_access_page")

        XCTAssertTrue(navigated, "Should navigate to WebAccessPage")
    }

    func testRefreshMainPage() {
        // Test pull-to-refresh functionality
        mainPage.refreshPage()

        // Wait for refresh to complete
        let expectation = XCTestExpectation(description: "Wait for refresh")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Verify collection view still exists after refresh
        XCTAssertTrue(mainPage.collectionView.exists, "Collection view should still exist after refresh")
    }

    func testTapScanButton() {
        // Test scan button interaction
        mainPage.tapScanButton()

        // Verify scanner UI appears (this will depend on actual implementation)
        // For now, just verify the button is tappable
        XCTAssertTrue(mainPage.scanButton.exists, "Scan button should still exist after tap")
    }

    func testMainPageAccessibility() {
        // Verify all accessibility identifiers are present
        XCTAssertTrue(app.otherElements["main.collectionView"].exists, "Collection view accessibility identifier should exist")
        XCTAssertTrue(app.buttons["main.scanButton"].exists, "Scan button accessibility identifier should exist")
    }
}
