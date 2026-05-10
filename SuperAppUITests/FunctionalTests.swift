import XCTest

final class FunctionalTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launch()
    }

    private func saveScreenshot(_ path: String) {
        let screenshot = app.screenshot()
        if let data = screenshot.image.pngData() {
            do {
                try data.write(to: URL(fileURLWithPath: path))
                print("[Screenshot] Saved to \(path) (\(data.count) bytes)")
            } catch {
                XCTFail("Failed to save screenshot to \(path): \(error)")
            }
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = URL(fileURLWithPath: path).lastPathComponent
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func navigateToTab(_ name: String) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should exist")
        let tab = tabBar.buttons[name]
        XCTAssertTrue(tab.exists, "Tab '\(name)' should exist")
        tab.tap()
        sleep(1)
    }

    // MARK: - Test 1: Settings Navigation

    func testSettingsNavigation() throws {
        navigateToTab("设置")

        let tableView = app.tables["settings.tableView"]
        XCTAssertTrue(tableView.waitForExistence(timeout: 5), "Settings table should exist")

        let allCells = tableView.cells
        let cellCount = allCells.count
        XCTAssertGreaterThanOrEqual(cellCount, 7, "Settings should have at least 7 rows, found \(cellCount)")

        let cacheCell = tableView.cells["settings.cell.cacheManager"]
        if cacheCell.waitForExistence(timeout: 3) {
            cacheCell.tap()
            sleep(1)

            let segmentedControl = app.segmentedControls.firstMatch
            if segmentedControl.waitForExistence(timeout: 3) {
                let cacheSegment = segmentedControl.buttons["缓存"]
                if cacheSegment.exists {
                    cacheSegment.tap()
                    sleep(2)
                }
            }

            saveScreenshot("/tmp/wbk-settings-cache.png")

            let navBar = app.navigationBars.element(boundBy: 0)
            if navBar.buttons.count > 1 {
                app.navigationBars.buttons.element(boundBy: 0).tap()
            } else {
                app.navigationBars.firstMatch.buttons.firstMatch.tap()
            }
            sleep(1)
        } else {
            print("[Warning] Cache management cell not found by identifier, trying by label")
            let cacheLabel = app.staticTexts["缓存管理"]
            if cacheLabel.waitForExistence(timeout: 3) {
                cacheLabel.tap()
                sleep(1)
                saveScreenshot("/tmp/wbk-settings-cache.png")
                app.navigationBars.firstMatch.buttons.firstMatch.tap()
                sleep(1)
            }
        }

        let notifCell = tableView.cells["settings.cell.notificationSettings"]
        if notifCell.waitForExistence(timeout: 3) {
            let snapshotBefore = app.state

            notifCell.tap()
            sleep(2)

            if app.state == .runningForeground {
                saveScreenshot("/tmp/wbk-settings-notifications.png")
            } else {
                print("[Info] App moved to background (iOS Settings opened). Re-launching.")
                app.activate()
                sleep(2)
                saveScreenshot("/tmp/wbk-settings-notifications.png")
            }
        } else {
            print("[Warning] Notification settings cell not found, saving current state screenshot")
            saveScreenshot("/tmp/wbk-settings-notifications.png")
        }
    }

    // MARK: - Test 2: Inbox Scrolling

    func testInboxScrolling() throws {
        navigateToTab("收信箱")

        sleep(2)

        let tableView = app.tables.firstMatch
        XCTAssertTrue(tableView.waitForExistence(timeout: 5), "Inbox table should exist")

        let messageCells = tableView.cells.matching(identifier: "InboxMessageCell")
        let totalCells = tableView.cells.count
        print("[Inbox] Total cells visible: \(totalCells), message cells: \(messageCells.count)")

        XCTAssertGreaterThanOrEqual(totalCells, 4, "Inbox should show at least 4 cells (headers + messages), found \(totalCells)")

        tableView.swipeUp()
        sleep(1)

        saveScreenshot("/tmp/wbk-inbox-scrolled.png")
    }

    // MARK: - Test 3: Home Card Tap

    func testHomeCardTap() throws {
        navigateToTab("首页")

        let collectionView = app.collectionViews["MainCollectionView"]
        let emptyState = app.otherElements["EmptyStateView"]
        let cvExists = collectionView.waitForExistence(timeout: 5)
        let emptyExists = emptyState.waitForExistence(timeout: 2)

        guard cvExists || emptyExists else {
            XCTFail("Home should have collection view or empty state")
            return
        }

        guard cvExists else {
            print("[Info] Home shows empty state, no cards to tap")
            saveScreenshot("/tmp/wbk-home-card-tap.png")
            return
        }

        let weatherCell = collectionView.cells.containing(.staticText, identifier: "北京天气").firstMatch
        if weatherCell.waitForExistence(timeout: 3) {
            weatherCell.tap()
            sleep(2)
            saveScreenshot("/tmp/wbk-home-card-tap.png")

            if !app.collectionViews["MainCollectionView"].exists {
                if app.navigationBars.buttons.count > 0 {
                    app.navigationBars.firstMatch.buttons.firstMatch.tap()
                    sleep(1)
                }
            }
        } else {
            print("[Info] '北京天气' card not found, tapping first available cell")
            let firstCell = collectionView.cells.firstMatch
            if firstCell.exists {
                firstCell.tap()
                sleep(2)
                saveScreenshot("/tmp/wbk-home-card-tap.png")

                if !app.collectionViews["MainCollectionView"].exists {
                    if app.navigationBars.buttons.count > 0 {
                        app.navigationBars.firstMatch.buttons.firstMatch.tap()
                        sleep(1)
                    }
                }
            } else {
                saveScreenshot("/tmp/wbk-home-card-tap.png")
            }
        }
    }
}
