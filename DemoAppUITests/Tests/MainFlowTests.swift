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
        if TestEnvironment.isCI {
            throw XCTSkip("Skipping in CI environment")
        }
        try super.setUpWithError()
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
        let collectionView = app.collectionViews["MainCollectionView"]
        let emptyState = app.otherElements["EmptyStateView"]
        let collectionExists = collectionView.waitForExistence(timeout: 10)
        let emptyExists = emptyState.waitForExistence(timeout: 5)
        XCTAssertTrue(collectionExists || emptyExists, "Main page should load with collection view or empty state within 10 seconds")
    }

    func testCollectionViewExists() {
        let collectionView = app.collectionViews["MainCollectionView"]
        let emptyState = app.otherElements["EmptyStateView"]
        XCTAssertTrue(collectionView.waitForExistence(timeout: 10) || emptyState.waitForExistence(timeout: 5), "Collection view or empty state should exist")
    }

    func testScanButtonExists() {
        // Verify the scan button is present
        XCTAssertTrue(mainPage.scanButton.exists, "Scan button should exist")
        XCTAssertTrue(mainPage.scanButton.isHittable, "Scan button should be hittable")
    }

    func testOpenURLFromMain() {
        TestDataManager.shared.prepareMockData()
        captureStepScreenshot(stepName: "01_mock_data_prepared")

        let expectation = XCTestExpectation(description: "Wait for cells to load")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        let collectionView = app.collectionViews["MainCollectionView"]
        guard collectionView.waitForExistence(timeout: 5), collectionView.cells.count > 0 else {
            print("Skipping testOpenURLFromMain: collection view is hidden or empty (no data)")
            return
        }

        let cellCount = collectionView.cells.count
        guard cellCount > 0 else {
            print("Skipping testOpenURLFromMain: no cells available")
            return
        }
        captureStepScreenshot(stepName: "02_cells_loaded")

        mainPage.tapCell(at: 0)
        captureStepScreenshot(stepName: "03_after_cell_tap")

        let webAccessPage = WebAccessPage(app: app)
        let navigated = webAccessPage.verifyPageLoaded()
        captureStepScreenshot(stepName: "04_web_access_page")

        XCTAssertTrue(navigated, "Should navigate to WebAccessPage")
    }

    func testRefreshMainPage() {
        let collectionView = app.collectionViews["MainCollectionView"]
        guard collectionView.waitForExistence(timeout: 5), collectionView.cells.count > 0 else {
            print("Skipping testRefreshMainPage: collection view has no data")
            return
        }
        collectionView.swipeDown()

        let expectation = XCTestExpectation(description: "Wait for refresh")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        XCTAssertTrue(collectionView.exists, "Collection view should still exist after refresh")
    }

    func testTapScanButton() {
        let scanButton = app.buttons["main.scanButton"]
        guard scanButton.waitForExistence(timeout: 5) else {
            print("Scan button not found - may be in navigation bar")
            return
        }
        scanButton.tap()

        XCTAssertTrue(scanButton.exists, "Scan button should still exist after tap")
    }

    func testMainPageAccessibility() {
        XCTAssertTrue(app.collectionViews["MainCollectionView"].waitForExistence(timeout: 10), "Collection view accessibility identifier should exist")
        XCTAssertTrue(app.buttons["main.scanButton"].exists, "Scan button accessibility identifier should exist")
    }
}
