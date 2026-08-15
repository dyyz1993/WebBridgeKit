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
            "notification.group.login-requests"
        ]
        func firstHittable() -> XCUIElement? {
            candidates.compactMap { identifier in
                let element = app.descendants(matching: .any)
                    .matching(identifier: identifier).firstMatch
                return element.exists && element.isHittable ? element : nil
            }.first
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
        print("[ANIM-DIAG] pre-tap count=\(expandedCardCount) hittable=\(header.isHittable) id=\(header.identifier)")
        saveScreenshot("/tmp/wbk-anim/pre-tap.png")
        // Tap the header's Button (the actual cell carrying the gesture); the
        // outer container Other shares the identifier but does not deliver
        // touches to the cell's gesture recognizer.
        let headerButton = app.buttons.matching(
            NSPredicate(format: "identifier == %@", header.identifier as String? ?? "")
        ).firstMatch
        let tapTarget: XCUIElement = headerButton.exists ? headerButton : header
        mark("collapse1")
        tapTarget.tap()
        sleep(1)
        print("[ANIM-DIAG] post-tap count=\(notificationCardQuery.count) headerValue=\(header.value ?? "nil")")
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
}
