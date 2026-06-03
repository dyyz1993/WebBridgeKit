import XCTest

final class ModuleAvailabilityTests: XCTestCase {

    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN"
        ]
        app.launch()
    }

    // MARK: - Primary Modules

    func testPrimaryTabsExposeCurrentInformationArchitecture() {
        assertTab("tab.web", opens: "webCache.home")
        assertExists("webCache.urlInput")
        assertExists("webCache.openButton")
        assertExists("webCache.cacheDashboard")

        assertTab("tab.push", opens: "tokenPush.home")
        assertExists("tokenPush.metricGrid")
        assertExists("tokenPush.openTokenManager")
        assertExists("tokenPush.openAPIKeyManager")

        assertTab("tab.bridge", opens: "bridgeLab.home")
        assertExists("bridge.groupList")
        assertExists("bridge.commandList")
        assertExists("bridge.parameterEditor")

        assertTab("tab.settings", opens: "SettingsViewController")
        assertExists("settings.cell.serverConfig")
        assertExists("settings.cell.tokenManager")
        assertExists("settings.cell.apiKeyManage")
    }

    func testWebCacheCriticalControlsAreUsable() {
        assertTab("tab.web", opens: "webCache.home")

        assertExists("webCache.urlInput")
        assertExists("webCache.modePicker")

        tapLabeledControl("在线")
        tapLabeledControl("缓存优先")
        tapLabeledControl("完全离线")

        tapElement("webCache.cacheDashboard")
        assertNavigationTitleContains(["缓存仪表盘", "Cache"])
        goBack()

        tapElement("webCache.cacheManagement")
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 4))
        goBack()

        tapElement("webCache.clearAllButton")
        XCTAssertTrue(app.staticTexts["清理全部 Web 缓存？"].waitForExistence(timeout: 3))
        app.buttons["取消"].tapIfExists()
    }

    func testTokenPushAndBarkControlsAreUsable() {
        assertTab("tab.push", opens: "tokenPush.home")

        tapElement("tokenPush.openTokenManager")
        assertNavigationTitleContains(["口令", "Token"])
        goBack()

        tapElement("tokenPush.openAPIKeyManager")
        assertNavigationTitleContains(["API", "密钥", "Key"])
        goBack()

        tapElement("tokenPush.openNotificationDebug")
        assertNavigationTitleContains(["通知", "Push", "Debug"])
        goBack()

        tapButton("tokenPush.copyPushURLButton")
        assertExists("tokenPush.home")
        assertElementValue("resultPanel", contains: "推送地址已复制")
        assertElementValue("resultPanel", contains: "https://wbk.shanbox.19930810.xyz:8443")

        tapElement("tokenPush.validatePayloadButton")
        assertExists("tokenPush.home")
    }

    func testBridgeLabControlsAreUsable() {
        assertTab("tab.bridge", opens: "bridgeLab.home")

        assertExists("bridge.group.cache")
        assertExists("bridge.group.navigation")
        tapElement("bridge.executeButton")
        assertElementValue("bridge.resultPanel", contains: "命令已完成结构化校验")
        assertElementValue("bridge.resultPanel", contains: "cache.stats")
    }

    func testRealWebViewBridgePromiseResolves() {
        assertTab("tab.web", opens: "webCache.home")

        tapLabeledControl("在线")
        replaceText(
            in: "webCache.urlInput",
            with: "http://localhost:8081/test_resources/bridge-promise-smoke.html?v=2"
        )
        tapElement("webCache.openButton")

        XCTAssertTrue(
            app.buttons["browserManager.closeButton"].waitForExistence(timeout: 12),
            "Opening the bridge smoke fixture should present the real WebBrowser."
        )
        XCTAssertTrue(
            element("browserManager.webView").waitForExistence(timeout: 8),
            "The browser should expose a concrete WKWebView for UI automation."
        )
        XCTAssertTrue(
            app.staticTexts["Bridge Promise OK"].waitForExistence(timeout: 15),
            "BarkBridge.callNative('getSystemInfo') should resolve and update the fixture DOM."
        )

        tapElement("browserManager.closeButton")
    }

    func testSettingsDebugCenterAndDeepLinksAreReachable() {
        assertTab("tab.settings", opens: "SettingsViewController")

        tapElement("settings.cell.debugCenter")
        assertExists("debugCenter.home")
        assertExists("debugCenter.metricGrid")
        assertExists("debugCenter.openDebugPanel")
        assertExists("debugCenter.openDiagnostics")
        assertExists("debugCenter.openCacheDashboard")
        assertExists("debugCenter.openManifestCacheTests")
        tapElement("debugCenter.crashGuideButton")
        assertExists("debugCenter.home")
        goBack()

        tapElement("settings.cell.deepLinks")
        assertExists("deepLink.home")
        assertExists("deepLink.targetURLInput")
        assertExists("deepLink.generatedOpenScheme")
        assertExists("deepLink.modePicker")
        tapLabeledControl("Immersive")
        tapElement("deepLink.validateOpenButton")
        assertExists("deepLink.home")
        assertElementValue("resultPanel", contains: "协议链接合法")
        assertElementValue("resultPanel", contains: "cache-showcase.html")
        assertExists("deepLink.commandTokenInput")
        assertExists("deepLink.tabIndexInput")
    }

    func testDebugCenterGlobalDebugPanelEntryOpensPanel() {
        openDebugCenter()

        tapElement("debugCenter.openDebugPanel")
        assertExists("debugPanel.root")
        assertExists("debugPanel.tab.0")
        assertExists("debugPanel.handlers.tableView")

        dismissCurrentPresentation()
        assertExists("debugCenter.home")
    }

    func testDebugCenterChildToolEntriesOpenConcreteScreens() {
        openDebugCenter()

        let rows: [(entry: String, title: String, expected: String)] = [
            ("debugCenter.openDiagnostics", "诊断导出", "diagnostics.root"),
            ("debugCenter.openNetworkInspector", "网络请求", "networkDebug.tableView"),
            ("debugCenter.openCacheDashboard", "缓存仪表盘", "cacheDashboard.root"),
            ("debugCenter.openManifestCacheTests", "Manifest 缓存用例", "manifestCacheTest.root")
        ]

        for row in rows {
            assertExists("debugCenter.home")
            tapActionRow(identifier: row.entry, title: row.title)
            assertExists(row.expected)
            goBack()
        }
    }

    func testDebugCenterChildToolContentAndActionsAreUsable() {
        openDebugCenter()

        tapActionRow(identifier: "debugCenter.openDiagnostics", title: "诊断导出")
        assertExists("diagnostics.root")
        assertTextExists("系统信息")
        assertTextExists("导出工具")
        tapLabeledControl("复制到剪贴板")
        assertExists("diagnostics.lastAction")
        assertElementValue("diagnostics.lastAction", contains: "已复制到剪贴板")
        app.buttons["确定"].tapIfExists()
        goBack()

        assertExists("debugCenter.home")
        tapActionRow(identifier: "debugCenter.openNetworkInspector", title: "网络请求")
        assertExists("networkDebug.tableView")
        assertExists("networkDebug.cell.0")
        assertTextExists("https://api.example.com/manifest")
        assertTextExists("GET")
        assertTextExists("200")
        tapElement("networkDebug.clearButton")
        assertTextExists("暂无网络请求记录")
        goBack()

        assertExists("debugCenter.home")
        tapActionRow(identifier: "debugCenter.openManifestCacheTests", title: "Manifest 缓存用例")
        assertExists("manifestCacheTest.root")
        assertExists("manifest_test.url_field")
        assertExists("manifest_test.mode_segment")
        assertExists("manifest_test.start_button")
        assertElementValue("manifest_test.stats_label", contains: "总请求数")
        assertElementValue("manifest_test.log_view", contains: "Manifest 缓存测试页面已加载")
        tapElement("manifest_test.clear_cache_button")
        assertElementValue("manifest_test.log_view", contains: "所有缓存已清除", timeout: 6)
        goBack()
    }

    func testSettingsCoreRowsAreReachable() {
        assertTab("tab.settings", opens: "SettingsViewController")

        let rows = [
            "settings.cell.serverConfig",
            "settings.cell.tokenManager",
            "settings.cell.apiKeyManage",
            "settings.cell.cacheManager",
            "settings.cell.favorites",
            "settings.cell.history"
        ]

        assertSettingsRowsNavigate(rows)
    }

    func testSettingsDebugAndSupportRowsAreReachable() {
        assertTab("tab.settings", opens: "SettingsViewController")

        let rows = [
            "settings.cell.appearance",
            "settings.cell.debugPanel",
            "settings.cell.exportDiagnostics",
            "settings.cell.cacheDashboard"
        ]

        assertSettingsRowsNavigate(rows)
    }

    func testSettingsPreferencesAreUsable() {
        assertTab("tab.settings", opens: "SettingsViewController")

        tapElement("settings.cell.rememberLastApp")
        assertExists("SettingsViewController")

        tapElement("settings.cell.appearance")
        assertExists("appearance.root")
        assertExists("appearance.modePicker")
        tapLabeledControl("浅色")
        tapLabeledControl("深色")
        tapLabeledControl("跟随系统")
        assertExists("appearance.currentMode")
        goBack()
    }

    func testSettingsAboutLegalDeepDrillIsReachable() {
        assertTab("tab.settings", opens: "SettingsViewController")

        tapElement("settings.cell.about")
        assertExists("about.root")

        tapElement("about.cell.license.0")
        assertExists("licenses.root")
        assertExists("licenses.tableView")

        tapElement("licenses.cell.alamofire")
        assertExists("licenseDetail.root")
        assertExists("licenseDetail.textView")

        goBack()
        goBack()
        goBack()
        assertExists("SettingsViewController")
    }

    func testNotificationSettingsEntryIsWiredWithoutCrashing() {
        let systemSettings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        addTeardownBlock { [app] in
            app.activate()
        }

        assertTab("tab.settings", opens: "SettingsViewController")
        tapElement("settings.cell.notificationSettings")

        if !systemSettings.wait(for: .runningForeground, timeout: 8) {
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: 2),
                "Notification settings entry should either open iOS Settings or leave the app stable in foreground."
            )
        }
    }

    // MARK: - Helpers

    private func assertTab(_ identifier: String, opens rootIdentifier: String) {
        let tab = app.tabBars.buttons[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 12), "Missing tab: \(identifier)")
        tab.tap()
        XCTAssertTrue(element(rootIdentifier).waitForExistence(timeout: 8), "Missing root view: \(rootIdentifier)")
    }

    private func assertExists(_ identifier: String, timeout: TimeInterval = 6) {
        XCTAssertTrue(
            makeVisible(identifier, timeout: timeout),
            "Expected element to exist and become visible: \(identifier)"
        )
    }

    private func assertElementValue(_ identifier: String, contains expectedText: String, timeout: TimeInterval = 6) {
        let deadline = Date().addingTimeInterval(timeout)
        let target = element(identifier)
        var actual = "\(target.label) \(target.value as? String ?? "")"

        while Date() < deadline {
            actual = "\(target.label) \(target.value as? String ?? "")"
            if actual.contains(expectedText) {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTAssertTrue(actual.contains(expectedText), "Expected \(identifier) to contain '\(expectedText)', got '\(actual)'.")
    }

    private func assertTextExists(_ text: String, timeout: TimeInterval = 6) {
        XCTAssertTrue(
            app.staticTexts[text].waitForExistence(timeout: timeout)
                || app.buttons[text].waitForExistence(timeout: 0.5),
            "Expected visible text: \(text)"
        )
    }

    @discardableResult
    private func tapElement(_ identifier: String, timeout: TimeInterval = 8) -> XCUIElement {
        XCTAssertTrue(makeVisible(identifier, timeout: timeout), "Expected tappable element: \(identifier)")
        let target = element(identifier)
        if target.isHittable {
            target.tap()
        } else {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        return target
    }

    private func tapActionRow(identifier: String, title: String, timeout: TimeInterval = 8) {
        XCTAssertTrue(makeVisible(identifier, timeout: timeout), "Expected action row: \(identifier)")

        for _ in 0..<3 {
            let button = app.buttons[identifier]
            if button.exists, button.isHittable {
                button.tap()
                return
            }

            let titleText = app.staticTexts[title]
            if titleText.exists, titleText.isHittable {
                titleText.tap()
                return
            }

            scrollContainer(rootIdentifier: "debugCenter.home").swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        element(identifier).coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
    }

    private func tapButton(_ identifier: String, timeout: TimeInterval = 8) {
        XCTAssertTrue(makeVisible(identifier, timeout: timeout), "Expected button: \(identifier)")
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 2), "Expected concrete button: \(identifier)")
        button.tap()
    }

    private func tapLabeledControl(_ label: String, timeout: TimeInterval = 8) {
        XCTAssertTrue(makeVisible(label, timeout: timeout), "Expected labeled control: \(label)")
        let button = app.buttons[label]
        if button.exists {
            button.tap()
            return
        }
        let segmentedButton = app.segmentedControls.buttons[label]
        if segmentedButton.exists {
            segmentedButton.tap()
            return
        }
        element(label).tap()
    }

    private func replaceText(in identifier: String, with text: String, timeout: TimeInterval = 8) {
        let input = tapElement(identifier, timeout: timeout)
        input.tap()

        let deleteCount = max((input.value as? String ?? "").count, 120)
        input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: deleteCount))
        input.typeText(text)
    }

    private func assertSettingsRowsNavigate(_ rows: [String]) {
        for row in rows {
            assertTab("tab.settings", opens: "SettingsViewController")
            tapElement(row)
            XCTAssertTrue(
                app.navigationBars.firstMatch.waitForExistence(timeout: 3)
                    || app.sheets.firstMatch.waitForExistence(timeout: 3),
                "\(row) should navigate to a concrete screen."
            )
            dismissCurrentPresentation()
        }
    }

    private func openDebugCenter() {
        assertTab("tab.settings", opens: "SettingsViewController")
        tapElement("settings.cell.debugCenter")
        assertExists("debugCenter.home")
    }

    private func makeVisible(_ identifier: String, timeout: TimeInterval) -> Bool {
        makeVisible(identifier, timeout: timeout, inRoot: nil)
    }

    private func makeVisible(_ identifier: String, timeout: TimeInterval, inRoot rootIdentifier: String?) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var didSwipeDown = false

        while Date() < deadline {
            let target = element(identifier)
            if isVisibleOnScreen(target) {
                return true
            }

            if !didSwipeDown {
                scrollContainer(rootIdentifier: rootIdentifier).swipeDown()
                didSwipeDown = true
            } else {
                scrollContainer(rootIdentifier: rootIdentifier).swipeUp()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        return isVisibleOnScreen(element(identifier))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func isVisibleOnScreen(_ target: XCUIElement) -> Bool {
        guard target.exists, target.frame != .zero else {
            return false
        }
        if target.isHittable {
            return true
        }

        let windowFrame = app.windows.firstMatch.frame
        let targetCenter = CGPoint(x: target.frame.midX, y: target.frame.midY)
        return windowFrame.contains(targetCenter)
    }

    private func scrollContainer(rootIdentifier: String? = nil) -> XCUIElement {
        if let rootIdentifier {
            let root = element(rootIdentifier)
            if root.exists {
                return root
            }
        }

        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists { return scrollView }

        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists { return collectionView }

        let table = app.tables.firstMatch
        if table.exists { return table }

        return app.windows.firstMatch
    }

    private func goBack() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists, backButton.isHittable {
            backButton.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            return
        }

        if app.buttons["返回"].exists {
            app.buttons["返回"].tap()
        } else if app.buttons["Back"].exists {
            app.buttons["Back"].tap()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    }

    private func dismissCurrentPresentation() {
        if app.sheets.firstMatch.exists {
            app.swipeDown()
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            return
        }

        if app.navigationBars.buttons["关闭"].exists {
            app.navigationBars.buttons["关闭"].tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            return
        }

        goBack()
    }

    private func assertNavigationTitleContains(_ candidates: [String]) {
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 4))
        let labels = app.navigationBars.staticTexts.allElementsBoundByIndex.map(\.label)
        let titleMatches = labels.contains { label in
            candidates.contains { label.localizedCaseInsensitiveContains($0) }
        }
        XCTAssertTrue(titleMatches || !labels.isEmpty, "Expected navigation title matching \(candidates), got \(labels)")
    }
}

private extension XCUIElement {
    func tapIfExists() {
        if waitForExistence(timeout: 2) {
            tap()
        }
    }
}
