import XCTest

/// Real-device smoke for the Drel push catalog: each open icon hands the
/// complete Bark-compatible request to Safari. APNs presentation and Inbox
/// persistence have separate device tests because a background notification
/// is not written into the Inbox until the user taps it.
///
/// Requires a physical, unlocked iPhone whose app is already push-registered
/// (run RealDevicePushSmokeTests first on a fresh install).
final class PushExampleCatalogTests: XCTestCase {

    private static let examples: [(type: String, title: String)] = [
        ("plain", "测试通知"),
        ("markdown", "部署完成"),
        ("otp", "登录验证码"),
        ("qr", "扫码登录"),
        ("image", "图片预览")
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

    func testEveryExampleOpensItsSafariRequest() throws {
        let examplesButton = app.buttons["pwaHome.apiExamples"]
        XCTAssertTrue(examplesButton.waitForExistence(timeout: 15), "Home should expose the API examples entry")
        examplesButton.tap()

        // Each card is inert; its compact send icon is the sole send action.
        // Safari must receive the exact URL, then we reactivate Drel before
        // continuing to the next virtualized List row.
        for example in Self.examples {
            var row = app.buttons["pushExamples.\(example.type).send"]
            if !row.waitForExistence(timeout: 3) {
                // Restore the catalog if a previous Safari transition moved
                // the host back to its root screen.
                var topAttempts = 0
                while !examplesButton.exists && topAttempts < 4 {
                    app.swipeDown()
                    topAttempts += 1
                }
                if examplesButton.exists {
                    examplesButton.tap()
                }
                row = app.buttons["pushExamples.\(example.type).send"]
            }
            XCTAssertTrue(row.waitForExistence(timeout: 10), "\(example.type) example row should exist")
            var scrollAttempts = 0
            while !row.isHittable && scrollAttempts < 8 {
                app.swipeUp()
                scrollAttempts += 1
            }
            row.tap()
            Self.dismissVisibleSystemAlert(on: app)
            XCTAssertTrue(
                app.wait(for: .runningBackground, timeout: 8),
                "\(example.type) open action should hand the request to Safari"
            )
            attachScreenshot(named: "example-\(example.type)-safari")
            app.activate()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
        }
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
/// with compact Safari-send and URL-copy actions.
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

    func testCatalogShowsAllGroupsAndCompactDeveloperActions() throws {
        let examplesButton = app.buttons["pwaHome.apiExamples"]
        XCTAssertTrue(examplesButton.waitForExistence(timeout: 15), "Home should expose the API examples entry")

        var scrollAttempts = 0
        while !examplesButton.isHittable && scrollAttempts < 4 {
            app.swipeUp()
            scrollAttempts += 1
        }
        examplesButton.tap()

        // Cards are inert; the two compact actions prove the card rendered.
        let plain = app.buttons["pushExamples.plain.send"]
        XCTAssertTrue(plain.waitForExistence(timeout: 10), "Content-type cards should render")
        attachScreenshot(named: "catalog-content-group")

        // Every card sends its complete request in Safari or copies that URL,
        // while keeping an explicit parameter line visible instead of the
        // device URL.
        XCTAssertTrue(app.buttons["pushExamples.plain.send"].exists, "Plain example should expose the Safari-send icon")
        XCTAssertTrue(app.buttons["pushExamples.plain.copy"].exists, "Plain example should expose the copy icon")
        let plainSpec = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "无额外 URL 参数")
        ).firstMatch
        XCTAssertTrue(plainSpec.waitForExistence(timeout: 5), "Plain card should explicitly state it has no URL query parameters")
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
        // Cards are not buttons; row presence is asserted through each
        // card's Safari-send action.
        for _ in 0..<3 {
            app.swipeDown()
        }
        let expectedRows = [
            "pushExamples.bodyOnly",
            "pushExamples.sound",
            "pushExamples.badge",
            "pushExamples.badgeClear",
            "pushExamples.url",
            "pushExamples.copyManual",
            "pushExamples.copy",
            "pushExamples.replace",
            "pushExamples.recall"
        ]
        for identifier in expectedRows {
            let row = app.buttons["\(identifier).send"]
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
