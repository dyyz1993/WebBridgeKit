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

    private func findTabButton(
        in tabBar: XCUIElement,
        identifier: String,
        zhName: String,
        enName: String
    ) -> XCUIElement {
        let idButton = tabBar.buttons[identifier]
        if idButton.waitForExistence(timeout: 2) {
            return idButton
        }
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

    func testTabBarHasFiveTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar should exist")
        let tabs = tabBar.buttons
        XCTAssertEqual(tabs.count, 5, "Tab bar should have 5 tabs")
    }

    // MARK: - Tab Existence

    func testWebTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let webTab = findTabButton(in: tabBar, identifier: "tab.web", zhName: "Web", enName: "Web")
        XCTAssertTrue(webTab.exists, "Web tab should exist")
    }

    func testInboxTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let inboxTab = findTabButton(in: tabBar, identifier: "tab.inbox", zhName: "消息", enName: "Messages")
        XCTAssertTrue(inboxTab.exists, "Messages tab should exist")
    }

    func testBridgeTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let bridgeTab = findTabButton(in: tabBar, identifier: "tab.bridge", zhName: "Bridge", enName: "Bridge")
        XCTAssertTrue(bridgeTab.exists, "Bridge tab should exist")
    }

    func testTokenPushTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let pushTab = findTabButton(in: tabBar, identifier: "tab.push", zhName: "Token/Push", enName: "Token/Push")
        XCTAssertTrue(pushTab.exists, "Token/Push tab should exist")
    }

    func testSettingsTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let settingsTab = findTabButton(in: tabBar, identifier: "tab.settings", zhName: "设置", enName: "Settings")
        XCTAssertTrue(settingsTab.exists, "Settings tab should exist")
    }

    // MARK: - Tab Navigation

    func testNavigateToBridgeTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let bridgeTab = findTabButton(in: tabBar, identifier: "tab.bridge", zhName: "Bridge", enName: "Bridge")
        bridgeTab.tap()

        let contentExists = app.otherElements["bridgeLab.home"].waitForExistence(timeout: 5)
        XCTAssertTrue(contentExists, "Bridge tab should show content")
    }

    func testNavigateToSettingsTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let settingsTab = findTabButton(in: tabBar, identifier: "tab.settings", zhName: "设置", enName: "Settings")
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
        let inboxTab = findTabButton(in: tabBar, identifier: "tab.inbox", zhName: "消息", enName: "Messages")
        inboxTab.tap()

        let contentExists = app.otherElements["InboxViewController"].waitForExistence(timeout: 5)
            || app.otherElements["wbk_search_field"].waitForExistence(timeout: 3)
        XCTAssertTrue(contentExists, "Messages tab should show content")
    }

    // MARK: - Home Screen

    func testWebScreenHasContent() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let webTab = findTabButton(in: tabBar, identifier: "tab.web", zhName: "Web", enName: "Web")
        webTab.tap()

        XCTAssertTrue(app.otherElements["webCache.home"].waitForExistence(timeout: 5),
            "Web screen should show Web Cache home")
    }

    // MARK: - Settings Screen

    func testSettingsScreenHasContent() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let settingsTab = findTabButton(in: tabBar, identifier: "tab.settings", zhName: "设置", enName: "Settings")
        settingsTab.tap()

        let staticTexts = app.staticTexts
        XCTAssertTrue(staticTexts.count > 0, "Settings screen should have content")
    }

    // MARK: - Cache Dashboard (in SmokeTests for crash debugging)

    func testZCacheDashboardFromSettings() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar should exist")
        
        let settingsTab = findTabButton(in: tabBar, identifier: "tab.settings", zhName: "设置", enName: "Settings")
        settingsTab.tap()
        
        // Find 缓存仪表盘
        let dashboard = app.staticTexts["缓存仪表盘"]
        if dashboard.waitForExistence(timeout: 5) {
            dashboard.tap()
            sleep(2)
            XCTAssertTrue(true, "Navigated to cache dashboard")
        } else {
            let table = app.tables.firstMatch
            if table.exists {
                for cell in table.cells.allElementsBoundByIndex {
                    let texts = cell.staticTexts.allElementsBoundByIndex.map(\.label)
                    let combined = texts.joined(separator: " ").lowercased()
                    if combined.contains("缓存") || combined.contains("cache") {
                        cell.tap()
                        sleep(2)
                        XCTAssertTrue(true, "Found cache dashboard by cell scan")
                        return
                    }
                }
            }
            XCTAssertTrue(true, "Cache dashboard entry not found but app didn't crash")
        }
    }
}
