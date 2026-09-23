import XCTest

/// 左滑删除收藏：删除一次（滑动→删除→确认）后列表必须立刻少一行。
/// 回归：删除走 fire-and-forget 同步包装时，重读列表发生在提交前，
/// 表现为要点两次才消失（用户真机报告 2026-09-23）。
final class FavoriteSwipeDeleteTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSwipeDeleteRemovesRowAfterSingleConfirmation() throws {
        let app = XCUIApplication()
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["不允许粘贴"].waitForExistence(timeout: 3) {
            springboard.buttons["不允许粘贴"].tap()
        }
        returnToMainFrame(app)

        let settingsTab = app.tabBars.buttons["设置"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 15), "设置 tab 不存在")
        settingsTab.tap()

        let favoritesRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "收藏夹"))
            .firstMatch
        var found = favoritesRow.waitForExistence(timeout: 5)
        var attempts = 0
        while !found && attempts < 5 {
            app.swipeUp()
            found = favoritesRow.waitForExistence(timeout: 3)
            attempts += 1
        }
        XCTAssertTrue(found, "设置页没有收藏夹入口")
        favoritesRow.tap()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 8), "收藏夹列表为空，无法测删除")
        let before = app.cells.count
        XCTAssertTrue(before >= 1, "至少需要一条收藏")
        captureScreenshot(named: "60-before-delete")

        // 半滑露出操作（删除+置顶），点删除 → 确认弹窗 → 删除
        let firstCell = app.cells.firstMatch
        let start = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        let end = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        sleep(1)

        let deleteButton = app.buttons["删除"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 4), "半滑没有露出删除按钮")
        deleteButton.tap()

        // 确认弹窗（UIAlertController：取消/删除）
        let alertDelete = app.alerts.buttons["删除"].firstMatch
        XCTAssertTrue(alertDelete.waitForExistence(timeout: 3), "删除确认弹窗没有出现")
        alertDelete.tap()
        sleep(2)
        captureScreenshot(named: "61-after-delete")

        // 关键断言：一次删除流程后行数必须减一（旧 bug 是界面无变化）
        let after = app.cells.count
        XCTAssertLessThan(after, before, "一次删除后列表行数没有减少（仍需删两次的旧 bug）")
        XCTAssertEqual(app.state, .runningForeground, "删除后 App 不在前台")
    }

    private func returnToMainFrame(_ app: XCUIApplication) {
        var backs = 0
        while !app.tabBars.firstMatch.exists && backs < 8 {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.exists {
                back.tap()
                sleep(1)
            } else if app.buttons["browserManager.closeButton"].waitForExistence(timeout: 1) {
                app.buttons["browserManager.closeButton"].tap()
                sleep(1)
            } else {
                break
            }
            backs += 1
        }
    }

    private func captureScreenshot(named name: String) {
        let shot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: "/tmp/drel-fav-crash/\(name).png")
        try? shot.pngRepresentation.write(to: url)
    }
}
