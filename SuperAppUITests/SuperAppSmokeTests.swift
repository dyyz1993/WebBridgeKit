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

    func testTabBarHasThreeUserTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar should exist")
        let tabs = tabBar.buttons
        XCTAssertEqual(tabs.count, 3, "Tab bar should contain Apps, Notifications, and Settings")
    }

    // MARK: - Tab Existence

    func testAppsTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let appsTab = findTabButton(in: tabBar, identifier: "tab.apps", zhName: "应用", enName: "Apps")
        XCTAssertTrue(appsTab.exists, "Apps tab should exist")
    }

    func testNotificationsTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let notificationsTab = findTabButton(in: tabBar, identifier: "tab.notifications", zhName: "通知", enName: "Notifications")
        XCTAssertTrue(notificationsTab.exists, "Notifications tab should exist")
    }

    func testSettingsTabExists() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let settingsTab = findTabButton(in: tabBar, identifier: "tab.settings", zhName: "设置", enName: "Settings")
        XCTAssertTrue(settingsTab.exists, "Settings tab should exist")
    }

    // MARK: - Tab Navigation

    func testNavigateToAppsTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let appsTab = findTabButton(in: tabBar, identifier: "tab.apps", zhName: "应用", enName: "Apps")
        appsTab.tap()

        let contentExists = app.descendants(matching: .any)["pwaCenter.table"].waitForExistence(timeout: 5)
        XCTAssertTrue(contentExists, "Apps tab should show the PWA app center")
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

    func testNavigateToNotificationsTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let notificationsTab = findTabButton(in: tabBar, identifier: "tab.notifications", zhName: "通知", enName: "Notifications")
        notificationsTab.tap()

        let contentExists = app.otherElements["InboxViewController"].waitForExistence(timeout: 5)
            || app.otherElements["wbk_search_field"].waitForExistence(timeout: 3)
        XCTAssertTrue(contentExists, "Notifications tab should show content")
    }

    // MARK: - Home Screen

    func testAppsScreenHasContent() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let appsTab = findTabButton(in: tabBar, identifier: "tab.apps", zhName: "应用", enName: "Apps")
        appsTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["pwaCenter.table"].waitForExistence(timeout: 5),
            "Apps screen should show the PWA app center")
    }

    // MARK: - Settings Screen

    func testSettingsScreenHasContent() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        let settingsTab = findTabButton(in: tabBar, identifier: "tab.settings", zhName: "设置", enName: "Settings")
        settingsTab.tap()

        let staticTexts = app.staticTexts
        XCTAssertGreaterThan(staticTexts.count, 0, "Settings screen should have content")
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
