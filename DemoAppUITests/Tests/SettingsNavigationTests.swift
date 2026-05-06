import XCTest
@testable import WebBridgeKit

final class SettingsNavigationTests: XCTestCase {

    var app: XCUIApplication!
    var settingsPage: SettingsPage!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = AppLauncher.shared.launchApp()
        settingsPage = SettingsPage(app: app)

        // Navigate to settings page
        let settingsTab = app.tabBars.buttons["设置"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()
        }
    }

    override func tearDownWithError() throws {
        AppLauncher.shared.terminateApp(app)
        app = nil
        settingsPage = nil
    }

    // MARK: - Test Cases

    func testSettingsPageLoads() {
        // Verify settings page loads
        XCTAssertTrue(settingsPage.verifyPageLoaded(), "Settings page should load within 10 seconds")
    }

    func testAllMenuItemsExist() {
        // Verify all menu items are present
        XCTAssertTrue(settingsPage.verifyAllMenuItemsExist(), "All settings menu items should exist")
    }

    func testTokenManageItemExists() {
        // Verify token manage item exists
        XCTAssertTrue(settingsPage.verifyMenuItemExists(.tokenManage), "Token manage item should exist")
    }

    func testServerConfigItemExists() {
        // Verify server config item exists
        XCTAssertTrue(settingsPage.verifyMenuItemExists(.serverConfig), "Server config item should exist")
    }

    func testApiKeyManageItemExists() {
        // Verify API key manage item exists
        XCTAssertTrue(settingsPage.verifyMenuItemExists(.apiKeyManage), "API key manage item should exist")
    }

    func testAboutItemExists() {
        // Verify about item exists
        XCTAssertTrue(settingsPage.verifyMenuItemExists(.about), "About item should exist")
    }

    func testNavigateToTokenManage() {
        // Tap token manage item
        settingsPage.tapTokenManage()

        // Verify navigation
        let navigationBar = app.navigationBars["口令管理"].firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5), "Should navigate to Token Management page")

        // Navigate back
        settingsPage.navigateBack()
    }

    func testNavigateToServerConfig() {
        // Tap server config item
        settingsPage.tapServerConfig()

        // Verify navigation
        let navigationBar = app.navigationBars["服务器配置"].firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5), "Should navigate to Server Configuration page")

        // Navigate back
        settingsPage.navigateBack()
    }

    func testNavigateToApiKeyManage() {
        // Tap API key manage item
        settingsPage.tapApiKeyManage()

        // Verify navigation
        let navigationBar = app.navigationBars["密钥管理"].firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5), "Should navigate to API Key Management page")

        // Navigate back
        settingsPage.navigateBack()
    }

    func testNavigateToAbout() {
        // Tap about item
        settingsPage.tapAbout()

        // Verify navigation
        let navigationBar = app.navigationBars["关于"].firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5), "Should navigate to About page")

        // Navigate back
        settingsPage.navigateBack()
    }

    func testAPIKeyManagementFlow() throws {
        // 1. 进入密钥管理
        settingsPage.tapApiKeyManage()

        // 2. 验证进入了密钥管理页面
        XCTAssertTrue(app.navigationBars["密钥管理"].waitForExistence(timeout: 5), "应该进入密钥管理页面")

        // 3. 测试永久密钥推送
        let testPermanentButton = app.buttons[" 测试"]
        if testPermanentButton.exists {
            testPermanentButton.tap()
            // 验证是否出现了测试结果弹窗
            let alert = app.alerts.firstMatch
            if alert.waitForExistence(timeout: 10) {
                alert.buttons["确定"].tap()
            }
        }

        // 4. 测试创建临时密钥并进行左滑测试
        let addButton = app.navigationBars.buttons["plus"]
        if addButton.exists {
            addButton.tap()
            
            // 输入名称
            let nameField = app.alerts.textFields.element(boundBy: 0)
            if nameField.exists {
                nameField.typeText("UI Test Key")
                app.alerts.buttons["下一步"].tap()
                
                // 选择时长 (1 小时)
                let oneHourButton = app.sheets.buttons["1 小时"]
                if oneHourButton.exists {
                    oneHourButton.tap()
                    
                    // 等待创建成功弹窗并关闭
                    if app.alerts["创建成功"].waitForExistence(timeout: 5) {
                        app.alerts.buttons["确定"].tap()
                    }
                }
            }
        }

        // 5. 在列表中找到新创建的 Key 并左滑测试
        let tableView = app.tables.firstMatch
        let firstCell = tableView.cells.firstMatch
        if firstCell.waitForExistence(timeout: 5) {
            // 左滑显示测试按钮
            firstCell.swipeLeft()
            
            let testAction = app.buttons["测试"]
            if testAction.waitForExistence(timeout: 5) {
                testAction.tap()
                // 验证测试结果
                if app.alerts.firstMatch.waitForExistence(timeout: 10) {
                    app.alerts.buttons["确定"].tap()
                }
            }
        }
    }

    func testNavigateThroughAllSettings() {
        // Test navigating to each settings page and back

        // Token Manage
        settingsPage.tapTokenManage()
        XCTAssertTrue(app.navigationBars.firstMatch.exists, "Should navigate to Token Management")
        settingsPage.navigateBack()

        // Server Config
        settingsPage.tapServerConfig()
        XCTAssertTrue(app.navigationBars.firstMatch.exists, "Should navigate to Server Configuration")
        settingsPage.navigateBack()

        // API Key Manage
        settingsPage.tapApiKeyManage()
        XCTAssertTrue(app.navigationBars.firstMatch.exists, "Should navigate to API Key Management")
        settingsPage.navigateBack()

        // About
        settingsPage.tapAbout()
        XCTAssertTrue(app.navigationBars.firstMatch.exists, "Should navigate to About")
        settingsPage.navigateBack()

        // Verify back to settings
        XCTAssertTrue(settingsPage.verifyPageLoaded(), "Should return to Settings page")
    }

    func testSettingsTableViewScroll() {
        // Test scrolling through settings table
        let tableView = settingsPage.tableView
        tableView.swipeUp()

        // Wait for scroll
        let expectation = XCTestExpectation(description: "Wait for scroll")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)

        // Verify table still exists
        XCTAssertTrue(tableView.exists, "Table view should exist after scrolling")
    }

    func testSettingsAccessibility() {
        let tableView = app.tables["settings.tableView"]
        XCTAssertTrue(tableView.waitForExistence(timeout: 10), "Table view accessibility identifier should exist")

        XCTAssertTrue(tableView.cells["settings.cell.tokenManage"].waitForExistence(timeout: 5), "Token manage cell accessibility identifier should exist")
        XCTAssertTrue(tableView.cells["settings.cell.serverConfig"].waitForExistence(timeout: 5), "Server config cell accessibility identifier should exist")
        XCTAssertTrue(tableView.cells["settings.cell.apiKeyManage"].waitForExistence(timeout: 5), "API key manage cell accessibility identifier should exist")
        XCTAssertTrue(tableView.cells["settings.cell.about"].waitForExistence(timeout: 5), "About cell accessibility identifier should exist")
    }
}
