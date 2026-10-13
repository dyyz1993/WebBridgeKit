import XCTest

/// 真机自动化探针：读取首页推送地址并打印到测试日志。
/// 用途：图标头像推送验证需要 device 的真实推送地址；
/// 不能带 --UITesting（种子数据会把通道覆盖成假地址）。
final class PushAddressProbeTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// SpringBoard 级系统弹窗（通知权限、允许粘贴等）
    @discardableResult
    private func dismissSystemAlerts() -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        var handled = false
        for alert in springboard.alerts.allElementsBoundByIndex {
            for name in ["允许", "好", "OK", "Allow", "确定", "允许粘贴", "允许“SuperApp”粘贴"] {
                if alert.buttons[name].exists {
                    alert.buttons[name].tap()
                    handled = true
                    break
                }
            }
        }
        return handled
    }

    func testPrintDevicePushAddress() throws {
        let app = XCUIApplication()
        app.launch()

        // 会话恢复可能直接顶出网页壳，先退回主框架
        if app.buttons["browser.moreButton"].waitForExistence(timeout: 3) {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // 通知权限等系统弹窗（首次启动）
        dismissSystemAlerts()

        // 确保在首页 tab
        if let homeTab = app.tabBars.buttons.allElementsBoundByIndex.first(where: { $0.exists }) {
            _ = homeTab
        }
        let homeTab = app.tabBars.buttons["首页"]
        if homeTab.waitForExistence(timeout: 6) {
            homeTab.tap()
        }

        let label = app.staticTexts["home.token_card.token_label"]
        var found = label.waitForExistence(timeout: 20)
        if !found {
            app.swipeDown()
            found = label.waitForExistence(timeout: 6)
        }

        if !found {
            // 诊断：dump 当前可见文本与按钮，帮助定位停在哪个界面
            let texts = app.staticTexts.allElementsBoundByIndex.prefix(15).map { $0.label }
            let buttons = app.buttons.allElementsBoundByIndex.prefix(15).map { $0.identifier.isEmpty ? $0.label : $0.identifier }
            print("[PROBE-DIAG] texts=\(texts)")
            print("[PROBE-DIAG] buttons=\(buttons)")
        }
        XCTAssertTrue(found, "首页地址卡片未出现")

        let address = label.label.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[PUSH-ADDRESS-BEGIN]\(address)[PUSH-ADDRESS-END]")

        // 备用通道：点复制按钮，从剪贴板兜底（处理“允许粘贴”弹窗）
        var viaPasteboard = ""
        let copyButton = app.buttons["home.token_card.copy_button"]
        if copyButton.waitForExistence(timeout: 5) {
            copyButton.tap()
            usleep(800_000)
            dismissSystemAlerts()
            usleep(500_000)
            viaPasteboard = UIPasteboard.general.string ?? ""
            print("[PUSH-ADDRESS-PB]\(viaPasteboard)[PUSH-ADDRESS-PB-END]")
        }

        let final = viaPasteboard.isEmpty ? address : viaPasteboard
        XCTAssertTrue(final.hasPrefix("http"), "地址不是 URL: \(final)")
        print("[PUSH-ADDRESS-BEGIN]\(final)[PUSH-ADDRESS-END]")
    }

    /// 首页「我的应用」区块截图：核对离线应用的独立图标是否渲染
    func testScreenshotHomeAppsSection() throws {
        let app = XCUIApplication()
        app.launch()

        dismissSystemAlerts()
        let homeTab = app.tabBars.buttons["首页"]
        if homeTab.waitForExistence(timeout: 8) {
            homeTab.tap()
        }

        // 应用磁贴是按钮（identifier = pwaHome.app.<appId>），直接定位
        let tile = app.buttons["pwaHome.app.dev.drel.data-template"]
        var found = tile.waitForExistence(timeout: 15)
        var scrolls = 0
        while found && !tile.isHittable && scrolls < 8 {
            app.swipeUp()
            scrolls += 1
            usleep(400_000)
        }
        XCTAssertTrue(tile.exists, "首页未找到应用磁贴（pwaHome.app.*）")

        sleep(3) // 给图标异步下载/加载留时间
        let shot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("home-apps-section.png")
        try? shot.pngRepresentation.write(to: url)
        print("[Screenshot] Saved to \(url.path)")

        let tiles = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'pwaHome.app.dev'"))
            .allElementsBoundByIndex.prefix(6).map { $0.label }
        print("[HOME-APPS]\(tiles)")
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "home-apps-section.png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 触发网关重验证（拉新清单+离线包），回首页截图确认独立图标
    func testRefreshGatewayAndScreenshotApps() throws {
        let app = XCUIApplication()
        app.launchEnvironment["WBK_GATEWAY_UI_PAYLOAD"] =
            #"{"id":"drel-gateway","name":"Drel Gateway","baseURL":"https://api.drel.app","healthPath":"/health","manifestPath":"/api/v1/html-apps","publicKeyID":"gw-2026-09-15","publicKey":"M3FVnjzVa8bjFQ-VtDov_mvYrik6c-DGSaRm-wdcLzY"}"#
        app.launch()

        dismissSystemAlerts()

        // 打开 手册与调试 → 管理自有服务
        let guide = app.buttons["pwaHome.guideAndDebug"]
        var prescroll = 0
        while !guide.exists && prescroll < 8 {
            app.swipeUp()
            prescroll += 1
        }
        XCTAssertTrue(guide.waitForExistence(timeout: 10), "首页没有 手册与调试")
        guide.tap()

        let manage = app.sheets.buttons["管理自有服务"].firstMatch
        if !manage.waitForExistence(timeout: 6) {
            app.buttons["管理自有服务"].firstMatch.tap()
        } else {
            manage.tap()
        }

        // 验证配置 → 拉取新清单（新 webManifest 摘要）→ 启用
        let validate = app.buttons["gateway.validate"]
        XCTAssertTrue(validate.waitForExistence(timeout: 8), "网关导入页应预填")
        var verified = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'verified'")
        ).firstMatch
        var attempts = 0
        while !verified.exists && attempts < 2 {
            attempts += 1
            dismissSystemAlerts()
            var hitScrolls = 0
            while validate.exists && !validate.isHittable && hitScrolls < 6 {
                app.swipeUp()
                hitScrolls += 1
                usleep(400_000)
            }
            if validate.isHittable {
                validate.tap()
            } else {
                validate.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            if !verified.waitForExistence(timeout: 45) {
                let texts = app.staticTexts.allElementsBoundByIndex.prefix(15).map { $0.label }
                print("[REFRESH-DIAG] attempt \(attempts) texts=\(texts)")
                dismissSystemAlerts()
            }
        }
        XCTAssertTrue(verified.exists, "验证报告未渲染")

        let activate = app.buttons["启用此网关"]
        var activateScrolls = 0
        while !activate.exists && activateScrolls < 10 {
            app.swipeUp()
            activateScrolls += 1
            usleep(400_000)
        }
        XCTAssertTrue(activate.waitForExistence(timeout: 10), "启用按钮未出现")
        activate.tap()
        _ = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "已启用")
        ).firstMatch.waitForExistence(timeout: 10)

        // 回首页截图
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let homeTab = app.tabBars.buttons["首页"]
        if homeTab.waitForExistence(timeout: 6) { homeTab.tap() }

        let tile = app.buttons["pwaHome.app.dev.drel.data-template"]
        var scrolls = 0
        while tile.exists && !tile.isHittable && scrolls < 8 {
            app.swipeUp()
            scrolls += 1
            usleep(400_000)
        }
        sleep(4) // 图标异步下载
        let shot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("home-apps-refreshed.png")
        try? shot.pngRepresentation.write(to: url)
        print("[Screenshot] Saved to \(url.path)")
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "home-apps-refreshed.png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 逐个应用更新离线包（显式动作），回首页截图确认新独立图标
    func testUpdateOfflinePackagesAndScreenshot() throws {
        let app = XCUIApplication()
        app.launch()

        dismissSystemAlerts()
        let homeTab = app.tabBars.buttons["首页"]
        if homeTab.waitForExistence(timeout: 8) { homeTab.tap() }

        for appID in ["dev.drel.data-template", "dev.drel.offline-network-demo"] {
            let tile = app.buttons["pwaHome.app.\(appID)"]
            var found = tile.waitForExistence(timeout: 15)
            var scrolls = 0
            while found && !tile.isHittable && scrolls < 8 {
                app.swipeUp()
                scrolls += 1
                usleep(400_000)
            }
            guard found else {
                print("[OFFLINE-UPDATE] tile missing: \(appID)")
                continue
            }
            tile.tap()

            // ActionSheet：v2 已装、网关是 v3 → 按钮应为「下载离线包」或「更新离线包」
            let action = app.sheets.buttons.matching(
                NSPredicate(format: "label CONTAINS '离线包'")
            ).firstMatch
            if action.waitForExistence(timeout: 6) {
                print("[OFFLINE-UPDATE] \(appID) → tap \(action.label)")
                action.tap()
                // 等待 HUD（成功=准备完成 / 失败=暂不可用），抓实际文案辅助诊断
                var hudText = "(no-hud)"
                for _ in 0..<15 {
                    usleep(2_000_000)
                    let huds = app.staticTexts.matching(
                        NSPredicate(format: "label CONTAINS '离线包'")
                    ).allElementsBoundByIndex
                    if let hit = huds.first(where: { $0.label.contains("准备完成") || $0.label.contains("暂不可用") }) {
                        hudText = hit.label
                        break
                    }
                }
                print("[OFFLINE-UPDATE-HUD] \(appID): \(hudText)")
                sleep(2)
            } else {
                print("[OFFLINE-UPDATE] \(appID) → 无离线包动作")
                app.swipeDown()
            }
        }

        sleep(3) // 元数据替换 + 图标下载
        let homeTab2 = app.tabBars.buttons["首页"]
        if homeTab2.waitForExistence(timeout: 6) { homeTab2.tap() }
        let tile = app.buttons["pwaHome.app.dev.drel.data-template"]
        var scrolls = 0
        while tile.exists && !tile.isHittable && scrolls < 8 {
            app.swipeUp()
            scrolls += 1
            usleep(400_000)
        }
        sleep(4)
        let shot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("home-apps-v3-icons.png")
        try? shot.pngRepresentation.write(to: url)
        print("[Screenshot] Saved to \(url.path)")
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "home-apps-v3-icons.png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
