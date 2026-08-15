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

    func testEveryExampleDeliversToInbox() throws {
        let examplesButton = app.buttons["pwaHome.apiExamples"]
        XCTAssertTrue(examplesButton.waitForExistence(timeout: 15), "Home should expose the API examples entry")

        for example in Self.examples {
            // The catalog is a pushed screen; enter it fresh for every type so a
            // Safari roundtrip always starts from a known navigation state.
            if !app.buttons["pushExamples.\(example.type)"].exists {
                examplesButton.tap()
            }
            let row = app.buttons["pushExamples.\(example.type)"]
            XCTAssertTrue(row.waitForExistence(timeout: 10), "\(example.type) example row should exist")
            // Rows below the fold must be scrolled into view before tapping,
            // otherwise the tap misses the button and Safari never opens.
            var scrollAttempts = 0
            while !row.isHittable && scrollAttempts < 6 {
                app.swipeUp()
                scrollAttempts += 1
            }
            row.tap()

            // The example opens Safari, which fires the server request. Pull the
            // app back almost immediately: the request completes server-side
            // regardless, and the push must arrive while the app is foreground
            // (willPresent) or the message is never recorded in the Inbox.
            Thread.sleep(forTimeInterval: 0.8)
            if app.state != .runningForeground {
                app.activate()
            }
            attachScreenshot(named: "example-\(example.type)-safari")

            // The example URL opens in the in-app browser, which covers the
            // tab bar. Close it via its toolbar close button, then pop the
            // catalog back to the home tab before switching — tapping a
            // sibling tab straight from the pushed catalog is unreliable.
            let browserClose = app.buttons["browserManager.closeButton"]
            if browserClose.waitForExistence(timeout: 3) {
                browserClose.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
            let navBack = app.navigationBars.buttons.firstMatch
            if navBack.exists {
                navBack.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }

            // Navigate to the Inbox and require the exact example title.
            let inboxTab = app.tabBars.buttons["tab.notifications"]
            XCTAssertTrue(inboxTab.waitForExistence(timeout: 5), "Notifications tab should exist")
            inboxTab.tap()
            let message = app.staticTexts[example.title]
            XCTAssertTrue(
                message.waitForExistence(timeout: 30),
                "\(example.type) push should be recorded in the Inbox as「\(example.title)」"
            )
            attachScreenshot(named: "example-\(example.type)-inbox")

            let homeTab = app.tabBars.buttons["tab.apps"]
            XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
            homeTab.tap()
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

        // The sound card links straight into the ringtone picker.
        let soundMore = app.buttons["pushExamples.sound.more"]
        var soundAttempts = 0
        while !soundMore.exists && soundAttempts < 8 {
            app.swipeUp()
            soundAttempts += 1
        }
        XCTAssertTrue(soundMore.waitForExistence(timeout: 5), "Sound card should link to the ringtone picker")
        soundMore.tap()
        XCTAssertTrue(app.buttons["pushRingtones.alarm"].waitForExistence(timeout: 10), "Ringtone picker should open from the sound card")
        attachScreenshot(named: "catalog-sound-links-ringtones")
        app.navigationBars.buttons.firstMatch.tap()

        // Presentation and behavior groups render below the fold.
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

        // Bundled .caf assets resolve as rows with real durations.
        let alarmRow = app.buttons["pushRingtones.alarm"]
        XCTAssertTrue(alarmRow.waitForExistence(timeout: 10), "Bundled alarm ringtone should be listed")
        alarmRow.tap()

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
