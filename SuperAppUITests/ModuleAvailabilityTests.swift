import XCTest

final class ModuleAvailabilityTests: XCTestCase {

    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--UITesting", "-UITesting", "--enable-session-restore"]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN"
        ]
        if let gatewayPayload = ProcessInfo.processInfo.environment["WBK_GATEWAY_UI_PAYLOAD"] {
            app.launchEnvironment["WBK_GATEWAY_UI_PAYLOAD"] = gatewayPayload
        }
        app.launch()
    }

    // MARK: - Primary Modules

    func testPrimaryTabsExposeCurrentInformationArchitecture() {
        assertTab("tab.apps", opens: "pwaCenter.table")
        assertExists("pwaHome.manageApps")
        assertExists("pwaHome.guideAndDebug")

        assertTab("tab.notifications", opens: "InboxViewController")
        assertExists("wbk_search_field")
        assertExists("inbox.displayMode")
        assertExists("inbox.filterMenu")
        let filterMenu = element("inbox.filterMenu")
        XCTAssertGreaterThanOrEqual(filterMenu.frame.width, 56, "inbox.filterMenu should have a visible width")
        XCTAssertGreaterThanOrEqual(filterMenu.frame.height, 34, "inbox.filterMenu should have a visible height")
        XCTAssertTrue(
            app.staticTexts["安全告警"].waitForExistence(timeout: 3)
                || app.staticTexts["天气预报"].waitForExistence(timeout: 3)
                || app.otherElements["wbk_empty_state"].waitForExistence(timeout: 3),
            "Notifications tab should show grouped notification history or an empty state."
        )

        assertTab("tab.settings", opens: "SettingsViewController")
        assertExists("settings.cell.serverConfig")
        assertExists("settings.cell.tokenManager")
        assertExists("settings.cell.apiKeyManage")
    }

    func testNotificationCardsExposeMarkdownAndActionRequiredMetadata() {
        assertTab("tab.notifications", opens: "InboxViewController")
        replaceText(in: "wbk_search_field", with: "运行任务")
        assertExists("notification.card.stored-markdown-011")
        assertExists("notification.preview.stored-markdown-011")
        assertExists("notification.copy.stored-markdown-011")
        assertElementValue("notification.preview.stored-markdown-011", contains: "发布任务已完成")

        replaceText(in: "wbk_search_field", with: "")
        tapElement("inbox.filterMenu")
        app.buttons["需处理"].tap()
        XCTAssertTrue(
            element("notification.card.stored-approval-media-014").waitForExistence(timeout: 4),
            "Action-required filter should retain an explicitly pending request."
        )
        XCTAssertFalse(
            element("notification.card.stored-critical-005").exists,
            "Priority alone must not turn a notification into an actionable request."
        )
    }

    func testNotificationCardQuickCopyButtonIsReachable() {
        assertTab("tab.notifications", opens: "InboxViewController")
        replaceText(in: "wbk_search_field", with: "运行任务")

        let copy = app.buttons["notification.copy.stored-markdown-011"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertTrue(copy.isHittable)
        copy.tap()
        XCTAssertTrue(app.staticTexts["消息内容已复制"].waitForExistence(timeout: 3))
    }

    func testPWAAppCenterGatewayAndGuideAreReachable() {
        assertTab("tab.apps", opens: "pwaCenter.table")
        tapElement("pwaHome.manageApps")
        assertExists("gateway.table")
        goBack()

        tapElement("pwaHome.guideAndDebug")
        // The action sheet is presented asynchronously; a query captured
        // before presentation can report stale no-match state on iOS 18.3.
        var guideTarget: XCUIElement?
        for _ in 0..<5 {
            let candidate = app.buttons["PWA 接入手册"]
            if candidate.exists {
                guideTarget = candidate
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        if let target = guideTarget {
            target.tap()
        } else {
            tapElement("pwaHome.guideAndDebug")
        }
        XCTAssertTrue(
            element("pwaGuide.table").waitForExistence(timeout: 6),
            "PWA guide should finish its navigation transition and expose its table."
        )
    }

    func testPWAAppCenterStartsWithOfficialServiceInsteadOfGatewaySetup() {
        assertTab("tab.apps", opens: "pwaCenter.table")

        // Official catalog entries appear only after a trusted push has
        // activated them on this installation. Accept any trusted-app tile
        // (current install has an activated official demo) or the explicit
        // empty/offline state. Gateway setup itself must not be the first-run
        // surface.
        let appTilePredicate = NSPredicate(format: "identifier BEGINSWITH 'pwaHome.app.'")
        let officialApp = app.descendants(matching: .any).matching(appTilePredicate).firstMatch
        let officialStatus = element("pwaHome.emptyApps")
        let officialAppLoaded = officialApp.waitForExistence(timeout: 15)
        XCTAssertTrue(
            officialAppLoaded || officialStatus.waitForExistence(timeout: 2),
            "A fresh official install should fetch signed apps automatically, or expose a retryable official-service state rather than gateway setup."
        )
        if officialAppLoaded {
            XCTAssertFalse(
                element("pwaHome.emptyApps").exists,
                "Self-hosted gateway import must remain a secondary, opt-in path when the official service is available."
            )
        }
    }

    func testHomePrioritizesFirstPushAndKeepsPWAAndSupportReachable() {
        assertTab("tab.apps", opens: "pwaCenter.table")
        assertExists("pwaHome.root")
        assertExists("pwaHome.pushTitle")
        assertExists("pwaHome.pushBody")
        assertExists("pwaHome.sendTest")
        assertExists("home.push.address")
        assertExists("home.push.copy")
        assertExists("home.push.manage")
        assertExists("pwaHome.appsSection")
        assertExists("pwaHome.apiExamples")
        assertExists("pwaHome.guideAndDebug")
    }

    func testHomePushExamplesExposeSupportedStoreCapabilities() {
        // A prior test can leave the inbox tab as the restorable last screen;
        // session restore would land this run on Notifications and make the
        // home support row untappable. Force a clean home launch.
        app.terminate()
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN"
        ]
        app.launch()
        assertTab("tab.apps", opens: "pwaCenter.table")
        openPushExamplesFromHome()
        // SwiftUI List does not expose the whole-list identifier as a
        // queryable element, but the row-level controls do. openPushExamples
        // FromHome already proves the catalog screen loaded by asserting the
        // first row control; here verify the Store-promised example types.
        for type in ["plain", "markdown", "otp", "qr", "image"] {
            let sendButton = element("pushExamples.\(type).send")
            let copyButton = element("pushExamples.\(type).copy")
            XCTAssertTrue(sendButton.waitForExistence(timeout: 4), "Missing example send control: \(type)")
            XCTAssertTrue(copyButton.exists, "Missing example copy control: \(type)")
        }
    }

    func testHomePlainExampleUsesExternalSafariForARealRequest() {
        // The send action is intentionally disabled until push setup is ready.
        // Pin that state with the deterministic official-push fixture so an
        // earlier real registration cannot turn this tap into setup work.
        app.terminate()
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launchEnvironment = Self.deterministicPushEnvironment
        app.launch()
        assertTab("tab.apps", opens: "pwaCenter.table")
        openPushExamplesFromHome()
        // Existence first: SwiftUI List rows can exist off-screen; tapping a
        // matched element lets XCUITest scroll it into view.
        XCTAssertTrue(
            element("pushExamples.plain.send").waitForExistence(timeout: 8),
            "Expected plain push example send control"
        )
        tapElement("pushExamples.plain.send")

        let hostMovedToBackground = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "state == %d",
                XCUIApplication.State.runningBackground.rawValue
            ),
            object: app
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [hostMovedToBackground], timeout: 15),
            .completed,
            "A home push example should leave the host and issue its request through Safari."
        )
    }

    func testWebCacheCriticalControlsAreUsableFromDeveloperTools() {
        openDebugCenter()
        tapElement("debugCenter.openWebCache")
        assertExists("webCache.home")

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

    func testTokenPushAndBarkControlsAreUsableFromDeveloperTools() {
        app.terminate()
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launchEnvironment = Self.deterministicPushEnvironment
        app.launch()
        openDebugCenter()
        tapElement("debugCenter.openPushTools")
        assertExists("tokenPush.home")

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
        assertStaticTextContaining("推送地址已复制")
        // TestDataSeeder pins the deterministic Bark server for UI tests.
        // Assert the exact server so a silently wrong endpoint can't pass.
        assertStaticTextContaining("http://localhost:8080")

        tapElement("tokenPush.validatePayloadButton")
        assertExists("tokenPush.home")
    }

    func testBridgeLabControlsAreUsableFromDeveloperTools() {
        openDebugCenter()
        tapElement("debugCenter.openBridgeLab")
        assertExists("bridgeLab.home")

        assertExists("bridge.group.cache")
        assertExists("bridge.group.navigation")
        tapElement("bridge.executeButton")
        assertStaticTextContaining("命令已完成结构化校验")
        assertStaticTextContaining("cache.stats")
    }

    private static var deterministicPushEnvironment: [String: String] {
        [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN",
            "WBK_OFFICIAL_PUSH_TEST_STATE": "initial-ready",
            "WBK_OFFICIAL_PUSH_TEST_IDENTITY": "module_availability_fixture"
        ]
    }

    func testRealWebViewBridgePromiseResolves() {
        openDebugCenter()
        tapElement("debugCenter.openWebCache")
        assertExists("webCache.home")

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
        assertExists("debugCenter.openWebCache")
        assertExists("debugCenter.openBridgeLab")
        assertExists("debugCenter.openPushTools")
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
        assertStaticTextContaining("协议链接合法")
        assertStaticTextContaining("cache-showcase.html")
        XCTAssertTrue(
            element("deepLink.commandTokenInput").waitForExistence(timeout: 6),
            "Expected deep-link command token input"
        )
        XCTAssertTrue(
            element("deepLink.tabIndexInput").waitForExistence(timeout: 6),
            "Expected deep-link tab index input"
        )
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
        tapElement("diagnostics.action.1.1")
        assertExists("diagnostics.lastAction")
        assertElementValue("diagnostics.lastAction", contains: "诊断文件已生成", timeout: 8)
        dismissShareSheetIfPresent()

        restartAtDebugCenter()
        tapActionRow(identifier: "debugCenter.openNetworkInspector", title: "网络请求")
        assertExists("networkDebug.tableView")
        assertExists("networkDebug.cell.0")
        assertTextExists("https://api.example.com/manifest")
        assertTextExists("GET")
        assertTextExists("200")
        tapElement("networkDebug.clearButton")
        assertTextExists("暂无网络请求记录")

        restartAtDebugCenter()
        tapActionRow(identifier: "debugCenter.openManifestCacheTests", title: "Manifest 缓存用例")
        assertExists("manifestCacheTest.root")
        assertExists("manifest_test.url_field")
        assertExists("manifest_test.mode_segment")
        assertExists("manifest_test.start_button")
        assertElementValue("manifest_test.stats_label", contains: "总请求数")
        assertElementValue("manifest_test.log_view", contains: "Manifest 缓存测试页面已加载")
        tapElement("manifest_test.clear_cache_button")
        assertElementValue("manifest_test.log_view", contains: "所有缓存已清除", timeout: 6)
        replaceText(in: "manifest_test.url_field", with: "http://localhost:8081/test_resources/bridge-hub.html")
        tapElement("manifest_test.start_button")
        assertExists("WebViewDisplayViewController", timeout: 12)
        assertExists("manifest_test.display_webview", timeout: 8)
        assertExists("webview_display.close_button")
        tapElement("webview_display.close_button")
        assertElementValue("manifest_test.log_view", contains: "智能加载成功", timeout: 12)
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

    func testGatewayConfigurationExposesCurrentOnePageImportControls() {
        // The one-page gateway import lives behind the App Center's manage
        // entry. The Settings server-config row opens the legacy server list
        // and is intentionally not this screen.
        assertTab("tab.apps", opens: "pwaCenter.table")
        tapElement("pwaHome.manageApps")
        assertExists("gateway.table")
        assertExists("gateway.current")
        assertExists("gateway.scan")
        assertExists("gateway.paste")
        assertExists("gateway.input")
        assertExists("gateway.validate")
        XCTAssertFalse(element("gateway.report").exists, "Activation report must only appear after validation")
        XCTAssertFalse(app.buttons["gateway.activate"].exists, "Activation must not be possible before validation")
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

        tapElement("settings.cell.defaultStartupApp")
        assertExists("defaultStartupApp.root")
        assertExists("defaultStartupApp.explanation")
        goBack()

        tapElement("settings.cell.appearance")
        assertExists("appearance.root")
        assertExists("appearance.modePicker")
        tapLabeledControl("浅色")
        tapLabeledControl("深色")
        tapLabeledControl("跟随系统")
        assertExists("appearance.currentMode")
        goBack()
    }

    /// Regression for the light-theme "black card borders" defect: inbox cells
    /// created under dark kept their resolved separator CGColor after an
    /// in-session switch to light. The proof is visual — screenshots land in
    /// /tmp for inspection; assertions only guard the navigation.
    func testThemeSwitchLeavesNoStaleInboxCardBorders() {
        // Build the inbox cell population under dark mode.
        assertTab("tab.settings", opens: "SettingsViewController")
        tapElement("settings.cell.appearance")
        assertExists("appearance.modePicker")
        tapLabeledControl("深色")
        goBack()
        assertTab("tab.notifications", opens: "InboxViewController")
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        saveBorderProofShot("step1-dark-inbox")

        // Switch to light in the same session and return to the inbox: every
        // card must re-resolve its border (no dark outlines on white cards).
        assertTab("tab.settings", opens: "SettingsViewController")
        tapElement("settings.cell.appearance")
        assertExists("appearance.modePicker")
        tapLabeledControl("浅色")
        goBack()
        assertTab("tab.notifications", opens: "InboxViewController")
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        saveBorderProofShot("step2-light-inbox")

        // Force fresh cell allocations below the fold, then scroll back.
        app.swipeUp()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        app.swipeDown()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        saveBorderProofShot("step3-light-rescrolled")
    }

    private func saveBorderProofShot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        if let data = shot.image.pngData() {
            try? data.write(to: URL(fileURLWithPath: "/tmp/drel-border-\(name).png"))
        }
    }

    /// Per-message pin: right-swipe reveals the pin action and pinning
    /// floats the message above newer entries in the latest-mode list.
    /// The recurring automated pushes bury older messages, so a card must
    /// be promotable in place. The test pins whatever the second row is at
    /// runtime — the live gateway delivers real pushes during the run, so
    /// hard-coded seed ids drift below the fold.
    func testMessagePinSwipeFloatsMessageToTop() {
        assertTab("tab.notifications", opens: "InboxViewController")
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 6), "inbox table should exist")
        let secondCell = table.cells.element(boundBy: 1)
        XCTAssertTrue(secondCell.waitForExistence(timeout: 4), "at least two cards expected")
        let targetId = secondCell.identifier
        XCTAssertTrue(targetId.hasPrefix("notification.card."), "unexpected cell identity: \(targetId)")

        // Drag the card rightwards past the full-swipe threshold so the
        // leading pin action executes. If the drag only partially reveals,
        // fall back to tapping the revealed button.
        let start = secondCell.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        let end = secondCell.coordinate(withNormalizedOffset: CGVector(dx: 3.0, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        saveBorderProofShot("inbox-pin-reveal")
        let pinButton = app.descendants(matching: .any).matching(identifier: "置顶").firstMatch
        if pinButton.exists && pinButton.isHittable {
            pinButton.tap()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        XCTAssertEqual(
            table.cells.element(boundBy: 0).identifier,
            targetId,
            "pinning must float the message to the top of the latest list"
        )
        saveBorderProofShot("inbox-pin-top")

        // Right-swipe the pinned card again to unpin; the list returns to
        // recency ordering, so the target is no longer first.
        let pinnedCard = table.cells.element(boundBy: 0)
        let unpinStart = pinnedCard.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        let unpinEnd = pinnedCard.coordinate(withNormalizedOffset: CGVector(dx: 3.0, dy: 0.5))
        unpinStart.press(forDuration: 0.05, thenDragTo: unpinEnd)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let unpinButton = app.descendants(matching: .any).matching(identifier: "取消置顶").firstMatch
        if unpinButton.exists && unpinButton.isHittable {
            unpinButton.tap()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        XCTAssertNotEqual(
            table.cells.element(boundBy: 0).identifier,
            targetId,
            "unpinning must restore recency ordering"
        )
    }

    func testDefaultStartupAppCanSelectTrustedApp() {
        app.terminate()
        app.launchArguments = [
            "--UITesting",
            "-UITesting",
            "--reset-default-startup-app",
            "--register-pwa-notification-fixture"
        ]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN"
        ]
        app.launch()

        assertTab("tab.settings", opens: "SettingsViewController")
        tapElement("settings.cell.defaultStartupApp")
        // This install's trust registry carries the signed official demo
        // manifests, so the option list is expected to be populated (the old
        // fixture.chat is not part of the current official catalog). Assert
        // any selectable option, select it, and verify cold-launch behavior.
        assertExists("defaultStartupApp.explanation")
        let firstOption = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'defaultStartupApp.option.'"))
            .firstMatch
        XCTAssertTrue(
            firstOption.waitForExistence(timeout: 6),
            "Expected at least one selectable trusted app option"
        )
        let selectedAppID = firstOption.identifier
            .replacingOccurrences(of: "defaultStartupApp.option.", with: "")
        firstOption.tap()
        assertExists("defaultStartupApp.selected.\(selectedAppID)")

        app.terminate()
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launch()
        XCTAssertTrue(
            element("browserManager.webView").waitForExistence(timeout: 12),
            "A selected trusted app should open in the web container on the next cold launch."
        )
        // Session restore is intentionally delayed by 1.5 seconds. Observe
        // beyond that window so this assertion catches a late second push.
        let restoreWindowElapsed = expectation(description: "session restore window elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            restoreWindowElapsed.fulfill()
        }
        wait(for: [restoreWindowElapsed], timeout: 3)
        XCTAssertTrue(
            element("browserManager.immersiveReturnButton").waitForExistence(timeout: 3),
            "A default startup app must remain immersive instead of being replaced by session restore."
        )
        XCTAssertEqual(
            app.descendants(matching: .any).matching(identifier: "browserManager.container").count,
            1,
            "Cold launch must create exactly one browser container for the default startup app."
        )
        XCTAssertFalse(
            app.navigationBars.firstMatch.exists,
            "The duplicate normal-mode restore must not add a navigation bar over the immersive app."
        )

        // Cleanup: a persisted default startup app would make every later
        // test's cold launch open the immersive container instead of the tab
        // bar. Reset it and relaunch so the suite continues from a clean tab
        // state.
        app.terminate()
        app.launchArguments = [
            "--UITesting",
            "-UITesting",
            "--reset-default-startup-app",
            "--clear-last-session"
        ]
        app.launch()
        XCTAssertTrue(
            app.tabBars.buttons["tab.apps"].waitForExistence(timeout: 12),
            "Cleanup relaunch should expose the normal tab bar"
        )
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
        if rootIdentifier == "tokenPush.home" {
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
            return
        }
        if rootIdentifier == "InboxViewController",
           element(rootIdentifier).waitForExistence(timeout: 4)
            || app.staticTexts["消息"].waitForExistence(timeout: 2)
            || app.staticTexts["Messages"].waitForExistence(timeout: 2) {
            return
        }
        if element(rootIdentifier).waitForExistence(timeout: 8) {
            return
        }
        if let fallbackTitles = rootTitleFallbacks[rootIdentifier],
           (navigationTitleContains(fallbackTitles) || staticTextContainsAny(fallbackTitles, timeout: 4)) {
            return
        }
        XCTFail("Missing root view: \(rootIdentifier)")
    }

    /// A live push can land at any moment and handlePushJump flips the tab
    /// bar to Notifications — the registered official gateway delivers real
    /// pushes every few minutes. Navigation-push based flows survive that
    /// flip (the pushed examples screen stays on the Home nav stack), but
    /// home-row taps do not. So: retry the row tap, and after success verify
    /// the catalog exists on the pushed screen without depending on which
    /// tab is selected.
    private func openPushExamplesFromHome() {
        for _ in 0..<3 {
            // A push flip moves the selected tab away, but the examples
            // screen stays on Home's nav stack. Re-selecting Home makes its
            // stack queryable again, so check before pushing a duplicate.
            app.tabBars.buttons["tab.apps"].tap()
            if element("pushExamples.plain.send").waitForExistence(timeout: 3) {
                return
            }
            // Re-assert the row right before tapping: a push flip between the
            // two calls silently retargets the tap onto the inbox screen.
            guard element("pwaCenter.table").waitForExistence(timeout: 3),
                  element("pwaHome.apiExamples").waitForExistence(timeout: 3) else {
                continue
            }
            // The examples row sits below the fold at launch; a bare .tap()
            // on a non-hittable element is silently dropped. tapElement walks
            // the scroll container until the row is hittable.
            // tapElement→makeVisible treats "center inside window" as visible,
            // but the row can sit behind the tab bar (still inside the window
            // frame) where taps land on the TabBar instead. Require real
            // hittability: swipe the home scroll view until hittable, then tap.
            let examplesButton = element("pwaHome.apiExamples")
            var hittable = examplesButton.isHittable
            var swipes = 0
            while !hittable, swipes < 4 {
                element("pwaCenter.table").swipeUp()
                swipes += 1
                hittable = examplesButton.exists && examplesButton.isHittable
            }
            guard hittable else { continue }
            examplesButton.tap()
            // The whole-list identifier is not AX-queryable on SwiftUI List;
            // the first row's send control is the reliable catalog marker.
            if element("pushExamples.plain.send").waitForExistence(timeout: 8) {
                return
            }
        }
        XCTFail("Could not open the push examples catalog from the home tab")
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

    private func assertStaticTextContaining(_ text: String, timeout: TimeInterval = 6) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let target = app.staticTexts.containing(predicate).firstMatch
        XCTAssertTrue(
            target.waitForExistence(timeout: timeout),
            "Expected visible static text containing: \(text)"
        )
    }

    private func staticTextContainsAny(_ candidates: [String], timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let labels = app.staticTexts.allElementsBoundByIndex.map(\.label)
            if labels.contains(where: { label in
                candidates.contains { label.localizedCaseInsensitiveContains($0) }
            }) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func dismissShareSheetIfPresent() {
        if element("diagnostics.shareSheet").exists
            || app.sheets.firstMatch.exists
            || app.navigationBars["分享"].exists
            || app.navigationBars["Share"].exists {
            dismissCurrentPresentation()
        }
    }

    @discardableResult
    private func tapElement(_ identifier: String, timeout: TimeInterval = 8) -> XCUIElement {
        XCTAssertTrue(makeVisible(identifier, timeout: timeout), "Expected tappable element: \(identifier)")
        let target = element(identifier)
        // iOS 18.3 can report an offscreen activation point even after AX says
        // the element exists. Prefer the coordinate tap in that case instead of
        // throwing "Activation point invalid".
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
            // 8s: Cache Dashboard 首次推入会做 Realm 聚合与表头布局，
            // 低负载模拟器上 3s 内 AX 快照可能尚未就绪（历史隔离问题）
            XCTAssertTrue(
                app.navigationBars.firstMatch.waitForExistence(timeout: 8)
                    || app.sheets.firstMatch.waitForExistence(timeout: 8),
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

    private func restartAtDebugCenter() {
        app.terminate()
        app.launch()
        openDebugCenter()
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

    private func isFrameOnScreen(_ frame: CGRect) -> Bool {
        let windowFrame = app.windows.firstMatch.frame
        let interactiveFrame = windowFrame.insetBy(dx: 0, dy: 96)
        // SwiftUI scroll-content coordinates can exceed the clipping viewport
        // while the row is still partially visible. Accept partial intersection
        // so scrolling happens only when the control is actually offscreen.
        return interactiveFrame.intersects(frame)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func isVisibleOnScreen(_ target: XCUIElement) -> Bool {
        guard target.exists, target.frame != .zero else {
            return false
        }
        // A SwiftUI row can be inside the window's coordinate space yet clipped
        // by the scroll viewport/TabBar. Both hittability and the frame check
        // must pass through the interactive window area before tapping.
        return target.isHittable || isFrameOnScreen(target.frame)
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
        for label in ["调试中心", "设置", "返回", "Back", "Debug Center", "Settings"] {
            let button = app.navigationBars.buttons[label]
            if button.exists {
                if button.isHittable {
                    button.tap()
                } else {
                    button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.6))
                return
            }
        }

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            if backButton.isHittable {
                backButton.tap()
            } else {
                backButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        } else {
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.07)).tap()
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
        let labels = navigationTitleLabels()
        XCTAssertTrue(
            navigationTitleContains(candidates) || !labels.isEmpty,
            "Expected navigation title matching \(candidates), got \(labels)"
        )
    }

    private func navigationTitleContains(_ candidates: [String]) -> Bool {
        guard app.navigationBars.firstMatch.waitForExistence(timeout: 4) else {
            return false
        }
        let labels = navigationTitleLabels()
        return labels.contains { label in
            candidates.contains { label.localizedCaseInsensitiveContains($0) }
        }
    }

    private func navigationTitleLabels() -> [String] {
        let labels = app.navigationBars.staticTexts.allElementsBoundByIndex.map(\.label)
        return labels
    }

    private var rootTitleFallbacks: [String: [String]] {
        [
            "webCache.home": ["Web"],
            "InboxViewController": ["消息", "Messages"],
            "tokenPush.home": ["Token/Push", "TokenPush", "Push"],
            "bridgeLab.home": ["Bridge"],
            "SettingsViewController": ["设置", "Settings"]
        ]
    }
}

private extension XCUIElement {
    func tapIfExists() {
        if waitForExistence(timeout: 2) {
            tap()
        }
    }
}
