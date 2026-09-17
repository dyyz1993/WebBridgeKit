import Foundation
import XCTest

final class VerifyFixesTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        setupInterruptionMonitor()
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launch()
        sleep(3)
    }

    override func tearDown() {
        app.terminate()
    }

    private func setupInterruptionMonitor() {
        addUIInterruptionMonitor(withDescription: "Paste Permission") { [weak self] (alert) -> Bool in
            let allowBtn = alert.buttons["允许粘贴"]
            if allowBtn.exists { allowBtn.tap(); return true }
            let allowPasteBtn = alert.buttons["Allow Paste"]
            if allowPasteBtn.exists { allowPasteBtn.tap(); return true }
            let dontAllow = alert.buttons["不允许粘贴"]
            if dontAllow.exists { dontAllow.tap(); return true }
            let dontAllowEn = alert.buttons["Don't Allow"]
            if dontAllowEn.exists { dontAllowEn.tap(); return true }
            return false
        }
        addUIInterruptionMonitor(withDescription: "System Alert") { (alert) -> Bool in
            let okBtn = alert.buttons["好"]
            if okBtn.exists { okBtn.tap(); return true }
            let okEn = alert.buttons["OK"]
            if okEn.exists { okEn.tap(); return true }
            return false
        }
    }

    private func saveScreenshot(_ path: String) {
        sleep(1)
        guard app.exists else { return }
        let screenshot = app.screenshot()
        if let data = screenshot.image.pngData() {
            try? data.write(to: URL(fileURLWithPath: path))
            print("[Screenshot] Saved to \(path) (\(data.count) bytes)")
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = URL(fileURLWithPath: path).lastPathComponent
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapTabNamed(_ name: String) {
        sleep(1)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar should exist")
        let tab = tabBar.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Tab '\(name)' should exist")
        tab.tap()
        sleep(2)
    }

    private func tapCellContaining(_ text: String) {
        sleep(1)
        let tableView = app.tables.firstMatch
        XCTAssertTrue(tableView.waitForExistence(timeout: 10), "Table should exist")
        let cell = tableView.cells.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        if cell.waitForExistence(timeout: 5) {
            let frame = cell.frame
            guard !frame.isEmpty && !frame.isNull else {
                XCTFail("Cell containing '\(text)' has invalid frame")
                return
            }
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        } else {
            XCTFail("Could not find cell containing '\(text)'")
        }
        sleep(2)
    }

    private func tapVisibleText(_ text: String) {
        let label = app.staticTexts[text].firstMatch
        var attempts = 0
        while !label.exists && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(label.waitForExistence(timeout: 10), "Text '\(text)' should exist")
        while !label.isHittable && attempts < 14 {
            app.swipeUp()
            attempts += 1
        }
        label.tap()
        sleep(2)
    }

    private func waitForNav() {
        sleep(2)
        if app.state != .runningForeground { app.activate(); sleep(1) }
    }

    /// Store configuration audit: the submitted Drel surface must expose only
    /// storage, system notification permission and the two-channel push setup.
    /// This protects against legacy gateway/key-management rows leaking back
    /// into the Store build when full developer features are restored locally.
    #if DREL_RELEASE_MINIMAL_SETTINGS
    func testDrelReleaseSettingsSurface() throws {
        tapTabNamed("设置")

        let cache = app.descendants(matching: .any)["settings.cell.cacheManager"]
        let notification = app.descendants(matching: .any)["settings.cell.notificationSettings"]
        let channels = app.descendants(matching: .any)["settings.cell.serverConfig"]
        XCTAssertTrue(cache.waitForExistence(timeout: 8), "storage management must remain available")
        XCTAssertTrue(notification.exists, "system notification permission must remain available")
        XCTAssertTrue(channels.exists, "official/custom channel setup must remain available")
        XCTAssertFalse(app.descendants(matching: .any)["settings.cell.apiKeyManage"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["settings.cell.pushEncryption"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["settings.cell.favorites"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["settings.cell.history"].exists)
        saveScreenshot("/tmp/drel-release-settings-overview.png")

        cache.tap()
        XCTAssertTrue(app.navigationBars["存储管理"].waitForExistence(timeout: 8))
        saveScreenshot("/tmp/drel-release-settings-storage.png")
        app.navigationBars["存储管理"].buttons.firstMatch.tap()

        XCTAssertTrue(channels.waitForExistence(timeout: 8))
        channels.tap()
        XCTAssertTrue(app.navigationBars["推送通道"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "官方 Drel")
        ).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "自定义推送")
        ).firstMatch.exists)
        saveScreenshot("/tmp/drel-release-settings-push-channels.png")
    }
    #endif

    func testFavoritesHasData() throws {
        tapTabNamed("设置")
        tapCellContaining("收藏夹")
        waitForNav()
        sleep(2)
        saveScreenshot("/tmp/wbk-fix-favorites.png")
    }

    func testCacheTabHasData() throws {
        tapTabNamed("设置")
        tapCellContaining("缓存管理")
        waitForNav()

        let segCtrl = app.segmentedControls.firstMatch
        if segCtrl.waitForExistence(timeout: 5) {
            let cacheSeg = segCtrl.buttons["缓存"]
            if cacheSeg.waitForExistence(timeout: 3) {
                cacheSeg.tap(); sleep(2)
            // swiftlint:disable:next empty_count -- XCUIElementQuery has no isEmpty API.
            } else if segCtrl.buttons.count > 0 {
                segCtrl.buttons.element(boundBy: 0).tap(); sleep(2)
            }
        }
        sleep(2)
        saveScreenshot("/tmp/wbk-fix-cache.png")
    }

    func testInboxMessageDetail() throws {
        tapTabNamed("tab.notifications")
        sleep(2)

        let tableView = app.tables.firstMatch
        XCTAssertTrue(tableView.waitForExistence(timeout: 5), "Inbox table should exist")
        XCTAssertGreaterThan(tableView.cells.count, 0, "Inbox should have messages")

        let firstCell = tableView.cells.element(boundBy: 0)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 3), "First message cell should exist")
        let frame = firstCell.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()

        waitForNav()
        sleep(2)
        saveScreenshot("/tmp/wbk-fix-inbox-detail.png")
    }

    /// Store-safe self-hosted push remains an optional direct-APNs setup,
    /// separate from the retired HTML-app gateway. This is intentionally UI
    /// automation rather than a static source assertion.
    func testSelfHostedPushConfigurationPasteEntry() throws {
        let server = "http://127.0.0.1:18080"
        app.terminate()
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN",
            "WBK_SELF_HOSTED_UI_TEST_DEVICE_TOKEN": "simulator-ui-validation-token",
            "WBK_SELF_HOSTED_UI_TEST_FIXTURE": "1"
        ]
        app.launch()
        sleep(2)
        tapTabNamed("设置")
        // The Drel Store settings screen uses a collection/card layout rather
        // than UITableView, so this must not reuse the legacy table helper.
        tapVisibleText("推送通道")
        waitForNav()

        XCTAssertTrue(app.navigationBars["推送通道"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "当前用于复制与示例发送")
        ).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "服务地址：https://api.drel.app")
        ).firstMatch.exists, "official channel must show the bundled Drel origin")
        XCTAssertTrue(app.staticTexts["自定义推送"].exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "尚未添加")
        ).firstMatch.exists)

        tapVisibleText("添加或管理自定义通道")
        waitForNav()

        XCTAssertTrue(app.navigationBars["自定义推送"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["尚未配置。官方 Drel 推送仍可正常使用。"].waitForExistence(timeout: 5))

        let paste = app.buttons["粘贴服务器地址或配置码"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["扫描配置码"].exists)
        paste.tap()

        let alert = app.alerts["连接推送服务"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let address = alert.textFields.firstMatch
        XCTAssertTrue(address.exists)
        address.tap()
        // The controller intentionally pre-fills the pasteboard for ordinary
        // users. Clear it so this test imports exactly the isolated endpoint.
        address.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 256))
        address.typeText(server)
        XCTAssertTrue(alert.buttons["连接"].exists)
        alert.buttons["连接"].tap()

        let connected = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "已连接：Simulator Self-hosted")
        ).firstMatch
        saveScreenshot("/tmp/drel-selfhosted-pairing-ui.png")
        XCTAssertTrue(connected.waitForExistence(timeout: 20), "isolated self-hosted pairing should finish")
    }

    /// Managed encrypted pairing uses a different QR host and descriptor from
    /// a direct self-hosted relay. It must never surface a plaintext push URL.
    func testManagedEncryptedPushConfigurationPasteEntry() throws {
        let server = "http://127.0.0.1:18081"
        var pairingRequest = URLRequest(url: URL(string: "\(server)/managed-push/pairings")!)
        pairingRequest.httpMethod = "POST"
        let pairingExpectation = expectation(description: "Issue managed pairing ticket")
        var pairingData: Data?
        var pairingResponse: URLResponse?
        var pairingError: Error?
        URLSession.shared.dataTask(with: pairingRequest) { data, response, error in
            pairingData = data
            pairingResponse = response
            pairingError = error
            pairingExpectation.fulfill()
        }.resume()
        wait(for: [pairingExpectation], timeout: 5)
        XCTAssertNil(pairingError)
        XCTAssertEqual((pairingResponse as? HTTPURLResponse)?.statusCode, 200)
        let issuedPairingData = try XCTUnwrap(pairingData)
        let pairing = try JSONDecoder().decode(ManagedPairing.self, from: issuedPairingData)
        let configuration = "drel://managed-encrypted-push?server=http%3A%2F%2F127.0.0.1%3A18081&token=\(pairing.pairingToken)"
        app.terminate()
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN",
            "WBK_SELF_HOSTED_UI_TEST_DEVICE_TOKEN": String(repeating: "a", count: 64)
        ]
        app.launch()
        sleep(2)
        tapTabNamed("设置")
        tapVisibleText("推送通道")
        waitForNav()

        tapVisibleText("添加或管理自定义通道")
        waitForNav()

        let paste = app.buttons["粘贴服务器地址或配置码"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()

        let alert = app.alerts["连接推送服务"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let address = alert.textFields.firstMatch
        XCTAssertTrue(address.exists)
        address.tap()
        address.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 256))
        address.typeText(configuration)
        alert.buttons["连接"].tap()

        let connected = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "已连接：Simulator Managed Encrypted Push")
        ).firstMatch
        saveScreenshot("/tmp/drel-managed-encrypted-pairing-ui.png")
        XCTAssertTrue(connected.waitForExistence(timeout: 20), "managed encrypted pairing should finish")
        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "直接推送地址")).firstMatch.exists,
            "managed encrypted mode must not expose a plaintext direct push URL"
        )
    }

    private struct ManagedPairing: Decodable {
        let pairingToken: String
    }
}
