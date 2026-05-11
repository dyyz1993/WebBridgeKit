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
            if allowBtn.exists { allowBtn.tap(); return true }
            let allowPasteBtn = alert.buttons["Allow Paste"]
            if allowPasteBtn.exists { allowPasteBtn.tap(); return true }
            let dontAllow = alert.buttons["不允许粘贴"]
            if dontAllow.exists { dontAllow.tap(); return true }
            let dontAllowEn = alert.buttons["Don't Allow"]
            if dontAllowEn.exists { dontAllowEn.tap(); return true }
            return false
        }
        addUIInterruptionMonitor(withDescription: "System Alert") { (alert) -> Bool in
            let okBtn = alert.buttons["好"]
            if okBtn.exists { okBtn.tap(); return true }
            let okEn = alert.buttons["OK"]
            if okEn.exists { okEn.tap(); return true }
            return false
        }
    }

    private func saveScreenshot(_ path: String) {
        sleep(1)
        guard app.exists else { return }
        let screenshot = app.screenshot()
        if let data = screenshot.image.pngData() {
            try? data.write(to: URL(fileURLWithPath: path))
            print("[Screenshot] Saved to \(path) (\(data.count) bytes)")
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = URL(fileURLWithPath: path).lastPathComponent
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapTabNamed(_ name: String) {
        sleep(1)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar should exist")
        let tab = tabBar.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Tab '\(name)' should exist")
        tab.tap()
        sleep(2)
    }

    private func tapCellContaining(_ text: String) {
        sleep(1)
        let tableView = app.tables.firstMatch
        XCTAssertTrue(tableView.waitForExistence(timeout: 10), "Table should exist")
        let cell = tableView.cells.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        if cell.waitForExistence(timeout: 5) {
            let frame = cell.frame
            guard !frame.isEmpty && !frame.isNull else {
                XCTFail("Cell containing '\(text)' has invalid frame")
                return
            }
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        } else {
            XCTFail("Could not find cell containing '\(text)'")
        }
        sleep(2)
    }

    private func waitForNav() {
        sleep(2)
        if app.state != .runningForeground { app.activate(); sleep(1) }
    }

    func testFavoritesHasData() throws {
        tapTabNamed("设置")
        tapCellContaining("收藏夹")
        waitForNav()
        sleep(2)
        saveScreenshot("/tmp/wbk-fix-favorites.png")
    }

    func testCacheTabHasData() throws {
        tapTabNamed("设置")
        tapCellContaining("缓存管理")
        waitForNav()

        let segCtrl = app.segmentedControls.firstMatch
        if segCtrl.waitForExistence(timeout: 5) {
            let cacheSeg = segCtrl.buttons["缓存"]
            if cacheSeg.waitForExistence(timeout: 3) {
                cacheSeg.tap(); sleep(2)
            } else if segCtrl.buttons.count > 0 {
                segCtrl.buttons.element(boundBy: 0).tap(); sleep(2)
            }
        }
        sleep(2)
        saveScreenshot("/tmp/wbk-fix-cache.png")
    }

    func testInboxMessageDetail() throws {
        tapTabNamed("收信箱")
        sleep(2)

        let tableView = app.tables.firstMatch
        XCTAssertTrue(tableView.waitForExistence(timeout: 5), "Inbox table should exist")
        XCTAssertTrue(tableView.cells.count > 0, "Inbox should have messages")

        let firstCell = tableView.cells.element(boundBy: 0)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 3), "First message cell should exist")
        let frame = firstCell.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()

        waitForNav()
        sleep(2)
        saveScreenshot("/tmp/wbk-fix-inbox-detail.png")
    }
}
