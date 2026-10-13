import XCTest

/// 推送 URL 消息 → 详情「打开链接」→ ⋯ 菜单收藏 → 收藏夹可见并可重开。
/// 规则断言：打开网页时底部 tab 必须隐藏（全屏与否只差顶部形态），返回后回显。
/// 列表类断言一律运行时动态取元素，禁止硬编码种子消息位置（模拟器会收到
/// 真实网关推送导致列表顺序漂移）。
final class FavoriteFlowTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPushedURLFavoritesFromBrowserStarAndReopens() throws {
        let app = XCUIApplication()
        // 与其它用例一致：注入 UITesting 参数以触发同步种子数据（收件箱 Pi Chat 消息）
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launch()

        // 会话恢复可能直接把上次的网页壳顶到最前（tab 处于隐藏态）；先退回主框架
        let restoredMore = app.buttons["browser.moreButton"]
        if restoredMore.waitForExistence(timeout: 3) {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // 1. 进入收件箱 tab
        let inboxTab = app.tabBars.buttons["通知"]
        XCTAssertTrue(inboxTab.waitForExistence(timeout: 15), "通知 tab 不存在")
        inboxTab.tap()

        // 2. 动态查找 Pi Chat 消息卡片
        let messageTitle = app.staticTexts["Pi Chat"].firstMatch
        XCTAssertTrue(messageTitle.waitForExistence(timeout: 15), "收件箱里没有 Pi Chat 消息")
        messageTitle.tap()

        // 3. 详情页 → 打开链接
        let openLink = app.buttons["打开链接"].firstMatch
        if openLink.waitForExistence(timeout: 8) {
            openLink.tap()
        } else {
            let openLinkText = app.staticTexts["打开链接"].firstMatch
            XCTAssertTrue(openLinkText.waitForExistence(timeout: 5), "详情页没有 打开链接 按钮")
            openLinkText.tap()
        }

        // 4. 浏览器壳出现：打开网页必须隐藏底部 tab；收藏收进 ⋯ 底部弹出菜单
        let moreButton = app.buttons["browser.moreButton"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 20), "浏览器壳没有出现（无 ⋯ 菜单按钮）")
        XCTAssertEqual(app.buttons.matching(identifier: "browser.moreButton").count, 1, "右上角 ⋯ 入口必须出现且仅出现一次")
        sleep(3) // 等 didFinish + tab 隐藏动画结束
        XCTAssertFalse(app.tabBars.firstMatch.exists, "打开网页后底部 tab 没有隐藏")
        captureScreenshot(named: "04-web-shell")

        // 收藏是 toggle 且收藏表持久化：按菜单项标题归一到「未收藏」再收藏，保证幂等。
        // 先验证「⋯ 有且仅有一个面板」：面板开启时再点 ⋯ 应收起而非叠加。
        moreButton.tap()
        let panelTile = app.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "收藏页面", "取消收藏")
        ).firstMatch
        XCTAssertTrue(panelTile.waitForExistence(timeout: 4), "⋯ 面板没有弹出")
        moreButton.tap()
        sleep(1) // 等收起动画结束
        XCTAssertFalse(
            app.buttons["收藏页面"].firstMatch.exists || app.buttons["取消收藏"].firstMatch.exists,
            "重复点 ⋯ 出现了叠加面板"
        )
        moreButton.tap()
        let favOn = app.buttons["取消收藏"].firstMatch
        if favOn.waitForExistence(timeout: 5) {
            captureScreenshot(named: "07-menu-favorited")
            favOn.tap()
            sleep(2) // 等「已取消收藏」HUD 消失，避免吞掉 ⋯ 按钮的 tap
            moreButton.tap()
            let favOffRetry = app.buttons["收藏页面"].firstMatch
            if !favOffRetry.waitForExistence(timeout: 4) {
                moreButton.tap()
            }
            XCTAssertTrue(favOffRetry.waitForExistence(timeout: 4), "菜单没再次弹出")
            captureScreenshot(named: "07-menu-not-favorited")
            favOffRetry.tap()
        } else {
            captureScreenshot(named: "07-menu-not-favorited")
            let favOff = app.buttons["收藏页面"].firstMatch
            XCTAssertTrue(favOff.exists, "底部菜单里没有收藏页面")
            favOff.tap()
            sleep(1)
            captureScreenshot(named: "09-after-fav-tap")
        }
        sleep(2) // 等「已收藏」HUD 消失，避免吞掉下一次点击

        // 5. 返回退出网页（tab 回显）→ 切设置 → 收藏夹验证（行可能折叠在屏幕外，滚动查找）
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "网页壳没有返回按钮")
        backButton.tap()
        let settingsTab = app.tabBars.buttons["设置"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "返回后底部 tab 没有回显")
        settingsTab.tap()

        let favoritesRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "收藏夹"))
            .firstMatch
        var found = favoritesRow.waitForExistence(timeout: 4)
        var attempts = 0
        while !found && attempts < 4 {
            app.swipeUp()
            found = favoritesRow.waitForExistence(timeout: 3)
            attempts += 1
        }
        XCTAssertTrue(found, "设置页没有收藏夹入口")
        favoritesRow.tap()

        let domainLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "pi-chat.shanbox")
        ).firstMatch
        XCTAssertTrue(domainLabel.waitForExistence(timeout: 10), "收藏夹里没有 pi-chat 条目")
        captureScreenshot(named: "05-favorites")

        // 6. 从收藏夹重开 → 普通浏览器壳（⋯ 菜单在、tab 隐藏、菜单内收藏态回显）
        domainLabel.tap()
        let reopenedMore = app.buttons["browser.moreButton"]
        XCTAssertTrue(reopenedMore.waitForExistence(timeout: 20), "收藏条目没有重新打开浏览器壳")
        XCTAssertFalse(app.tabBars.firstMatch.exists, "重开网页后底部 tab 没有隐藏")
        captureScreenshot(named: "06-reopened")
        reopenedMore.tap()
        XCTAssertTrue(app.buttons["取消收藏"].firstMatch.waitForExistence(timeout: 5), "重开后收藏状态没有回显在菜单里")
        captureScreenshot(named: "08-menu-favorited")
        // 面板无取消按钮，点遮罩关闭
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        XCTAssertFalse(app.buttons["取消收藏"].waitForExistence(timeout: 3), "点遮罩后面板没有关闭")
    }

    private func captureScreenshot(named name: String) {
        let dir = URL(fileURLWithPath: "/tmp/drel-fav-verify")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
