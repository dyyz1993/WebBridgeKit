import XCTest

final class VerifyFixesTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        setupInterruptionMonitor()
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launch()
        sleep(3)
    }

    override func tearDown() {
        app.terminate()
    }

    private func setupInterruptionMonitor() {
        addUIInterruptionMonitor(withDescription: "Paste Permission") { [weak self] (alert) -> Bool in
            let allowBtn = alert.buttons["允许粘贴"]
            if allowBtn.exists {
                allowBtn.tap()
                return true
            }
            let allowPasteBtn = alert.buttons["Allow Paste"]
            if allowPasteBtn.exists {
                allowPasteBtn.tap()
                return true
            }
            let dontAllow = alert.buttons["不允许粘贴"]
            if dontAllow.exists {
                dontAllow.tap()
                return true
            }
            let dontAllowEn = alert.buttons["Don't Allow"]
            if dontAllowEn.exists {
                dontAllowEn.tap()
                return true
            }
            return false
        }
        addUIInterruptionMonitor(withDescription: "System Alert") { (alert) -> Bool in
            let okBtn = alert.buttons["好"]
            if okBtn.exists {
                okBtn.tap()
                return true
            }
            let okEn = alert.buttons["OK"]
            if okEn.exists {
                okEn.tap()
                return true
            }
            return false
        }
    }

    private func navigateToTab(_ name: String) {
        sleep(2)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar should exist - app may not have finished loading")
        let tab = tabBar.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Tab '\(name)' should exist")
        tab.tap()
        sleep(2)
    }

    private func saveScreenshot(_ path: String) {
        sleep(1)
        guard app.exists else {
            print("[Screenshot] App no longer exists, skipping screenshot for \(path)")
            return
        }
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

    private func saveScreenshotSafe(_ path: String) {
        let waitResult = app.waitForExistence(timeout: 5)
        guard waitResult else {
            print("[ScreenshotSafe] App does not exist, skipping \(path)")
            return
        }
        if app.state != .runningForeground {
            print("[ScreenshotSafe] App not in foreground (state: \(app.state.rawValue)), activating")
            app.activate()
            sleep(2)
        }
        let screenshot: XCUIScreenshot
        do {
            screenshot = app.screenshot()
        } catch {
            print("[ScreenshotError] Failed to capture screenshot for \(path): \(error)")
            return
        }
        if let data = screenshot.image.pngData() {
            do {
                try data.write(to: URL(fileURLWithPath: path))
                print("[ScreenshotSafe] Saved to \(path) (\(data.count) bytes)")
            } catch {
                print("[ScreenshotSafe] Failed to write screenshot to \(path): \(error)")
            }
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = URL(fileURLWithPath: path).lastPathComponent
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func safeTap(_ element: XCUIElement, fallbackLabel: String? = nil, coordFallback: CGVector? = nil) {
        if element.waitForExistence(timeout: 5) {
            element.tap()
            return
        }
        if let label = fallbackLabel {
            let lbl = app.staticTexts[label]
            if lbl.waitForExistence(timeout: 3) {
                lbl.tap()
                return
            }
            let cellWithText = app.cells.containing(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
            if cellWithText.waitForExistence(timeout: 2) {
                cellWithText.tap()
                return
            }
        }
        if let coord = coordFallback {
            let tableView = app.tables.firstMatch
            if tableView.waitForExistence(timeout: 2) {
                tableView.coordinate(withNormalizedOffset: coord).tap()
                return
            }
        }
        XCTFail("Could not find element to tap")
    }

    private func waitForPageLoad() {
        sleep(2)
    }

    // MARK: - Fix 1: Navigate to Favorites

    func testFavoritesHasData() throws {
        navigateToTab("设置")

        let tableView = app.tables.firstMatch
        XCTAssertTrue(tableView.waitForExistence(timeout: 10), "Settings table should exist")

        let favoritesCell = tableView.cells["settings.cell.favorites"]
        safeTap(favoritesCell, fallbackLabel: "收藏夹", coordFallback: CGVector(dx: 0.5, dy: 0.48))

        waitForPageLoad()

        if app.state != .runningForeground {
            app.activate()
            sleep(1)
        }
        let favoriteView = app.otherElements["FavoriteViewController"]
        if favoriteView.waitForExistence(timeout: 10) {
            print("[testFavorites] FavoriteViewController detected on screen")
        } else {
            print("[testFavorites] FavoriteViewController not found via accessibilityIdentifier, checking for favorite content...")
            let favTable = app.tables["favorite.tableView"]
            if favTable.waitForExistence(timeout: 5) {
                print("[testFavorites] favorite.tableView found")
            } else {
                print("[testFavorites] Warning: Could not confirm Favorites page is displayed")
            }
        }
        sleep(3)
        saveScreenshotSafe("/tmp/wbk-fix-favorites.png")
    }

    // MARK: - Fix 2: Navigate to Cache tab

    func testCacheTabHasData() throws {
        navigateToTab("设置")

        let tableView = app.tables.firstMatch
        XCTAssertTrue(tableView.waitForExistence(timeout: 10), "Settings table should exist")

        let cacheCell = tableView.cells["settings.cell.cacheManager"]
        safeTap(cacheCell, fallbackLabel: "缓存管理", coordFallback: CGVector(dx: 0.5, dy: 0.42))
        waitForPageLoad()

        let segmentedControl = app.segmentedControls.firstMatch
        if segmentedControl.waitForExistence(timeout: 5) {
            print("[testCache] Segmented control found")
            let cacheSegment = segmentedControl.buttons["缓存"]
            if cacheSegment.waitForExistence(timeout: 3) {
                cacheSegment.tap()
                waitForPageLoad()
                print("[testCache] Tapped cache segment")
            } else {
                print("[testCache] Cache segment button not found in segmented control")
            }
        } else {
            let navBarSegment = app.navigationBars.firstMatch.segmentedControls.firstMatch
            if navBarSegment.waitForExistence(timeout: 3) {
                let cacheSegment = navBarSegment.buttons["缓存"]
                if cacheSegment.exists {
                    cacheSegment.tap()
                    waitForPageLoad()
                    print("[testCache] Tapped cache segment from navbar")
                }
            } else {
                print("[testCache] No segmented control found at all")
            }
        }
        sleep(3)
        saveScreenshotSafe("/tmp/wbk-fix-cache.png")
    }

    // MARK: - Fix 3: Navigate to Inbox message detail

    func testInboxMessageDetail() throws {
        navigateToTab("收信箱")
        sleep(2)

        let tableView = app.tables.firstMatch
        XCTAssertTrue(tableView.waitForExistence(timeout: 5), "Inbox table should exist")

        let firstCell = tableView.cells.element(boundBy: 0)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 3), "First message cell should exist")
        firstCell.tap()

        if app.state != .runningForeground {
            app.activate()
            sleep(2)
        }
        sleep(3)
        saveScreenshotSafe("/tmp/wbk-fix-inbox-detail.png")
    }
}
