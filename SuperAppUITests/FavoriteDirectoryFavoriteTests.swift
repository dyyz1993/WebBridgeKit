import XCTest

/// 收藏夹交互回归：目录形态的应用收藏（推送 url 收藏产生，无 index.html）
/// 重开必须回沉浸式全屏，而不是回落普通模式。
/// 入口走收件箱消息（URL 推送会落收件箱）：通知 → 详情 → 打开链接 → 普通
/// 网页壳 → ⋯ 菜单收藏（存当前地址 = 目录形态）→ 收藏夹点开 → 断言无导航栏。
final class FavoriteDirectoryFavoriteTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDirectoryFormFavoriteReopensImmersive() throws {
        let app = XCUIApplication()
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["不允许粘贴"].waitForExistence(timeout: 3) {
            springboard.buttons["不允许粘贴"].tap()
        }
        returnToMainFrame(app)

        // 通知 tab → 找 URL 推送消息（外部 simctl push 注入，标题「数据模板」）
        let inboxTab = app.tabBars.buttons["通知"]
        XCTAssertTrue(inboxTab.waitForExistence(timeout: 15), "通知 tab 不存在")
        inboxTab.tap()

        let messageRow = app.staticTexts["数据模板"].firstMatch
        var rowFound = messageRow.waitForExistence(timeout: 10)
        var scrolls = 0
        while !rowFound && scrolls < 5 {
            app.swipeUp()
            rowFound = messageRow.waitForExistence(timeout: 3)
            scrolls += 1
        }
        XCTAssertTrue(rowFound, "收件箱里没有数据模板消息（外部推送未注入？）")
        messageRow.tap()

        // 详情页 → 打开链接 → 普通网页壳
        let openLink = app.buttons["打开链接"].firstMatch
        let openTarget = openLink.exists ? openLink : app.staticTexts["打开链接"].firstMatch
        XCTAssertTrue(openTarget.waitForExistence(timeout: 6), "详情页没有打开链接")
        openTarget.tap()

        let moreButton = app.buttons["browser.moreButton"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 15), "普通网页壳没有出现")
        // 等页面正文渲染（导航提交后 webView.url 才有值，否则 ⋯ 菜单是空的）
        let pageBody = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "数据模板页")
        ).firstMatch
        XCTAssertTrue(pageBody.waitForExistence(timeout: 20), "模板页正文没有渲染")
        sleep(1)

        // ⋯ 菜单 → 收藏入口（存当前地址 = 目录形态）；已收藏时标签是
        // 「取消收藏」，未收藏是「收藏页面」——两者都认，测试可重复跑
        func openMenuAndFindTile() -> XCUIElement? {
            moreButton.tap()
            let predicate = NSPredicate(
                format: "identifier == %@ OR identifier == %@ OR label == %@ OR label == %@",
                "actionsheet.收藏页面", "actionsheet.取消收藏", "收藏页面", "取消收藏"
            )
            let tile = app.buttons.matching(predicate).firstMatch
            if tile.waitForExistence(timeout: 4) { return tile }
            return nil
        }
        guard let firstTile = openMenuAndFindTile() else {
            XCTFail("菜单里没有收藏入口")
            return
        }
        // 归一到未收藏态再收藏（开关语义，测试必须可重复）：已收藏时先取消
        if firstTile.identifier == "actionsheet.取消收藏" || firstTile.label == "取消收藏" {
            firstTile.tap()
            sleep(2)
        }
        // 「已取消收藏」HUD 会吞掉紧随的 ⋯ tap（FavoriteFlowTests 同款坑，
        // 那边用条件重试兜住）：单次 tap 后没见面板就再点一次；
        // 不能盲目双击——面板若已开着，第二次 ⋯ 是收起。
        moreButton.tap()
        let tilePredicate = NSPredicate(
            format: "identifier == %@ OR identifier == %@ OR label == %@ OR label == %@",
            "actionsheet.收藏页面", "actionsheet.取消收藏", "收藏页面", "取消收藏"
        )
        let retriedTile = app.buttons.matching(tilePredicate).firstMatch
        if !retriedTile.waitForExistence(timeout: 4) {
            moreButton.tap()
        }
        guard retriedTile.waitForExistence(timeout: 4) else {
            XCTFail("归一后菜单没有重新弹出")
            return
        }
        retriedTile.tap()
        sleep(2)

        // 返回主框架 → 设置 → 收藏夹
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "网页壳没有返回按钮")
        back.tap()
        let settingsTab = app.tabBars.buttons["设置"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 8), "返回后底部 tab 没有回显")
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

        // 菜单收藏存的是页面标题「Drel 数据模板」
        let templateRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "数据模板")
        ).firstMatch
        var rowFound2 = templateRow.waitForExistence(timeout: 8)
        var swipes = 0
        while !rowFound2 && swipes < 4 {
            app.swipeUp()
            rowFound2 = templateRow.waitForExistence(timeout: 3)
            swipes += 1
        }
        XCTAssertTrue(rowFound2, "收藏夹里没有数据模板条目")
        capture(named: "90-directory-favorite-listed")
        templateRow.tap()

        // 关键断言：目录形态收藏重开 = 沉浸式（无导航栏）
        sleep(4)
        capture(named: "91-reopened")
        XCTAssertFalse(app.navigationBars.firstMatch.exists,
                       "目录形态收藏重开没有进入沉浸式（导航栏仍在）")
        XCTAssertEqual(app.state, .runningForeground)
    }

    private func returnToMainFrame(_ app: XCUIApplication) {
        var backs = 0
        while !app.tabBars.firstMatch.exists && backs < 10 {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.exists {
                back.tap()
                sleep(1)
            } else if app.buttons["browserManager.closeButton"].waitForExistence(timeout: 1) {
                app.buttons["browserManager.closeButton"].tap()
                sleep(1)
            } else {
                // 沉浸页无导航栏：左缘胶囊展开后再点返回格退出
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.036, dy: 0.19)).tap()
                sleep(1)
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.19)).tap()
                sleep(2)
            }
            backs += 1
        }
    }

    private func capture(named name: String) {
        let shot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: "/tmp/drel-fav-crash/\(name).png")
        try? shot.pngRepresentation.write(to: url)
    }
}
