//
//  UIFidelityTests.swift
//  SuperAppUITests
//
//  Automated UI Fidelity Screenshot Tests
//  Captures screenshots of each component catalog section for visual regression testing.
//

import XCTest

final class UIFidelityTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--show-component-catalog",
            "-UITesting"
        ]
        app.launch()
    }

    // MARK: - Screenshot Helper

    private func takeScreenshot(named name: String) -> XCTAttachment {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return attachment
    }

    private func scrollToSection(_ sectionIdentifier: String) {
        let scrollView = app.scrollViews["ComponentCatalogScrollView"]
        guard scrollView.waitForExistence(timeout: 10) else {
            XCTFail("ComponentCatalogScrollView not found")
            return
        }

        let section = scrollView.otherElements.matching(identifier: sectionIdentifier).firstMatch

        if !section.exists {
            scrollView.swipeUp()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
        }

        if section.exists && !section.isHittable {
            for _ in 0..<5 {
                scrollView.swipeUp()
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
                if section.isHittable { break }
            }
        }
    }

    // MARK: - Full Catalog Screenshot

    func testFullCatalogScreenshot() {
        let scrollView = app.scrollViews["ComponentCatalogScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10), "Component Catalog should be visible")
        takeScreenshot(named: "00-full-catalog-top")
    }

    // MARK: - Section 1: Colors

    func testColorTokensSection() {
        scrollToSection("CatalogSection_Colors")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_Colors"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Colors section should exist")
        takeScreenshot(named: "01-colors-tokens")
    }

    // MARK: - Section 2: Typography

    func testTypographySection() {
        scrollToSection("CatalogSection_Typography")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_Typography"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Typography section should exist")
        takeScreenshot(named: "02-typography-tokens")
    }

    // MARK: - Section 3: Spacing

    func testSpacingTokensSection() {
        scrollToSection("CatalogSection_Spacing")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_Spacing"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Spacing section should exist")
        takeScreenshot(named: "03-spacing-tokens")
    }

    // MARK: - Section 4: Corner Radius

    func testCornerRadiusSection() {
        scrollToSection("CatalogSection_CornerRadius")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_CornerRadius"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "CornerRadius section should exist")
        takeScreenshot(named: "04-corner-radius")
    }

    // MARK: - Section 5: Shadows

    func testShadowsSection() {
        scrollToSection("CatalogSection_Shadows")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_Shadows"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Shadows section should exist")
        takeScreenshot(named: "05-shadows")
    }

    // MARK: - Section 6: Buttons

    func testButtonsSection() {
        scrollToSection("CatalogSection_Buttons")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_Buttons"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Buttons section should exist")
        takeScreenshot(named: "06-buttons")
    }

    // MARK: - Section 7: Badges

    func testBadgesSection() {
        scrollToSection("CatalogSection_Badges")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_Badges"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Badges section should exist")
        takeScreenshot(named: "07-badges")
    }

    // MARK: - Section 8: Cards

    func testCardsSection() {
        scrollToSection("CatalogSection_Cards")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_Cards"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Cards section should exist")
        takeScreenshot(named: "08-cards")
    }

    // MARK: - Section 9: Empty States

    func testEmptyStatesSection() {
        scrollToSection("CatalogSection_EmptyStates")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_EmptyStates"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Empty States section should exist")
        takeScreenshot(named: "09-empty-states")
    }

    // MARK: - Section 10: Gradient Views

    func testGradientViewsSection() {
        scrollToSection("CatalogSection_GradientViews")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_GradientViews"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Gradient Views section should exist")
        takeScreenshot(named: "10-gradient-views")
    }

    // MARK: - Section 11: Section Headers

    func testSectionHeadersSection() {
        scrollToSection("CatalogSection_SectionHeaders")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_SectionHeaders"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Section Headers should exist")
        takeScreenshot(named: "11-section-headers")
    }

    // MARK: - Section 12: Message Cells

    func testMessageCellsSection() {
        scrollToSection("CatalogSection_MessageCells")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_MessageCells"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Message Cells section should exist")
        takeScreenshot(named: "12-message-cells")
    }

    // MARK: - Section 13: Token Card

    func testTokenCardSection() {
        scrollToSection("CatalogSection_TokenCard")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_TokenCard"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Token Card section should exist")
        takeScreenshot(named: "13-token-card")
    }

    // MARK: - Section 14: Quick Actions

    func testQuickActionsSection() {
        scrollToSection("CatalogSection_QuickActions")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_QuickActions"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Quick Actions section should exist")
        takeScreenshot(named: "14-quick-actions")
    }

    // MARK: - Section 15: Filter Pills

    func testFilterPillsSection() {
        scrollToSection("CatalogSection_FilterPills")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_FilterPills"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Filter Pills section should exist")
        takeScreenshot(named: "15-filter-pills")
    }

    // MARK: - Section 16: FAB

    func testFABSection() {
        scrollToSection("CatalogSection_FAB")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_FAB"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "FAB section should exist")
        takeScreenshot(named: "16-fab")
    }

    // MARK: - Section 17: Menu Items

    func testMenuItemsSection() {
        scrollToSection("CatalogSection_MenuItems")
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements["CatalogSection_MenuItems"]
        XCTAssertTrue(section.waitForExistence(timeout: 10), "Menu Items section should exist")
        takeScreenshot(named: "17-menu-items")
    }

    // MARK: - Scrolling Through All Sections (Integration)

    func testScrollThroughAllSections() {
        let scrollView = app.scrollViews["ComponentCatalogScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10))

        let sectionIds = [
            "CatalogSection_Colors",
            "CatalogSection_Typography",
            "CatalogSection_Spacing",
            "CatalogSection_CornerRadius",
            "CatalogSection_Shadows",
            "CatalogSection_Buttons",
            "CatalogSection_Badges",
            "CatalogSection_Cards",
            "CatalogSection_EmptyStates",
            "CatalogSection_GradientViews",
            "CatalogSection_SectionHeaders",
            "CatalogSection_MessageCells",
            "CatalogSection_TokenCard",
            "CatalogSection_QuickActions",
            "CatalogSection_FilterPills",
            "CatalogSection_FAB",
            "CatalogSection_MenuItems"
        ]

        var foundCount = 0
        for sectionId in sectionIds {
            scrollToSection(sectionId)
            let section = scrollView.otherElements[sectionId]
            if section.exists {
                foundCount += 1
            }
            scrollView.swipeUp()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        }

        XCTAssertGreaterThan(foundCount, sectionIds.count / 2,
            "At least half of sections (\(sectionIds.count / 2)) should be found, got \(foundCount)")
        takeScreenshot(named: "99-all-sections-scrolled")
    }
}
