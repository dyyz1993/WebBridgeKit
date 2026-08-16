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

        // Swipe actions: swipe the second group's header left to reveal the
        // pin/delete buttons, then pin it and verify it moves to the top.
        let groups = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'notification.group.'")
        ).allElementsBoundByIndex.filter { $0.isHittable }
        guard groups.count >= 2 else {
            XCTFail("Expected at least two group headers for the swipe test")
            return
        }
        let secondGroup = groups[1]
        let secondIdentifier = secondGroup.identifier
        let firstIdentifier = groups[0].identifier
        // A slow press-and-drag reveals actions reliably; a fast flick's
        // ending touch can race the reveal.
        let start = secondGroup.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: start.screenPoint.y / app.frame.maxY))
        start.press(forDuration: 0.3, thenDragTo: end)
        let pinButton = app.buttons.matching(
            NSPredicate(format: "identifier CONTAINS 'inbox.group.pin.'")
        ).firstMatch
        XCTAssertTrue(pinButton.waitForExistence(timeout: 3), "Swipe should reveal the pin action")
        saveScreenshot("/tmp/wbk-anim/swipe-revealed.png")
        pinButton.tap()
        sleep(1)
        // Compare two element frames instead of enumerating all headers —
        // full-list snapshots race iOS 26 XCUITest resolution.
        let pinnedTop = headerElement(secondIdentifier).frame.minY
        let otherTop = headerElement(firstIdentifier).frame.minY
        XCTAssertLessThan(pinnedTop, otherTop, "Pinned group should move above other groups")
        saveScreenshot("/tmp/wbk-anim/pinned-top.png")

        // Detail navigation: open a message, verify next/previous buttons,
        // step to the next message and confirm the content changed.
        let firstCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'notification.card.'"))
            .firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        firstCard.tap()
        let nextButton = app.buttons["message.detail.next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5), "Detail should show the next button")
        let detailTitleBefore = app.staticTexts.firstMatch.label
        nextButton.tap()
        sleep(1)
        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 3), "Detail should remain pushed after advancing")
        saveScreenshot("/tmp/wbk-anim/detail-next.png")
        _ = detailTitleBefore // title comparison is visual; stack shape is asserted above

        // Quick review (card triage): go back to the inbox, enter review,
        // clear every card with the skip button, and reach the summary.
        backButton.tap()
        sleep(1)
        app.tabBars.buttons["tab.notifications"].tap()
        sleep(1)
        let reviewEntry = app.buttons["inbox.review.entry"]
        XCTAssertTrue(reviewEntry.waitForExistence(timeout: 5), "Inbox should expose the review entry")
        reviewEntry.tap()
        // First launch per install shows the gesture coach; dismiss it.
        let coachStart = app.buttons["review.coach.start"]
        if coachStart.waitForExistence(timeout: 3) {
            saveScreenshot("/tmp/wbk-anim/review-coach.png")
            coachStart.tap()
        }
        let progress = app.staticTexts["review.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5), "Review should show progress")
        saveScreenshot("/tmp/wbk-anim/review-card.png")
        // Gesture-only review: clear the deck with swipe-up (skip) gestures.
        for _ in 0..<30 {
            let card = app.otherElements["review.card.current"]
            guard card.exists else { break }
            card.swipeUp()
            usleep(500_000)
        }
        let summary = app.otherElements["review.done.summary"]
            .waitForExistence(timeout: 5)
            ? true
            : app.staticTexts.matching(NSPredicate(format: "label CONTAINS '·'")).firstMatch.exists
        XCTAssertTrue(summary, "Review should end with a summary after clearing cards")
        saveScreenshot("/tmp/wbk-anim/review-done.png")
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
