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
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN"
        ]
        app.launch()
    }

    private func findTabButton(in tabBar: XCUIElement, zhName: String, enName: String) -> XCUIElement {
        let zhButton = tabBar.buttons[zhName]
        if zhButton.waitForExistence(timeout: 2) {
            return zhButton
        }
        return tabBar.buttons[enName]
    }

    // MARK: - App Launch

    func testAppLaunchesSuccessfully() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar should be visible after launch")
    }

    func testTabBarHasFourTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar should exist")
        let tabs = tabBar.buttons
        XCTAssertEqual(tabs.count, 4, "Tab bar should have 4 tabs")
    }

    // MARK: - Tab Existence

    func testHomeTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let homeTab = findTabButton(in: tabBar, zhName: "首页", enName: "Home")
        XCTAssertTrue(homeTab.exists, "Home tab should exist")
    }

    func testInboxTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let inboxTab = findTabButton(in: tabBar, zhName: "收信箱", enName: "Inbox")
        XCTAssertTrue(inboxTab.exists, "Inbox tab should exist")
    }

    func testDiscoverTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let discoverTab = findTabButton(in: tabBar, zhName: "发现", enName: "Discover")
        XCTAssertTrue(discoverTab.exists, "Discover tab should exist")
    }

    func testSettingsTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let settingsTab = findTabButton(in: tabBar, zhName: "设置", enName: "Settings")
        XCTAssertTrue(settingsTab.exists, "Settings tab should exist")
    }

    // MARK: - Tab Navigation

    func testNavigateToDiscoverTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let discoverTab = findTabButton(in: tabBar, zhName: "发现", enName: "Discover")
        discoverTab.tap()

        let contentExists = app.staticTexts.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(contentExists, "Discover tab should show content")
    }

    func testNavigateToSettingsTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let settingsTab = findTabButton(in: tabBar, zhName: "设置", enName: "Settings")
        settingsTab.tap()

        let tableView = app.tables["settings.tableView"]
        let anyContent = app.staticTexts.firstMatch
        let tableViewExists = tableView.waitForExistence(timeout: 5)
        let contentExists = anyContent.waitForExistence(timeout: 2)
        XCTAssertTrue(tableViewExists || contentExists, "Settings screen should have content")
    }

    func testNavigateToInboxTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let inboxTab = findTabButton(in: tabBar, zhName: "收信箱", enName: "Inbox")
        inboxTab.tap()

        let contentExists = app.staticTexts.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(contentExists, "Inbox tab should show content")
    }

    // MARK: - Home Screen

    func testHomeScreenHasCollectionView() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let homeTab = findTabButton(in: tabBar, zhName: "首页", enName: "Home")
        homeTab.tap()

        let collectionView = app.collectionViews["MainCollectionView"]
        let emptyState = app.otherElements["EmptyStateView"]
        let collectionViewExists = collectionView.waitForExistence(timeout: 5)
        let emptyStateExists = emptyState.waitForExistence(timeout: 2)
        XCTAssertTrue(collectionViewExists || emptyStateExists, "Home screen should have a collection view or empty state")
    }

    // MARK: - Settings Screen

    func testSettingsScreenHasContent() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let settingsTab = findTabButton(in: tabBar, zhName: "设置", enName: "Settings")
        settingsTab.tap()

        let staticTexts = app.staticTexts
        XCTAssertTrue(staticTexts.count > 0, "Settings screen should have content")
    }
}
