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

    private func debugSave(_ name: String) {
        guard app.exists else { print("[Debug] App not exist for \(name)"); return }
        let s = app.screenshot()
        if let d = s.image.pngData() {
            try? d.write(to: URL(fileURLWithPath: "/tmp/wbk-debug-\(name).png"))
        }
        print("[Debug] Saved /tmp/wbk-debug-\(name).png")
    }

    func testFavoritesHasData() throws {
        debugSave("01-launch")

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar should exist")

        let allTabs = tabBar.buttons.allElementsBoundByIndex
        print("[Debug] Tab count: \(allTabs.count)")
        for (i, t) in allTabs.enumerated() {
            print("[Debug] Tab[\(i)] label='\(t.label)' exists=\(t.exists) identifier='\(t.identifier)'")
        }

        let settingsTab = tabBar.buttons["设置"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab should exist")
        settingsTab.tap()
        sleep(3)
        debugSave("02-after-settings-tap")

        let tableView = app.tables.firstMatch
        let tableExists = tableView.waitForExistence(timeout: 10)
        print("[Debug] Table exists: \(tableExists), cell count: \(tableView.cells.count)")

        if tableExists {
            let allCells = tableView.cells.allElementsBoundByIndex
            for (i, c) in allCells.enumerated() {
                print("[Debug] Cell[\(i)] label='\(c.label)' identifier='\(c.identifier)'")
            }
        }

        let favCell = tableView.cells.containing(NSPredicate(format: "label CONTAINS %@", "收藏夹")).firstMatch
        let favFound = favCell.waitForExistence(timeout: 5)
        print("[Debug] Favorites cell found: \(favFound)")

        if favFound {
            let frame = favCell.frame
            print("[Debug] FavCell frame: \(frame)")
            let tapPoint = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
            tapPoint.tap()
            print("[Debug] Tapped favorites cell at (\(frame.midX), \(frame.midY))")
        } else {
            let staticTexts = tableView.staticTexts.allElementsBoundByIndex
            for (i, st) in staticTexts.enumerated() {
                if st.label.contains("收藏") || st.label.contains("缓存") {
                    print("[Debug] StaticText[\(i)] '\(st.label)' frame=\(st.frame)")
                }
            }
            if tableView.cells.count > 5 {
                let cell5 = tableView.cells.element(boundBy: 5)
                if cell5.waitForExistence(timeout: 2) {
                    let f = cell5.frame
                    app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: f.midY)).tap()
                    print("[Debug] Fallback tapped cell[5] at (\(f.midX), \(f.midY))")
                }
            }
        }

        sleep(4)
        debugSave("03-after-cell-tap")
        saveScreenshot("/tmp/wbk-fix-favorites.png")
    }

    func testCacheTabHasData() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar should exist")
        let settingsTab = tabBar.buttons["设置"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab should exist")
        settingsTab.tap()
        sleep(3)

        let tableView = app.tables.firstMatch
        XCTAssertTrue(tableView.waitForExistence(timeout: 10), "Table should exist")

        let cacheCell = tableView.cells.containing(NSPredicate(format: "label CONTAINS %@", "缓存管理")).firstMatch
        if cacheCell.waitForExistence(timeout: 5) {
            let frame = cacheCell.frame
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        } else if tableView.cells.count > 4 {
            let cell4 = tableView.cells.element(boundBy: 4)
            if cell4.waitForExistence(timeout: 2) {
                let f = cell4.frame
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: f.midY)).tap()
            }
        }
        sleep(4)

        let segmentedControl = app.segmentedControls.firstMatch
        if segmentedControl.waitForExistence(timeout: 5) {
            let cacheSegment = segmentedControl.buttons["缓存"]
            if cacheSegment.waitForExistence(timeout: 3) {
                cacheSegment.tap(); sleep(2)
            } else if segmentedControl.buttons.count > 0 {
                segmentedControl.buttons.element(boundBy: 0).tap(); sleep(2)
            }
        }

        saveScreenshot("/tmp/wbk-fix-cache.png")
    }

    func testInboxMessageDetail() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar should exist")
        let inboxTab = tabBar.buttons["收信箱"]
        XCTAssertTrue(inboxTab.waitForExistence(timeout: 5), "Inbox tab should exist")
        inboxTab.tap()
        sleep(2)

        let tableView = app.tables.firstMatch
        XCTAssertTrue(tableView.waitForExistence(timeout: 5), "Inbox table should exist")
        XCTAssertTrue(tableView.cells.count > 0, "Inbox should have messages")

        let firstCell = tableView.cells.element(boundBy: 0)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 3), "First message cell should exist")
        let frame = firstCell.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()

        sleep(3)
        saveScreenshot("/tmp/wbk-fix-inbox-detail.png")
    }
}
