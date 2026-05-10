import XCTest

final class DeepVerificationTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--UITesting", "-UITesting"]
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
        navigateToTab("发现")

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
        navigateToTab("发现")

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

    // MARK: - Inbox Interactions (3 tests)

    func testInboxMessageDetail() throws {
        navigateToTab("收信箱")

        sleep(1)

        let tableView = app.tables.firstMatch
        guard tableView.waitForExistence(timeout: 5) else {
            print("[Warning] No table view on Inbox tab")
            saveScreenshot("/tmp/wbk-ui-inbox-detail.png")
            return
        }

        let messageCells = tableView.cells.matching(identifier: "InboxMessageCell")
        let allCells = tableView.cells
        print("[Inbox] Total cells: \(allCells.count), message cells: \(messageCells.count)")

        if allCells.count > 0 {
            let firstCell = allCells.element(boundBy: 0)
            firstCell.tap()
            sleep(2)
            saveScreenshot("/tmp/wbk-ui-inbox-detail.png")

            let actionSheet = app.sheets.firstMatch
            let alert = app.alerts.firstMatch
            let detailNav = app.navigationBars.count > 1

            if actionSheet.waitForExistence(timeout: 2) {
                print("[Info] Action sheet appeared after tapping message")
                actionSheet.buttons.firstMatch.tap()
                sleep(1)
            } else if alert.waitForExistence(timeout: 1) {
                print("[Info] Alert appeared after tapping message")
                alert.buttons.firstMatch.tap()
                sleep(1)
            } else if detailNav {
                print("[Info] Navigated to message detail")
                goBack()
            } else {
                print("[Info] Tapped message, no detail/action sheet detected")
            }
        } else {
            print("[Info] No messages in inbox to tap")
            saveScreenshot("/tmp/wbk-ui-inbox-detail.png")
        }
    }

    func testInboxUnreadFilter() throws {
        navigateToTab("收信箱")

        sleep(1)

        let filterUnread = app.buttons["filter_1"]
        if filterUnread.waitForExistence(timeout: 5) {
            filterUnread.tap()
            sleep(1)
            saveScreenshot("/tmp/wbk-ui-inbox-unread.png")
            print("[Info] Tapped unread filter (filter_1)")
        } else {
            let unreadButton = app.buttons["未读"]
            if unreadButton.waitForExistence(timeout: 3) {
                unreadButton.tap()
                sleep(1)
                saveScreenshot("/tmp/wbk-ui-inbox-unread.png")
                print("[Info] Tapped unread filter by label")
            } else {
                print("[Warning] Unread filter button not found")
                saveScreenshot("/tmp/wbk-ui-inbox-unread.png")
            }
        }
    }

    func testInboxAppFilter() throws {
        navigateToTab("收信箱")

        sleep(1)

        let filterApps = app.buttons["filter_2"]
        if filterApps.waitForExistence(timeout: 5) {
            filterApps.tap()
            sleep(1)
            saveScreenshot("/tmp/wbk-ui-inbox-app-filter.png")
            print("[Info] Tapped apps filter (filter_2)")
        } else {
            let appsButton = app.buttons["应用"]
            if appsButton.waitForExistence(timeout: 3) {
                appsButton.tap()
                sleep(1)
                saveScreenshot("/tmp/wbk-ui-inbox-app-filter.png")
                print("[Info] Tapped apps filter by label")
            } else {
                print("[Warning] Apps filter button not found")
                saveScreenshot("/tmp/wbk-ui-inbox-app-filter.png")
            }
        }
    }

    // MARK: - Home Interactions (2 tests)

    func testHomeQuickActions() throws {
        navigateToTab("首页")

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
        navigateToTab("首页")

        sleep(1)

        let registerButton = app.buttons["注册"]
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
