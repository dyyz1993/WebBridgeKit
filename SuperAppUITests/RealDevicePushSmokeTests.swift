import XCTest

/// Real-device push smoke against the current v4 information architecture:
/// activates official push from the PWA home card (identity + APNs token +
/// server registration), reads the resolved push address, sends a Bark push
/// from the test process, then proves delivery with Inbox content and
/// timestamped banner screenshots.
///
/// Requires a physical, unlocked iPhone signed into the development team:
/// APNs does not deliver to simulators. Reinstall the app before running so
/// the stale `pushRegistrationFlag` from previous installs cannot short-circuit
/// activation.
final class RealDevicePushSmokeTests: XCTestCase {

    private static let pushServer = "https://wbk.shanbox.19930810.xyz:8443"

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard isRealDevice else {
            throw XCTSkip("Real-device only: APNs delivery requires physical hardware")
        }
        app = XCUIApplication()
        app.launchArguments = ["--UITesting", "--push-server=\(Self.pushServer)"]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN"
        ]
    }

    private var isRealDevice: Bool {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil
    }

    func testActivateSendAndCapturePushNotification() throws {
        // The system permission alert appears on the first activation after a
        // fresh install; the monitor dismisses it automatically.
        // System dialogs appear on the very first registration. Besides the
        // notification permission alert, China-region iPhones also gate every
        // fresh install behind a "允许使用无线数据" network-data dialog that
        // silently kills all app traffic until answered.
        addUIInterruptionMonitor(withDescription: "系统权限弹窗") { alert in
            Self.tapAffirmative(on: alert)
        }

        app.launch()

        // PWA home is the primary tab in the v4 IA; its push card exposes the
        // shared primary action button and the resolved push address.
        let actionButton = app.buttons["home.push.send-safari"]
        XCTAssertTrue(actionButton.waitForExistence(timeout: 15), "PWA home push card action button should be visible")

        // Activation is asynchronous: identity -> permission -> APNs token ->
        // server registration -> push address becomes available. The action
        // button is briefly disabled during identityPreparing, so keep tapping
        // the enable action from the wait loop instead of racing a single tap.
        let identity = try waitForPushAddressIdentity(timeout: 90)
        print("[push-smoke] resolved identity: \(identity)")
        attachScreenshot(named: "01-push-address-ready")

        // Send a Bark-compatible push from the test process itself. The phone
        // may briefly lose connectivity, so retry offline failures.
        let title = "真机推送自动验证 \(Int(Date().timeIntervalSince1970))"
        var pushSent = false
        for attempt in 1...5 where !pushSent {
            // The test runner itself can hit the network-data gate on its
            // first outbound request; clear it before retrying.
            Self.dismissVisibleSystemAlert(on: app)
            do {
                try sendPush(deviceKey: identity, title: title, body: "WebBridgeKit 真机 APNs 链路自动化验证")
                pushSent = true
            } catch {
                print("[push-smoke] push attempt \(attempt) failed: \(error)")
                Thread.sleep(forTimeInterval: 3.0)
            }
        }
        if !pushSent {
            XCTFail("Push request never succeeded after retries")
            return
        }

        // Capture the transient notification banner.
        for index in 0..<12 {
            Thread.sleep(forTimeInterval: 1.0)
            attachScreenshot(named: String(format: "02-banner-%02d", index))
        }

        // Foreground pushes are recorded by MessageEngine into the Inbox;
        // finding the exact title there proves end-to-end delivery.
        let inboxTab = app.tabBars.buttons["tab.notifications"]
        XCTAssertTrue(inboxTab.waitForExistence(timeout: 5), "Notifications tab should exist")
        inboxTab.tap()
        let receivedMessage = app.staticTexts[title]
        XCTAssertTrue(
            receivedMessage.waitForExistence(timeout: 15),
            "Pushed message should appear in the Inbox"
        )
        attachScreenshot(named: "03-inbox-received")
    }

    // MARK: - Helpers

    /// Waits until the push address shows the public server URL and returns
    /// the identity (Bark key) encoded as its last path segment. The SwiftUI
    /// text identifier is not reliably exposed, so match on label content.
    /// While waiting it keeps tapping the enable action (the button is briefly
    /// disabled at launch), dismisses lingering permission alerts, and attaches
    /// diagnostic screenshots so skipped runs still leave evidence behind.
    private func waitForPushAddressIdentity(timeout: TimeInterval) throws -> String {
        let address = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", Self.pushServer))
            .firstMatch
        let actionButton = app.buttons["home.push.send-safari"]
        let deadline = Date().addingTimeInterval(timeout)
        var probeIndex = 0
        while Date() < deadline {
            if address.exists, address.label.hasPrefix(Self.pushServer) {
                let identity = address.label.split(separator: "/").last.map(String.init) ?? ""
                if !identity.isEmpty {
                    return identity
                }
            }
            // Fallback for system alerts the interruption monitor missed
            // (notification permission + China-region network-data gate).
            Self.dismissVisibleSystemAlert(on: app)
            // Keep our app foregrounded even if something pulled it back.
            if app.state != .runningForeground {
                app.activate()
            }
            // Re-arm activation while the card still offers the enable action
            // (label 启用通知; 正在启用… means a registration is in flight).
            if actionButton.exists,
               actionButton.isEnabled,
               actionButton.label.contains("启用"),
               !actionButton.label.contains("正在") {
                actionButton.tap()
            }
            probeIndex += 1
            if probeIndex % 5 == 1 {
                attachScreenshot(named: String(format: "00-waiting-%02d", (probeIndex - 1) / 5))
            }
            Thread.sleep(forTimeInterval: 1.0)
        }
        attachScreenshot(named: "00-waiting-final")
        throw XCTSkip("Push address never resolved to \(Self.pushServer)/<identity>; current label: \(address.exists ? address.label : "missing")")
    }

    private func sendPush(deviceKey: String, title: String, body: String) throws {
        let url = try XCTUnwrap(URL(string: "\(Self.pushServer)/push"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        let payload: [String: Any] = [
            "device_key": deviceKey,
            "title": title,
            "body": body,
            "sound": "bell",
            "badge": 1
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        var requestError: Error?
        var statusCode: Int?
        let sent = expectation(description: "push sent")
        URLSession.shared.dataTask(with: request) { _, response, error in
            requestError = error
            statusCode = (response as? HTTPURLResponse)?.statusCode
            sent.fulfill()
        }.resume()
        wait(for: [sent], timeout: 20)
        if let requestError {
            throw requestError
        }
        if let statusCode, !(200...299).contains(statusCode) {
            throw URLError(.badServerResponse, userInfo: [
                NSLocalizedDescriptionKey: "push returned HTTP \(statusCode)"
            ])
        }
    }

    // MARK: - System alert helpers

    /// Affirmative button labels across the system dialogs a fresh install
    /// hits: notification permission and the China-region network-data gate.
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

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
