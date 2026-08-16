import XCTest

/// Real-device smoke for the「全部 API 示例」catalog: taps every push example
/// (plain / markdown / otp / qr / image / chat / approval), lets Safari fire
/// the Bark request, then verifies each message landed in the Inbox with its
/// exact title — proving URL generation, server acceptance, APNs delivery and
/// content recording end to end for every Push v2 content type.
///
/// Requires a physical, unlocked iPhone whose app is already push-registered
/// (run RealDevicePushSmokeTests first on a fresh install).
final class PushExampleCatalogTests: XCTestCase {

    private static let examples: [(type: String, title: String)] = [
        ("plain", "测试通知"),
        ("markdown", "部署完成"),
        ("otp", "登录验证码"),
        ("qr", "扫码登录"),
        ("image", "图片预览"),
        ("chat", "Team Chat 新消息"),
        ("approval", "需要确认生产发布")
    ]

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil else {
            throw XCTSkip("Real-device only: APNs delivery requires physical hardware")
        }
        app = XCUIApplication()
        // Every xcodebuild test run reinstalls the app, which re-arms the
        // China-region 「允许使用无线数据」gate that silently denies all app
        // traffic — the example URLs then load blank and no push is ever
        // sent. The monitor answers that dialog (and the notification
        // permission alert) with the affirmative option.
        addUIInterruptionMonitor(withDescription: "系统权限弹窗") { alert in
            Self.tapAffirmative(on: alert)
        }
        app.launchArguments = [
            "--UITesting",
            "--push-server=https://wbk.shanbox.19930810.xyz:8443"
        ]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN"
        ]
        app.launch()
    }

    private static let affirmativeAlertButtons = [
        "无线局域网与蜂窝网络", "WLAN & Cellular",
        "允许", "Allow", "允许通知"
    ]

    @discardableResult
    private static func tapAffirmative(on alert: XCUIElement) -> Bool {
        for label in affirmativeAlertButtons {
            let button = alert.buttons[label]
            if button.exists {
                button.tap()
                return true
            }
        }
        return false
    }

    private static func dismissVisibleSystemAlert(on app: XCUIApplication) {
        let alert = app.alerts.firstMatch
        guard alert.exists else { return }
        tapAffirmative(on: alert)
    }

    func testEveryExampleDeliversToInbox() throws {
        let examplesButton = app.buttons["pwaHome.apiExamples"]
        XCTAssertTrue(examplesButton.waitForExistence(timeout: 15), "Home should expose the API examples entry")
        examplesButton.tap()

        // Phase 1 — fire every example from the catalog in one pass. Each
        // card opens the URL in the IN-APP browser (the app never leaves the
        // foreground, so every push arrives via willPresent and is recorded);
        // closing the browser returns straight to the catalog, ready for the
        // next card. Per-example trips back through the home tab proved
        // fragile: scroll positions virtualize the entry card away.
        for example in Self.examples {
            var row = app.buttons["pushExamples.\(example.type)"]
            if !row.waitForExistence(timeout: 3) {
                // Closing the in-app browser can land back on the catalog or
                // pop all the way to home depending on presentation context.
                // Recover either way: scroll home to the top (List rows
                // virtualize away below the fold) and re-enter the catalog.
                var topAttempts = 0
                while !examplesButton.exists && topAttempts < 4 {
                    app.swipeDown()
                    topAttempts += 1
                }
                if examplesButton.exists {
                    examplesButton.tap()
                }
                row = app.buttons["pushExamples.\(example.type)"]
            }
            XCTAssertTrue(row.waitForExistence(timeout: 10), "\(example.type) example row should exist")
            var scrollAttempts = 0
            while !row.isHittable && scrollAttempts < 8 {
                app.swipeUp()
                scrollAttempts += 1
            }
            row.tap()
            // The wireless-data gate can surface right after the first
            // outbound request; dismiss any system dialog (the interruption
            // monitor only fires on interactions).
            Self.dismissVisibleSystemAlert(on: app)

            let browserClose = app.buttons["browserManager.closeButton"]
            XCTAssertTrue(
                browserClose.waitForExistence(timeout: 8),
                "\(example.type) send should open the in-app browser"
            )
            attachScreenshot(named: "example-\(example.type)-send")
            browserClose.tap()
            Thread.sleep(forTimeInterval: 1.0)
            Self.dismissVisibleSystemAlert(on: app)
        }

        // Phase 2 — one Inbox visit asserts every delivery. Sends are done
        // by now, so each title only needs to appear once in the list.
        let inboxTab = app.tabBars.buttons["tab.notifications"]
        XCTAssertTrue(inboxTab.waitForExistence(timeout: 5), "Notifications tab should exist")
        inboxTab.tap()
        for example in Self.examples {
            let message = app.staticTexts[example.title]
            var scrollAttempts = 0
            while !message.exists && scrollAttempts < 6 {
                app.swipeUp()
                scrollAttempts += 1
            }
            XCTAssertTrue(
                message.waitForExistence(timeout: 30),
                "\(example.type) push should be recorded in the Inbox as「\(example.title)」"
            )
        }
        attachScreenshot(named: "catalog-all-delivered-inbox")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// Simulator-only smoke for the upgraded Bark-style capability catalog:
/// verifies all three groups (content types / presentation / behavior) render
/// with copy buttons and captures screenshots for visual review.
final class CatalogSimulatorSmokeTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil else {
            throw XCTSkip("Simulator only: this smoke checks catalog rendering, not delivery")
        }
        app = XCUIApplication()
        // --UITesting skips the launch-time pasteboard import check; without it
        // the system paste-permission alert blocks the run loop and the runner
        // is killed for never reaching idle.
        app.launchArguments = ["--UITesting", "-UITesting"]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN"
        ]
        app.launch()
    }

    func testCatalogShowsAllGroupsAndCopyButtons() throws {
        let examplesButton = app.buttons["pwaHome.apiExamples"]
        XCTAssertTrue(examplesButton.waitForExistence(timeout: 15), "Home should expose the API examples entry")

        var scrollAttempts = 0
        while !examplesButton.isHittable && scrollAttempts < 4 {
            app.swipeUp()
            scrollAttempts += 1
        }
        examplesButton.tap()

        // Content group keeps the historical pushExamples.<type> identifiers.
        let plain = app.buttons["pushExamples.plain"]
        XCTAssertTrue(plain.waitForExistence(timeout: 10), "Content-type cards should render")
        attachScreenshot(named: "catalog-content-group")

        // Every card carries send (browser push) and copy buttons, plus the
        // parameter spec line instead of the raw device URL.
        XCTAssertTrue(app.buttons["pushExamples.plain.send"].exists, "Plain example should expose a send button")
        XCTAssertTrue(app.buttons["pushExamples.plain.copy"].exists, "Plain example should expose a copy button")
        let markdownSpec = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "contentType=markdown&markdown=1")
        ).firstMatch
        XCTAssertTrue(markdownSpec.waitForExistence(timeout: 5), "Markdown card should show its parameter spec")

        // The sound card exposes the ringtone-picker link. Don't navigate
        // through it here: the back tap races with incoming push banners
        // (they overlay the nav bar) and once routed the test to the Inbox.
        // The picker itself is covered by testRingtonePickerLoadsBundledSounds.
        let soundMore = app.buttons["pushExamples.sound.more"]
        var soundAttempts = 0
        while !soundMore.exists && soundAttempts < 8 {
            app.swipeUp()
            soundAttempts += 1
        }
        XCTAssertTrue(soundMore.waitForExistence(timeout: 5), "Sound card should link to the ringtone picker")

        // Presentation and behavior groups render below the fold. Return to
        // the top first so the swipe loop below starts from a known offset.
        for _ in 0..<3 {
            app.swipeDown()
        }
        let expectedRows = [
            "pushExamples.sound",
            "pushExamples.critical",
            "pushExamples.badge",
            "pushExamples.url",
            "pushExamples.copy",
            "pushExamples.replace"
        ]
        for identifier in expectedRows {
            let row = app.buttons[identifier]
            var attempts = 0
            while !row.exists && attempts < 8 {
                app.swipeUp()
                attempts += 1
            }
            XCTAssertTrue(row.waitForExistence(timeout: 5), "\(identifier) card should render")
        }

        // Cards with previews render the native notification mock banner
        // (Bark's illustration treatment). Previews are plain views, not
        // buttons, so query across element types. The previous loop ends at
        // the list bottom; reset to the top before walking down again.
        for _ in 0..<3 {
            app.swipeDown()
        }
        let expectedPreviews = [
            "pushExamples.icon.preview",
            "pushExamples.group.preview",
            "pushExamples.critical.preview",
            "pushExamples.copy.preview"
        ]
        for identifier in expectedPreviews {
            let preview = app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier == %@", identifier)
            ).firstMatch
            var attempts = 0
            while !preview.exists && attempts < 8 {
                app.swipeUp()
                attempts += 1
            }
            XCTAssertTrue(preview.waitForExistence(timeout: 5), "\(identifier) should render")
        }
        attachScreenshot(named: "catalog-behavior-group")
    }

    func testRingtonePickerLoadsBundledSounds() throws {
        let guideButton = app.buttons["pwaHome.guideAndDebug"]
        XCTAssertTrue(guideButton.waitForExistence(timeout: 15), "Home should expose the guide & debug entry")

        var scrollAttempts = 0
        while !guideButton.isHittable && scrollAttempts < 4 {
            app.swipeUp()
            scrollAttempts += 1
        }
        guideButton.tap()

        let ringtoneEntry = app.sheets.buttons["推送铃声"]
        XCTAssertTrue(ringtoneEntry.waitForExistence(timeout: 10), "Guide sheet should offer the ringtone picker")
        ringtoneEntry.tap()

        // Bundled .caf assets resolve as rows with real durations. The picker
        // silently drops files AVAudioPlayer cannot open, so walking the full
        // alphabet and requiring the last name doubles as a file-integrity
        // gate: a corrupt sound would vanish from this list.
        let alarmRow = app.buttons["pushRingtones.alarm"]
        XCTAssertTrue(alarmRow.waitForExistence(timeout: 10), "Bundled alarm ringtone should be listed")
        alarmRow.tap()

        // Distinct ringtones spread head/middle/tail of the alphabetical
        // library; "update" is last, so reaching it proves the full traversal.
        let expectedSounds = [
            "alarm", "anticipate", "bell", "gotosleep",
            "minuet", "suspense", "typewriters", "update"
        ]
        for name in expectedSounds {
            let row = app.buttons["pushRingtones.\(name)"]
            var attempts = 0
            while !row.exists && attempts < 10 {
                app.swipeUp()
                attempts += 1
            }
            XCTAssertTrue(
                row.waitForExistence(timeout: 5),
                "Ringtone \(name) should be listed (missing or unloadable .caf)"
            )
        }
        attachScreenshot(named: "ringtone-library-tail")

        var topAttempts = 0
        while !alarmRow.isHittable && topAttempts < 10 {
            app.swipeDown()
            topAttempts += 1
        }

        let tryButton = app.buttons["pushRingtones.try"]
        XCTAssertTrue(tryButton.waitForExistence(timeout: 5), "Action bar should render after selection")
        XCTAssertTrue(app.buttons["pushRingtones.copy"].exists, "Copy URL button should render")
        XCTAssertTrue(app.buttons["pushRingtones.import"].exists, "Custom sound import button should render")
        attachScreenshot(named: "ringtone-picker")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
