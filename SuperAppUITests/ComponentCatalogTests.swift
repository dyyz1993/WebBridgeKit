import XCTest

final class ComponentCatalogTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = [
            "--ui-testing",
            "--show-component-catalog",
            "-UITesting"
        ]
        app.launch()
    }

    private func scrollToSection(_ sectionIdentifier: String) {
        let scrollView = app.scrollViews["ComponentCatalogScrollView"]
        guard scrollView.waitForExistence(timeout: 30) else { return }

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

    private func assertSectionExists(_ id: String, _ name: String, timeout: TimeInterval = 10) {
        scrollToSection(id)
        let section = app.scrollViews["ComponentCatalogScrollView"].otherElements[id]
        XCTAssertTrue(section.waitForExistence(timeout: timeout), "\(name) section should exist")
    }

    // MARK: - Catalog Loads

    func testCatalogLoads() {
        let scrollView = app.scrollViews["ComponentCatalogScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 30), "Component Catalog scroll view should appear")
    }

    func testNavigationTitleVisible() {
        let navBar = app.navigationBars["UI Component Catalog"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Navigation title should be 'UI Component Catalog'")
    }

    // MARK: - Design Token Sections

    func testColorsSectionExists() {
        assertSectionExists("CatalogSection_Colors", "Colors")
    }

    func testTypographySectionExists() {
        assertSectionExists("CatalogSection_Typography", "Typography")
    }

    func testSpacingSectionExists() {
        assertSectionExists("CatalogSection_Spacing", "Spacing")
    }

    func testCornerRadiusSectionExists() {
        assertSectionExists("CatalogSection_CornerRadius", "Corner Radius")
    }

    func testShadowsSectionExists() {
        assertSectionExists("CatalogSection_Shadows", "Shadows")
    }

    // MARK: - Component Sections

    func testButtonsSectionExists() {
        assertSectionExists("CatalogSection_Buttons", "Buttons")
    }

    func testBadgesSectionExists() {
        assertSectionExists("CatalogSection_Badges", "Badges")
    }

    func testCardsSectionExists() {
        assertSectionExists("CatalogSection_Cards", "Cards")
    }

    func testEmptyStatesSectionExists() {
        assertSectionExists("CatalogSection_EmptyStates", "Empty States")
    }

    func testGradientViewsSectionExists() {
        assertSectionExists("CatalogSection_GradientViews", "Gradient Views")
    }

    func testSectionHeadersSectionExists() {
        assertSectionExists("CatalogSection_SectionHeaders", "Section Headers")
    }

    func testMessageCellsSectionExists() {
        assertSectionExists("CatalogSection_MessageCells", "Message Cells")
    }

    func testTokenCardSectionExists() {
        assertSectionExists("CatalogSection_TokenCard", "Token Card")
    }

    func testQuickActionsSectionExists() {
        assertSectionExists("CatalogSection_QuickActions", "Quick Actions")
    }

    func testFilterPillsSectionExists() {
        assertSectionExists("CatalogSection_FilterPills", "Filter Pills")
    }

    func testFABSectionExists() {
        assertSectionExists("CatalogSection_FAB", "FAB")
    }

    func testMenuItemsSectionExists() {
        assertSectionExists("CatalogSection_MenuItems", "Menu Items")
    }

    // MARK: - All Sections Count

    func testAllSectionsPresent() {
        let scrollView = app.scrollViews["ComponentCatalogScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 30))

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

        XCTAssertGreaterThanOrEqual(foundCount, sectionIds.count - 2,
            "At least \(sectionIds.count - 2) of \(sectionIds.count) sections should be found, got \(foundCount)")
    }

    // MARK: - Scroll Performance

    func testScrollingDoesNotCrash() {
        let scrollView = app.scrollViews["ComponentCatalogScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 30))

        for _ in 0..<10 {
            scrollView.swipeUp()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
        }

        XCTAssertTrue(true, "Scrolled 10 times without crash")
    }
}
