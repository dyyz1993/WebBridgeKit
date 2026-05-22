import XCTest

final class LayoutGuardTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--ui-testing"]
        app.launch()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 3)
    }

    private func navigateToTab(identifier: String, zhName: String, enName: String) {
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let button = tabBar.buttons[identifier].exists
                ? tabBar.buttons[identifier]
                : (tabBar.buttons[zhName].exists ? tabBar.buttons[zhName] : tabBar.buttons[enName])
            if button.exists { button.tap() }
        } else {
            let button = app.buttons[identifier].exists
                ? app.buttons[identifier]
                : (app.buttons[zhName].exists ? app.buttons[zhName] : app.buttons[enName])
            if button.exists { button.tap() }
        }
    }

    private func checkVisibleElementsNoZeroFrame(on tab: String) {
        let visible = app.otherElements.allElementsBoundByIndex
        var checked = 0
        for v in visible where v.isHittable {
            XCTAssert(v.frame.width > 0 && v.frame.height > 0, "\(tab): element has zero frame")
            checked += 1
            if checked >= 20 { break }
        }
    }

    // MARK: - Combined Layout Checks

    func testHomeLayoutIntegrity() {
        navigateToTab(identifier: "tab.home", zhName: "首页", enName: "Home")

        let cards = app.otherElements.matching(NSPredicate(format: "identifier == 'wbk_resource_card'")).allElementsBoundByIndex
        for card in cards.prefix(5) where card.isHittable {
            let h = card.frame.height
            XCTAssertGreaterThanOrEqual(h, 80, "Card height \(h) < 80")
            XCTAssertLessThanOrEqual(h, 140, "Card height \(h) > 140")
        }

        checkVisibleElementsNoZeroFrame(on: "Home")

        let wbkButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'wbk_'")).allElementsBoundByIndex
        for button in wbkButtons.prefix(10) where button.isHittable {
            let w = button.frame.width, h = button.frame.height
            guard w > 0, h > 0 else { continue }
            XCTAssertGreaterThanOrEqual(w, 44, "WBK button '\(button.identifier)' width \(w) < 44pt")
            XCTAssertGreaterThanOrEqual(h, 44, "WBK button '\(button.identifier)' height \(h) < 44pt")
        }
    }

    func testInboxLayoutIntegrity() {
        navigateToTab(identifier: "tab.inbox", zhName: "收信箱", enName: "Inbox")

        let searchField = app.otherElements["wbk_search_field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Inbox search field should exist")
        let h = searchField.frame.height
        XCTAssertGreaterThanOrEqual(h, 36, "Search height \(h) too small")
        XCTAssertLessThanOrEqual(h, 50, "Search height \(h) too large")

        let windowFrame = app.windows.firstMatch.frame
        XCTAssertTrue(windowFrame.contains(searchField.frame), "Search field not fully visible")

        checkVisibleElementsNoZeroFrame(on: "Inbox")

        let screenWidth = windowFrame.width
        let pills = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'filter_'")).allElementsBoundByIndex
        for pill in pills where pill.isHittable {
            XCTAssertLessThanOrEqual(pill.frame.maxX, screenWidth, "Filter pill extends beyond screen")
        }
    }

    func testDiscoverAndSettingsLayoutIntegrity() {
        navigateToTab(identifier: "tab.discover", zhName: "发现", enName: "Discover")
        checkVisibleElementsNoZeroFrame(on: "Discover")

        navigateToTab(identifier: "tab.settings", zhName: "设置", enName: "Settings")
        let settingsView = app.otherElements["SettingsViewController"]
        XCTAssertTrue(settingsView.waitForExistence(timeout: 3), "Settings view should exist")

        let rows = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'settings.cell.'")).allElementsBoundByIndex
        for row in rows where row.isHittable {
            XCTAssertGreaterThanOrEqual(row.frame.height, 44, "Settings row height \(row.frame.height) < 44")
        }

        checkVisibleElementsNoZeroFrame(on: "Settings")
    }

    // MARK: - Tab Bar & Navigation (combined)

    func testTabBarNavigationAndSafeArea() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3), "Tab bar should exist")
        let tabFrame = tabBar.frame

        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 3), "Navigation bar should exist")
        XCTAssertGreaterThanOrEqual(navBar.frame.origin.y, 44, "Nav bar overlaps status bar")

        let navBottom = navBar.frame.maxY
        XCTAssertGreaterThanOrEqual(navBottom, 47,
            "Nav bar bottom \(navBottom) overlaps status bar area")

        let tabTop = tabBar.frame.minY
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(tabTop, screen.height - tabBar.frame.height - 34,
            "Tab bar overlaps home indicator area")

        let tabs: [(String, String, String)] = [
            ("tab.home", "首页", "Home"),
            ("tab.inbox", "收信箱", "Inbox"),
            ("tab.discover", "发现", "Discover"),
            ("tab.settings", "设置", "Settings")
        ]
        for (id, zh, en) in tabs {
            navigateToTab(identifier: id, zhName: zh, enName: en)
            for sv in app.scrollViews.allElementsBoundByIndex where sv.isHittable {
                XCTAssertLessThanOrEqual(sv.frame.maxY, tabFrame.minY + 1, "\(en): Scroll overlaps tab bar")
            }
            for cv in app.collectionViews.allElementsBoundByIndex where cv.isHittable {
                XCTAssertLessThanOrEqual(cv.frame.maxY, tabFrame.minY + 1, "\(en): Collection overlaps tab bar")
            }
        }

        let tabButtons = tabBar.buttons.allElementsBoundByIndex
        for btn in tabButtons where btn.exists {
            XCTAssertGreaterThan(btn.frame.width, 0, "Tab button has zero width")
            XCTAssertLessThanOrEqual(btn.frame.maxX, screen.width,
                "Tab button extends beyond screen width")
        }
    }

    // MARK: - Empty State

    func testEmptyStateActionVisibleAboveTabBar() {
        navigateToTab(identifier: "tab.discover", zhName: "发现", enName: "Discover")
        let emptyState = app.otherElements["EmptyStateView"]
        guard emptyState.waitForExistence(timeout: 3) else { return }
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist")
        for button in emptyState.buttons.allElementsBoundByIndex where button.isHittable {
            XCTAssertLessThan(button.frame.maxY, tabBar.frame.minY, "Empty state button behind tab bar")
        }
    }

    // MARK: - Text & Frame Containment (lightweight)

    func testTextAndButtonsOnCurrentTab() {
        let screen = app.windows.element(boundBy: 0).frame

        let labels = app.staticTexts.allElementsBoundByIndex
        var labelChecked = 0
        for label in labels where label.exists {
            XCTAssertGreaterThan(label.frame.width, 0, "label '\(label.identifier)' has zero width")
            XCTAssertGreaterThan(label.frame.height, 0, "label '\(label.identifier)' has zero height")
            labelChecked += 1
            if labelChecked >= 30 { break }
        }

        let buttons = app.buttons.allElementsBoundByIndex
        var btnChecked = 0
        for element in buttons where element.isHittable {
            XCTAssertTrue(screen.contains(element.frame),
                "button '\(element.identifier)' frame \(element.frame) extends beyond screen \(screen)")
            btnChecked += 1
            if btnChecked >= 30 { break }
        }
    }
}

final class ComponentCatalogLayoutTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--ui-testing", "--show-component-catalog"]
        app.launch()
        _ = app.scrollViews["ComponentCatalogScrollView"].waitForExistence(timeout: 5)
    }

    func testLastItemInScrollViewCanBeScrolledIntoView() {
        let sv = app.scrollViews["ComponentCatalogScrollView"]
        XCTAssertTrue(sv.exists, "ComponentCatalogScrollView should exist")
        for _ in 0..<8 {
            sv.swipeUp()
        }
        if let last = sv.otherElements.allElementsBoundByIndex.last, last.exists {
            XCTAssertTrue(last.isHittable, "Last item not hittable after scrolling")
        }
    }

    func testComponentCatalogAllButtonsAccessible() {
        let sv = app.scrollViews["ComponentCatalogScrollView"]
        XCTAssertTrue(sv.exists, "ComponentCatalogScrollView should exist")
        var checked = 0
        for button in app.buttons.allElementsBoundByIndex where button.isHittable {
            XCTAssertGreaterThan(button.frame.width, 0, "Button zero width")
            XCTAssertGreaterThan(button.frame.height, 0, "Button zero height")
            checked += 1
            if checked >= 30 { break }
        }
    }
}
