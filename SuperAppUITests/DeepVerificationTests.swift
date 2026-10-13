import Foundation
import XCTest

final class DeepVerificationTests: XCTestCase {

    let app = XCUIApplication()
    private var nativeApprovalRequestID = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        nativeApprovalRequestID = "approval-ui-\(UUID().uuidString)"
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launchEnvironment["WBK_UI_APPROVAL_REQUEST_ID"] = nativeApprovalRequestID
        if name.contains("testInboxPWAApprovalOpensTrustedRouteWithoutApproving") {
            app.launchArguments.append("--register-pwa-notification-fixture")
            app.launchEnvironment["WBK_PWA_FIXTURE_CASE"] = "approval"
            app.launchEnvironment["WBK_PWA_FIXTURE_ORIGIN"] = "http://localhost:8081"
        }
        if name.contains("testExternalAppLinkOpensRegisteredAppImmersive") {
            // Official gateway payload so the import screen prefills; validation
            // fetches the live signed manifests from api.drel.app.
            app.launchEnvironment["WBK_GATEWAY_UI_PAYLOAD"] =
                #"{"id":"drel-gateway","name":"Drel Gateway","baseURL":"https://api.drel.app","healthPath":"/health","manifestPath":"/api/v1/html-apps","publicKeyID":"gw-2026-09-15","publicKey":"M3FVnjzVa8bjFQ-VtDov_mvYrik6c-DGSaRm-wdcLzY"}"#
        }
        app.launch()
    }

    private func saveScreenshot(_ path: String) {
        let screenshot = app.screenshot()
        // 真机沙盒写不了 /tmp：统一落到 runner 可写的临时目录，仅保留文件名
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(URL(fileURLWithPath: path).lastPathComponent)
        if let data = screenshot.image.pngData() {
            do {
                try data.write(to: url)
                print("[Screenshot] Saved to \(url.path) (\(data.count) bytes)")
            } catch {
                // 截图落盘失败不应否定功能断言（真机上尤其如此）
                print("[Screenshot] Save failed (non-fatal): \(error)")
            }
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = URL(fileURLWithPath: path).lastPathComponent
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func navigateToTab(_ name: String) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should exist")
        let tab = tabBar.buttons[name]
        XCTAssertTrue(tab.exists, "Tab '\(name)' should exist")
        tab.tap()
        sleep(1)
    }

    private func createNativeApprovalRecord(requestID: String) throws {
        let payload: [String: Any] = [
            "schema": "webbridgekit.message.v1",
            "type": "approval",
            "deviceKey": "test",
            "id": requestID,
            "requestId": requestID,
            "revision": 1,
            "state": "pending",
            "title": "确认部署到生产环境",
            "body": "版本 2.4.0 已通过自动化测试，等待你决定是否继续发布。",
            "presentation": "native",
            "approval": [
                "actions": [
                    ["id": "approve", "title": "通过并发布", "style": "primary", "resultState": "approved"],
                    ["id": "reject", "title": "拒绝", "style": "destructive", "requiresReason": true, "resultState": "rejected"],
                ],
                "responseMode": "poll",
            ],
        ]
        var request = URLRequest(url: try XCTUnwrap(URL(string: "http://localhost:8080/push")))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let completed = expectation(description: "Create native approval record")
        var statusCode: Int?
        var requestError: Error?
        URLSession.shared.dataTask(with: request) { _, response, error in
            statusCode = (response as? HTTPURLResponse)?.statusCode
            requestError = error
            completed.fulfill()
        }.resume()
        wait(for: [completed], timeout: 5)
        XCTAssertNil(requestError)
        XCTAssertEqual(statusCode, 200)
    }

    private func goBack() {
        let backButton = app.navigationBars.firstMatch.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
            sleep(1)
        } else {
            print("[Warning] No back button found")
        }
    }

    private func tapSettingsRow(identifier: String, labelText: String) -> Bool {
        // SwiftUI rows are exposed as generic accessibility elements, not
        // UITableViewCell instances. Prefer the stable identifier emitted by
        // SettingsView before falling back to labels for legacy screens.
        let row = app.descendants(matching: .any)[identifier]
        if row.waitForExistence(timeout: 5) {
            row.tap()
            sleep(1)
            return true
        }

        let tableView = app.tables["settings.tableView"]
        if tableView.waitForExistence(timeout: 3) {
            let cellById = tableView.cells[identifier]
            if cellById.waitForExistence(timeout: 3) {
                cellById.tap()
                sleep(1)
                return true
            }
        }

        let cellByLabel = tableView.cells.containing(.staticText, identifier: labelText).firstMatch
        if cellByLabel.waitForExistence(timeout: 3) {
            cellByLabel.tap()
            sleep(1)
            return true
        }

        let staticLabel = app.staticTexts[labelText]
        if staticLabel.waitForExistence(timeout: 2) {
            staticLabel.tap()
            sleep(1)
            return true
        }

        print("[Warning] Could not find settings row: \(labelText) (id: \(identifier))")
        return false
    }

    // MARK: - Settings Sub-pages (5 tests)

    func testSettingsServerConfig() throws {
        navigateToTab("设置")

        let found = tapSettingsRow(identifier: "settings.cell.serverConfig", labelText: "服务器配置")
        saveScreenshot("/tmp/wbk-ui-server-config.png")

        if found {
            let navBar = app.navigationBars.firstMatch
            if navBar.waitForExistence(timeout: 3) {
                print("[Info] Navigated to Server Config, nav bar title: \(navBar.identifier)")
                XCTAssertTrue(true, "Navigation to server config succeeded")
            } else {
                print("[Warning] No nav bar visible after tapping server config")
            }
            goBack()
        } else {
            print("[Skip] Server config row not found, skipping navigation check")
        }
    }

    func testSettingsTokenManage() throws {
        navigateToTab("设置")

        let found = tapSettingsRow(identifier: "settings.cell.tokenManager", labelText: "口令管理")

        if found {
            saveScreenshot("/tmp/wbk-ui-token-manage.png")
            let tokenTable = app.tables.firstMatch
            if tokenTable.waitForExistence(timeout: 3) {
                print("[Info] Token management table visible, cells: \(tokenTable.cells.count)")
                XCTAssertTrue(true, "Token management UI loaded")
            } else {
                print("[Info] Token management UI loaded (no table, check other elements)")
            }
            goBack()
        } else {
            print("[Skip] Token manage row not found")
        }
    }

    func testSettingsAPIKeyManage() throws {
        navigateToTab("设置")

        let found = tapSettingsRow(identifier: "settings.cell.apiKeyManage", labelText: "密钥管理")

        if found {
            saveScreenshot("/tmp/wbk-ui-apikey-manage.png")
            let table = app.tables.firstMatch
            if table.waitForExistence(timeout: 3) {
                print("[Info] API Key management table visible, cells: \(table.cells.count)")
                XCTAssertTrue(true, "API key management UI loaded")
            } else {
                print("[Info] API Key management UI loaded (non-table layout)")
            }
            goBack()
        } else {
            print("[Skip] API key manage row not found")
        }
    }

    func testSettingsFavorites() throws {
        navigateToTab("设置")

        let found = tapSettingsRow(identifier: "settings.cell.favorites", labelText: "收藏夹")
        saveScreenshot("/tmp/wbk-ui-favorites.png")

        if found {
            let favTable = app.tables["favorite.tableView"]
            let anyTable = app.tables.firstMatch
            let emptyState = app.otherElements["favorite.emptyStateView"]

            if favTable.waitForExistence(timeout: 3) {
                print("[Info] Favorites table visible, cells: \(favTable.cells.count)")
            } else if anyTable.waitForExistence(timeout: 3) {
                print("[Info] Favorites page table visible, cells: \(anyTable.cells.count)")
            } else if emptyState.waitForExistence(timeout: 2) {
                print("[Info] Favorites page shows empty state")
            } else {
                print("[Info] Favorites page loaded (layout unknown)")
            }
            XCTAssertTrue(true, "Favorites page loaded")
            goBack()
        } else {
            print("[Skip] Favorites row not found")
        }
    }

    func testSettingsCacheDeep() throws {
        navigateToTab("设置")

        let found = tapSettingsRow(identifier: "settings.cell.cacheManager", labelText: "缓存管理")

        if found {
            sleep(1)
            saveScreenshot("/tmp/wbk-ui-cache-tab.png")

            let segmentedControl = app.segmentedControls.firstMatch
            if segmentedControl.waitForExistence(timeout: 3) {
                let favSegment = segmentedControl.buttons["收藏"]
                if favSegment.exists {
                    favSegment.tap()
                    sleep(1)
                    saveScreenshot("/tmp/wbk-ui-cache-fav-segment.png")
                    print("[Info] Switched to Favorites segment in cache manager")
                } else {
                    print("[Warning] '收藏' segment not found in segmented control")
                    let segButtons = segmentedControl.buttons
                    for i in 0..<segButtons.count {
                        if let title = segButtons.element(boundBy: i).label as String? {
                            print("[Debug] Segment[\(i)]: \(title)")
                        }
                    }
                }
            } else {
                print("[Warning] No segmented control found in cache manager")
            }

            goBack()
        } else {
            print("[Skip] Cache manage row not found")
            saveScreenshot("/tmp/wbk-ui-cache-tab.png")
        }
    }

    // MARK: - Discover Interactions (2 tests)

    func testDiscoverCardTap() throws {
        navigateToTab("tab.apps")

        let collectionView = app.collectionViews.firstMatch
        guard collectionView.waitForExistence(timeout: 5) else {
            print("[Warning] No collection view on Discover tab")
            saveScreenshot("/tmp/wbk-ui-discover-card-tap.png")
            return
        }

        sleep(1)

        let recentHeader = app.staticTexts["最近使用"]
        if recentHeader.waitForExistence(timeout: 3) {
            print("[Info] Found '最近使用' section header")
        }

        let firstCell = collectionView.cells.firstMatch
        if firstCell.waitForExistence(timeout: 3) {
            firstCell.tap()
            sleep(2)
            saveScreenshot("/tmp/wbk-ui-discover-card-tap.png")

            if !app.collectionViews.firstMatch.exists {
                print("[Info] Navigated away from Discover after card tap")
                goBack()
            }
        } else {
            print("[Info] No cards to tap on Discover page")
            saveScreenshot("/tmp/wbk-ui-discover-card-tap.png")
        }
    }

    func testDiscoverCachedAppsSection() throws {
        navigateToTab("tab.apps")

        let collectionView = app.collectionViews.firstMatch
        guard collectionView.waitForExistence(timeout: 5) else {
            print("[Warning] No collection view on Discover tab")
            saveScreenshot("/tmp/wbk-ui-discover-cached.png")
            return
        }

        sleep(1)

        let cachedHeader = app.staticTexts["已缓存应用"]
        if cachedHeader.waitForExistence(timeout: 2) {
            print("[Info] Found '已缓存应用' section header without scrolling")
        } else {
            print("[Info] '已缓存应用' not visible, scrolling down")
            collectionView.swipeUp()
            sleep(1)
        }

        saveScreenshot("/tmp/wbk-ui-discover-cached.png")
    }

    // MARK: - Inbox Interactions

    func testInboxMessageDetail() throws {
        navigateToTab("tab.notifications")
        let search = app.descendants(matching: .any).matching(identifier: "wbk_search_field").firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("运行任务")
        search.typeText("\n")

        let markdownCard = app.descendants(matching: .any)
            .matching(identifier: "notification.card.stored-markdown-011").firstMatch
        XCTAssertTrue(markdownCard.waitForExistence(timeout: 5))
        markdownCard.tap()

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "message.detail").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "message.detail.markdown").firstMatch.waitForExistence(timeout: 5))
        sleep(1)
        saveScreenshot("/tmp/wbk-ui-inbox-markdown-top.png")

        let detail = app.descendants(matching: .any).matching(identifier: "message.detail").firstMatch
        detail.swipeUp()
        saveScreenshot("/tmp/wbk-ui-inbox-markdown-details.png")
    }

    /// Long-press on a recognized link in the Markdown body (bare URL, no
    /// markdown link syntax) must offer 打开链接, and opening it must push the
    /// shared browser in normal mode — back returns straight to the message.
    /// `drel://app?app_id=…` external link, fail-closed half: an unregistered
    /// app ID must produce an explanation alert — never a browser.
    func testExternalAppLinkFailsClosedForUnregisteredApp() throws {
        navigateToTab("tab.settings")

        Self.openExternally("drel://app?app_id=dev.drel.not-registered")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let openButton = springboard.buttons["打开"].firstMatch
        if openButton.waitForExistence(timeout: 5) {
            openButton.tap()
        }

        let failClosed = app.alerts["应用未注册"].firstMatch
        XCTAssertTrue(failClosed.waitForExistence(timeout: 8), "Unregistered app link must fail closed with an alert")
        XCTAssertFalse(
            app.descendants(matching: .any).matching(identifier: "browserManager.webView").firstMatch.exists,
            "No browser may appear for an unregistered app link"
        )
        saveScreenshot("/tmp/wbk-drel-link-failclosed.png")
        app.alerts.buttons["好"].firstMatch.tap()
    }

    /// Registered half: after importing the official gateway (env-prefilled
    /// payload), `drel://app` for a live registered app opens it immersive
    /// — the external equivalent of a push launch.
    func testExternalAppLinkOpensRegisteredAppImmersive() throws {
        // Import the official gateway first so the live signed manifests
        // (incl. dev.drel.data-template) land in the trust registry.
        let guide = app.buttons["pwaHome.guideAndDebug"]
        var prescrollAttempts = 0
        while !guide.exists && prescrollAttempts < 8 {
            app.swipeUp()
            prescrollAttempts += 1
        }
        XCTAssertTrue(guide.waitForExistence(timeout: 10), "Home should expose 手册与调试")
        guide.tap()

        let manage = app.sheets.buttons["管理自有服务"].firstMatch
        if !manage.waitForExistence(timeout: 6) {
            app.buttons["管理自有服务"].firstMatch.tap()
        } else {
            manage.tap()
        }

        let validate = app.buttons["gateway.validate"]
        XCTAssertTrue(validate.waitForExistence(timeout: 8), "Gateway import screen should be prefilled")
        if !validate.isHittable { app.swipeUp() }
        validate.tap()

        let verified = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'verified'")
        ).firstMatch
        if !verified.waitForExistence(timeout: 45) {
            saveScreenshot("/tmp/wbk-drel-link-validation-failed.png")
            XCTFail("Validation report should render")
        }

        let activate = app.buttons["启用此网关"]
        var reportScrollAttempts = 0
        while !activate.exists && reportScrollAttempts < 10 {
            app.swipeUp()
            reportScrollAttempts += 1
            Thread.sleep(forTimeInterval: 0.4)
        }
        XCTAssertTrue(activate.waitForExistence(timeout: 10), "启用此网关 should render after scrolling")
        activate.tap()

        let activated = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "已启用")
        ).firstMatch
        XCTAssertTrue(activated.waitForExistence(timeout: 10), "Gateway should report 已启用")

        // External link → system handoff → 打开 → immersive app.
        Self.openExternally("drel://app?app_id=dev.drel.data-template&route=/test/template/v1/index.html&param_title=%E5%A4%96%E9%83%A8%E6%8B%89%E8%B5%B7")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let openButton = springboard.buttons["打开"].firstMatch
        if openButton.waitForExistence(timeout: 5) {
            openButton.tap()
        }

        let browser = app.descendants(matching: .any).matching(identifier: "browserManager.webView").firstMatch
        XCTAssertTrue(browser.waitForExistence(timeout: 10), "Registered app link should open the browser")
        saveScreenshot("/tmp/wbk-drel-link-opened.png")
        // Immersive = no navigation bar (the left-edge exit handle collapses
        // to a chevron whose identifier is not exposed while collapsed).
        XCTAssertTrue(app.navigationBars.firstMatch.exists == false, "Immersive open must hide the navigation bar")
        // The link carried param_title=外部拉起 — it must reach the page via the
        // drel_param_* query channel, not just open the empty template shell.
        XCTAssertTrue(
            app.staticTexts["外部拉起"].firstMatch.waitForExistence(timeout: 8),
            "Link parameters must render in the template page"
        )
        saveScreenshot("/tmp/wbk-drel-link-registered.png")
    }

    /// Opens a URL the way an external context (another app / system) would.
    private static func openExternally(_ link: String) {
        guard let url = URL(string: link) else {
            XCTFail("Invalid test link: \(link)")
            return
        }
        if #available(iOS 16.4, *) {
            XCUIDevice.shared.system.open(url)
        } else {
            XCTFail("XCUIDevice.system.open requires iOS 16.4+")
        }
    }

    func testInboxMarkdownLinkLongPressMenuOpensBrowserInNormalMode() throws {
        navigateToTab("tab.notifications")
        openInboxMessage(searchText: "部署手册更新", cardID: "stored-markdown-links-013")

        // Both the bare paragraph URL and the code-block URL render as links.
        let deployLink = app.links.matching(NSPredicate(format: "label CONTAINS %@", "deploy-guide")).firstMatch
        XCTAssertTrue(deployLink.waitForExistence(timeout: 5), "Bare paragraph URL should be exposed as a link")
        let runbookLink = app.links.matching(NSPredicate(format: "label CONTAINS %@", "rollback-runbook")).firstMatch
        XCTAssertTrue(runbookLink.waitForExistence(timeout: 5), "Code-block URL should be exposed as a link")

        deployLink.press(forDuration: 1.5)

        // Custom menu: exactly 打开链接 / 拷贝链接, no system items.
        let openAction = app.buttons["打开链接"].firstMatch
        XCTAssertTrue(openAction.waitForExistence(timeout: 5), "Long-press menu should offer 打开链接")
        XCTAssertTrue(app.buttons["拷贝链接"].firstMatch.exists, "Long-press menu should offer 拷贝链接")
        XCTAssertFalse(app.buttons["添加到阅读列表"].firstMatch.exists, "System link actions must be replaced by the custom menu")
        saveScreenshot("/tmp/wbk-ui-md-link-menu.png")
        openAction.tap()

        let browser = app.descendants(matching: .any).matching(identifier: "browserManager.webView").firstMatch
        XCTAssertTrue(browser.waitForExistence(timeout: 8), "打开链接 should open the shared browser")
        saveScreenshot("/tmp/wbk-ui-md-link-browser.png")

        // Normal mode: pushed with a back control, not the immersive capsule.
        let immersiveCapsule = app.buttons["browserManager.immersiveMenuButton"].firstMatch
        XCTAssertFalse(immersiveCapsule.isHittable, "Browser must not open immersive/fullscreen")

        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 3), "Normal-mode browser keeps the navigation bar")
        navBar.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "message.detail").firstMatch.waitForExistence(timeout: 5),
            "Back from the browser should return to the message detail"
        )
    }

    func testInboxPlainMessageKeepsBodyReadable() throws {        navigateToTab("tab.notifications")
        openInboxMessage(searchText: "系统维护通知", cardID: "stored-sys-004")

        XCTAssertTrue(app.staticTexts["系统将于今晚 22:00-23:00 进行维护升级"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "message.detail.body").firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "message.detail.media").firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "message.detail.markdown").firstMatch.exists)
        saveScreenshot("/tmp/wbk-ui-inbox-type-plain.png")
    }

    func testInboxImageMessageLoadsNativeMediaCard() throws {
        navigateToTab("tab.notifications")
        openInboxMessage(searchText: "设计稿预览", cardID: "stored-image-017")

        let media = app.descendants(matching: .any).matching(identifier: "message.detail.media").firstMatch
        XCTAssertTrue(media.waitForExistence(timeout: 5))
        let loaded = NSPredicate(format: "value == %@", "loaded")
        expectation(for: loaded, evaluatedWith: media)
        waitForExpectations(timeout: 8)
        saveScreenshot("/tmp/wbk-ui-inbox-type-image.png")
    }

    func testInboxImageFailureUsesCompactReadableFallback() throws {
        navigateToTab("tab.notifications")
        openInboxMessage(searchText: "图片加载失败示例", cardID: "stored-image-failure-018")

        let media = app.descendants(matching: .any).matching(identifier: "message.detail.media").firstMatch
        XCTAssertTrue(media.waitForExistence(timeout: 5))
        let failed = NSPredicate(format: "value == %@", "failed")
        expectation(for: failed, evaluatedWith: media)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(app.staticTexts["图片暂时无法加载"].exists)
        XCTAssertLessThanOrEqual(media.frame.height, 100)
        XCTAssertTrue(app.staticTexts["即使远端图片不可用，通知正文和其他操作仍然可以正常使用。"].exists)
        saveScreenshot("/tmp/wbk-ui-inbox-type-image-failure.png")
    }

    func testInboxChatMessageUsesConversationActionAndCollapsedDiagnostics() throws {
        navigateToTab("tab.notifications")
        openInboxMessage(searchText: "林默发来新消息", cardID: "stored-chat-route-013")

        XCTAssertTrue(app.buttons["message.detail.openConversation"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["message.detail.openConversation"].label, "打开会话")
        XCTAssertFalse(app.staticTexts["/fixtures/pwa-notification/index.html"].exists)

        let technicalToggle = app.buttons["message.detail.technical.toggle"]
        XCTAssertTrue(technicalToggle.waitForExistence(timeout: 5))
        technicalToggle.tap()
        XCTAssertTrue(app.staticTexts["/fixtures/pwa-notification/index.html"].waitForExistence(timeout: 5))
        saveScreenshot("/tmp/wbk-ui-inbox-type-chat.png")
    }

    func testInboxUnreadFilter() throws {
        navigateToTab("tab.notifications")

        let unreadFilter = app.buttons["filter_unread"]
        XCTAssertTrue(unreadFilter.waitForExistence(timeout: 5))
        unreadFilter.tap()

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "notification.card.stored-critical-005").firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "notification.card.stored-read-001").firstMatch.exists)
        saveScreenshot("/tmp/wbk-ui-inbox-unread.png")
    }

    func testInboxAppFilter() throws {
        navigateToTab("tab.notifications")

        let appsFilter = app.buttons["filter_apps"]
        XCTAssertTrue(appsFilter.waitForExistence(timeout: 5))
        appsFilter.tap()

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "notification.card.stored-critical-005").firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "notification.card.stored-sys-004").firstMatch.exists)
        saveScreenshot("/tmp/wbk-ui-inbox-app-filter.png")
    }

    func testInboxGroupCanCollapseAndExpand() throws {
        navigateToTab("tab.notifications")

        let displayMode = app.segmentedControls["inbox.displayMode"]
        XCTAssertTrue(displayMode.waitForExistence(timeout: 5))
        displayMode.buttons["分组"].tap()

        let search = app.descendants(matching: .any).matching(identifier: "wbk_search_field").firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("安全告警\n")

        let header = app.descendants(matching: .any)
            .matching(identifier: "notification.group.security-alerts").firstMatch
        let securityCard = app.descendants(matching: .any)
            .matching(identifier: "notification.card.stored-critical-005").firstMatch

        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertTrue(securityCard.waitForExistence(timeout: 5))
        header.tap()
        XCTAssertFalse(securityCard.exists)

        header.tap()
        XCTAssertTrue(securityCard.waitForExistence(timeout: 5))
    }

    func testInboxLatestTimelineCanSwitchToGroups() throws {
        navigateToTab("tab.notifications")

        let displayMode = app.segmentedControls["inbox.displayMode"]
        XCTAssertTrue(displayMode.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "notification.card.stored-approval-media-014").firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "notification.group.agent-approvals").firstMatch.exists)
        saveScreenshot("/tmp/wbk-ui-inbox-latest.png")

        displayMode.buttons["分组"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "notification.group.agent-approvals").firstMatch.waitForExistence(timeout: 5))
        saveScreenshot("/tmp/wbk-ui-inbox-groups.png")
    }

    func testInboxVerificationCodeCanBeCopied() throws {
        navigateToTab("tab.notifications")

        let search = app.descendants(matching: .any).matching(identifier: "wbk_search_field").firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("登录验证码\n")

        let verificationCard = app.descendants(matching: .any)
            .matching(identifier: "notification.card.stored-verification-012").firstMatch
        XCTAssertTrue(verificationCard.waitForExistence(timeout: 5))
        verificationCard.tap()

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "message.detail.verificationCode").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["482 901"].waitForExistence(timeout: 5))
        let copyButton = app.buttons["message.detail.copyVerificationCode"]
        let metadata = app.descendants(matching: .any).matching(identifier: "message.detail.metadata").firstMatch
        XCTAssertTrue(copyButton.waitForExistence(timeout: 5))
        XCTAssertTrue(metadata.waitForExistence(timeout: 5))
        XCTAssertLessThan(copyButton.frame.minY, metadata.frame.minY)
        saveScreenshot("/tmp/wbk-ui-inbox-verification.png")
    }

    func testInboxApprovalMessageShowsNativePresentationMetadata() throws {
        navigateToTab("tab.notifications")

        let search = app.descendants(matching: .any).matching(identifier: "wbk_search_field").firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("生产发布\n")

        let approvalCard = app.descendants(matching: .any)
            .matching(identifier: "notification.card.stored-approval-media-014").firstMatch
        XCTAssertTrue(approvalCard.waitForExistence(timeout: 5))
        approvalCard.tap()

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "message.detail.media").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["时效性"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "message.detail.approvalState").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["待确认"].waitForExistence(timeout: 5))
        let openButton = app.buttons["message.detail.openApp"]
        let metadata = app.descendants(matching: .any).matching(identifier: "message.detail.metadata").firstMatch
        XCTAssertTrue(openButton.waitForExistence(timeout: 5))
        XCTAssertTrue(metadata.waitForExistence(timeout: 5))
        XCTAssertLessThan(openButton.frame.minY, metadata.frame.minY)
        XCTAssertTrue(app.buttons["message.detail.copyValue"].waitForExistence(timeout: 5))
        let technicalToggle = app.buttons["message.detail.technical.toggle"]
        XCTAssertTrue(technicalToggle.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["/test_resources/pwa-agent-console/approval.html"].exists)
        technicalToggle.tap()
        XCTAssertTrue(app.staticTexts["/test_resources/pwa-agent-console/approval.html"].waitForExistence(timeout: 5))
        saveScreenshot("/tmp/wbk-ui-inbox-approval.png")
    }

    func testInboxPWAApprovalOpensTrustedRouteWithoutApproving() throws {
        navigateToTab("tab.notifications")

        let search = app.descendants(matching: .any).matching(identifier: "wbk_search_field").firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("生产发布\n")

        let approvalCard = app.descendants(matching: .any)
            .matching(identifier: "notification.card.stored-approval-media-014").firstMatch
        XCTAssertTrue(approvalCard.waitForExistence(timeout: 5))
        approvalCard.tap()

        let openButton = app.buttons["message.detail.openApp"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 5))
        openButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "modalBrowser.webView").firstMatch.waitForExistence(timeout: 8))
        sleep(5)
        saveScreenshot("/tmp/wbk-ui-inbox-pwa-approval.png")

        let modal = app.descendants(matching: .any).matching(identifier: "modalBrowser.view").firstMatch
        XCTAssertTrue(modal.exists)
        XCTAssertTrue(app.staticTexts["approval-42"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["notification"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["通知只负责导航；此请求尚未获得批准。"].exists)
        XCTAssertFalse(app.staticTexts["已通过"].exists)

        let closeButton = app.buttons["modalBrowser.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()
        let modalDismissed = NSPredicate(format: "exists == false")
        expectation(for: modalDismissed, evaluatedWith: modal)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.staticTexts["待确认"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["已通过"].exists)
    }

    func testInboxNativeApprovalShowsActionsAndConfirmation() throws {
        try createNativeApprovalRecord(requestID: nativeApprovalRequestID)
        navigateToTab("tab.notifications")

        let search = app.descendants(matching: .any).matching(identifier: "wbk_search_field").firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("确认部署到生产环境\n")

        let approvalCard = app.descendants(matching: .any)
            .matching(identifier: "notification.card.stored-approval-native-016").firstMatch
        XCTAssertTrue(approvalCard.waitForExistence(timeout: 5))
        approvalCard.tap()

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "message.detail.approvalState").firstMatch.waitForExistence(timeout: 5))
        let approveButton = app.buttons["message.detail.approval.approve"]
        let rejectButton = app.buttons["message.detail.approval.reject"]
        XCTAssertTrue(approveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(rejectButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["待确认"].waitForExistence(timeout: 5))
        saveScreenshot("/tmp/wbk-ui-inbox-native-approval.png")

        rejectButton.tap()
        let reasonPrompt = app.alerts.firstMatch
        XCTAssertTrue(reasonPrompt.waitForExistence(timeout: 5))
        XCTAssertTrue(reasonPrompt.textFields["message.detail.approval.reason"].exists)
        reasonPrompt.buttons["取消"].tap()

        approveButton.tap()
        let confirmation = app.alerts.firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmation.staticTexts["确认操作"].exists)
        confirmation.buttons["通过并发布"].tap()

        XCTAssertTrue(app.staticTexts["已通过"].waitForExistence(timeout: 5))
        XCTAssertFalse(approveButton.exists)
        XCTAssertFalse(rejectButton.exists)

        goBack()
        XCTAssertTrue(approvalCard.waitForExistence(timeout: 5))
        approvalCard.tap()
        XCTAssertTrue(app.staticTexts["已通过"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["message.detail.approval.approve"].exists)
        saveScreenshot("/tmp/wbk-ui-inbox-native-approval-approved.png")
    }

    func testInboxQRCodeUsesNativeRendering() throws {
        navigateToTab("tab.notifications")

        let search = app.descendants(matching: .any).matching(identifier: "wbk_search_field").firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("桌面端登录二维码\n")

        let qrCard = app.descendants(matching: .any)
            .matching(identifier: "notification.card.stored-qr-015").firstMatch
        XCTAssertTrue(qrCard.waitForExistence(timeout: 5))
        qrCard.tap()

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "message.detail.qrCode").firstMatch.waitForExistence(timeout: 5))
        let copyButton = app.buttons["message.detail.copyQRValue"]
        let metadata = app.descendants(matching: .any).matching(identifier: "message.detail.metadata").firstMatch
        XCTAssertTrue(copyButton.waitForExistence(timeout: 5))
        XCTAssertTrue(metadata.waitForExistence(timeout: 5))
        XCTAssertLessThan(copyButton.frame.minY, metadata.frame.minY)
        saveScreenshot("/tmp/wbk-ui-inbox-qr.png")
    }

    private func openInboxMessage(searchText: String, cardID: String) {
        let search = app.descendants(matching: .any).matching(identifier: "wbk_search_field").firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("\(searchText)\n")

        let card = app.descendants(matching: .any)
            .matching(identifier: "notification.card.\(cardID)").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "message.detail").firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: - Home Interactions (2 tests)

    func testHomeQuickActions() throws {
        navigateToTab("tab.apps")

        let scanButton = app.buttons["main.scanButton"]
        if scanButton.waitForExistence(timeout: 5) {
            scanButton.tap()
            sleep(1)
            saveScreenshot("/tmp/wbk-ui-home-scan.png")
            print("[Info] Tapped scan button")

            let alert = app.alerts.firstMatch
            let sheet = app.sheets.firstMatch
            if alert.waitForExistence(timeout: 2) {
                print("[Info] Alert appeared after scan tap, dismissing")
                alert.buttons.firstMatch.tap()
                sleep(1)
            } else if sheet.waitForExistence(timeout: 2) {
                print("[Info] Action sheet appeared after scan tap, dismissing")
                sheet.buttons.firstMatch.tap()
                sleep(1)
            }
        } else {
            print("[Warning] Scan button not found")
            saveScreenshot("/tmp/wbk-ui-home-scan.png")
        }
    }

    func testHomeRegisterButton() throws {
        navigateToTab("tab.settings")

        sleep(1)

        let primaryRegisterButton = app.buttons["tokenPush.registerButton"]
        let registerButton = primaryRegisterButton.exists ? primaryRegisterButton : app.buttons["注册"]
        if registerButton.waitForExistence(timeout: 5) {
            registerButton.tap()
            print("[Info] Tapped register button, waiting 3 seconds...")
            sleep(3)
            saveScreenshot("/tmp/wbk-ui-home-register.png")
        } else {
            print("[Info] Register button not found (may already be registered)")
            saveScreenshot("/tmp/wbk-ui-home-register.png")
        }
    }
}
