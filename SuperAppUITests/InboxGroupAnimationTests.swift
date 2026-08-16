import XCTest

/// Animation probe + regression for the inbox notification group accordion.
///
/// The test itself asserts collapse/expand correctness and display-mode
/// switching; mid-animation quality is verified by recording the simulator
/// screen (`xcrun simctl io booted recordVideo`) while this test runs and
/// inspecting the extracted frames.
final class InboxGroupAnimationTests: XCTestCase {

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

    private var notificationCardQuery: XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'notification.card.'"))
    }

    /// Drops a wallclock anchor so video frames can be mapped to exact events
    /// during animation verification.
    private func mark(_ name: String) {
        let path = "/tmp/wbk-anim/anchor-\(name)-\(String(format: "%.3f", Date().timeIntervalSince1970))"
        FileManager.default.createFile(atPath: path, contents: nil)
    }

    /// Finds the first seeded group header that is on screen, scrolling once
    /// if none of the candidates is hittable.
    private func firstVisibleGroupHeader() -> XCUIElement? {
        let candidates = [
            "notification.group.security-alerts",
            "notification.group.verification-codes",
            "notification.group.agent-approvals",
            "notification.group.team-chat-linmo",
            "notification.group.server-alerts",
            "notification.group.system-notices",
            "notification.group.agent-tasks",
            "notification.group.design-reviews",
            "notification.group.login-requests",
            "notification.group.weather-updates",
            "notification.group.shop-orders",
            "notification.group.shop-promo",
            "notification.group.game-invites",
            "notification.group.other"
        ]
        func firstHittable() -> XCUIElement? {
            let visible = candidates.compactMap { identifier -> XCUIElement? in
                guard isOnScreen(identifier, timeout: 0.2) else { return nil }
                return headerElement(identifier)
            }
            if let header = visible.first { return header }
            // Deep scrolls can land on groups outside the candidate list; fall
            // back to any header-shaped element currently on screen.
            return app.otherElements.matching(
                NSPredicate(format: "identifier BEGINSWITH 'notification.group.'")
            ).allElementsBoundByIndex.first {
                let frame = $0.frame
                return frame.height > 0 && frame.minY >= 0 && frame.maxY <= app.frame.maxY
            }
        }
        if let header = firstHittable() { return header }
        app.swipeUp()
        return firstHittable()
    }

    func testGroupCollapseExpandAndDisplayModeTransitions() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should exist")
        tabBar.buttons["tab.notifications"].tap()
        sleep(1)

        let displayMode = app.segmentedControls["inbox.displayMode"]
        XCTAssertTrue(displayMode.waitForExistence(timeout: 5))
        displayMode.buttons["分组"].tap()
        sleep(1)

        let header = try XCTUnwrap(firstVisibleGroupHeader(), "No seeded group header is visible")
        let expandedCardCount = notificationCardQuery.count
        XCTAssertGreaterThan(expandedCardCount, 0, "Groups mode should show seeded cards")

        // Round 1: collapse (fold animation + below sections sliding up),
        // then expand (staggered slide-from-header entrance).
        // Round 1: collapse (fold animation + below sections sliding up),
        // then expand (staggered slide-from-header entrance).
        mark("collapse1")
        header.tap()
        sleep(1)
        saveScreenshot("/tmp/wbk-anim/groups-collapsed.png")
        let collapsedCardCount = notificationCardQuery.count
        XCTAssertLessThan(collapsedCardCount, expandedCardCount, "Collapsing a group should hide its cards")

        mark("expand1")
        header.tap()
        sleep(1)
        saveScreenshot("/tmp/wbk-anim/groups-expanded.png")
        XCTAssertEqual(notificationCardQuery.count, expandedCardCount, "Expanding should restore the cards")

        // Long press to exercise the header's pressed highlight state.
        mark("press-down")
        header.press(forDuration: 0.6)
        mark("press-up")
        sleep(1)

        // Round 2: a second toggle round for mid-animation video coverage.
        mark("collapse2")
        header.tap()
        sleep(1)
        mark("expand2")
        header.tap()
        sleep(1)

        // Rapid double toggle (350ms) guards the animation-overlap mutex.
        mark("rapid-1")
        header.tap()
        usleep(350_000)
        mark("rapid-2")
        header.tap()
        sleep(2)

        // Display-mode transitions should cross-dissolve rather than snap.
        mark("mode-latest")
        displayMode.buttons["最新"].tap()
        sleep(1)
        saveScreenshot("/tmp/wbk-anim/mode-latest.png")
        mark("mode-groups")
        displayMode.buttons["分组"].tap()
        sleep(1)
        saveScreenshot("/tmp/wbk-anim/mode-groups.png")
        XCTAssertEqual(notificationCardQuery.count, expandedCardCount)
    }

    /// Group headers surface as `otherElements` with `notification.group.*`
    /// identifiers; resolving against that small collection keeps the
    /// accessibility scan cheap. Full-tree `descendants(.any)` queries
    /// saturate the app's main thread for seconds and freeze the UI under
    /// automation.
    private func headerElement(_ identifier: String) -> XCUIElement {
        app.otherElements.matching(identifier: identifier).firstMatch
    }

    /// `isHittable` can hard-fail when the snapshot goes stale mid-scroll;
    /// `waitForExistence` polls safely and the frame check filters off-screen
    /// headers without hitting the same resolution path.
    private func isOnScreen(_ identifier: String, timeout: TimeInterval = 1) -> Bool {
        let element = headerElement(identifier)
        guard element.waitForExistence(timeout: timeout) else { return false }
        let frame = element.frame
        return frame.height > 0 && frame.minY >= 0 && frame.maxY <= app.frame.maxY
    }


}
