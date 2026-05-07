//
//  SuperAppSmokeTests.swift
//  SuperAppUITests
//
//  Created on 2026-05-06.
//  Copyright © 2026年 WebBridgeKit. All rights reserved.
//

import XCTest

final class SuperAppSmokeTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--UITesting"]
        app.launch()
    }

    // MARK: - App Launch

    func testAppLaunchesSuccessfully() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should be visible after launch")
    }

    func testTabBarHasFourTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should exist")
        let tabs = tabBar.buttons
        XCTAssertEqual(tabs.count, 4, "Tab bar should have 4 tabs")
    }

    // MARK: - Tab Navigation

    func testHomeTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        let homeTab = tabBar.buttons["首页"]
        XCTAssertTrue(homeTab.exists, "Home tab should exist")
    }

    func testTestCasesTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        let testCasesTab = tabBar.buttons["用例"]
        XCTAssertTrue(testCasesTab.exists, "Test cases tab should exist")
    }

    func testManageTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        let manageTab = tabBar.buttons["管理"]
        XCTAssertTrue(manageTab.exists, "Manage tab should exist")
    }

    func testSettingsTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        let settingsTab = tabBar.buttons["设置"]
        XCTAssertTrue(settingsTab.exists, "Settings tab should exist")
    }

    // MARK: - Tab Navigation

    func testNavigateToManageTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        tabBar.buttons["管理"].tap()

        let segmentedControl = app.segmentedControls.firstMatch
        XCTAssertTrue(segmentedControl.waitForExistence(timeout: 5), "Segmented control should exist in manage tab")
    }

    func testNavigateToSettingsTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        tabBar.buttons["设置"].tap()

        let tableView = app.tables["settings.tableView"]
        XCTAssertTrue(tableView.waitForExistence(timeout: 5), "Settings table view should exist")
    }

    func testNavigateToTestCasesTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        tabBar.buttons["用例"].tap()

        let tableView = app.tables["ManifestTestCasesTableView"]
        XCTAssertTrue(tableView.waitForExistence(timeout: 5), "Test cases table view should exist")
    }

    // MARK: - Home Screen

    func testHomeScreenHasCollectionView() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        tabBar.buttons["首页"].tap()

        let collectionView = app.collectionViews["MainCollectionView"]
        let emptyState = app.otherElements["EmptyStateView"]
        let collectionViewExists = collectionView.waitForExistence(timeout: 5)
        let emptyStateExists = emptyState.waitForExistence(timeout: 2)
        XCTAssertTrue(collectionViewExists || emptyStateExists, "Home screen should have a collection view or empty state")
    }

    // MARK: - Settings Screen

    func testSettingsScreenHasContent() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        tabBar.buttons["设置"].tap()

        let staticTexts = app.staticTexts
        XCTAssertTrue(staticTexts.count > 0, "Settings screen should have content")
    }
}
