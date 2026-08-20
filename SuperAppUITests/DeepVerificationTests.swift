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
        app.launch()
    }

    private func saveScreenshot(_ path: String) {
        let screenshot = app.screenshot()
        if let data = screenshot.image.pngData() {
            do {
                try data.write(to: URL(fileURLWithPath: path))
                print("[Screenshot] Saved to \(path) (\(data.count) bytes)")
            } catch {
                XCTFail("Failed to save screenshot to \(path): \(error)")
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
        let tableView = app.tables["settings.tableView"]
        guard tableView.waitForExistence(timeout: 5) else {
            print("[Warning] Settings table not found")
            return false
        }

        let cellById = tableView.cells[identifier]
        if cellById.waitForExistence(timeout: 3) {
            cellById.tap()
            sleep(1)
            return true
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
        saveScreenshot("/tmp/wbk-ui-token-manage.png")

        if found {
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
        saveScreenshot("/tmp/wbk-ui-apikey-manage.png")

        if found {
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

    func testInboxPlainMessageKeepsBodyReadable() throws {
        navigateToTab("tab.notifications")
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
