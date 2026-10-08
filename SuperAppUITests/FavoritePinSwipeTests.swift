import XCTest

/// 收藏夹右滑置顶：整滑直触发（不需要点按钮），置顶行必须浮到原行之上；
/// 再右滑一次取消置顶，行回到非置顶区按时间的末位（还原状态）。
/// 回归点（用户 2026-09-25）：置顶应该是「右滑一下就置顶」，滑出按钮
/// 还要点一下的交互不成立；列表按收藏时间倒序、置顶浮顶。
final class FavoritePinSwipeTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFullSwipeRightPinsInPlaceWithoutTappingButton() throws {
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

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 8), "收藏夹列表为空")
        let rowCount = app.cells.count
        XCTAssertGreaterThanOrEqual(rowCount, 2, "置顶浮顶断言至少需要两条收藏")

        // 目标 = 列表末行：置顶行永远排在前面，所以末行必然未置顶，
        // 且是未置顶里最早的（时间倒序），取消置顶后必然回到末行。
        let beforeIndex = rowCount - 1
        let targetId = app.cells.element(boundBy: beforeIndex).identifier
        XCTAssertTrue(targetId.hasPrefix("favorite.card."), "unexpected cell identity: \(targetId)")

        // 整滑（右滑越过阈值）直接触发置顶，全程不点任何按钮
        fullSwipeRight(app.cells.element(boundBy: beforeIndex))
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        captureScreenshot(named: "70-after-pin-swipe")

        var pinnedIndex = -1
        for i in 0..<app.cells.count where app.cells.element(boundBy: i).identifier == targetId {
            pinnedIndex = i
            break
        }
        XCTAssertGreaterThanOrEqual(pinnedIndex, 0, "置顶后目标行消失了")
        XCTAssertLessThan(pinnedIndex, beforeIndex, "整滑右滑后目标行没有上浮（置顶未生效或仍需点按钮）")
        captureScreenshot(named: "71-pinned-floats")

        // 再整滑一次取消置顶：目标行回到非置顶区时间末位
        fullSwipeRight(app.cells.element(boundBy: pinnedIndex))
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let restoredIndex = app.cells.count - 1
        XCTAssertEqual(
            app.cells.element(boundBy: restoredIndex).identifier,
            targetId,
            "取消置顶后目标行应回到时间倒序的末位"
        )
        XCTAssertEqual(app.state, .runningForeground, "操作后 App 不在前台")
    }

    private func fullSwipeRight(_ cell: XCUIElement) {
        // AGENTS.md 配方：小距离 swipeRight 触发不了 action，
        // 必须用 press+drag 拖过整滑阈值（dx 3.0）
        let start = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        let end = cell.coordinate(withNormalizedOffset: CGVector(dx: 3.0, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
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
