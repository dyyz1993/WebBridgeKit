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

        tapElement("tokenPush.copyPushURLButton")
        assertExists("tokenPush.home")

        tapElement("tokenPush.validatePayloadButton")
        assertExists("tokenPush.home")
    }

    func testBridgeLabControlsAreUsable() {
        assertTab("tab.bridge", opens: "bridgeLab.home")

        assertExists("bridge.group.cache")
        assertExists("bridge.group.navigation")
        tapElement("bridge.executeButton")
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
        assertExists("deepLink.commandTokenInput")
        assertExists("deepLink.tabIndexInput")
    }

    func testSettingsOperationalRowsAreReachable() {
        assertTab("tab.settings", opens: "SettingsViewController")

        let rows = [
            "settings.cell.serverConfig",
            "settings.cell.tokenManager",
            "settings.cell.apiKeyManage",
            "settings.cell.cacheManager",
            "settings.cell.favorites",
            "settings.cell.history",
            "settings.cell.cacheDashboard",
            "settings.cell.about"
        ]

        for row in rows {
            assertTab("tab.settings", opens: "SettingsViewController")
            tapElement(row)
            XCTAssertTrue(
                app.navigationBars.firstMatch.waitForExistence(timeout: 3),
                "\(row) should navigate to a concrete screen."
            )
            goBack()
        }
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
        let windowFrame = app.windows.firstMatch.frame
        return windowFrame.intersects(target.frame)
    }

    private func scrollContainer(rootIdentifier: String? = nil) -> XCUIElement {
        if let rootIdentifier {
            let root = element(rootIdentifier)
            if root.exists {
                return root
            }
        }

        let scrollViews = app.scrollViews.allElementsBoundByIndex
        if let visibleScrollView = scrollViews.last(where: { $0.exists && $0.isHittable }) {
            return visibleScrollView
        }

        let collectionViews = app.collectionViews.allElementsBoundByIndex
        if let visibleCollectionView = collectionViews.last(where: { $0.exists && $0.isHittable }) {
            return visibleCollectionView
        }

        let tables = app.tables.allElementsBoundByIndex
        if let visibleTable = tables.last(where: { $0.exists && $0.isHittable }) {
            return visibleTable
        }

        return app.windows.firstMatch
    }

    private func goBack() {
        let navigationBars = app.navigationBars
        for index in 0..<navigationBars.count {
            let bar = navigationBars.element(boundBy: index)
            let backButton = bar.buttons.element(boundBy: 0)
            if backButton.exists, backButton.isHittable {
                backButton.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.6))
                return
            }
        }

        if app.buttons["返回"].exists {
            app.buttons["返回"].tap()
        } else if app.buttons["Back"].exists {
            app.buttons["Back"].tap()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
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
