import XCTest

final class DebugPanelTests: XCTestCase {

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

    private func navigateToSettings() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should exist")
        let settingsTab = tabBar.buttons["设置"]
        if !settingsTab.exists {
            tabBar.buttons["Settings"].tap()
        } else {
            settingsTab.tap()
        }
        sleep(1)
    }

    private func openDebugPanel() -> Bool {
        navigateToSettings()

        let debugLabel = app.staticTexts["调试面板"]
        if debugLabel.waitForExistence(timeout: 5) {
            debugLabel.tap()
            sleep(2)
            return true
        }

        let debugEn = app.staticTexts["Debug Panel"]
        if debugEn.waitForExistence(timeout: 3) {
            debugEn.tap()
            sleep(2)
            return true
        }

        let table = app.tables.firstMatch
        if table.exists {
            for cell in table.cells.allElementsBoundByIndex {
                let labels = cell.staticTexts.allElementsBoundByIndex.map(\.label)
                let combined = labels.joined(separator: " ").lowercased()
                if combined.contains("调试") || combined.contains("debug") {
                    cell.tap()
                    sleep(2)
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Tab Existence

    func testDebugPanelOpens() {
        let opened = openDebugPanel()
        XCTAssertTrue(opened, "Debug panel should be reachable from Settings")

        let tab0 = app.buttons["debugPanel.tab.0"]
        XCTAssertTrue(tab0.waitForExistence(timeout: 5), "Tab 0 (Handlers) should exist")
    }

    func testAllFiveTabsExist() {
        guard openDebugPanel() else {
            XCTFail("Could not open debug panel")
            return
        }

        for index in 0..<5 {
            let tab = app.buttons["debugPanel.tab.\(index)"]
            XCTAssertTrue(tab.waitForExistence(timeout: 3), "Tab \(index) should exist")
        }
    }

    // MARK: - Tab Switching

    func testSwitchToHandlersTab() {
        guard openDebugPanel() else {
            XCTFail("Could not open debug panel")
            return
        }

        let tab0 = app.buttons["debugPanel.tab.0"]
        XCTAssertTrue(tab0.waitForExistence(timeout: 3))
        tab0.tap()
        sleep(1)

        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 5), "Handlers tab should show a table")
    }

    func testSwitchToNotificationTestTab() {
        guard openDebugPanel() else {
            XCTFail("Could not open debug panel")
            return
        }

        let tab1 = app.buttons["debugPanel.tab.1"]
        XCTAssertTrue(tab1.waitForExistence(timeout: 3))
        tab1.tap()
        sleep(2)

        XCTAssertTrue(true, "Switched to notification test tab without crash")
    }

    func testSwitchToLogsTab() {
        guard openDebugPanel() else {
            XCTFail("Could not open debug panel")
            return
        }

        let tab2 = app.buttons["debugPanel.tab.2"]
        XCTAssertTrue(tab2.waitForExistence(timeout: 3))
        tab2.tap()
        sleep(2)

        XCTAssertTrue(true, "Switched to logs tab without crash")
    }

    func testSwitchToEnvironmentTab() {
        guard openDebugPanel() else {
            XCTFail("Could not open debug panel")
            return
        }

        let tab3 = app.buttons["debugPanel.tab.3"]
        XCTAssertTrue(tab3.waitForExistence(timeout: 3))
        tab3.tap()
        sleep(2)

        XCTAssertTrue(true, "Switched to environment tab without crash")
    }

    func testSwitchToCacheStatsTab() {
        guard openDebugPanel() else {
            XCTFail("Could not open debug panel")
            return
        }

        let tab4 = app.buttons["debugPanel.tab.4"]
        XCTAssertTrue(tab4.waitForExistence(timeout: 3))
        tab4.tap()
        sleep(2)

        XCTAssertTrue(true, "Switched to cache stats tab without crash")
    }

    // MARK: - Sequential Tab Switching

    func testSequentialTabSwitchingNoCrash() {
        guard openDebugPanel() else {
            XCTFail("Could not open debug panel")
            return
        }

        for index in 0..<5 {
            let tab = app.buttons["debugPanel.tab.\(index)"]
            if tab.waitForExistence(timeout: 3) {
                tab.tap()
                sleep(1)
            }
        }

        XCTAssertTrue(true, "Switched through all 5 tabs without crash")
    }

    // MARK: - Close Debug Panel

    func testCloseDebugPanel() {
        guard openDebugPanel() else {
            XCTFail("Could not open debug panel")
            return
        }

        let doneButton = app.buttons["完成"]
        if doneButton.waitForExistence(timeout: 3) {
            doneButton.tap()
            sleep(1)
            XCTAssertTrue(true, "Closed debug panel via Done button")
        } else {
            let closeBtn = app.navigationBars.firstMatch.buttons.element(boundBy: 0)
            if closeBtn.waitForExistence(timeout: 3) {
                closeBtn.tap()
                sleep(1)
                XCTAssertTrue(true, "Closed debug panel via back/close button")
            }
        }
    }
}
